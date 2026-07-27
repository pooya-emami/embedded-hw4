CC = g++
CFLAGS = -Wall -Wextra -O2 -std=c++11
LIBS = -lcurl

TARGET = alert_daemon

all: $(TARGET)

$(TARGET): main.cpp
	$(CC) $(CFLAGS) -o $(TARGET) main.cpp $(LIBS)

clean:
	rm -f $(TARGET)

.PHONY: all clean