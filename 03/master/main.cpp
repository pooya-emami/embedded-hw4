#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <sqlite3.h>
#include <curl/curl.h>
#include <libmemcached/memcached.h>
#include <mosquitto.h>
#include "mongoose.h"

struct Config {
    int port = 8080;
    std::string db = "master.db";

    std::string slave1_ip = "127.0.0.1";
    int slave1_port = 8081;

    std::string slave2_ip = "127.0.0.1";
    int slave2_port = 8082;

    std::string memcached_ip = "127.0.0.1";
    int memcached_port = 11211;

    std::string mqtt_broker_ip = "127.0.0.1";
    int mqtt_broker_port = 1883;
    std::string mqtt_request_topic = "sensors/request";
    std::string mqtt_response_topic = "sensors/response";
};

Config cfg;
memcached_st *memc = nullptr;
struct mosquitto *mosq = nullptr;

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
            else if (key == "MEMCACHED_IP") cfg.memcached_ip = value;
            else if (key == "MEMCACHED_PORT") cfg.memcached_port = std::stoi(value);
            else if (key == "MQTT_BROKER_IP") cfg.mqtt_broker_ip = value;
            else if (key == "MQTT_BROKER_PORT") cfg.mqtt_broker_port = std::stoi(value);
            else if (key == "MQTT_REQUEST_TOPIC") cfg.mqtt_request_topic = value;
            else if (key == "MQTT_RESPONSE_TOPIC") cfg.mqtt_response_topic = value;
        }
    }
}

struct CurlBuffer {
    std::string data;
};

static size_t curl_write(void *ptr, size_t size, size_t nmemb, void *userdata) {
    size_t len = size * nmemb;
    CurlBuffer *buf = static_cast<CurlBuffer*>(userdata);
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

std::string resolve_sensor(const std::string &sensor_type, const std::string &sensor_id) {
    std::string cache_key = sensor_type + "_" + sensor_id;

    std::string answer = cache_get(cache_key);

    if (answer.empty()) {
        answer = search_database(cfg.db, sensor_type, sensor_id);

        if (answer.empty()) {
            answer = ask_slave(cfg.slave1_ip, cfg.slave1_port, sensor_type, sensor_id);

            if (answer.empty() || answer.find("\"error\"") != std::string::npos) {
                answer = ask_slave(cfg.slave2_ip, cfg.slave2_port, sensor_type, sensor_id);
            }
        }

        if (!answer.empty()) {
            cache_set(cache_key, answer);
        }
    }

    return answer;
}

void handler(struct mg_connection *c, int ev, void *data) {
    if (ev != MG_EV_HTTP_MSG) return;

    auto *msg = (mg_http_message*) data;

    if (mg_strcmp(msg->uri, mg_str("/query")) != 0)
        return;

    char type[64], id[64];
    mg_http_get_var(&msg->query, "sensor_type", type, sizeof(type));
    mg_http_get_var(&msg->query, "sensor_id", id, sizeof(id));

    std::string answer = resolve_sensor(type, id);

    if (!answer.empty()) {
        mg_http_reply(c, 200,
                      "Content-Type: application/json\r\n",
                      "%s", answer.c_str());
    } else {
        mg_http_reply(c, 404,
                      "Content-Type: application/json\r\n",
                      "{\"error\":\"Sensor data not found\"}");
    }
}

std::string extract_json_field(const std::string &json, const std::string &key) {
    std::string search = "\"" + key + "\":\"";
    size_t pos = json.find(search);
    if (pos == std::string::npos) return "";
    pos += search.size();
    size_t end = json.find("\"", pos);
    if (end == std::string::npos) return "";
    return json.substr(pos, end - pos);
}

void on_mqtt_message(struct mosquitto *m, void *userdata,
                     const struct mosquitto_message *msg) {
    if (!msg->payload || msg->payloadlen <= 0) return;

    std::string payload(static_cast<char*>(msg->payload), msg->payloadlen);
    std::cout << "[MQTT] Received request: " << payload << "\n";

    std::string sensor_type = extract_json_field(payload, "sensor_type");
    std::string sensor_id = extract_json_field(payload, "sensor_id");
    std::string request_id = extract_json_field(payload, "request_id");

    if (sensor_type.empty() || sensor_id.empty()) {
        std::cerr << "[MQTT] Malformed request, missing sensor_type/sensor_id\n";
        return;
    }

    std::string answer = resolve_sensor(sensor_type, sensor_id);

    std::stringstream response;
    if (!answer.empty()) {
        // inject request_id into the response so the client can correlate it
        response << answer.substr(0, answer.size() - 1);
        if (!request_id.empty()) {
            response << ",\"request_id\":\"" << request_id << "\"";
        }
        response << "}";
    } else {
        response << "{\"error\":\"Sensor data not found\"";
        if (!request_id.empty()) {
            response << ",\"request_id\":\"" << request_id << "\"";
        }
        response << "}";
    }

    std::string response_str = response.str();
    mosquitto_publish(mosq, nullptr,
                      cfg.mqtt_response_topic.c_str(),
                      response_str.size(), response_str.c_str(),
                      1 /* QoS 1 */, false);

    std::cout << "[MQTT] Published response: " << response_str << "\n";
}

void on_mqtt_connect(struct mosquitto *m, void *userdata, int rc) {
    if (rc == 0) {
        std::cout << "[MQTT] Connected to broker, subscribing to "
                  << cfg.mqtt_request_topic << "\n";
        mosquitto_subscribe(m, nullptr, cfg.mqtt_request_topic.c_str(), 1);
    } else {
        std::cerr << "[MQTT] Connection failed, rc=" << rc << "\n";
    }
}

int main(int argc, char **argv) {
    load_config(argc > 1 ? argv[1] : "config.example");

    memc = memcached_create(nullptr);
    memcached_server_add(memc, cfg.memcached_ip.c_str(), cfg.memcached_port);

    mosquitto_lib_init();
    mosq = mosquitto_new("master_node", true, nullptr);
    if (!mosq) {
        std::cerr << "Failed to create mosquitto client\n";
        return 1;
    }

    mosquitto_connect_callback_set(mosq, on_mqtt_connect);
    mosquitto_message_callback_set(mosq, on_mqtt_message);

    if (mosquitto_connect(mosq, cfg.mqtt_broker_ip.c_str(), cfg.mqtt_broker_port, 60) != MOSQ_ERR_SUCCESS) {
        std::cerr << "Failed to connect to MQTT broker at "
                  << cfg.mqtt_broker_ip << ":" << cfg.mqtt_broker_port << "\n";
        return 1;
    }

    mosquitto_loop_start(mosq);

    mg_mgr mgr{};
    mg_mgr_init(&mgr);

    std::stringstream addr;
    addr << "http://0.0.0.0:" << cfg.port;

    mg_http_listen(&mgr, addr.str().c_str(), handler, nullptr);

    std::cout << "Master running on port " << cfg.port << "\n";
    std::cout << "MQTT broker: " << cfg.mqtt_broker_ip << ":" << cfg.mqtt_broker_port << "\n";

    while (true) {
        mg_mgr_poll(&mgr, 1000);
    }

    return 0;
}