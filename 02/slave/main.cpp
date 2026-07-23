#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <sqlite3.h>
#include <libmemcached/memcached.h>

#include "mongoose.h"

struct Config {
    int port = 8081;
    std::string db = "slave.db";

    std::string memcached_ip = "127.0.0.1";
    int memcached_port = 11211;
};

Config cfg;
memcached_st *memc = nullptr;

void load_config(const std::string &filename) {
    std::ifstream f(filename);
    if (!f.is_open()) {
        std::cout << "Using default settings\n";
        return;
    }

    std::string line;
    while (std::getline(f, line)) {
        if (line.empty() || line[0] == '#') continue;

        std::string key, value;
        std::stringstream ss(line);

        if (std::getline(ss, key, '=') && std::getline(ss, value)) {
            if (key == "SLAVE_PORT") cfg.port = std::stoi(value);
            else if (key == "SLAVE_DB") cfg.db = value;
            else if (key == "MEMCACHED_IP") cfg.memcached_ip = value;
            else if (key == "MEMCACHED_PORT") cfg.memcached_port = std::stoi(value);
        }
    }
}

std::string cache_get(const std::string &key) {
    size_t value_length;
    uint32_t flags;

    char *value = memcached_get(memc, key.c_str(), key.size(),
                                &value_length, &flags, nullptr);

    if (!value) return "";

    std::string result(value, value_length);
    free(value);
    return result;
}

void cache_set(const std::string &key, const std::string &value) {
    memcached_set(memc, key.c_str(), key.size(),
                  value.c_str(), value.size(),
                  3600, 0);
}

std::string get_sensor_data_sqlite(const std::string &db_name,
                                   const std::string &type,
                                   const std::string &id) {
    sqlite3 *db;
    sqlite3_stmt *stmt;

    if (sqlite3_open(db_name.c_str(), &db) != SQLITE_OK)
        return "";

    std::stringstream query;
    query << "SELECT s.sensor_id,s.sensor_type,s.sensor_name,"
             "r.value,s.unit,r.recorded_at "
             "FROM sensors s JOIN sensor_readings r "
             "ON s.sensor_id=r.sensor_id "
             "WHERE s.sensor_type='" << type << "' "
             "AND s.sensor_id='" << id << "' "
             "ORDER BY datetime(r.recorded_at) DESC LIMIT 1";

    std::string result;

    if (sqlite3_prepare_v2(db, query.str().c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
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

    std::string cache_key = sensor_type + "_" + sensor_id;

    // Try cache first
    std::string reply = cache_get(cache_key);

    // If not cached, read SQLite
    if (reply.empty()) {
        reply = get_sensor_data_sqlite(cfg.db, sensor_type, sensor_id);

        // If found, store in cache
        if (!reply.empty()) {
            cache_set(cache_key, reply);
        }
    }

    if (!reply.empty()) {
        mg_http_reply(c, 200,
                      "Content-Type: application/json\r\n",
                      "%s", reply.c_str());
    } else {
        mg_http_reply(c, 404,
                      "Content-Type: application/json\r\n",
                      "{\"error\":\"Sensor data not found\"}");
    }
}

int main(int argc, char **argv) {
    load_config(argc > 1 ? argv[1] : "config.example");

    memc = memcached_create(nullptr);
    memcached_server_add(memc, cfg.memcached_ip.c_str(), cfg.memcached_port);

    mg_mgr mgr;
    mg_mgr_init(&mgr);

    std::stringstream address;
    address << "http://0.0.0.0:" << cfg.port;

    mg_http_listen(&mgr, address.str().c_str(), handler, nullptr);

    std::cout << "Slave running on port " << cfg.port << "\n";
    std::cout << "Database: " << cfg.db << "\n";

    while (true)
        mg_mgr_poll(&mgr, 1000);

    mg_mgr_free(&mgr);
    memcached_free(memc);
    return 0;
}
