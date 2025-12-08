CC=gcc
CFLAGS=-Wall -Werror -I/usr/include/ -Wno-deprecated-declarations
LDFLAGS=-ltss2-esys -ltss2-mu -ltss2-tctildr -lssl -lcrypto

# Detect architecture
ARCH := $(shell uname -m)

# Set architecture-specific flags if needed
ifeq ($(ARCH),aarch64)
    # ARM64 specific flags (if any)
    CFLAGS += -march=armv8-a
endif

ifeq ($(ARCH),x86_64)
    # x86-64 specific flags (if any)
    CFLAGS += -march=x86-64
endif

SOURCES=tpm-app-persist.c
EXECUTABLE=tpm-app-persist

all: $(EXECUTABLE)

$(EXECUTABLE): $(SOURCES)
	@echo "Building for architecture: $(ARCH)"
	$(CC) $(CFLAGS) $(SOURCES) -o $(EXECUTABLE) $(LDFLAGS)

clean:
	rm -f $(EXECUTABLE)
