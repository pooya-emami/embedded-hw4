# Part 1: Distributed Database System - README

## Project Overview
This is the base implementation of a distributed database system for sensor data management in a hotel. The system consists of one Master node and two Slave nodes, each maintaining local SQLite databases with sensor readings.

## System Architecture

### Network Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                        Network                              │
│                    (LAN / Virtual)                          │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Master     │  │   Slave 1    │  │   Slave 2    │    │
│  │   Node       │  │   Node       │  │   Node       │    │
│  │              │  │              │  │              │    │
│  │ IP: dynamic  │  │ IP: dynamic  │  │ IP: dynamic  │    │
│  │ Port: dynamic│  │ Port: dynamic│  │ Port: dynamic│    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │                 │                  │             │
│         └─────────────────┴──────────────────┘             │
│                     Master-Slave                            │
│                     Communication                           │
└─────────────────────────────────────────────────────────────┘
```

### Request Flow
1. **Operator** → Master Node (HTTP Request)
2. **Master Node** → Local SQLite (Check if data exists)
3. **If NOT found**: Master → Slave 1 (Forward request)
4. **If NOT found**: Master → Slave 2 (Forward request)
5. **If found**: Response propagates back: Slave 2 or Slave 1 → Master → Client
6. **If NOT found anywhere**: Master returns "Sensor data not found" message

## Prerequisites

### System Requirements
- Ubuntu 22.04 (or compatible)
- GCC/G++ compiler
- SQLite3
- curl (for testing)

### Installation

1. **Update package list and install dependencies:**
```bash
sudo apt update
sudo apt install -y sqlite3 libsqlite3-dev build-essential
sudo apt-get install -y jq
```

2. **Install Mongoose Library:**
```bash
# Create directory for Mongoose
mkdir -p /mongoose
cd /mongoose

# Download Mongoose source files
wget https://raw.githubusercontent.com/cesanta/mongoose/master/mongoose.c
wget https://raw.githubusercontent.com/cesanta/mongoose/master/mongoose.h

# Compile as shared library
gcc -O2 -fPIC -c mongoose.c -o mongoose.o
gcc -shared -o libmongoose.so mongoose.o

# Install system-wide
sudo cp libmongoose.so /usr/local/lib/
sudo ldconfig
sudo cp mongoose.h /usr/local/include/
```

## Project Structure
```
   01
   │   README.md
   │
   ├───data
   │       master_sensors.csv
   │       slave1_sensors.csv
   │       slave2_sensors.csv
   │
   ├───master
   │       config.bonus
   │       config.example
   │       main.cpp
   │       Makefile
   │       master_init_db.sh
   │
   ├───scripts
   │       build_and_run.sh
   │       test_requests.sh
   │
   └───slave
           config.example
           main.cpp
           Makefile
           slave1_init_db.sh
           slave2_init_db.sh
```

## Database Structure

### Sensors Table
```sql
CREATE TABLE sensors (
    id INTEGER PRIMARY KEY,
    sensor_id TEXT NOT NULL,
    sensor_type TEXT NOT NULL,
    value TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

The database stores sensor readings with the following fields:
- **id**: Unique record identifier
- **sensor_id**: Unique identifier for each sensor (e.g., 101, 102)
- **sensor_type**: Type of sensor (temperature, humidity, motion, etc.)
- **value**: Latest reading value
- **timestamp**: Time when reading was recorded

### Initial Data Files
The initialization scripts use provided CSV/JSON data files to populate the databases with initial sensor readings. Each node receives its own subset of sensor data.

## Compilation and Build

### Run and Build All Components 
Each command below must be done separately on each node.
```bash
# Navigate to part 1 directory
cd 01/scripts

# Build and run all nodes
./build_and_run.sh master
./build_and_run.sh slave1
./build_and_run.sh slave2
```

### Build with Database Initialization
```bash
# Build nodes and initialize databases
./build_and_run.sh master --dbgen
./build_and_run.sh slave1 --dbgen
./build_and_run.sh slave2 --dbgen
```

## Configuration

### Configuration File Format (config.example)
cofiguration on master side:
```
MASTER_IP=192.168.xxx.xxx

MASTER_PORT=8080
MASTER_DB=master.db

SLAVE1_IP=192.168.xxx.xxx
SLAVE1_PORT=8081

SLAVE2_IP=192.168.xxx.xxx
SLAVE2_PORT=8082
```
cofiguration on slave side:

slave 1:
```
SLAVE_PORT=8081
SLAVE_DB=slave1.db 
```
slave 2:
```
SLAVE_PORT=8082
SLAVE_DB=slave2.db 
```

### Configuration Parameters
- **port**: Server listening port
- **db_path**: Path to SQLite database file
- **master_host**: Master node IP address (for slaves)
- **master_port**: Master node port (for slaves)
- **slaves**: List of slave nodes with host and port

## 

## Testing the System

### Automated Testing
```bash
# Run all test requests
cd 01/scripts
./test_requests.sh
```

### Manual Testing with curl

**Query for specific sensor:**
```bash
# Query temperature sensor with ID 101
curl -s "http://master_ip:8080/query?sensor_type=temperature&sensor_id=101" | jq '.'

# Query humidity sensor with ID 302
curl -s "http://master_ip:8080/query?sensor_type=humidity&sensor_id=302" | jq '.'

# Query non-existent sensor
curl -s "http://master_ip:8080/query?sensor_type=temperature&sensor_id=999" | jq '.'
```

### Expected Response Format

**Success Response:**
```json
{
    "sensor_type": "temperature",
    "sensor_id": "101",
    "value": "24.8",
    "timestamp": "2026-06-01 10:15:00",
    "source": "master"
}
```

**Not Found Response:**
```json
{
    "error": "Data not found",
    "sensor_type": "temperature",
    "sensor_id": "101"
}
```

## Bonus Implementation

### Single IP with Multiple Ports
The bonus implementation uses port forwarding to manage multiple nodes on a single IP.

**Setup:**
```bash
# Install socat
sudo apt install -y socat

# Port forwarding
socat TCP-LISTEN:9081,fork,reuseaddr TCP:slave1_ip:8081 &
socat TCP-LISTEN:9082,fork,reuseaddr TCP:slave2_ip:8082 &

# Run master with bonus config
cd 01/scripts
./build_and_run.sh master config.bonus

# Stop socat when done
pkill socat
```

## Security Considerations

### Current Security Measures
- Basic error handling to prevent information disclosure
- Configuration-based IP and port management

### Security Improvements (Suggested)
1. **HTTPS Implementation**: Use TLS/SSL for encrypted communication
2. **Authentication**: Implement API key or JWT authentication
3. **Input Validation**: Sanitize all inputs to prevent SQL injection
4. **Rate Limiting**: Prevent DoS attacks
5. **Firewall Configuration**: Restrict access to authorized IPs
6. **Logging**: Implement comprehensive audit logging
7. **Data Encryption**: Encrypt sensitive data at rest
8. **Backup Strategy**: Regular database backups