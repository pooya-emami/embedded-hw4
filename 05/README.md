# Part 5: Sensor History API (logging)

## Project Overview
Part 5 adds a new API endpoint called **`/history`**, which returns all recorded values of a sensor for a specific date.  
This complements the existing `/query` endpoint (latest value).

The Master handles history requests first; if the sensor does not belong to the Master, the request is forwarded to Slave1 and then Slave2.

---

## System Architecture

### Components
```
Client → Master → /history
                    ↓
            Master SQLite
                    ↓ not found
            Slave1 → Slave1 SQLite
                    ↓ not found
            Slave2 → Slave2 SQLite
```

### Data Flow
1. Client sends `/history?sensor_type=...&sensor_id=...&date=YYYY-MM-DD`.  
2. Master checks its database.  
3. If no records exist, Master forwards to Slave1.  
4. If still no records, Slave1 forwards to Slave2.  
5. The node returns all readings for the given date.  
6. Master returns the final JSON response.

---

## Requirements

### No additional packages required

### Make all scripts executable
```bash
find . -type f -name "*.sh" -exec chmod +x {} \;
```

### Ensure Part 3 API is running
Part 5 uses the same Master/Slave servers from Part 3.

---

## Build & Run

### Build Master and Slaves
```bash
cd ~/HW4/05/scripts
./build_and_run.sh master
./build_and_run.sh slave1
./build_and_run.sh slave2
```

### Build with database initialization
```bash
./build_and_run.sh master --dbgen
./build_and_run.sh slave1 --dbgen
./build_and_run.sh slave2 --dbgen
```

### Run history tests (Master only)
```bash
./test_history.sh
```

Or save output:
```bash
./test_history.sh > results.txt
```
---

## Project Structure
```
05/
│   README.md
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
│       test_history.sh
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

## History API Specification

### Endpoint
```
/history?sensor_type=<type>&sensor_id=<id>&date=<YYYY-MM-DD>
```

### Successful Response
```
{
  "sensor_name": "<type>",
  "sensor_id": "<id>",
  "date": "<YYYY-MM-DD>",
  "values": [
    { "time": "HH:MM:SS", "value": "<value>" },
    ...
  ]
}
```

### Error Responses

Missing parameters:
```
{"error":"Missing parameters: sensor_type, sensor_id, date"}
```

Invalid date format:
```
{"error":"Invalid date format. Use YYYY-MM-DD"}
```

No data for that date:
```
{
  "sensor_name":"<type>",
  "sensor_id":"<id>",
  "date":"<YYYY-MM-DD>",
  "values":[]
}
```

---

## Sample Test Results

### Test 1 — Sensor 101 on 2026‑06‑01 (Master)
```
{
  "sensor_name": "temperature",
  "sensor_id": "101",
  "date": "2026-06-01",
  "values": [
    { "time": "10:00:00", "value": "24.2" },
    { "time": "10:15:00", "value": "24.8" }
  ]
}
```

### Test 2 — Sensor 201 on 2026‑06‑01 (Slave1)
```
{
  "sensor_name": "temperature",
  "sensor_id": "201",
  "date": "2026-06-01",
  "values": [
    { "time": "10:00:00", "value": "25.0" },
    { "time": "10:15:00", "value": "25.3" }
  ]
}
```

### Test 3 — Sensor 301 on 2026‑06‑01 (Slave2)
```
{
  "sensor_name": "temperature",
  "sensor_id": "301",
  "date": "2026-06-01",
  "values": [
    { "time": "10:00:00", "value": "22.9" },
    { "time": "10:15:00", "value": "23.1" }
  ]
}
```

### Test 4 — Sensor 101 on 2026‑06‑02 (no data)
```
{
  "sensor_name": "temperature",
  "sensor_id": "101",
  "date": "2026-06-02",
  "values": []
}
```

### Test 5 — Missing sensor_id
```
{"error":"Missing parameters: sensor_type, sensor_id, date"}
```

### Test 6 — Invalid date format
```
{"error":"Invalid date format. Use YYYY-MM-DD"}
```

### Test 7 — Compare `/query` vs `/history`

Latest value:
```
{
  "sensor_id": "101",
  "sensor_type": "temperature",
  "sensor_name": "Floor1_Room101_Temp",
  "value": "24.8",
  "unit": "C",
  "recorded_at": "2026-06-01 10:15:00",
  "response_time_ms": 1.10996,
  "source": "master_database"
}
```

History:
```
{
  "sensor_name": "temperature",
  "sensor_id": "101",
  "date": "2026-06-01",
  "values": [
    { "time": "10:00:00", "value": "24.2" },
    { "time": "10:15:00", "value": "24.8" }
  ]
}
```

---

## Notes
- `/history` returns **all** readings for a given date.  
- `/query` returns **only the latest** reading.  
- History queries follow the same Master → Slave fallback chain.  
- History results are **not cached**; they always come from SQLite.