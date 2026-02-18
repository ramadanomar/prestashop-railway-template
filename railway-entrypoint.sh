#!/bin/bash
set -e

# Railway-aware entrypoint wrapper for PrestaShop
#
# This script wraps the official PrestaShop Docker entrypoint to add:
# 1. Version tracking: records the installed PS version in .ps-version
# 2. Upgrade detection: force-copies new core files when the image version changes
# 3. Delegates to the original entrypoint for installation and startup
#
# The official entrypoint (docker_run.sh) uses `cp -n` (no-clobber) which means
# updated core files from a new image are NEVER copied into the volume after
# initial install. This wrapper detects version mismatches and handles upgrades.

VERSION_FILE="/var/www/html/.ps-version"
PS_DATA_DIR="/tmp/data-ps/prestashop"

# --- Version tracking and upgrade logic ---

if [ -f "$VERSION_FILE" ]; then
    INSTALLED_VERSION=$(cat "$VERSION_FILE")
else
    INSTALLED_VERSION=""
fi

# PS_VERSION is set by the official PrestaShop Docker image at build time
CURRENT_VERSION="${PS_VERSION:-unknown}"

if [ -n "$INSTALLED_VERSION" ] && [ "$INSTALLED_VERSION" != "$CURRENT_VERSION" ]; then
    echo "* [Railway] Detected version change: $INSTALLED_VERSION -> $CURRENT_VERSION"
    echo "* [Railway] Updating core PrestaShop files..."

    # Force-copy core files from the image into the volume
    # cp -R -T merges directories (overwrites existing files, keeps extras)
    # This preserves user-installed modules, themes, and uploads while updating core files
    if [ -d "$PS_DATA_DIR" ]; then
        cp -R -T -p "$PS_DATA_DIR/" /var/www/html/
        echo "* [Railway] Core files updated successfully"
    else
        echo "* [Railway] Warning: PS data directory not found at $PS_DATA_DIR, skipping update"
    fi
fi

# Record the current version (will be written after first install by entrypoint,
# or updated here after upgrade)
# We write this after the volume is populated, so check if the webroot has content
if [ -d "/var/www/html/config" ] || [ -d "$PS_DATA_DIR" ]; then
    echo "$CURRENT_VERSION" > "$VERSION_FILE" 2>/dev/null || true
fi

# --- Delegate to the original PrestaShop entrypoint ---

# The official entrypoint handles:
# - Waiting for MySQL to be ready
# - Copying files on first boot (cp -n from /tmp/data-ps/)
# - Running the CLI installer (when PS_INSTALL_AUTO=1)
# - Setting file permissions
# - Starting Apache

exec /tmp/docker_run.sh "$@"
