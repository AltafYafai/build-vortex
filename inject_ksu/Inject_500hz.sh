#!/usr/bin/env bash

# Define Kconfig Hz file location
KCONFIG_HZ="kernel/Kconfig.hz"

echo " Applying 500Hz patch to $KCONFIG_HZ..."

# Check if target file exists
if [ ! -f "$KCONFIG_HZ" ]; then
    echo "❌ Error: File $KCONFIG_HZ not found."
    echo "Ensure the script is run from the kernel source root directory."
    exit 1
fi

# Already patched? Skip.
if grep -q "HZ_500" "$KCONFIG_HZ"; then
    echo " [✓] HZ_500 already present in $KCONFIG_HZ — skipping."
    exit 0
fi

# Inject HZ_500 choice entry before HZ_1000 block inside the choice.
# Result: 100 / 250 / 300 / 500 / 1000
sed -i '/^\tconfig HZ_1000$/{
i\\
\tconfig HZ_500
i\\
\t\tbool "500 HZ"
i\\
\thelp
i\\
\t 500 Hz provides excellent interactive responsiveness, ideal for
i\\
\t gaming and real-time audio on mobile SoCs. A sweet spot between
i\\
\t 300 Hz and 1000 Hz for Snapdragon devices like the Redmi 12 5G.
i\\

}' "$KCONFIG_HZ"

# Add the default value line in the "config HZ" int block
sed -i '/default 300 if HZ_300/a\\tdefault 500 if HZ_500' "$KCONFIG_HZ"

echo " [✓] Successfully added HZ_500 entry to $KCONFIG_HZ."
