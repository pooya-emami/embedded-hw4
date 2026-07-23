CC = gcc
CFLAGS = -Wall -O2 -I.
LDFLAGS = -lcurl -lsqlite3 -lmemcached

SRCS = main.c mongoose.c
OBJS = $(SRCS:.c=.o)
TARGET = master_server

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $(TARGET) $(LDFLAGS)

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean