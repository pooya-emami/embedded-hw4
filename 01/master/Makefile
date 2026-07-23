CC = g++
CFLAGS = -Wall -O2 -I.
LDFLAGS = -lsqlite3 -lcurl -lmongoose

SRCS = main.cpp
OBJS = $(SRCS:.cpp=.o)

TARGET = master_server

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $(TARGET) $(LDFLAGS)

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean
