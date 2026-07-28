# Part 2: Two‑Layer Database System with Memcached (Caching)

## Overview
In this part, the distributed database system is extended with a **two‑layer architecture** consisting of:

- A persistent storage layer (**SQLite**)  
- A fast in‑memory caching layer (**Memcached**)  

Each node (Master, Slave 1, Slave 2) now uses Memcached to accelerate sensor lookups and reduce load on SQLite.

The Master–Slave communication model remains identical to Part 1, but the internal data‑access path changes.

---

## System Architecture

### Two‑Layer Data Flow
```
Client → Master → Cache (Memcached)
                     ↓ miss
                 SQLite (DB)
                     ↓
         Cache updated with fresh value
                     ↓
                 Response to client
```

### Distributed Lookup Flow
```
Client → Master
    ├── Cache hit → return
    └── Cache miss → Master SQLite
            ├── Found → update cache → return
            └── Not found → forward to Slave 1
                    ├── Cache hit → return to Master
                    └── Cache miss → Slave 1 SQLite
                            ├── Found → update cache → return
                            └── Not found → going back to Master and forward to Slave 2
```

---

## Prerequisites

### Install Memcached
```bash
sudo apt update
sudo apt install -y memcached libmemcached-dev
```

### Start Memcached Service
```bash
sudo systemctl enable memcached
sudo systemctl start memcached
sudo systemctl status memcached
```

### Verify Memcached is Running
```bash
echo "stats" | nc localhost 11211
```

---

## Project Structure
```
02/
│   README.md
│   report.md
│
├── master/
│     main.cpp
│     Makefile
│     db_init_master.sh
│     memcached_init_master.sh
│     config.example
│
├── slave/
│     main.cpp
│     Makefile
│     db_init_slave.sh
│     memcached_init_slave.sh
│     config.example
│
└── scripts/
      build_and_run.sh
      benchmark_read.sh
```

---

## Configuration

### Example Master Configuration
```
MASTER_IP=192.168.xxx.xxx
MASTER_PORT=8080
MASTER_DB=master.db

MEMCACHED_IP=127.0.0.1
MEMCACHED_PORT=11211

SLAVE1_IP=192.168.xxx.xxx
SLAVE1_PORT=8081

SLAVE2_IP=192.168.xxx.xxx
SLAVE2_PORT=8082
```

### Example Slave Configuration
```
SLAVE_PORT=8081
SLAVE_DB=slave1.db

MEMCACHED_IP=127.0.0.1
MEMCACHED_PORT=11211
```

---

## Build & Run

### Build Master or Slave
```bash
cd 02/scripts
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

### Start Memcached for Each Node
```bash
./memcached_init_master.sh
./memcached_init_slave.sh
```

---

## How Caching Works

### 1. Cache Lookup
When a request arrives:

1. Construct cache key:  
   ```
   <sensor_type>:<sensor_id>
   ```
2. Query Memcached:
   ```cpp
   memcached_get(...)
   ```

If found → return immediately.

---

### 2. Cache Miss → SQLite Lookup
If the key is not in cache:

1. Query SQLite:
   ```sql
   SELECT value FROM sensors WHERE sensor_type=? AND sensor_id=? ORDER BY timestamp DESC LIMIT 1;
   ```
2. If found → store in cache:
   ```cpp
   memcached_set(...)
   ```

---

### 3. Cache Population Strategy
Cache is populated **on demand**, meaning:

- First read → SQLite → cache updated  
- Subsequent reads → served from cache  

This ensures minimal overhead and avoids preloading.

---

## Benchmark Script

### benchmark_read.sh
This script performs:

- **Round 1:** Cold read (cache empty → SQLite)  
- **Round 2:** Warm read (cache populated → Memcached)

### Run Benchmark
```bash
cd 02/scripts
./benchmark_read.sh
```
or
```bash
./benchmark_read.sh > results.txt
```

---

## Final Benchmark Results

### Client‑Side (curl round‑trip)
- **Round 1 (cold):** 50 ms average  
- **Round 2 (warm):** 20 ms average  
- **Improvement:** 30 ms (≈ 60%)

### Server‑Side (response_time_ms from JSON)
- **Round 1 (cold):** 5.31 ms average  
- **Round 2 (warm):** 4.78 ms average  
- **Improvement:** 0.53 ms (≈ 10%)

### Summary
Caching provides:
- A **significant improvement** in end‑to‑end latency (client‑side)  
- A **moderate improvement** in server‑side processing time  
- A **consistent reduction** in load on SQLite due to cache hits in Round 2  

---

## Analysis

### Cache Initialization
Cache is **not preloaded**. It is filled only when a sensor is read for the first time.

### When Data Comes from Cache
- Round 2 of benchmark  
- Any repeated request  
- Any Master → Slave forwarded request after first lookup  

### When Data Comes from SQLite
- First lookup  
- Cache eviction  
- Cache flush  
- Memcached restart  

### Why Round 2 Might Not Hit Cache
- Key expiration (if TTL configured)  
- Cache flush  
- Memcached restart  
- Incorrect key format  
- Cache disabled in config  

---

## Manual Testing

### Query Master
```bash
curl -s "http://MASTER_IP:MASTER_PORT/query?sensor_type=temperature&sensor_id=101"
```

### Query Slave Directly (for debugging)
```bash
curl -s "http://SLAVE1_IP:SLAVE1_PORT/query?sensor_type=humidity&sensor_id=302"
```