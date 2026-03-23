#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# bake_ksu_into_source.sh
#
# Bakes KernelSU-Next driver directly into kernel_xiaomi_sky repo so that
# during build, setup.sh (curl) is NOT needed — driver is already in source.
#
# Usage:
#   cd <kernel_source_root>   # kernel_xiaomi_sky checkout
#   bash bake_ksu_into_source.sh [susfs|nosusfs]
#
# After running, commit and push:
#   git add drivers/kernelsu
#   git commit -m "kernelsu: add KernelSU-Next driver (pre-baked)"
#   git push
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

MODE="${1:-susfs}"   # susfs | nosusfs

KSRC="$(pwd)"
DRIVER_DIR="$KSRC/drivers/kernelsu"

# ── Validate we're in a kernel tree ──────────────────────────────────────────
if [ ! -f "$KSRC/Makefile" ] || ! grep -q "^KERNELVERSION\|^VERSION\|^SUBLEVEL" "$KSRC/Makefile" 2>/dev/null; then
  echo "❌ Run this from the kernel source root (no Makefile found)."
  exit 1
fi

# ── Clean up any stale driver ────────────────────────────────────────────────
if [ -d "$DRIVER_DIR" ]; then
  echo "⚠️  Removing existing $DRIVER_DIR..."
  rm -rf "$DRIVER_DIR"
fi

# Remove stale Kconfig/Makefile entries
for PARENT in drivers/staging drivers; do
  [ -f "$PARENT/Kconfig" ]  && sed -i '/kernelsu/Id' "$PARENT/Kconfig"
  [ -f "$PARENT/Makefile" ] && sed -i '/kernelsu/Id' "$PARENT/Makefile"
done

# ── Fetch KernelSU-Next via official setup.sh ─────────────────────────────────
echo "⬇️  Fetching KernelSU-Next (mode: $MODE)..."

if [ "$MODE" = "susfs" ]; then
  # pershoot/dev-susfs — SuSFS v2.1.0 integrated
  curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/refs/heads/dev-susfs/kernel/setup.sh" | bash -s dev-susfs
else
  # KernelSU-Next/stable — no SuSFS
  curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s stable
fi

# ── Verify ───────────────────────────────────────────────────────────────────
if [ ! -f "$DRIVER_DIR/Makefile" ]; then
  echo "❌ Setup failed — $DRIVER_DIR/Makefile not found."
  exit 1
fi

echo ""
echo "✅ KernelSU-Next driver installed at $DRIVER_DIR"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Now commit and push:"
echo "   git add drivers/kernelsu"
echo "   git add drivers/Kconfig drivers/Makefile"
echo '   git commit -m "kernelsu: add KernelSU-Next driver (pre-baked)"'
echo "   git push"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
