CC = g++
CFLAGS = -Wall -O2 -I.
LDFLAGS = -lsqlite3

SRCS = main.cpp mongoose.c
OBJS = $(SRCS:.c=.o)
OBJS := $(OBJS:.cpp=.o)

TARGET = slave_server

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $(TARGET) $(LDFLAGS)

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean
