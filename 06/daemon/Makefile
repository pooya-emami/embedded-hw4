CC = g++
CFLAGS = -Wall -O2 -I.
LDFLAGS = -lsqlite3 -lcurl

SRCS = main.cpp
OBJS = $(SRCS:.cpp=.o)

TARGET = alert_daemon

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $(TARGET) $(LDFLAGS)

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean


