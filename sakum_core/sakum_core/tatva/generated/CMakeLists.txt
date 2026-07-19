cmake_minimum_required(VERSION 3.10)
project(tatva LANGUAGES C ASM)

# Architecture detection
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
    set(TATVA_ARCH x86_64)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
    set(TATVA_ARCH arm64)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "riscv64")
    set(TATVA_ARCH riscv64)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
    set(TATVA_ARCH wasm)
else()
    message(FATAL_ERROR "Unsupported architecture: ${CMAKE_SYSTEM_PROCESSOR}")
endif()

# OS detection
if(WIN32)
    set(TATVA_OS windows)
elseif(APPLE)
    set(TATVA_OS macos)
elseif(UNIX)
    set(TATVA_OS linux)
else()
    set(TATVA_OS baremetal)
endif()

add_library(tatva STATIC
    tatva.c
    tatva_${TATVA_ARCH}.c
)

target_include_directories(tatva PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_definitions(tatva PUBLIC
    TATVA_ARCH_${TATVA_ARCH}=1
    TATVA_OS_${TATVA_OS}=1
)

# Install headers
install(FILES tatva.h DESTINATION include)
install(TARGETS tatva DESTINATION lib)
