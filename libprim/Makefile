# libprim Makefile - cross-platform, multi-architecture assembly primitives.
#
# Builds a static library (libprim.a) + test binary for the chosen target.
#
# Variables:
#   OS   = macos | linux | windows   (default: auto-detect)
#   ARCH = x86_64 | i386 | arm64 | arm32 | riscv64   (default: host)
#
# Host build / test:
#   make test            # build + run tests on current host
#
# Cross / all:
#   make all             # build lib for current OS x all arches (where possible)
#   make lipo           # macOS: fat lib = arm64 + x86_64
#   make clean

SRC_ROOT := .
INCDIR   := $(SRC_ROOT)/include
BUILD    := $(SRC_ROOT)/build/$(OS)_$(ARCH)

# ─── Auto-detect OS ──────────────────────────────────────────────────
ifeq ($(OS),)
  UNAME_S := $(shell uname -s)
  ifeq ($(UNAME_S),Darwin)
    OS := macos
  else ifeq ($(UNAME_S),Linux)
    OS := linux
  else
    OS := windows
  endif
endif

# ─── Auto-detect ARCH ────────────────────────────────────────────────
ifeq ($(ARCH),)
  UNAME_M := $(shell uname -m)
  ifeq ($(UNAME_M),x86_64)
    ARCH := x86_64
  else ifeq ($(UNAME_M),arm64)
    ARCH := arm64
  else ifeq ($(UNAME_M),aarch64)
    ARCH := arm64
  else ifeq ($(UNAME_M),i386)
    ARCH := i386
  else ifeq ($(UNAME_M),riscv64)
    ARCH := riscv64
  else
    ARCH := x86_64
  endif
endif

# ─── Toolchain / flags per OS ────────────────────────────────────────
ifeq ($(OS),macos)
  CC      ?= gcc
  AS      ?= gcc
  OSDEF   := -DMACOS
  ARCHFL  := -arch $(ARCH)
  LIBPATH := $(SRC_ROOT)/lib/macos
  EXTRA   :=
  ifeq ($(ARCH),i386)
    ASFLAGS := -arch i386 -m32
  else
    ASFLAGS := -arch $(ARCH)
  endif
else ifeq ($(OS),linux)
  CC      ?= gcc
  AS      ?= gcc
  OSDEF   := -DLINUX
  LIBPATH := $(SRC_ROOT)/lib/linux
  ifeq ($(ARCH),i386)
    ASFLAGS := -m32
  else   ifeq ($(ARCH),arm32)
    ASFLAGS := -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard
    CC      := arm-linux-gnueabihf-gcc
    AS      := arm-linux-gnueabihf-gcc
  else ifeq ($(ARCH),arm64)
    CC      := aarch64-linux-gnu-gcc
    AS      := aarch64-linux-gnu-gcc
    ASFLAGS :=
  else ifeq ($(ARCH),riscv64)
    CC      := riscv64-linux-gnu-gcc
    AS      := riscv64-linux-gnu-gcc
    ASFLAGS := -march=rv64gc -mabi=lp64d
  else
    ASFLAGS :=
  endif
else ifeq ($(OS),windows)
  CC      ?= clang
  AS      ?= clang
  OSDEF   := -DWINDOWS
  LIBPATH := $(SRC_ROOT)/lib/windows
  ifeq ($(ARCH),i386)
    ASFLAGS := -m32 -target i386-windows-gnu
  else ifeq ($(ARCH),arm64)
    ASFLAGS := -target aarch64-windows-gnu
  else ifeq ($(ARCH),arm32)
    ASFLAGS := -target armv7-windows-gnu
  else ifeq ($(ARCH),riscv64)
    ASFLAGS := -target riscv64 -march=rv64gc -mabi=lp64d
  else
    ASFLAGS := -target x86_64-windows-gnu
  endif
endif

# ─── Sources ─────────────────────────────────────────────────────────
SRC := $(SRC_ROOT)/src/$(ARCH)/prim.s
OBJ := $(BUILD)/prim.o

LIB := $(LIBPATH)/libprim_$(ARCH).a
TEST_OBJ := $(BUILD)/test_prim.o
TEST_BIN := $(BUILD)/test_prim

ASFLAGS += $(OSDEF) -I$(SRC_ROOT) -I$(INCDIR)
CFLAGS  += $(OSDEF) -I$(INCDIR) -O2

# ─── QEMU user-mode emulator per arch (for cross-execution testing) ────
# Override with EMU=... if your binary is named differently.
ifeq ($(ARCH),arm64)
  EMU ?= qemu-aarch64
  EMU_FLAGS ?= -L $(shell $(CC) -print-sysroot 2>/dev/null || echo /)
else ifeq ($(ARCH),arm32)
  EMU ?= qemu-arm
  EMU_FLAGS ?= -L $(shell $(CC) -print-sysroot 2>/dev/null || echo /)
else ifeq ($(ARCH),riscv64)
  EMU ?= qemu-riscv64
  EMU_FLAGS ?= -L $(shell $(CC) -print-sysroot 2>/dev/null || echo /)
else
  # x86_64 / i386 run natively on the host (or via qemu-x86_64)
  EMU ?=
  EMU_FLAGS ?=
endif

.PHONY: all lib test qtest qtest-all check-symbols lipo clean

all: lib

lib: $(LIB)

# ─── Cross-execution test via QEMU ────────────────────────────────────
# Builds the test binary with the cross toolchain, then runs it under the
# matching QEMU user-mode emulator. Requires the cross gcc + qemu-<arch>.
qtest: $(LIB)
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -static -I$(INCDIR) tests/test_prim.c $(LIB) -o $(TEST_BIN)
	@if [ -z "$(EMU)" ]; then \
	    echo "No emulator for arch=$(ARCH); running natively."; \
	    $(TEST_BIN); \
	elif command -v $(EMU) >/dev/null 2>&1; then \
	    echo "Running under $(EMU) ..."; \
	    $(EMU) $(EMU_FLAGS) $(TEST_BIN); \
	else \
	    echo "SKIP: emulator '$(EMU)' not found (install qemu-user). Object built at $(TEST_BIN)."; \
	fi

# Run qtest for every non-host arch we can emulate.
qtest-all:
	@for a in arm64 arm32 riscv64; do \
	    echo "=== qtest $$a ==="; \
	    $(MAKE) OS=linux ARCH=$$a qtest || exit 1; \
	done

# ─── Static symbol check (no emulator needed) ────────────────────────
# Assembles each arch object with the best available assembler and asserts
# all 13 prim_* symbols are defined as global text. Useful where QEMU /
# cross gcc are unavailable (validates the assembly compiles + exports).
REQUIRED = prim_memcpy prim_memset prim_strlen prim_memcmp \
           prim_sadd_overflow prim_uadd_overflow prim_smul_overflow prim_umul_overflow \
           prim_sadd_sat prim_smul_sat prim_fsqrt prim_fma prim_fabs

check-symbols:
	@echo "Checking symbols per arch ..."
	@for a in x86_64 i386 arm64 arm32 riscv64; do \
	    obj="$(SRC_ROOT)/build/symcheck/$$a.o"; \
	    case $$a in \
	      x86_64) as=$(AS);       flags="-arch x86_64 -DMACOS -I. -I./include";; \
	      i386)   as=$(AS);       flags="-arch i386 -m32 -DMACOS -I. -I./include";; \
	      arm64)  as=$(AS);       flags="-arch arm64 -DMACOS -I. -I./include";; \
	      arm32)  as=arm-none-eabi-gcc; flags="-DLINUX -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -I. -I./include";; \
	      riscv64) as=riscv64-elf-gcc; flags="-DLINUX -march=rv64gc -mabi=lp64d -I. -I./include";; \
	    esac; \
	    mkdir -p $(SRC_ROOT)/build/symcheck; \
	    if $$as -x assembler-with-cpp $$flags -c $(SRC_ROOT)/src/$$a/prim.s -o $$obj 2>/dev/null; then \
	        miss=""; \
	        for s in $(REQUIRED); do \
	            if ! nm $$obj 2>/dev/null | grep -Eq "[Tt] [._]*$$s$$"; then \
	                miss="$$miss $$s"; \
	            fi; \
	        done; \
	        if [ -z "$$miss" ]; then echo "  $$a: OK (13/13 symbols)"; \
	        else echo "  $$a: MISSING$$miss"; fi; \
	    else \
	        echo "  $$a: (assembler unavailable or failed)"; \
	    fi; \
	done

$(OBJ): $(SRC)
	@mkdir -p $(BUILD)
	$(AS) -x assembler-with-cpp $(ASFLAGS) -c $< -o $@

$(LIB): $(OBJ)
	@mkdir -p $(LIBPATH)
	ar rcs $@ $<

# ─── Test (host only) ────────────────────────────────────────────────
test: $(LIB)
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) $(ARCHFL) -I$(INCDIR) tests/test_prim.c $(LIB) -o $(TEST_BIN)
	$(TEST_BIN)

# ─── macOS universal (fat) library: arm64 + x86_64 ───────────────────
lipo:
	@mkdir -p $(LIBPATH)
	$(MAKE) OS=macos ARCH=arm64 lib
	$(MAKE) OS=macos ARCH=x86_64 lib
	lipo -create -output $(LIBPATH)/libprim.a \
	    $(LIBPATH)/libprim_arm64.a $(LIBPATH)/libprim_x86_64.a
	@echo "Built universal lib: $(LIBPATH)/libprim.a"

clean:
	rm -rf $(SRC_ROOT)/build $(SRC_ROOT)/lib
