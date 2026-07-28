# Part 6: Sensor Alert Daemon

## Overview
Part 6 introduces a **background alert daemon** that continuously monitors sensor values and triggers alerts when thresholds are exceeded.  
The daemon runs under **systemd**, logs events through `journalctl`, and stores alerts in a dedicated SQLite database (`alerts.db`).

The daemon reads sensor values from the Master API (`/query`) and evaluates them based on thresholds defined in `config.example`.

---

## System Architecture

### Components
```
alert_daemon (systemd service)
        ↓
Master API (/query)
        ↓
Master DB / Cache / Slave fallback
        ↓
Alert evaluation
        ↓
alerts.db (SQLite)
        ↓
journalctl logs
```

### Alert Types
- temperature_high  
- humidity_low  
- humidity_high  
- co2_high  
- smoke_detected  
- motion_detected  
- invalid_data  
- no_data  

Each alert is stored with:
- sensor_id  
- sensor_name  
- alert_type  
- sensor_value  
- created_at  
- status (active/resolved)

---

## Requirements

### Install systemd (usually already installed)
```bash
sudo apt install -y systemd
```

### Make all scripts executable
```bash
find . -type f -name "*.sh" -exec chmod +x {} \;
```

### Ensure Part 3/5 API is running
The daemon depends on the Master API.

---

## Project Structure
```
06/
│   README.md
│
├── daemon/
│       config.example
│       main.cpp
│       Makefile
│
├── scripts/
│       alert_test.sh
│       build_and_run.sh
│       install.sh
│
└── systemd/
        sensor-alert.service
```

---

## Build & Run

### Build daemon
```bash
cd ~/HW4/06/scripts
./build_and_run.sh
```

### Run daemon in foreground (optional)
```bash
./build_and_run.sh --run
```

---

## Install systemd service (Master only)

### Install (one time)
```bash
cd ~/HW4/06/scripts
./install.sh
```

This installs:
- `/usr/local/bin/alert_daemon`
- `/etc/sensor-alert/config.example`
- `/etc/systemd/system/sensor-alert.service`

### Start service
```bash
sudo systemctl start sensor-alert
```

### Check status
```bash
systemctl status sensor-alert
```

### Stop service
```bash
sudo systemctl stop sensor-alert
pkill alert_daemon
```

### View logs
```bash
journalctl -u sensor-alert -f
```

---

## Alert Database

### Copy DB for inspection
```bash
cp -f /usr/local/bin/alerts.db ~/HW4/06/daemon/
```

### View alerts
```bash
sqlite3 /usr/local/bin/alerts.db "SELECT * FROM alerts;"
```

---

## Alert Testing

### Temperature high
```bash
./alert_test.sh master --sensor 101 45
```

### Temperature resolved
```bash
./alert_test.sh master --sensor 101 25
```

### Humidity low
```bash
./alert_test.sh slave1 --sensor 202 10
```

### Humidity high
```bash
./alert_test.sh slave1 --sensor 202 100
```

### Invalid data
```bash
./alert_test.sh slave2 --sensor 304 abc
```

### No data
```bash
./alert_test.sh master --sensor 101 --rm_data
```

### Motion resolved
```bash
./alert_test.sh master --sensor 103 0
```

---

## Configuration (daemon/config.example)

Contains:
- Master IP and port  
- DB paths  
- Alert thresholds  
- Sensor list  
- Check interval  

Example fields:
```
MASTER_IP=192.168.233.139
MASTER_PORT=8080
CHECK_INTERVAL_SECONDS=30
ALERT_DB=alerts.db

TEMP_MAX=35.0
HUMIDITY_MIN=20.0
HUMIDITY_MAX=80.0
CO2_MAX=1000
```

Sensors:
```
SENSOR=temperature,101,Floor1_Room101_Temp
SENSOR=humidity,102,Floor1_Room101_Humidity
...
```

---

## systemd Service File

`systemd/sensor-alert.service`:
```
[Unit]
Description=Sensor Alert Daemon
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/bin
ExecStart=/usr/local/bin/alert_daemon /etc/sensor-alert/config.example
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

---

## Notes
- The daemon checks all sensors every `CHECK_INTERVAL_SECONDS`.  
- Alerts remain active until resolved by normal sensor values.  
- All alerts are logged to `journalctl`.  
- The daemon automatically restarts if it crashes.  
- The systemd service ensures the daemon runs on every boot.  
- `alert_test.sh` allows manual triggering and resolving of alerts.