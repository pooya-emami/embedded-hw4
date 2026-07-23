#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <chrono>
#include <sqlite3.h>
#include <curl/curl.h>
#include <libmemcached/memcached.h>

#include "mongoose.h"

struct Config {
    int port = 8080;
    std::string db = "master.db";

    std::string slave1_ip = "127.0.0.1";
    int slave1_port = 8081;

    std::string slave2_ip = "127.0.0.1";
    int slave2_port = 8082;

    std::string memcached_host = "127.0.0.1";
    int memcached_port = 11211;
};

Config cfg;
memcached_st* memc = nullptr;

void load_config(const std::string &file_name) {
    std::ifstream f(file_name);
    if (!f.is_open()) {
        std::cout << "Using default configuration\n";
        return;
    }

    std::string line;
    while (std::getline(f, line)) {
        if (line.empty() || line[0] == '#') continue;

        std::string key, value;
        std::stringstream ss(line);

        if (std::getline(ss, key, '=') && std::getline(ss, value)) {
            if (key == "MASTER_PORT") cfg.port = std::stoi(value);
            else if (key == "MASTER_DB") cfg.db = value;
            else if (key == "SLAVE1_IP") cfg.slave1_ip = value;
            else if (key == "SLAVE1_PORT") cfg.slave1_port = std::stoi(value);
            else if (key == "SLAVE2_IP") cfg.slave2_ip = value;
            else if (key == "SLAVE2_PORT") cfg.slave2_port = std::stoi(value);
            else if (key == "MEMCACHED_HOST") cfg.memcached_host = value;
            else if (key == "MEMCACHED_PORT") cfg.memcached_port = std::stoi(value);
        }
    }
}

struct CurlBuffer { std::string data; };

static size_t curl_write(void *ptr, size_t size, size_t nmemb, void *userdata) {
    size_t len = size * nmemb;
    auto *buf = static_cast<CurlBuffer*>(userdata);
    buf->data.append(static_cast<char*>(ptr), len);
    return len;
}

std::string ask_slave(const std::string &ip, int port,
                      const std::string &type, const std::string &id) {
    CURL *curl = curl_easy_init();
    if (!curl) return "";

    std::stringstream url;
    url << "http://" << ip << ":" << port
        << "/query?sensor_type=" << type
        << "&sensor_id=" << id;

    CurlBuffer buf;

    curl_easy_setopt(curl, CURLOPT_URL, url.str().c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_write);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buf);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 5);

    CURLcode res = curl_easy_perform(curl);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) return "";
    return buf.data;
}

std::string search_database(const std::string &db_file,
                            const std::string &type,
                            const std::string &id) {
    sqlite3 *db;
    sqlite3_stmt *stmt;

    if (sqlite3_open(db_file.c_str(), &db) != SQLITE_OK)
        return "";

    std::stringstream sql;
    sql << "SELECT s.sensor_id,s.sensor_type,s.sensor_name,"
           "r.value,s.unit,r.recorded_at "
           "FROM sensors s JOIN sensor_readings r "
           "ON s.sensor_id=r.sensor_id "
           "WHERE s.sensor_type='" << type << "' "
           "AND s.sensor_id='" << id << "' "
           "ORDER BY datetime(r.recorded_at) DESC LIMIT 1";

    std::string result;

    if (sqlite3_prepare_v2(db, sql.str().c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            std::stringstream json;
            json << "{"
                 << "\"sensor_id\":\"" << sqlite3_column_text(stmt,0) << "\","
                 << "\"sensor_type\":\"" << sqlite3_column_text(stmt,1) << "\","
                 << "\"sensor_name\":\"" << sqlite3_column_text(stmt,2) << "\","
                 << "\"value\":\"" << sqlite3_column_text(stmt,3) << "\","
                 << "\"unit\":\"" << sqlite3_column_text(stmt,4) << "\","
                 << "\"recorded_at\":\"" << sqlite3_column_text(stmt,5) << "\""
                 << "}";
            result = json.str();
        }
        sqlite3_finalize(stmt);
    }

    sqlite3_close(db);
    return result;
}

void init_memcached() {
    std::stringstream ss;
    ss << cfg.memcached_host << ":" << cfg.memcached_port;

    memc = memcached_create(nullptr);
    memcached_server_st* servers = memcached_servers_parse(ss.str().c_str());
    memcached_server_push(memc, servers);
    memcached_server_list_free(servers);
}

std::string cache_key(const std::string &type, const std::string &id) {
    return type + ":" + id;
}

std::string get_from_cache(const std::string &type, const std::string &id) {
    if (!memc) return "";
    std::string key = cache_key(type, id);

    size_t value_length;
    uint32_t flags;
    memcached_return rc;

    char* value = memcached_get(memc, key.c_str(), key.size(),
                                &value_length, &flags, &rc);

    if (rc != MEMCACHED_SUCCESS || !value) return "";

    std::string result(value, value_length);
    free(value);
    return result;
}

void set_cache(const std::string &type, const std::string &id,
               const std::string &value, int ttl_seconds = 60) {
    if (!memc) return;
    std::string key = cache_key(type, id);
    memcached_set(memc, key.c_str(), key.size(),
                  value.c_str(), value.size(),
                  ttl_seconds, 0);
}

void handler(struct mg_connection *c, int ev, void *data) {
    if (ev != MG_EV_HTTP_MSG) return;

    auto *msg = (mg_http_message*) data;

    if (mg_strcmp(msg->uri, mg_str("/query")) != 0)
        return;

    char type[64], id[64];
    mg_http_get_var(&msg->query, "sensor_type", type, sizeof(type));
    mg_http_get_var(&msg->query, "sensor_id", id, sizeof(id));

    std::string sensor_type = type;
    std::string sensor_id = id;

    auto start = std::chrono::steady_clock::now();

    // 1) Try cache
    std::string answer = get_from_cache(sensor_type, sensor_id);

    // 2) Cache miss → DB → slaves → then cache
    if (answer.empty()) {
        answer = search_database(cfg.db, sensor_type, sensor_id);

        if (answer.empty()) {
            answer = ask_slave(cfg.slave1_ip, cfg.slave1_port,
                               sensor_type, sensor_id);

            if (answer.empty() || answer.find("\"error\"") != std::string::npos) {
                answer = ask_slave(cfg.slave2_ip, cfg.slave2_port,
                                   sensor_type, sensor_id);
            }
        }

        if (!answer.empty()) {
            set_cache(sensor_type, sensor_id, answer);
        }
    }

    auto end = std::chrono::steady_clock::now();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();

    if (!answer.empty()) {
        std::stringstream wrapped;
        wrapped << "{"
                << "\"data\":" << answer << ","
                << "\"response_time_ms\":" << ms
                << "}";

        mg_http_reply(c, 200,
                      "Content-Type: application/json\r\n",
                      "%s", wrapped.str().c_str());
    } else {
        mg_http_reply(c, 404,
                      "Content-Type: application/json\r\n",
                      "{\"error\":\"Sensor data not found\",\"response_time_ms\":"
                      + std::to_string(ms) + "}");
    }
}

int main(int argc, char **argv) {
    load_config(argc > 1 ? argv[1] : "config.example");
    init_memcached();

    mg_mgr mgr{};
    mg_mgr_init(&mgr);

    std::stringstream addr;
    addr << "http://0.0.0.0:" << cfg.port;
    std::string address = addr.str();

    mg_http_listen(&mgr, address.c_str(), handler, nullptr);

    std::cout << "Master (with cache) running on port " << cfg.port << "\n";

    while (true) {
        mg_mgr_poll(&mgr, 1000);
    }

    mg_mgr_free(&mgr);
    if (memc) memcached_free(memc);
    return 0;
}
