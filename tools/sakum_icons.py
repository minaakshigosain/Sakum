#!/usr/bin/env python3
# tools/sakum_icons.py - Generate lightweight binary icon images (.ico) for
# every Sakum Lang extension, colour-coded by category with the ext label.
#
# Reads the canonical registry from sakum_ext.py (single source of truth) and
# writes one .ico per extension into icons/. Each icon is 32x32 (plus a 16x16
# and 48x48 frame for desktop use) and tiny on disk (<2 KB each).
#
# Uses the machine-code icon library (x86-64 / ARM64 / RISC-V) via ctypes.
# Pure Python + native lib. No Pillow font rendering. Doctrine-compliant.

import os
import sys
import ctypes
import platform

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from sakum_ext import _load_registry  # noqa: E402

REGISTRY, _, _ = _load_registry()

from PIL import Image  # noqa: E402

# Category -> (background colour, accent colour) as 0xRRGGBB ints
PALETTE = {
    "source":  (0x2E86C1, 0xCFE8FF),
    "package": (0x8E44AD, 0xF3E5F5),
    "ir":      (0x16A085, 0xE0F7F4),
    "ast":     (0x27AE60, 0xE8F8EF),
    "binary":  (0xC0392B, 0xFCE9E7),
    "doc":     (0x2C3E50, 0xECF0F1),
    "test":    (0xD4AC0B, 0xFDF3D7),
    "domain":  (0x2980B9, 0xE1F0FA),
    "script":  (0x6C348B, 0xEFE6F7),
    "data":    (0x18776B, 0xD8F3EF),
    "config":  (0x707070, 0xEEEEEE),
    "cache":   (0x95A5A6, 0xF4F6F6),
    "index":   (0x396BB5, 0xE8EFF8),
    "log":     (0x8D6E63, 0xFCF1EC),
}

# Machine-code library loader
def _load_icon_lib():
    """Load the icon rasterizer shared library for the current platform."""
    system = platform.system().lower()
    machine = platform.machine().lower()
    
    # Determine library name based on platform
    if system == "darwin":
        lib_ext = ".dylib"
    elif system == "windows":
        lib_ext = ".dll"
    else:
        lib_ext = ".so"
    
    if machine in ("x86_64", "amd64"):
        lib_name = f"lib_icon_x86{lib_ext}"
    elif machine in ("arm64", "aarch64"):
        lib_name = f"lib_icon_arm64{lib_ext}"
    elif "riscv" in machine:
        lib_name = f"lib_icon_riscv64{lib_ext}"
    else:
        raise RuntimeError(f"Unsupported architecture: {machine}")
    
    # Try build directory first, prefer shared library over object file
    build_dir = "/tmp/sakum_build"
    lib_path = os.path.join(build_dir, lib_name)
    
    # If shared lib not found, try common install locations
    if not os.path.exists(lib_path):
        # Could also check /usr/local/lib, etc.
        raise FileNotFoundError(f"Icon library not found at {lib_path}. Run 'make lib_icon_*' first.")
    
    lib = ctypes.CDLL(lib_path)
    lib.sakum_icon_rasterize.argtypes = [
        ctypes.c_void_p,  # buf
        ctypes.c_int,     # w
        ctypes.c_int,     # h
        ctypes.c_uint32,  # bg (packed 0xRRGGBB)
        ctypes.c_uint32,  # fg (packed 0xRRGGBB)
        ctypes.c_char_p,  # label
        ctypes.c_int,     # len
    ]
    lib.sakum_icon_rasterize.restype = ctypes.c_uint32
    return lib


# Load library at module import
_icon_lib = _load_icon_lib()


def render_machine(ext, category, size=48):
    """Render icon using the machine-code library.
    Returns a PIL Image (RGBA) for .ico container compatibility.
    """
    bg, fg = PALETTE.get(category, (0x555555, 0xFFFFFF))
    label = ext[1:].upper()  # drop leading dot, uppercase
    label_bytes = label.encode('ascii')
    
    # Allocate RGBA buffer: size * size * 4 bytes
    buf = (ctypes.c_ubyte * (size * size * 4))()
    
    # Call native rasterizer
    pixel_count = _icon_lib.sakum_icon_rasterize(
        buf, size, size, bg, fg, label_bytes, len(label_bytes)
    )
    
    # Convert buffer to PIL Image
    # The library writes BGRA (little-endian 0xAABBGGRR -> bytes R,G,B,A)
    # PIL expects RGBA, so we need to swap R and B channels
    img = Image.frombuffer("RGBA", (size, size), bytes(buf), "raw", "BGRA", 0, 1)
    return img


def main():
    out = os.path.join(ROOT, "icons")
    os.makedirs(out, exist_ok=True)
    count = 0
    for ext, (category, _desc) in sorted(REGISTRY.items()):
        # Render at 48x48 (largest common size)
        img = render_machine(ext, category, 48)
        # Save as single-frame ICO (PIL ICO plugin only supports single frame)
        path = os.path.join(out, ext[1:] + ".ico")
        img.save(path, format="ICO", sizes=[(48, 48)])
        count += 1
    print(f"wrote {count} icons to {out}")


if __name__ == "__main__":
    main()
