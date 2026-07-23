#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sqlite3.h>
#include <mongoose.h>

#define MAX_LINE 256

typedef struct {
    int port;
    char db_path[256];
} Config;

Config config;

// Read config file
void read_config(const char *filename) {
    FILE *file = fopen(filename, "r");
    if (!file) {
        fprintf(stderr, "Warning: Could not open %s, using defaults\n", filename);
        return;
    }
    
    char line[MAX_LINE];
    while (fgets(line, sizeof(line), file)) {
        if (line[0] == '#' || line[0] == '\n') continue;
        
        char key[64], value[256];
        if (sscanf(line, "%[^=]=%s", key, value) == 2) {
            value[strcspn(value, "\n")] = 0;
            
            if (strcmp(key, "SLAVE_PORT") == 0) config.port = atoi(value);
            else if (strcmp(key, "SLAVE_DB") == 0) strcpy(config.db_path, value);
        }
    }
    fclose(file);
}

static char *query_local_db(const char *db_path, const char *sensor_type, const char *sensor_id) {
    sqlite3 *db;
    sqlite3_stmt *stmt;
    char *result = NULL;
    char sql[512];
    
    if (sqlite3_open(db_path, &db) != SQLITE_OK) {
        return NULL;
    }
    
    snprintf(sql, sizeof(sql), 
             "SELECT s.sensor_id, s.sensor_type, s.sensor_name, r.value, s.unit, r.recorded_at "
             "FROM sensors s JOIN sensor_readings r ON s.sensor_id = r.sensor_id "
             "WHERE s.sensor_type = '%s' AND s.sensor_id = '%s' "
             "ORDER BY datetime(r.recorded_at) DESC LIMIT 1",
             sensor_type, sensor_id);
    
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            result = malloc(512);
            snprintf(result, 512, 
                     "{\"sensor_id\":\"%s\",\"sensor_type\":\"%s\",\"sensor_name\":\"%s\","
                     "\"value\":\"%s\",\"unit\":\"%s\",\"recorded_at\":\"%s\"}",
                     sqlite3_column_text(stmt, 0),
                     sqlite3_column_text(stmt, 1),
                     sqlite3_column_text(stmt, 2),
                     sqlite3_column_text(stmt, 3),
                     sqlite3_column_text(stmt, 4),
                     sqlite3_column_text(stmt, 5));
        }
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    return result;
}

static void http_handler(struct mg_connection *c, int ev, void *ev_data) {
    if (ev == MG_EV_HTTP_MSG) {
        struct mg_http_message *hm = (struct mg_http_message *)ev_data;
        
        if (mg_strcmp(hm->uri, mg_str("/query")) == 0) {
            char sensor_type[64], sensor_id[64];
            mg_http_get_var(&hm->query, "sensor_type", sensor_type, sizeof(sensor_type));
            mg_http_get_var(&hm->query, "sensor_id", sensor_id, sizeof(sensor_id));
            
            char *response = query_local_db(config.db_path, sensor_type, sensor_id);
            
            if (response) {
                mg_http_reply(c, 200, "Content-Type: application/json\r\n", "%s", response);
                free(response);
            } else {
                mg_http_reply(c, 404, "Content-Type: application/json\r\n", 
                             "{\"error\":\"Sensor data not found\"}");
            }
        }
    }
}

int main(int argc, char *argv[]) {
    // Set defaults
    config.port = 8081;
    strcpy(config.db_path, "slave.db");
    
    if (argc >= 2) {
        read_config(argv[1]);
    } else {
        read_config("config.example");
    }
    
    struct mg_mgr mgr;
    mg_mgr_init(&mgr);
    
    char addr[32];
    snprintf(addr, sizeof(addr), "http://0.0.0.0:%d", config.port);
    mg_http_listen(&mgr, addr, http_handler, NULL);
    
    printf("Slave server running on port %d\n", config.port);
    printf("Using database: %s\n", config.db_path);
    
    while (1) {
        mg_mgr_poll(&mgr, 1000);
    }
    
    mg_mgr_free(&mgr);
    return 0;
}
