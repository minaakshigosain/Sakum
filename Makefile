# SAKUM Runtime Build System
# Builds cross-platform static binary from assembly sources

# Configuration
ARCH ?= x86_64
OS    ?= macos
BUILD ?= release

# Paths
SRC_ROOT    := .
CORE_DIR    := $(SRC_ROOT)/core
PLATFORM_DIR:= $(SRC_ROOT)/platform
MODULES_DIR := $(SRC_ROOT)/modules
BUILD_DIR   := $(SRC_ROOT)/build/$(OS)_$(ARCH)
BIN_DIR     := $(SRC_ROOT)/bin

# Core source files
CORE_SRCS := \
    $(CORE_DIR)/sakum_runtime.s \
    $(CORE_DIR)/capability_registry.s \
    $(CORE_DIR)/module_loader.s \
    $(CORE_DIR)/dependency_graph.s \
    $(CORE_DIR)/health_monitor.s \
    $(CORE_DIR)/scheduler.s \
    $(CORE_DIR)/audit_log.s \
    $(CORE_DIR)/memory_pool.s \
    $(CORE_DIR)/crypto.s

# Platform-specific source
ifeq ($(OS),macos)
    PLATFORM_SRCS := $(PLATFORM_DIR)/macos_$(ARCH).s
    ASMFLAGS      += -DMACOS -D$(ARCH)
    LDFLAGS       += -Wl,-no_pie -nostdlib -lSystem
    CC            ?= clang
    ifeq ($(ARCH),x86_64)
        ASMFLAGS  += -arch x86_64
    else ifeq ($(ARCH),arm64)
        ASMFLAGS  += -arch arm64
    endif
else ifeq ($(OS),linux)
    PLATFORM_SRCS := $(PLATFORM_DIR)/linux_$(ARCH).s
    ASMFLAGS      += -DLINUX -D$(ARCH)
    LDFLAGS       += -nostdlib -static
    CC            ?= gcc
    ifeq ($(ARCH),x86_64)
        ASMFLAGS  += -m64
    else ifeq ($(ARCH),arm64)
        ASMFLAGS  += -target aarch64-linux-gnu
    else ifeq ($(ARCH),riscv64)
        ASMFLAGS  += -target riscv64-linux-gnu
    endif
else ifeq ($(OS),windows)
    PLATFORM_SRCS := $(PLATFORM_DIR)/windows_$(ARCH).s
    ASMFLAGS      += -DWINDOWS -D$(ARCH)
    LDFLAGS       += -nostdlib -Wl,-subsystem:console
    CC            ?= clang
    ifeq ($(ARCH),x86_64)
        ASMFLAGS  += -target x86_64-windows-gnu
    endif
endif

# Common assembly flags
ASMFLAGS += -I$(CORE_DIR) -I$(PLATFORM_DIR) -I$(SRC_ROOT)/include

# Build targets
ALL_OBJS := $(patsubst %.s,$(BUILD_DIR)/%.o,$(CORE_SRCS) $(PLATFORM_SRCS))

# Main target
TARGET := $(BIN_DIR)/sakum_$(OS)_$(ARCH)

.PHONY: all clean test install modules

all: $(TARGET)

# Compile assembly to object
$(BUILD_DIR)/%.o: %.s
	@mkdir -p $(dir $@)
	$(CC) $(ASMFLAGS) -c $< -o $@

# Link final binary
$(TARGET): $(ALL_OBJS)
	@mkdir -p $(BIN_DIR)
	$(CC) $(ASMFLAGS) $(ALL_OBJS) -o $@ $(LDFLAGS)
	@echo "Built: $@"

# Module build
modules:
	@$(MAKE) -C $(MODULES_DIR) all

# Test
test: $(TARGET)
	@$(TARGET) --self-test

# Clean
clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)

# Install
install: $(TARGET)
	cp $(TARGET) /usr/local/bin/sakum

# Debug build
debug: BUILD=debug
debug: ASMFLAGS += -g -DDEBUG
debug: all

# Release build
release: BUILD=release
release: ASMFLAGS += -O2 -DNDEBUG
release: all

# Cross-compile for all targets
cross: all
	@$(MAKE) OS=linux ARCH=x86_64
	@$(MAKE) OS=linux ARCH=arm64
	@$(MAKE) OS=linux ARCH=riscv64
	@$(MAKE) OS=windows ARCH=x86_64

# Generate capability.def from module manifests
gen-capabilities:
	@python3 tools/gen_capability_def.py $(MODULES_DIR) > $(SRC_ROOT)/capability.def

# Lint assembly
lint:
	@find . -name "*.s" -exec echo "Checking {}" \; -exec nasm -f macho64 -I$(CORE_DIR) -I$(PLATFORM_DIR) {} \;

# Help
help:
	@echo "SAKUM Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Build for current OS/ARCH"
	@echo "  debug        - Debug build with symbols"
	@echo "  release      - Optimized release build"
	@echo "  cross        - Build for all platforms"
	@echo "  modules      - Build capability modules"
	@echo "  test         - Run self-tests"
	@echo "  clean        - Remove build artifacts"
	@echo "  install      - Install to /usr/local/bin"
	@echo ""
	@echo "Variables:"
	@echo "  OS=macos|linux|windows  (default: auto-detect)"
	@echo "  ARCH=x86_64|arm64|riscv64  (default: x86_64)"
	@echo "  BUILD=debug|release  (default: release)"

# Auto-detect OS
ifeq ($(OS),)
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Darwin)
        OS := macos
    else ifeq ($(UNAME_S),Linux)
        OS := linux
    else ifeq ($(findstring CYGWIN,$(UNAME_S)),CYGWIN)
        OS := windows
    else ifeq ($(findstring MINGW,$(UNAME_S)),MINGW)
        OS := windows
    else
        OS := macos
    endif
endif

# Auto-detect ARCH
ifeq ($(ARCH),)
    UNAME_M := $(shell uname -m)
    ifeq ($(UNAME_M),x86_64)
        ARCH := x86_64
    else ifeq ($(UNAME_M),arm64)
        ARCH := arm64
    else ifeq ($(UNAME_M),aarch64)
        ARCH := arm64
    else ifeq ($(UNAME_M),riscv64)
        ARCH := riscv64
    else
        ARCH := x86_64
    endif
endif