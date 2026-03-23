#!/usr/bin/env bash

# Define target defconfig location
DEFCONFIG="arch/arm64/configs/gki_defconfig"

echo "⚙️  Injecting KSU & SuSFS configuration into $DEFCONFIG"

# ── Base KernelSU configs (written only when any KSU variant is selected) ──
if [ "$KSU" != "no" ]; then
  cat >> $DEFCONFIG <<EOF
# ===============================================
# KernelSU Base — required by all variants
CONFIG_KSU=y
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
EOF

  # ── Manual Hook config entries ──────────────────────────────────────────
  # kernelsu (tiann) is kprobes-only — never gets manual hook config.
  # next supports manual hooks when KSU_MANUAL_HOOK=true.
  if [ "$KSU_MANUAL_HOOK" == "true" ] && [ "$KSU" != "kernelsu" ]; then
    echo "🔧 Mode: Manual Hook enabled ($KSU)"
    cat >> $DEFCONFIG <<EOF
# Manual Hook method (scope-minimized, better for detach/hide)
CONFIG_KSU_MANUAL_HOOK=y
EOF
  else
    cat >> $DEFCONFIG <<EOF
# Kprobes hook method (default)
# CONFIG_KSU_MANUAL_HOOK is not set
EOF
  fi

  # ── SuSFS config entries ─────────────────────────────────────────────────
  # Only KSU=next supports SUSFS. tiann (kernelsu) does not.
  if [ "$KSU_SUSFS" == "true" ] && [ "$KSU" == "next" ]; then
    echo "🔧 Mode: SuSFS enabled ($KSU)"
    cat >> $DEFCONFIG <<EOF
# SuSFS — simonpunk/susfs4ksu (latest branch for target kernel)
# Configs match pershoot dev-susfs Kconfig exactly
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_MAP=y
# ── Deprecated in susfs v2.x — removed from Kconfig, explicitly not set ──
# CONFIG_KSU_SUSFS_TRY_UMOUNT is not set
# CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT is not set
# CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT is not set
# CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT is not set
# CONFIG_KSU_SUSFS_MAGIC_MOUNT is not set
# CONFIG_KSU_SUSFS_OVERLAYFS_AUTO_KSTAT is not set
EOF
  else
    echo "🔧 Mode: No SuSFS ($KSU, kprobes)"
    cat >> $DEFCONFIG <<EOF
# SuSFS disabled
# CONFIG_KSU_SUSFS is not set
# CONFIG_KSU_SUSFS_SUS_SU is not set
# CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS is not set
EOF
  fi

else
  # KSU=no — vanilla kernel, no root configs injected
  echo "🔧 Mode: Vanilla (no root) — skipping KSU config injection"
fi

# ── SuvoKernel Optimizations ────────────────────────────────────────────────
echo "⚙️  Adding SuvoKernel Optimizations"
cat >> $DEFCONFIG <<EOF
# ── Timer Frequency ──────────────────────────────────────────────
CONFIG_HZ_500=y
CONFIG_HZ=500

# ── Network: BBR + FQ ────────────────────────────────────────────
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_NET_SCH_FQ=y
CONFIG_DEFAULT_BBR=y
CONFIG_IP_NF_TARGET_TTL=y

# ── CPU & Frequency ──────────────────────────────────────────────
CONFIG_CPU_FREQ=y
CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y
CONFIG_CPU_FREQ_GOV_ONDEMAND=y
CONFIG_CPU_FREQ_GOV_PERFORMANCE=y

# ── I/O Scheduler ────────────────────────────────────────────────
CONFIG_IOSCHED_BFQ=y
CONFIG_BFQ_GROUP_IOSCHED=y
CONFIG_DEFAULT_BFQ=y

# ── Memory ───────────────────────────────────────────────────────
CONFIG_SWAP=y
CONFIG_ZRAM=y
CONFIG_ZRAM_WRITEBACK=y
CONFIG_ZSMALLOC=y
CONFIG_ZSMALLOC_STAT=y

# ── Filesystem ───────────────────────────────────────────────────
CONFIG_TMPFS_XATTR=y
CONFIG_TMPFS_POSIX_ACL=y

# ── Security: No traces ──────────────────────────────────────────
# KernelSU + SuSFS integrated — hides all root traces
CONFIG_SECURITY=y
CONFIG_LSM="lockdown,yama,loadpin,safesetid,selinux,bpf"
EOF

# ── LTO — 5.10 only ─────────────────────────────────────────────────────────
if [ "$KVER" == "5.10" ]; then
  echo "⚙️  Adding Full LTO & Compiler Optimization (KVER 5.10 only)"
  cat >> $DEFCONFIG <<EOF
# LTO & Compiler Optimization (5.10 only)
CONFIG_LTO=y
CONFIG_LTO_CLANG=y
CONFIG_ARCH_SUPPORTS_LTO_CLANG=y
CONFIG_ARCH_SUPPORTS_LTO_CLANG_THIN=y
CONFIG_HAS_LTO_CLANG=y
# CONFIG_LTO_NONE is not set
# CONFIG_LTO_CLANG_FULL is not set
CONFIG_LTO_CLANG_THIN=y
EOF
else
  echo "⚙️  LTO skipped (only for KVER 5.10)"
fi
