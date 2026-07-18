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
# On Windows (mingw): -m64
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
else ifeq ($(HOST_OS),windows)
  X86_64_FLAGS := -m64
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
# Full x86-64 set: builds on macOS and Linux (raw-syscall + BSD-socket files
# use #ifdef PLAT_MACOS / #else blocks, so both OSes are supported).
X86_64_TARGETS := cipher eval simd self adv pipe pipeline wasm scan sniff \
                   bramann webhook ai tracker serve sakum \
                   lib_crypto lib_quantum lib_bounds lib_overflow \
                   lib_memory_safe lib_numeric lib_simd lib_vector lib_rvv lib_survive db sys \
                   keywords lib_domains lib_icon_x86

# Windows x86-64 subset: only the libc / computational cores. Windows has no
# raw-syscall ABI and no fork/setsid/BSD-sockets, so the network/daemon files
# (scan, bramann, webhook, ai, pipe, sniff, tracker, serve) are excluded.
X86_64_WINDOWS_TARGETS := cipher eval simd self adv pipeline wasm \
                   lib_crypto lib_quantum lib_bounds lib_overflow \
                   lib_memory_safe lib_numeric lib_simd lib_vector lib_rvv db sys \
                   keywords lib_domains

ARM64_TARGETS := tracker_arm64 tracker_arm64_neon sys_arm64 \
                 lib_domains_arm64 keywords_arm64 lib_icon_arm64

RISCV64_TARGETS := sys_riscv64 \
                   lib_domains_riscv64 keywords_riscv64 lib_icon_riscv64

# On Windows, restrict the default x86-64 set to the compatible subset.
ifeq ($(HOST_OS),windows)
  X86_64_TARGETS := $(X86_64_WINDOWS_TARGETS)
endif

ALL_TARGETS := $(X86_64_TARGETS) $(ARM64_TARGETS) $(RISCV64_TARGETS)

.PHONY: all clean test cross info win test-domains $(ALL_TARGETS)

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
	@echo "x86_64 targets (active): $(X86_64_TARGETS)"
	@echo "  windows subset: $(X86_64_WINDOWS_TARGETS)"
	@echo "ARM64 targets:  $(ARM64_TARGETS)"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Windows convenience target: force the Windows-compatible subset even when the
# host is macOS/Linux (requires a mingw-w64 toolchain, e.g. x86_64-w64-mingw32-gcc).
MINGW := $(shell command -v x86_64-w64-mingw32-gcc 2>/dev/null || command -v x86_64-w64-mingw32-gcc-posix 2>/dev/null || echo "")
win:
ifeq ($(MINGW),)
	@echo "ERROR: no mingw-w64 toolchain found (need x86_64-w64-mingw32-gcc)."
	@echo "       Install it (brew install mingw-w64 / apt install gcc-mingw-w64) then retry."
else
	@echo "Building Windows x86-64 subset with $(MINGW)..."
	@mkdir -p $(BUILD_DIR)
	@for t in $(X86_64_WINDOWS_TARGETS); do \
		src=$$(ls $(ASM_DIR)/sakum_$$t.s 2>/dev/null || ls $(TOOLS_DIR)/$$t.s 2>/dev/null || ls $(ASM_DIR)/sakum_lib_$$t.s 2>/dev/null || ls $(ASM_DIR)/sakum_lib_memory.safe.s 2>/dev/null); \
		$(MINGW) -m64 -include $(ASM_DIR)/platform.inc -DPLAT_WINDOWS $$src -o $(BUILD_DIR)/$$t.exe || echo "FAIL: $$t"; \
	done
	@echo "Done. PE binaries in $(BUILD_DIR)/*.exe"
endif

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

# tantra sys kit: x86_64 (already in X86_64_TARGETS), arm64, riscv64
$(BUILD_DIR)/sys_arm64: $(ASM_DIR)/sakum_sys_arm64.s | $(BUILD_DIR)
	$(CC) $(ARM64_FLAGS) $< -o $@

$(BUILD_DIR)/sys_riscv64: $(ASM_DIR)/sakum_sys_riscv64.s | $(BUILD_DIR)
ifeq ($(CROSS_RISCV64),)
	@echo "SKIP sys_riscv64: no riscv64 cross-compiler (install riscv64-linux-gnu-gcc)"
else
	$(CROSS_RISCV64) -march=rv64gcv -mabi=lp64d -static -nostdlib $< -o $@
endif

# ---- domain keyword library + registry: all ISAs ----
# x86-64 (and Windows subset) handled by the generic $(BUILD_DIR)/% pattern rule.
# ARM64 ports (aarch64-elf or native arm64).
$(BUILD_DIR)/lib_domains_arm64: $(ASM_DIR)/sakum_lib_domains_arm64.s | $(BUILD_DIR)
ifeq ($(CROSS_AARCH64),)
	$(CC) $(ARM64_FLAGS) -I $(ASM_DIR) -c $< -o $@.o && echo "OK  (asm) $<" || echo "SKIP lib_domains_arm64: assembler"
else
	$(CROSS_AARCH64) -I $(ASM_DIR) -c $< -o $@.o && echo "OK  (asm) $<"
endif

# Icon library targets: compile as shared libraries for ctypes (NO_MAIN)
# macOS: .dylib, Linux: .so, Windows: .dll
# RISC-V uses bare-metal toolchain -> static object file
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  SHARED_EXT := dylib
  SHARED_FLAGS := -dynamiclib
else
  SHARED_EXT := so
  SHARED_FLAGS := -shared
endif

$(BUILD_DIR)/lib_icon_x86: $(ASM_DIR)/sakum_lib_icon.s | $(BUILD_DIR)
	$(CC) $(X86_64_FLAGS) -include $(ASM_DIR)/platform.inc -DNO_MAIN -I $(ASM_DIR) $(SHARED_FLAGS) $< -o $(BUILD_DIR)/lib_icon_x86.$(SHARED_EXT)

$(BUILD_DIR)/lib_icon_arm64: $(ASM_DIR)/sakum_lib_icon_arm64.s | $(BUILD_DIR)
	$(CC) $(ARM64_FLAGS) -I $(ASM_DIR) -DNO_MAIN $(SHARED_FLAGS) $< -o $(BUILD_DIR)/lib_icon_arm64.$(SHARED_EXT)

# RISC-V: bare-metal toolchain -> static object file (no -shared)
$(BUILD_DIR)/lib_icon_riscv64: $(ASM_DIR)/sakum_lib_icon_riscv64.s | $(BUILD_DIR)
ifeq ($(CROSS_RISCV64),)
	@echo "SKIP lib_icon_riscv64: no riscv64 cross-compiler"
else
	$(CROSS_RISCV64) -I $(ASM_DIR) -DNO_MAIN -c $< -o $(BUILD_DIR)/lib_icon_riscv64.o
endif

$(BUILD_DIR)/keywords_arm64: $(ASM_DIR)/sakum_keywords_arm64.s | $(BUILD_DIR)
ifeq ($(CROSS_AARCH64),)
	$(CC) $(ARM64_FLAGS) -I $(ASM_DIR) -c $< -o $@.o && echo "OK  (asm) $<" || echo "SKIP keywords_arm64: assembler"
else
	$(CROSS_AARCH64) -I $(ASM_DIR) -c $< -o $@.o && echo "OK  (asm) $<"
endif

# RISC-V ports (riscv64-elf / riscv64-linux-gnu).
$(BUILD_DIR)/lib_domains_riscv64: $(ASM_DIR)/sakum_lib_domains_riscv64.s | $(BUILD_DIR)
ifeq ($(CROSS_RISCV64),)
	@echo "SKIP lib_domains_riscv64: no riscv64 cross-compiler (install riscv64-elf-gcc)"
else
	$(CROSS_RISCV64) -I $(ASM_DIR) -c $< -o $@.o && echo "OK  (asm) $<"
endif

$(BUILD_DIR)/keywords_riscv64: $(ASM_DIR)/sakum_keywords_riscv64.s | $(BUILD_DIR)
ifeq ($(CROSS_RISCV64),)
	@echo "SKIP keywords_riscv64: no riscv64 cross-compiler"
else
	$(CROSS_RISCV64) -I $(ASM_DIR) -c $< -o $@.o && echo "OK  (asm) $<"
endif

# ============================================================
# Phony target aliases (make cipher -> make /tmp/sakum_build/cipher)
# ============================================================
$(X86_64_TARGETS): %: $(BUILD_DIR)/%
	@echo "OK  $<"

$(ARM64_TARGETS): %: $(BUILD_DIR)/%
	@echo "OK  $<"

$(RISCV64_TARGETS): %: $(BUILD_DIR)/%
	@echo "OK  $<"

# ============================================================
# Test targets
# ============================================================
LIB_TARGETS := lib_crypto lib_quantum lib_bounds lib_overflow \
               lib_memory_safe lib_numeric lib_simd lib_vector lib_rvv

test: cipher $(LIB_TARGETS)
	@$(BUILD_DIR)/cipher && echo "PASS: cipher" || echo "FAIL: cipher"

validate:
	@cd assembly && python3 validate.py
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

	# Run the domain-library harness on every ISA the host can actually execute.
	# x86-64 and (on Apple Silicon) ARM64 run natively; RISC-V runs only on a
	# Linux host with qemu-riscv64 + riscv64-linux-gnu-gcc (see
	# tools/run_domains/README.md).
test-domains:
		@echo "=== x86-64 domain harness ==="; \
		./tools/run_domains/build_run_x86_64.sh; \
		echo "=== ARM64 ==="; \
		case "$(HOST_ISA)" in \
		  arm64) ./tools/run_domains/build_native_arm64.sh ;; \
		  *) echo "host ISA is $(HOST_ISA); ARM64 cross-asm verified via 'make lib_domains_arm64'" ;; \
		esac; \
		echo "=== RISC-V ==="; \
		if command -v riscv64-linux-gnu-gcc >/dev/null 2>&1 && command -v qemu-riscv64 >/dev/null 2>&1; then \
		  ./tools/run_domains/build_run_riscv64.sh; \
		else \
		  echo "execute under qemu-riscv64 on a Linux host (see tools/run_domains/README.md)"; \
		fi

clean:
	rm -rf $(BUILD_DIR)
	rm -f assembly/.lib_domains_x86_nomain.s

ext-check:
	python3 tools/sakum_ext.py check .

ext-pdf:
	python3 tools/make_ext_pdf.py

ext-docs: ext-pdf

.PHONY: ext-check ext-pdf ext-docs
