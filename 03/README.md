# Part 3: MQTT Implementation

## Project Overview
Part 3 extends the distributed sensor‑database system by adding **MQTT messaging** while keeping the **Memcached caching layer** from Part 2.  
The Master and Slave nodes now operate with three layers:

1. **Memcached** – fast in‑memory cache  
2. **SQLite** – persistent storage  
3. **Mosquitto MQTT Broker** – publish/subscribe request handling  

MQTT allows clients to request sensor values using topics instead of HTTP.

---

## System Architecture

### Components
```
Client (mosquitto_pub / mosquitto_sub)
        ↓
Mosquitto Broker
        ↓
Master Node
   ├── Memcached
   └── SQLite
        ↓
Slave 1 → Slave 2 (fallback chain)
```

### MQTT Request Flow
1. Client publishes a request to:
   ```
   sensors/request/<sensor_type>/<sensor_id>
   ```
2. Master receives the MQTT message.  
3. Master performs:
   - Cache lookup  
   - SQLite lookup  
   - Slave fallback chain  
4. Master publishes the response to:
   ```
   sensors/response/<sensor_type>/<sensor_id>
   ```

---

## Requirements

### Install MQTT Packages
```bash
sudo apt update
sudo apt install -y \
    libmosquitto-dev \
    mosquitto \
    mosquitto-clients
```

### Install Part 2 Dependencies
```bash
sudo apt install -y sqlite3 libsqlite3-dev libmemcached-dev memcached
```

### Verify Mosquitto
```bash
mosquitto -h
```

Expected:
```
mosquitto version 2.0.11
mosquitto is an MQTT v5.0/v3.1.1/v3.1 broker.
```

---

## Enable Mosquitto (Master VM)
```bash
sudo systemctl enable mosquitto
sudo systemctl start mosquitto
sudo systemctl status mosquitto
```

---

## Project Structure
```
03/
│   README.md
│   report.md
│
├── data/
│       master_sensors.csv
│       slave1_sensors.csv
│       slave2_sensors.csv
│
├── master/
│       config.example
│       db_init_master.sh
│       main.cpp
│       Makefile
│       memcached_init_master.sh
│       mqtt_init_master.sh
│
├── scripts/
│       build_and_run.sh
│       mqtt_benchmark.sh
│       results.txt
│
└── slave/
        config.example
        db_init_slave1.sh
        db_init_slave2.sh
        main.cpp
        Makefile
        memcached_init_slave.sh
```

---

## Configuration

### Master Configuration Example
```
MASTER_IP=192.168.xxx.xxx
MASTER_PORT=8080
MASTER_DB=master.db

MEMCACHED_IP=127.0.0.1
MEMCACHED_PORT=11211

MQTT_BROKER_IP=127.0.0.1
MQTT_BROKER_PORT=1883

SLAVE1_IP=192.168.xxx.xxx
SLAVE1_PORT=8081

SLAVE2_IP=192.168.xxx.xxx
SLAVE2_PORT=8082
```

### Slave Configuration Example
```
SLAVE_PORT=8081
SLAVE_DB=slave1.db

MEMCACHED_IP=127.0.0.1
MEMCACHED_PORT=11211

MQTT_BROKER_IP=127.0.0.1
MQTT_BROKER_PORT=1883
```

---

## Build & Run

### Make all scripts executable
```bash
find . -type f -name "*.sh" -exec chmod +x {} \;
```

### Build Master and Slaves
```bash
./build_and_run.sh master
./build_and_run.sh slave1
./build_and_run.sh slave2
```

### Build with Database Initialization
```bash
./build_and_run.sh master --dbgen
./build_and_run.sh slave1 --dbgen
./build_and_run.sh slave2 --dbgen
```

---

## MQTT Initialization

### Master MQTT Setup
```bash
./mqtt_init_master.sh
```

This script:
- Connects to the Mosquitto broker  
- Subscribes the Master to request topics  
- Prepares the Master to publish responses  

---

## MQTT Topic Structure

### Request Topic
```
sensors/request/<sensor_type>/<sensor_id>
```

Example:
```
sensors/request/temperature/101
```

### Response Topic
```
sensors/response/<sensor_type>/<sensor_id>
```

Example:
```
sensors/response/temperature/101
```

---

## How MQTT + Caching Works

### 1. Client publishes request
```bash
mosquitto_pub -h 127.0.0.1 -t sensors/request/temperature/101 -m "get"
```

### 2. Master receives the message
Master extracts:
- sensor_type  
- sensor_id  

### 3. Master performs lookup
Order:
1. Memcached  
2. SQLite  
3. Slave fallback chain  

### 4. Master publishes response
```bash
mosquitto_pub -t sensors/response/temperature/101 -m '{"value":24.8,"timestamp":"..."}'
```

### 5. Client listens
```bash
mosquitto_sub -h 127.0.0.1 -t sensors/response/temperature/101
```

---

## Benchmark Script

### Run MQTT Benchmark
```bash
./mqtt_benchmark.sh
```

### Save Results
```bash
./mqtt_benchmark.sh > results.txt
```

### Benchmark Behavior
The script performs:

#### Round 1 (Cold Read)
- Cache empty  
- SQLite + fallback chain  
- Full MQTT round‑trip  

#### Round 2 (Warm Read)
- Cache populated  
- Memcached hit  
- Faster MQTT response  

---

## Final Benchmark Results

### Client‑Side (MQTT round‑trip)
- **Round 1 (cold):** 100 ms average  
- **Round 2 (warm):** 49 ms average  
- **Improvement:** 51 ms  
- **Improvement percentage:** ~51%

### Server‑Side (response_time_ms)
- **Round 1 (cold):** 40.02 ms average  
- **Round 2 (warm):** 1.54 ms average  
- **Improvement:** 38.48 ms  
- **Improvement percentage:** ~96%

### Summary
MQTT combined with caching provides:
- A large reduction in server‑side processing time  
- Noticeably faster client‑side response times  
- Consistent warm‑cache behavior across all sensors  
- Minimal load on SQLite during warm reads  

---

## Manual MQTT Testing

### Publish Request
```bash
mosquitto_pub -h 127.0.0.1 \
    -t sensors/request/humidity/302 \
    -m "get"
```

### Subscribe for Response
```bash
mosquitto_sub -h 127.0.0.1 \
    -t sensors/response/humidity/302
```