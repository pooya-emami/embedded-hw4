#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <unordered_set>
#include <thread>
#include <chrono>
#include <ctime>
#include <curl/curl.h>

struct Sensor {
    std::string type;
    std::string id;
    std::string name;
};

struct Config {
    std::string master_ip = "127.0.0.1";
    int master_port = 8080;
    int check_interval_seconds = 30;

    double temp_max = 35.0;
    double humidity_min = 20.0;
    double humidity_max = 80.0;
    
    std::vector<Sensor> sensors;  // List of sensors to monitor
};

Config cfg;

void load_config(const std::string &filename) {
    std::ifstream f(filename);
    if (!f.is_open()) {
        std::cerr << "Error: Could not open config file: " << filename << "\n";
        return;
    }

    std::string line;
    while (std::getline(f, line)) {
        if (line.empty() || line[0] == '#') continue;

        std::string key, value;
        std::stringstream ss(line);
        if (std::getline(ss, key, '=') && std::getline(ss, value)) {
            if (value.empty()) continue;
            
            if (key == "MASTER_IP") cfg.master_ip = value;
            else if (key == "MASTER_PORT") cfg.master_port = std::stoi(value);
            else if (key == "CHECK_INTERVAL_SECONDS") cfg.check_interval_seconds = std::stoi(value);
            else if (key == "TEMP_MAX") cfg.temp_max = std::stod(value);
            else if (key == "HUMIDITY_MIN") cfg.humidity_min = std::stod(value);
            else if (key == "HUMIDITY_MAX") cfg.humidity_max = std::stod(value);
            else if (key == "SENSOR") {
                // Format: SENSOR=type,id,name
                // Example: SENSOR=temperature,101,Floor1_Room101_Temp
                std::stringstream sensor_ss(value);
                Sensor s;
                std::getline(sensor_ss, s.type, ',');
                std::getline(sensor_ss, s.id, ',');
                std::getline(sensor_ss, s.name, ',');
                if (!s.type.empty() && !s.id.empty() && !s.name.empty()) {
                    cfg.sensors.push_back(s);
                }
            }
        }
    }
}

struct CurlBuffer { std::string data; };

static size_t curl_write(void *ptr, size_t size, size_t nmemb, void *userdata) {
    size_t len = size * nmemb;
    CurlBuffer *buf = static_cast<CurlBuffer*>(userdata);
    buf->data.append(static_cast<char*>(ptr), len);
    return len;
}

std::string get_sensor_value(const std::string &type, const std::string &id) {
    CURL *curl = curl_easy_init();
    if (!curl) return "";

    std::stringstream url;
    url << "http://" << cfg.master_ip << ":" << cfg.master_port
        << "/query?sensor_type=" << type << "&sensor_id=" << id;

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

std::string extract_json_field(const std::string &json, const std::string &key) {
    std::string search = "\"" + key + "\":\"";
    size_t pos = json.find(search);
    if (pos == std::string::npos) return "";
    pos += search.size();
    size_t end = json.find("\"", pos);
    if (end == std::string::npos) return "";
    return json.substr(pos, end - pos);
}

std::string now() {
    auto t = std::chrono::system_clock::now();
    std::time_t c = std::chrono::system_clock::to_time_t(t);
    char buf[64];
    std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", std::localtime(&c));
    return buf;
}

std::unordered_set<std::string> active_alerts;

void raise_alert(const Sensor &s, const std::string &alert_type, const std::string &value) {
    std::string key = s.id + "_" + alert_type;
    if (active_alerts.count(key)) return;

    active_alerts.insert(key);

    std::cout << "[ALERT] " << alert_type
              << " | Sensor " << s.id
              << " (" << s.name << ")"
              << " | Value: " << value
              << " | Time: " << now() << "\n";
}

void check_sensor(const Sensor &s) {
    std::string json = get_sensor_value(s.type, s.id);
    
    if (json.empty()) {
        raise_alert(s, "no_data", "none");
        return;
    }

    std::string value_str = extract_json_field(json, "value");
    if (value_str.empty()) return;

    double value = std::stod(value_str);

    if (s.type == "temperature" && value > cfg.temp_max)
        raise_alert(s, "temperature_high", value_str);

    if (s.type == "humidity") {
        if (value < cfg.humidity_min)
            raise_alert(s, "humidity_low", value_str);
        else if (value > cfg.humidity_max)
            raise_alert(s, "humidity_high", value_str);
    }

    if (s.type == "co2" && value > 1000)
        raise_alert(s, "co2_high", value_str);

    if (s.type == "smoke" && value == 1)
        raise_alert(s, "smoke_detected", value_str);

    if (s.type == "motion" && value == 1)
        raise_alert(s, "motion_detected", value_str);
}

int main(int argc, char **argv) {
    load_config(argc > 1 ? argv[1] : "config.example");

    std::cout << "========================================\n";
    std::cout << "     Sensor Alert Daemon Started\n";
    std::cout << "========================================\n";
    std::cout << "Master API: " << cfg.master_ip << ":" << cfg.master_port << "\n";
    std::cout << "Monitoring " << cfg.sensors.size() << " sensors\n";
    std::cout << "Check interval: " << cfg.check_interval_seconds << "s\n";
    std::cout << "========================================\n\n";

    while (true) {
        std::cout << "[" << now() << "] Checking " << cfg.sensors.size() << " sensors...\n";

        for (auto &s : cfg.sensors) {
            check_sensor(s);
        }

        std::cout << "[" << now() << "] Check complete. Sleeping "
                  << cfg.check_interval_seconds << " seconds...\n\n";
        std::this_thread::sleep_for(std::chrono::seconds(cfg.check_interval_seconds));
    }

    return 0;
}