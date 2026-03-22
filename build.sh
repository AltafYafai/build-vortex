#!/usr/bin/env bash

# Constants
WORKDIR="$(pwd)"
if [ "$KVER" == "6.6" ]; then
  RELEASE="v0.3"
elif [ "$KVER" == "5.10" ]; then
  RELEASE="v0.3"
elif [ "$KVER" == "6.1" ]; then
  RELEASE="v0.1"
fi

KERNEL_NAME="SuvoKernel"
USER="Suvojeet"
HOST="suvojeet-sengupta"
TIMEZONE="Asia/Kolkata"
ANYKERNEL_REPO="https://github.com/Kingfinik98/AnyKernel3"

# Fixed Logic: 5.10 & 6.1 use gki_defconfig, others use quartix_defconfig
if [ "$KVER" == "5.10" ]; then
  KERNEL_DEFCONFIG="gki_defconfig"
elif [ "$KVER" == "6.1" ]; then
  KERNEL_DEFCONFIG="gki_defconfig"
else
  KERNEL_DEFCONFIG="gki_defconfig"
fi

if [ "$KVER" == "6.6" ]; then
  KERNEL_REPO="https://github.com/ramabondanp/android_kernel_common-6.6.git"
  ANYKERNEL_BRANCH="master"
  KERNEL_BRANCH="android15-6.6-staging"
elif [ "$KVER" == "6.1" ]; then
  KERNEL_REPO="https://github.com/ramabondanp/android_kernel_common-6.1.git"
  ANYKERNEL_BRANCH="master"
  KERNEL_BRANCH="android14-6.1-staging"
elif [ "$KVER" == "5.10" ]; then
  KERNEL_REPO="https://github.com/suvojeet-sengupta/kernel_xiaomi_sky.git"
  ANYKERNEL_BRANCH="master"
  KERNEL_BRANCH="lineage-23.1"
fi
# sky (5.10): merge vendor configs so hardware_info.ko gets built,
# which exports set_tpinfo_gki needed by FT8720 and NT36672C touchscreen drivers.
if [ "$KVER" == "5.10" ]; then
  DEFCONFIG_TO_MERGE="arch/arm64/configs/vendor/sky_GKI.config"
else
  DEFCONFIG_TO_MERGE=""
fi
GKI_RELEASES_REPO="https://github.com/suvojeet-sengupta/build-vortex"
#Change the clang by removing the (#) sign then apply
#CLANG_URL="https://github.com/linastorvaldz/idk/releases/download/clang-r547379/clang.tgz"
#CLANG_URL="https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b/archive/refs/heads/lineage-20.0.tar.gz"
#CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main-kernel-2025/clang-r536225.tar.gz"
#CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/62cdcefa89e31af2d72c366e8b5ef8db84caea62/clang-r547379.tar.gz"
#CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/105aba85d97a53d364585ca755752dae054b49e8/clang-r584948b.tar.gz"
#CLANG_URL="https://github.com/greenforce-project/greenforce_clang/releases/download/20260210/gf-clang-23.0.0-20260210.tar.gz"
CLANG_URL="https://github.com/greenforce-project/greenforce_clang/releases/download/20260302/gf-clang-23.0.0-20260302.tar.gz"
#CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/42d2c090c14c9c7f4dfd365ae551e2b959dc775c/clang-r584948b.tar.gz"
#CLANG_URL="https://github.com/linastorvaldz/gki-builder/releases/download/clang-r487747c/clang-r487747c.tar.gz"
#CLANG_URL="$(./clang.sh slim)"
CLANG_BRANCH=""
AK3_ZIP_NAME="$KERNEL_NAME-REL-KVER-VARIANT-BUILD_DATE.zip"
OUTDIR="$WORKDIR/out"
KSRC="$WORKDIR/ksrc"
KERNEL_PATCHES="$WORKDIR/kernel-patches"

# Handle error
exec > >(tee $WORKDIR/build.log) 2>&1
trap 'error "Failed at line $LINENO [$BASH_COMMAND]"' ERR

# Import functions
source $WORKDIR/functions.sh

# Set timezone
sudo timedatectl set-timezone "$TIMEZONE" || export TZ="$TIMEZONE"

# Clone kernel source
log "Cloning kernel source from $(simplify_gh_url "$KERNEL_REPO")"
git clone -q --depth=1 $KERNEL_REPO -b $KERNEL_BRANCH $KSRC

cd $KSRC
LINUX_VERSION=$(make kernelversion)
LINUX_VERSION_CODE=${LINUX_VERSION//./}
DEFCONFIG_FILE=$(find ./arch/arm64/configs -name "$KERNEL_DEFCONFIG")

# --- PATCH 500HZ (INSTALLED AT THE BEGINNING) ---
log "Applying 500Hz patch..."
bash $WORKDIR/inject_ksu/Inject_500hz.sh
#--------------------------------------

# --- ADD KSU INJECT SCRIPT ---
log "Injecting custom KSU & SuSFS configs..."
export KSU
export KSU_SUSFS
bash $WORKDIR/inject_ksu/gki_defconfig.sh
# --------------------------------------
cd $WORKDIR

# Set Kernel variant
log "Setting Kernel variant..."
case "$KSU" in
  "kernelsu") VARIANT="KSU-Official" ;;
  "next")     VARIANT="KSU-Next" ;;
  "no")       VARIANT="VNL" ;;
esac
# Append +SuSFS suffix when SUSFS is enabled (applies to all KSU variants)
susfs_included && VARIANT+="+SuSFS"

# Replace Placeholder in zip name
AK3_ZIP_NAME=${AK3_ZIP_NAME//KVER/$LINUX_VERSION}
AK3_ZIP_NAME=${AK3_ZIP_NAME//VARIANT/$VARIANT}

# Download Clang
CLANG_DIR="$WORKDIR/clang"
CLANG_BIN="${CLANG_DIR}/bin"
if [ -z "$CLANG_BRANCH" ]; then
  log "🔽 Downloading Clang..."
  wget -qO clang-archive "$CLANG_URL"
  mkdir -p "$CLANG_DIR"
  case "$(basename $CLANG_URL)" in
    *.tar.* | *.tgz)
      tar -xf clang-archive -C "$CLANG_DIR"
      ;;
    *.7z)
      7z x clang-archive -o${CLANG_DIR}/ -bd -y > /dev/null
      ;;
    *)
      error "Unsupported file format"
      ;;
  esac
  rm clang-archive

  if [ $(find "$CLANG_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l) -eq 1 ] \
    && [ $(find "$CLANG_DIR" -mindepth 1 -maxdepth 1 -type f | wc -l) -eq 0 ]; then
    SINGLE_DIR=$(find "$CLANG_DIR" -mindepth 1 -maxdepth 1 -type d)
    mv $SINGLE_DIR/* $CLANG_DIR/
    rm -rf $SINGLE_DIR
  fi
else
  log "🔽 Cloning Clang..."
  git clone --depth=1 -q "$CLANG_URL" -b "$CLANG_BRANCH" "$CLANG_DIR"
fi

# Clone GNU Assembler
log "Cloning GNU Assembler..."
GAS_DIR="$WORKDIR/gas"
git clone --depth=1 -q \
  https://android.googlesource.com/platform/prebuilts/gas/linux-x86 \
  -b main \
  "$GAS_DIR"

export PATH="${CLANG_BIN}:${GAS_DIR}:$PATH"

# Extract clang version
COMPILER_STRING=$(clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')

cd $KSRC

## KernelSU setup
if ksu_included; then
  # Remove any pre-existing KernelSU driver trees to avoid conflicts
  for KSU_PATH in drivers/staging/kernelsu drivers/kernelsu KernelSU KernelSU-Next; do
    if [ -d "$KSU_PATH" ]; then
      log "Stale KernelSU driver found in $KSU_PATH — removing..."
      KSU_DIR=$(dirname "$KSU_PATH")
      [ -f "$KSU_DIR/Kconfig" ]  && sed -i '/kernelsu/Id' "$KSU_DIR/Kconfig"
      [ -f "$KSU_DIR/Makefile" ] && sed -i '/kernelsu/Id' "$KSU_DIR/Makefile"
      rm -rf "$KSU_PATH"
    fi
  done

  # ── Official KernelSU (tiann/KernelSU) ──────────────────────────────────
  # Normal install — latest main. No SuSFS support.
  if [ "$KSU" == "kernelsu" ]; then
    log "Setting up Official KernelSU (tiann/KernelSU, latest main)..."
    [ "$KSU_MANUAL_HOOK" == "true" ] && \
      log "⚠️  KSU_MANUAL_HOOK=true is ignored — tiann/KernelSU is kprobes-only"
    [ "$KSU_SUSFS" == "true" ] && \
      log "⚠️  KSU_SUSFS=true is ignored for KSU=kernelsu — use KSU=next for SuSFS support"
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main
    config --enable CONFIG_KSU
    config --enable CONFIG_KPROBES
    config --enable CONFIG_KPROBE_EVENTS
    log "Official KernelSU setup done."

  # ── KernelSU-Next + SuSFS (pershoot/KernelSU-Next, dev-susfs branch) ─────
  # pershoot's dev-susfs branch has SuSFS FULLY pre-integrated into the driver.
  # Latest development branch — more up to date than next-susfs.
  # No manual cp fs/susfs.c into driver needed, no config stripping issues.
  elif [ "$KSU" == "next" ]; then
    if susfs_included; then
      log "Setting up KernelSU-Next+SuSFS (pershoot dev-susfs — fully pre-integrated)..."
      curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/refs/heads/dev-susfs/kernel/setup.sh" | bash -s dev-susfs
    else
      log "Setting up KernelSU-Next (KernelSU-Next/KernelSU-Next stable — no SuSFS)..."
      curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s stable
    fi
    config --enable CONFIG_KSU
    config --enable CONFIG_KPROBES
    config --enable CONFIG_KPROBE_EVENTS
    log "KernelSU-Next setup done."
  fi
fi

# ── SuSFS kernel-side patches (simonpunk/susfs4ksu) ──────────────────────────
# pershoot next-susfs: driver already ships susfs.c + prctl routing built-in.
# Only need: cp include/ headers + 50_add_susfs to hook kernel/fs files.
# tiann (kernelsu): no SuSFS support.
if susfs_included && [ "$KSU" == "next" ]; then
  log "Applying SuSFS kernel-side patches (simonpunk/susfs4ksu, latest branch)..."
  SUSFS_DIR="$WORKDIR/susfs"
  SUSFS_PATCHES="${SUSFS_DIR}/kernel_patches"
  if [ "$KVER" == "6.6" ]; then
    SUSFS_BRANCH="gki-android15-6.6"
  elif [ "$KVER" == "6.1" ]; then
    SUSFS_BRANCH="gki-android14-6.1"
  elif [ "$KVER" == "5.10" ]; then
    SUSFS_BRANCH="gki-android12-5.10"
  fi

  git clone --depth=1 -q https://gitlab.com/simonpunk/susfs4ksu -b "$SUSFS_BRANCH" "$SUSFS_DIR"

  # IMPORTANT: pershoot dev-susfs driver ships its own susfs.c + susfs.h inside
  # KernelSU-Next/kernel/. simonpunk's v2.1.0 has different function signatures
  # (void __user **) vs pershoot's API (struct-typed pointers) — ABI mismatch!
  # Fix: copy pershoot's own susfs.c + susfs.h from the driver to kernel tree.
  # The driver dir is at KernelSU-Next/ (setup.sh clones to kernel root).
  PERSHOOT_DRIVER="KernelSU-Next/kernel"
  if [ -f "$PERSHOOT_DRIVER/susfs.c" ]; then
    log "Using pershoot driver's susfs.c + susfs.h (ABI-compatible)..."
    cp "$PERSHOOT_DRIVER/susfs.c"         ./fs/susfs.c
    cp "$PERSHOOT_DRIVER/susfs.h"         ./include/linux/susfs.h 2>/dev/null || true
    # Copy any additional susfs headers from driver
    find "$PERSHOOT_DRIVER" -name "susfs*.h" -exec cp {} ./include/linux/ \; 2>/dev/null || true
  else
    log "⚠️  pershoot susfs.c not found in driver, falling back to simonpunk's..."
    cp -R "$SUSFS_PATCHES/fs/"*      ./fs/
    cp -R "$SUSFS_PATCHES/include/"* ./include/
  fi
  patch -p1 < "$SUSFS_PATCHES/50_add_susfs_in_${SUSFS_BRANCH}.patch" || true

  # Per-version kernel compatibility fixups
  LVER_4=$(echo "$LINUX_VERSION_CODE" | head -c4)
  LVER_3=$(echo "$LINUX_VERSION_CODE" | head -c3)
  LVER_2=$(echo "$LINUX_VERSION_CODE" | head -c2)
  LVER_1=$(echo "$LINUX_VERSION_CODE" | head -c1)

  if [ "$LVER_4" -eq 6630 ] 2>/dev/null; then
    patch -p1 < $KERNEL_PATCHES/susfs/namespace.c_fix.patch
    patch -p1 < $KERNEL_PATCHES/susfs/task_mmu.c_fix.patch
  elif [ "$LVER_4" -eq 6658 ] 2>/dev/null; then
    patch -p1 < $KERNEL_PATCHES/susfs/task_mmu.c_fix-k6.6.58.patch
  elif [ "$LVER_2" -eq 61 ] 2>/dev/null; then
    patch -p1 < $KERNEL_PATCHES/susfs/fs_proc_base.c-fix-k6.1.patch
  elif [ "$LVER_3" -eq 510 ] 2>/dev/null; then
    # pershoot next-susfs driver already ships susfs_set_uname_from_kernel()
    # and susfs_uname_is_active() — these helpers are built into the driver,
    # not in fs/susfs.c at kernel root. Patch is not needed and will fail
    # trying to find fs/susfs.c. Skip entirely.
    log "[✓] pershoot next-susfs: susfs helpers built into driver — skipping patch."
  fi

  # statfs CRC symbol mismatch fix for GKI 6.x kernels
  if [ "$LVER_1" -eq 6 ] 2>/dev/null; then
    if [ "$KVER" == "6.1" ]; then
      log "Applying manual statfs CRC fix for GKI 6.1..."
      sed -i '/#include <linux\/susfs_def.h>/i #ifndef __GENKSYMS__' fs/statfs.c
      sed -i '/#include "mount.h"/a #endif' fs/statfs.c
    else
      log "Applying statfs CRC fix patch for GKI 6.x..."
      patch -p1 < $KERNEL_PATCHES/susfs/fix-statfs-crc-mismatch-susfs.patch
    fi
  fi

  SUSFS_VERSION=$(grep -E '^#define SUSFS_VERSION' ./include/linux/susfs.h | cut -d' ' -f3 | sed 's/"//g')
  config --enable CONFIG_KSU_SUSFS
  config --enable CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT
  config --enable CONFIG_KSU_SUSFS_SUS_PATH
  config --enable CONFIG_KSU_SUSFS_SUS_MOUNT
  config --enable CONFIG_KSU_SUSFS_SUS_KSTAT
  config --enable CONFIG_KSU_SUSFS_SUS_KSTAT_SPOOF_GENERIC
  config --enable CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT
  config --enable CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT
  config --enable CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSTAT
  config --enable CONFIG_KSU_SUSFS_SPOOF_UNAME
  config --enable CONFIG_KSU_SUSFS_ENABLE_LOG
  config --enable CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS
  config --enable CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
  config --enable CONFIG_KSU_SUSFS_OPEN_REDIRECT
  log "[✓] SuSFS $SUSFS_VERSION patched and configured."
else
  config --disable CONFIG_KSU_SUSFS
fi

# ── Manual Hooks (applied AFTER SuSFS so patches don't conflict) ─────────────
# SuSFS and manual hooks both touch fs/read_write.c, fs/stat.c, kernel/reboot.c etc.
# Correct order: KernelSU install → SuSFS patches → Manual hooks
if ksu_included && [ "$KSU_MANUAL_HOOK" == "true" ] && [ "$KSU" != "kernelsu" ]; then
  log "Applying manual hook patches (post-SuSFS, KSU=$KSU)..."
  # SuSFS and manual hooks both touch fs/read_write.c, kernel/reboot.c etc.
  # kernel/reboot.c is handled exclusively by reboot-hook.patch below —
  # exclude it from manual-hook-v1.6 to prevent double-patching which causes
  # ksu_handle_sys_reboot() to land inside SYSCALL_DEFINE4 macro args → compile error.
  patch -p1 --fuzz=5 --ignore-whitespace \
    --exclude='kernel/reboot.c' \
    < $KERNEL_PATCHES/hooks/manual-hook-v1.6.patch || true
  patch -p1 --fuzz=5 --ignore-whitespace \
    < $KERNEL_PATCHES/hooks/reboot-hook.patch || true
  config --enable CONFIG_KSU_MANUAL_HOOK
  log "[✓] Manual hooks applied."
fi

# Declare needed variables
export KBUILD_BUILD_USER="$USER"
export KBUILD_BUILD_HOST="$HOST"
export KBUILD_BUILD_TIMESTAMP=$(date)
export KCFLAGS="-w"
if [ $(echo "$LINUX_VERSION_CODE" | head -c1) -eq 6 ]; then
  MAKE_ARGS=(
    LLVM=1
    ARCH=arm64
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
    -j$(nproc --all)
    O=$OUTDIR
  )
else
  MAKE_ARGS=(
    LLVM=1
    LLVM_IAS=1
    ARCH=arm64
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
    -j$(nproc --all)
    O=$OUTDIR
  )
fi

KERNEL_IMAGE="$OUTDIR/arch/arm64/boot/Image"
MODULE_SYMVERS="$OUTDIR/Module.symvers"
if [ $(echo "$LINUX_VERSION_CODE" | head -c1) -eq 6 ]; then
  KMI_CHECK="$WORKDIR/py/kmi-check-6.x.py"
else
  KMI_CHECK="$WORKDIR/py/kmi-check-5.x.py"
fi

text=$(
  cat << EOF
🐧 *Linux Version*: $LINUX_VERSION
📅 *Build Date*: $KBUILD_BUILD_TIMESTAMP
📛 *Root*: $VARIANT
ඞ *SuSFS*: $(susfs_included && ksu_included && echo "$SUSFS_VERSION" || echo "None")
🔰 *Compiler*: $COMPILER_STRING
EOF
)

## Build GKI
log "Generating config..."
make ${MAKE_ARGS[@]} $KERNEL_DEFCONFIG

if [ "$DEFCONFIG_TO_MERGE" ]; then
  log "Merging configs..."
  if [ -f "scripts/kconfig/merge_config.sh" ]; then
    ./scripts/kconfig/merge_config.sh -m -O $OUTDIR $OUTDIR/.config $DEFCONFIG_TO_MERGE
    make ${MAKE_ARGS[@]} olddefconfig
  else
    error "scripts/kconfig/merge_config.sh does not exist in the kernel source"
  fi
fi

# set localversion — AFTER merge so sky_GKI.config -gki doesn't override it
if [ $TODO == "kernel" ]; then
  LATEST_COMMIT_HASH=$(git rev-parse --short HEAD)
  if [ $STATUS == "BETA" ]; then
    SUFFIX="$LATEST_COMMIT_HASH"
  else
    SUFFIX="${RELEASE}@${LATEST_COMMIT_HASH}"
  fi
  $KSRC/scripts/config --file $OUTDIR/.config --set-str CONFIG_LOCALVERSION "-$KERNEL_NAME-sky/$SUFFIX"
  $KSRC/scripts/config --file $OUTDIR/.config --disable CONFIG_LOCALVERSION_AUTO
  sed -i 's/echo "+"/# echo "+"/g' $KSRC/scripts/setlocalversion
  make ${MAKE_ARGS[@]} olddefconfig
  log "Kernel localversion set to: -$KERNEL_NAME-sky/$SUFFIX"
fi

# ── Re-apply SuSFS configs AFTER final olddefconfig ──────────────────────────
# olddefconfig runs twice (after merge_config + after localversion) and can
# strip CONFIG_KSU_SUSFS_* if Kconfig dependency resolution fails at that point.
# Re-enabling here — after the very last olddefconfig — guarantees they survive
# into the final .config that the compiler sees. No more olddefconfig after this.
if susfs_included && [ "$KSU" == "next" ]; then
  log "Re-pinning SuSFS configs post-olddefconfig..."
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS_SUS_PATH
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS_SUS_MOUNT
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS_SUS_KSTAT
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS_SUS_KSTAT_SPOOF_GENERIC
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSTAT
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS_SPOOF_UNAME
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS_ENABLE_LOG
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
  $KSRC/scripts/config --file $OUTDIR/.config --enable CONFIG_KSU_SUSFS_OPEN_REDIRECT
  log "[✓] SuSFS configs locked in .config — will compile into kernel"
fi

# Upload defconfig if we are doing defconfig
if [ $TODO == "defconfig" ]; then
  log "Uploading defconfig..."
  upload_file $OUTDIR/.config
  exit 0
fi

# Build the actual kernel
log "Building kernel..."
make ${MAKE_ARGS[@]}

# Check KMI Function symbol
if [ $(echo "$LINUX_VERSION_CODE" | head -c1) -eq 6 ]; then
  $KMI_CHECK "$KSRC/android/abi_gki_aarch64.stg" "$MODULE_SYMVERS" || true
else
  $KMI_CHECK "$KSRC/android/abi_gki_aarch64.xml" "$MODULE_SYMVERS" || true
fi

# Return to the initial working directory (Post-compiling steps)
cd $WORKDIR
# ----------------------------------------------------

## Post-compiling stuff
cd $WORKDIR

# Clone AnyKernel
log "Cloning anykernel from $(simplify_gh_url "$ANYKERNEL_REPO")"
git clone -q --depth=1 $ANYKERNEL_REPO -b $ANYKERNEL_BRANCH anykernel

# Set kernel string in anykernel
if [ $STATUS == "BETA" ]; then
  BUILD_DATE=$(date -d "$KBUILD_BUILD_TIMESTAMP" +"%Y%m%d-%H%M")
  AK3_ZIP_NAME=${AK3_ZIP_NAME//BUILD_DATE/$BUILD_DATE}
  AK3_ZIP_NAME=${AK3_ZIP_NAME//-REL/}
  sed -i \
    "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${LINUX_VERSION} (${BUILD_DATE}) ${VARIANT}/g" \
    $WORKDIR/anykernel/anykernel.sh
else
  AK3_ZIP_NAME=${AK3_ZIP_NAME//-BUILD_DATE/}
  AK3_ZIP_NAME=${AK3_ZIP_NAME//REL/$RELEASE}
  sed -i \
    "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${RELEASE} ${LINUX_VERSION} ${VARIANT}/g" \
    $WORKDIR/anykernel/anykernel.sh
fi

# Zip the anykernel
cd anykernel
log "Zipping anykernel..."
cp $KERNEL_IMAGE .
zip -r9 $WORKDIR/$AK3_ZIP_NAME ./*
cd $OLDPWD

if [ "${STATUS}" != "BETA" ]; then
  echo "BASE_NAME=$KERNEL_NAME-$VARIANT" >> $GITHUB_ENV
  mkdir -p $WORKDIR/artifacts
  mv $WORKDIR/*.zip $WORKDIR/artifacts
fi

if [ "${LAST_BUILD}" == "true" ] && [ "${STATUS}" != "BETA" ]; then
  (
    echo "LINUX_VERSION=$LINUX_VERSION"
    echo "SUSFS_VERSION=$(curl -s https://gitlab.com/simonpunk/susfs4ksu/raw/gki-android15-6.6/kernel_patches/include/linux/susfs.h | grep -E '^#define SUSFS_VERSION' | cut -d' ' -f3 | sed 's/"//g')"
    echo "KERNEL_NAME=$KERNEL_NAME"
    echo "RELEASE_REPO=$(simplify_gh_url "$GKI_RELEASES_REPO")"
  ) >> $WORKDIR/artifacts/info.txt
fi

if [ $STATUS == "BETA" ]; then
  upload_file "$WORKDIR/$AK3_ZIP_NAME" "$text"
  upload_file "$WORKDIR/build.log"
else
  send_msg "✅ Build Succeeded for $VARIANT variant."
fi

exit 0
