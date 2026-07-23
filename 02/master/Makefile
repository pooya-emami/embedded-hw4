CXX = g++
CC  = gcc

CFLAGS = -Wall -O2 -I.
LDFLAGS = -lsqlite3 -lcurl -lpthread

SRCS_CPP = main.cpp
SRCS_C   = mongoose.c

OBJS = $(SRCS_CPP:.cpp=.o) $(SRCS_C:.c=.o)

TARGET = master_server

all: $(TARGET)

%.o: %.cpp
	$(CXX) $(CFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJS)
	$(CXX) $(OBJS) -o $(TARGET) $(LDFLAGS)

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean
