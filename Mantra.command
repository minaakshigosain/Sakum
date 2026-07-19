#!/bin/bash
# Mantra Terminal — double-click to open
cd "$(dirname "$0")" || exit 1
clear
echo "  Starting Mantra Terminal..."
/usr/bin/env python3 sakum_core/mantra/mantra.py
echo ""
echo "  [Mantra exited. Close this window or press any key.]"
read -n 1
