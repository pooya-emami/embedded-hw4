# HW4 – Distributed Sensor System

This project implements a multi‑part distributed sensor system with Master/Slave nodes, caching, MQTT messaging, SNMP exposure, history queries, and a systemd‑managed alert daemon.  
Each part builds on the previous one, adding new functionality while keeping the same core architecture.

---

## Directory Structure
```
HW4/
│   .gitignore
│   README.md
│
├── 01/   Distributed DB (Master + 2 Slaves)
├── 02/   Memcached Caching Layer
├── 03/   MQTT Messaging Integration
├── 04/   SNMP Sensor Exposure
├── 05/   History API (per‑day sensor readings)
└── 06/   Alert Daemon (systemd service)
```

---

## Part Summaries

### **01 – Distributed Database System**
- Master + Slave1 + Slave2  
- SQLite databases  
- `/query` endpoint for latest sensor value  
- Master → Slave fallback chain  
- Basic HTTP server using Mongoose  

### **02 – Two‑Layer System with Memcached**
- Adds Memcached caching to all nodes  
- Cache → DB → fallback lookup order  
- Benchmark comparing cold vs warm cache  

### **03 – MQTT Integration**
- Adds MQTT request/response topics  
- Master subscribes to request topic  
- Responses published to MQTT broker  
- Cache + DB + fallback still used  

### **04 – SNMP Support**
- Master exposes sensors via SNMP OIDs  
- `snmpd` + `pass` directive → custom script  
- SNMP queries call Master API internally  
- `read_all_sensors.sh` for testing  

### **05 – History API**
- Adds `/history` endpoint  
- Returns all readings for a given date  
- Master → Slave fallback chain  
- Includes validation and error handling  
- `test_history.sh` for automated tests  

### **06 – Alert Daemon (systemd)**
- Background daemon monitors sensors  
- Threshold‑based alerts (temp, humidity, CO2, smoke, motion)  
- Alerts stored in `alerts.db`  
- Managed by systemd (`sensor-alert.service`)  
- `alert_test.sh` for triggering alerts  

---

## How to Run (High‑Level)
1. Build and run Master/Slaves for the part you are testing.  
2. Use provided scripts (`build_and_run.sh`, `test_history.sh`, `mqtt_benchmark.sh`, etc.).  
3. For Part 6, install and start the systemd service.  
4. Use `journalctl` to monitor daemon logs.  