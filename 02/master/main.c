#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sqlite3.h>
#include <curl/curl.h>
#include <mongoose.h>
#include <libmemcached/memcached.h>

#define MAX_LINE 256

typedef struct {
    int port;
    char db[256];
    char slave1_ip[64];
    int slave1_port;
    char slave2_ip[64];
    int slave2_port;
    char memcached_host[64];
    int memcached_port;
} Config;

Config cfg;
memcached_st *memc;

void load_config(const char *file_name)
{
    FILE *f = fopen(file_name, "r");

    if (!f) {
        printf("Using default configuration\n");
        return;
    }

    char line[MAX_LINE];

    while (fgets(line, sizeof(line), f)) {
        if (line[0] == '#' || line[0] == '\n')
            continue;

        char key[64], value[256];

        if (sscanf(line, "%[^=]=%s", key, value) != 2)
            continue;

        if (!strcmp(key, "MASTER_PORT"))
            cfg.port = atoi(value);
        else if (!strcmp(key, "MASTER_DB"))
            strcpy(cfg.db, value);
        else if (!strcmp(key, "SLAVE1_IP"))
            strcpy(cfg.slave1_ip, value);
        else if (!strcmp(key, "SLAVE1_PORT"))
            cfg.slave1_port = atoi(value);
        else if (!strcmp(key, "SLAVE2_IP"))
            strcpy(cfg.slave2_ip, value);
        else if (!strcmp(key, "SLAVE2_PORT"))
            cfg.slave2_port = atoi(value);
        else if (!strcmp(key, "MEMCACHED_HOST"))
            strcpy(cfg.memcached_host, value);
        else if (!strcmp(key, "MEMCACHED_PORT"))
            cfg.memcached_port = atoi(value);
    }

    fclose(f);
}

char *cache_get(const char *type, const char *id)
{
    if (!memc) return NULL;

    char key[128];
    sprintf(key, "%s:%s", type, id);

    size_t len;
    uint32_t flags;
    return memcached_get(memc, key, strlen(key), &len, &flags, NULL);
}

void cache_set(const char *type, const char *id, const char *data)
{
    if (!memc) return;

    char key[128];
    sprintf(key, "%s:%s", type, id);
    memcached_set(memc, key, strlen(key), data, strlen(data), 300, 0);
}

struct buffer {
    char *data;
    size_t size;
};

static size_t curl_write(void *ptr, size_t size, size_t nmemb, void *userdata)
{
    struct buffer *buf = userdata;
    size_t len = size * nmemb;

    buf->data = realloc(buf->data, buf->size + len + 1);
    memcpy(buf->data + buf->size, ptr, len);
    buf->size += len;
    buf->data[buf->size] = '\0';

    return len;
}

char *ask_slave(char *ip, int port, char *type, char *id)
{
    CURL *curl = curl_easy_init();

    if (!curl)
        return NULL;

    char url[256];
    sprintf(url, "http://%s:%d/query?sensor_type=%s&sensor_id=%s",
            ip, port, type, id);

    struct buffer buf = {NULL, 0};

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_write);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buf);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 5);

    if (curl_easy_perform(curl) != CURLE_OK) {
        free(buf.data);
        buf.data = NULL;
    }

    curl_easy_cleanup(curl);
    return buf.data;
}

char *search_database(char *db_file, char *type, char *id)
{
    char *cached = cache_get(type, id);
    if (cached) {
        printf("Cache HIT: %s:%s\n", type, id);
        return cached;
    }
    printf("Cache MISS: %s:%s\n", type, id);

    sqlite3 *db;
    sqlite3_stmt *stmt;

    if (sqlite3_open(db_file, &db) != SQLITE_OK)
        return NULL;

    char sql[512];
    sprintf(sql,
        "SELECT s.sensor_id,s.sensor_type,s.sensor_name,"
        "r.value,s.unit,r.recorded_at "
        "FROM sensors s JOIN sensor_readings r "
        "ON s.sensor_id=r.sensor_id "
        "WHERE s.sensor_type='%s' AND s.sensor_id='%s' "
        "ORDER BY datetime(r.recorded_at) DESC LIMIT 1",
        type, id);

    char *result = NULL;

    if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            result = malloc(512);
            sprintf(result,
                "{\"sensor_id\":\"%s\","
                "\"sensor_type\":\"%s\","
                "\"sensor_name\":\"%s\","
                "\"value\":\"%s\","
                "\"unit\":\"%s\","
                "\"recorded_at\":\"%s\"}",
                sqlite3_column_text(stmt,0),
                sqlite3_column_text(stmt,1),
                sqlite3_column_text(stmt,2),
                sqlite3_column_text(stmt,3),
                sqlite3_column_text(stmt,4),
                sqlite3_column_text(stmt,5));

            if (result)
                cache_set(type, id, result);
        }
        sqlite3_finalize(stmt);
    }

    sqlite3_close(db);
    return result;
}

void handler(struct mg_connection *c, int ev, void *data)
{
    if (ev != MG_EV_HTTP_MSG)
        return;

    struct mg_http_message *msg = data;

    if (mg_strcmp(msg->uri, mg_str("/query")))
        return;

    char type[64];
    char id[64];

    mg_http_get_var(&msg->query, "sensor_type", type, sizeof(type));
    mg_http_get_var(&msg->query, "sensor_id", id, sizeof(id));

    char *answer = search_database(cfg.db, type, id);

    if (!answer) {
        answer = ask_slave(cfg.slave1_ip, cfg.slave1_port, type, id);

        if (!answer || strstr(answer, "\"error\"")) {
            free(answer);
            answer = ask_slave(cfg.slave2_ip, cfg.slave2_port, type, id);
        }

        if (answer && !strstr(answer, "\"error\""))
            cache_set(type, id, answer);
    }

    if (answer) {
        mg_http_reply(c, 200,
                      "Content-Type: application/json\r\n",
                      "%s", answer);
        free(answer);
    } else {
        mg_http_reply(c, 404,
                      "Content-Type: application/json\r\n",
                      "{\"error\":\"Sensor data not found\"}");
    }
}

int main(int argc, char **argv)
{
    cfg.port = 8080;
    strcpy(cfg.db, "master.db");
    strcpy(cfg.slave1_ip, "127.0.0.1");
    cfg.slave1_port = 8081;
    strcpy(cfg.slave2_ip, "127.0.0.1");
    cfg.slave2_port = 8082;
    strcpy(cfg.memcached_host, "127.0.0.1");
    cfg.memcached_port = 11211;

    load_config(argc > 1 ? argv[1] : "config.example");

    memc = memcached_create(NULL);
    memcached_server_add(memc, cfg.memcached_host, cfg.memcached_port);

    struct mg_mgr mgr;
    mg_mgr_init(&mgr);

    char address[64];
    sprintf(address, "http://0.0.0.0:%d", cfg.port);

    mg_http_listen(&mgr, address, handler, NULL);

    printf("Master running on port %d\n", cfg.port);
    printf("Memcached: %s:%d\n", cfg.memcached_host, cfg.memcached_port);

    while(1)
        mg_mgr_poll(&mgr, 1000);

    mg_mgr_free(&mgr);
    return 0;
}