# Makefile - Sakum Lang cross-platform build system
#
# Auto-detects host OS and ISA. Builds all compilable targets.
# x86-64 assembly files are always built for x86-64 (Rosetta on ARM64 Mac).
# ARM64 assembly files are built natively on ARM64.
#
# Usage:
#   make              # build everything for host
#   make cipher       # build just the cipher
#   make clean        # remove build artifacts
#   make test         # build + run self-tests
#   make cross        # list available cross-compilation targets

# --- Auto-detect host OS ---
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_S),Darwin)
  HOST_OS := macos
else ifeq ($(UNAME_S),Linux)
  HOST_OS := linux
else ifneq (,$(findstring MINGW,$(UNAME_S)))
  HOST_OS := windows
else ifneq (,$(findstring MSYS,$(UNAME_S)))
  HOST_OS := windows
else
  HOST_OS := unknown
endif

# --- Auto-detect host ISA ---
ifeq ($(UNAME_M),x86_64)
  HOST_ISA := x86_64
else ifeq ($(UNAME_M),arm64)
  HOST_ISA := arm64
else ifeq ($(UNAME_M),aarch64)
  HOST_ISA := arm64
else ifneq (,$(findstring riscv,$(UNAME_M)))
  HOST_ISA := riscv64
else
  HOST_ISA := x86_64
endif

# --- Compiler ---
CC := gcc

# --- x86-64 flags: always use x86-64 regardless of host ---
# On ARM64 Mac: -arch x86_64 (runs under Rosetta)
# On x86-64 Linux: -m64
# On ARM64 Linux: need cross-compiler or -m64 won't work
ifeq ($(HOST_OS),macos)
  X86_64_FLAGS := -arch x86_64
else ifeq ($(HOST_OS),linux)
  ifeq ($(HOST_ISA),x86_64)
    X86_64_FLAGS := -m64
  else
    # ARM64/RISCV Linux: try -m64 (needs multilib) or cross-compiler
    X86_64_FLAGS := -m64
  endif
else
  X86_64_FLAGS :=
endif

# --- ARM64 flags ---
ifeq ($(HOST_OS),macos)
  ARM64_FLAGS := -arch arm64
else ifeq ($(HOST_OS),linux)
  ifeq ($(HOST_ISA),arm64)
    ARM64_FLAGS :=
  else
    ARM64_FLAGS := -m64
  endif
else
  ARM64_FLAGS :=
endif

# --- Cross-compilers (auto-detected) ---
CROSS_AARCH64 := $(shell command -v aarch64-elf-gcc 2>/dev/null || command -v aarch64-linux-gnu-gcc 2>/dev/null || echo "")
CROSS_ARM32 := $(shell command -v arm-none-eabi-gcc 2>/dev/null || echo "")
CROSS_RISCV64 := $(shell command -v riscv64-elf-gcc 2>/dev/null || command -v riscv64-linux-gnu-gcc 2>/dev/null || echo "")

# --- Output ---
BUILD_DIR := /tmp/sakum_build
ASM_DIR := assembly
TOOLS_DIR := tools

# --- Targets ---
X86_64_TARGETS := cipher eval simd self adv pipe pipeline wasm scan sniff \
                  bramann webhook ai tracker serve sakum \
                  lib_crypto lib_quantum lib_bounds lib_overflow \
                  lib_memory_safe lib_numeric lib_simd lib_vector lib_rvv db

ARM64_TARGETS := tracker_arm64 tracker_arm64_neon

ALL_TARGETS := $(X86_64_TARGETS) $(ARM64_TARGETS)

.PHONY: all clean test cross info $(ALL_TARGETS)

all: $(ALL_TARGETS)

info:
	@echo "Host OS:     $(HOST_OS)"
	@echo "Host ISA:    $(HOST_ISA)"
	@echo "Compiler:    $(CC)"
	@echo "x86_64 flag: $(X86_64_FLAGS)"
	@echo "ARM64 flag:  $(ARM64_FLAGS)"
	@echo "Cross aarch64: $(if $(CROSS_AARCH64),yes,no)"
	@echo "Cross arm32:   $(if $(CROSS_ARM32),yes,no)"
	@echo "Cross riscv64: $(if $(CROSS_RISCV64),yes,no)"
	@echo "x86_64 targets: $(X86_64_TARGETS)"
	@echo "ARM64 targets:  $(ARM64_TARGETS)"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# ============================================================
# x86-64 targets: always built with x86-64 flags
# These compile on ANY host via Rosetta (macOS) or multilib (Linux)
# ============================================================

# Pattern rule for all x86-64 targets
$(BUILD_DIR)/%: $(ASM_DIR)/sakum_%.s | $(BUILD_DIR)
	$(CC) $(X86_64_FLAGS) -include $(ASM_DIR)/platform.inc $< -o $@

# tools/ targets (different source path)
$(BUILD_DIR)/serve: $(TOOLS_DIR)/serve.s | $(BUILD_DIR)
	$(CC) $(X86_64_FLAGS) -include $(ASM_DIR)/platform.inc $< -o $@

$(BUILD_DIR)/sakum: $(TOOLS_DIR)/sakum.s | $(BUILD_DIR)
	$(CC) $(X86_64_FLAGS) -include $(ASM_DIR)/platform.inc $< -o $@

# Lib files have dots in names, need explicit rules
$(BUILD_DIR)/lib_memory_safe: $(ASM_DIR)/sakum_lib_memory.safe.s | $(BUILD_DIR)
	$(CC) $(X86_64_FLAGS) -include $(ASM_DIR)/platform.inc $< -o $@

# ============================================================
# ARM64 targets: built with ARM64 flags (native on ARM64 Mac)
# ============================================================

$(BUILD_DIR)/tracker_arm64: $(ASM_DIR)/sakum_tracker_arm64.s | $(BUILD_DIR)
	$(CC) $(ARM64_FLAGS) $< -o $@

$(BUILD_DIR)/tracker_arm64_neon: $(ASM_DIR)/sakum_tracker_arm64_neon.s | $(BUILD_DIR)
	$(CC) $(ARM64_FLAGS) $< -o $@

# ============================================================
# Phony target aliases (make cipher -> make /tmp/sakum_build/cipher)
# ============================================================
$(X86_64_TARGETS): %: $(BUILD_DIR)/%
	@echo "OK  $<"

$(ARM64_TARGETS): %: $(BUILD_DIR)/%
	@echo "OK  $<"

# ============================================================
# Test targets
# ============================================================
LIB_TARGETS := lib_crypto lib_quantum lib_bounds lib_overflow \
               lib_memory_safe lib_numeric lib_simd lib_vector lib_rvv

test: cipher $(LIB_TARGETS)
	@$(BUILD_DIR)/cipher && echo "PASS: cipher" || echo "FAIL: cipher"
	@for t in $(LIB_TARGETS); do \
		$(BUILD_DIR)/$$t >/dev/null 2>&1 && echo "PASS: $$t" || echo "FAIL: $$t"; \
	done

# ============================================================
# Cross-compilation info
# ============================================================
cross:
	@echo "=== Available cross-compilation targets ==="
ifdef CROSS_AARCH64
	@echo "  aarch64-linux  ($(CROSS_AARCH64))"
endif
ifdef CROSS_ARM32
	@echo "  arm32-bare     ($(CROSS_ARM32))"
endif
ifdef CROSS_RISCV64
	@echo "  riscv64-linux  ($(CROSS_RISCV64))"
endif
	@echo "  (install cross-compilers to enable more targets)"

clean:
	rm -rf $(BUILD_DIR)
