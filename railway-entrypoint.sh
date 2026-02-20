#!/bin/bash
set -e

# Railway-aware entrypoint wrapper for PrestaShop
#
# This script wraps the official PrestaShop Docker entrypoint to add:
# 1. Volume cleanup: removes ext4 lost+found and stale install locks
# 2. Admin folder normalization: renames random admin dir back to PS_FOLDER_ADMIN
# 3. Apache MPM fix: ensures only mpm_prefork is loaded (required for mod_php)
# 4. Version tracking: records the installed PS version in .ps-version
# 5. Upgrade detection: force-copies new core files when the image version changes
# 6. Delegates to the original entrypoint for installation and startup
#
# The official entrypoint (docker_run.sh) uses `cp -n` (no-clobber) which means
# updated core files from a new image are NEVER copied into the volume after
# initial install. This wrapper detects version mismatches and handles upgrades.

# --- Clean up volume artifacts ---
# Railway volumes use ext4 which creates a lost+found directory at the mount root.
# Symfony's Finder crashes when scanning /var/www/html and hits this restricted dir.
# Remove it before anything else to prevent installation failures.
rm -rf /var/www/html/lost+found 2>/dev/null || true

# --- Clean up stale install lock ---
# If a previous install crashed (e.g. due to lost+found), the lock file remains
# and blocks all future installs. Remove it if no settings file exists yet.
if [ -f /var/www/html/install.lock ] && [ ! -f /var/www/html/config/settings.inc.php ] && [ ! -f /var/www/html/app/config/parameters.php ]; then
    echo "* [Railway] Removing stale install.lock from a previous failed installation"
    rm -f /var/www/html/install.lock
fi

# --- Remove leftover install folder ---
# The installer may exit non-zero (set -e kills the script) before it can rm the
# install folder. If PS is already installed, the install folder must not exist
# or the back office shows a security warning.
PS_FOLDER_INSTALL="${PS_FOLDER_INSTALL:-install}"
if [ -d "/var/www/html/$PS_FOLDER_INSTALL" ] && { [ -f /var/www/html/config/settings.inc.php ] || [ -f /var/www/html/app/config/parameters.php ]; }; then
    echo "* [Railway] Removing leftover install folder ($PS_FOLDER_INSTALL)"
    rm -rf "/var/www/html/$PS_FOLDER_INSTALL"
fi

# --- Prevent docker_run.sh mv conflict ---
# docker_run.sh does: mv /var/www/html/admin /var/www/html/$PS_FOLDER_ADMIN/
# On restarts, cp -n recreates admin/ from the image, but the target (admin-railway)
# already exists from a previous boot. Remove the stale admin/ so the mv won't fail.
EXPECTED_ADMIN="${PS_FOLDER_ADMIN:-admin}"
if [ "$EXPECTED_ADMIN" != "admin" ] && [ -d "/var/www/html/$EXPECTED_ADMIN" ] && [ -d "/var/www/html/admin" ]; then
    echo "* [Railway] Removing stale admin/ (target $EXPECTED_ADMIN already exists)"
    rm -rf /var/www/html/admin
fi

# --- Normalize admin folder name ---
# The PrestaShop CLI installer renames admin/ to admin<random> for security.
# For a Railway template with predictable URLs, we rename it back to PS_FOLDER_ADMIN.
# This runs on every startup to catch both existing installs and post-restart states.
if [ ! -d "/var/www/html/$EXPECTED_ADMIN" ]; then
    # Find the randomized admin directory (admin + random chars, excluding admin-api)
    ACTUAL_ADMIN=""
    for dir in /var/www/html/admin*/; do
        dirname=$(basename "$dir")
        # Skip admin-api and the expected name itself
        if [ "$dirname" != "admin-api" ] && [ "$dirname" != "$EXPECTED_ADMIN" ] && [ "$dirname" != "admin*" ]; then
            # Verify it's actually an admin dir (has index.php and themes/)
            if [ -f "$dir/index.php" ] && [ -d "$dir/themes" ]; then
                ACTUAL_ADMIN="$dirname"
                break
            fi
        fi
    done

    if [ -n "$ACTUAL_ADMIN" ]; then
        echo "* [Railway] Renaming admin folder: $ACTUAL_ADMIN -> $EXPECTED_ADMIN"
        mv "/var/www/html/$ACTUAL_ADMIN" "/var/www/html/$EXPECTED_ADMIN"
        # Clear Symfony cache so compiled routes pick up the new path
        rm -rf /var/www/html/var/cache/* 2>/dev/null || true
        echo "* [Railway] Admin folder normalized, cache cleared"
    fi
fi

# --- Fix Apache MPM conflict ---
# Ensure only mpm_prefork is loaded (mpm_event/mpm_worker conflict with mod_php)
rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.* 2>/dev/null || true
if [ ! -f /etc/apache2/mods-enabled/mpm_prefork.load ]; then
    ln -sf /etc/apache2/mods-available/mpm_prefork.load /etc/apache2/mods-enabled/mpm_prefork.load 2>/dev/null || true
    ln -sf /etc/apache2/mods-available/mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf 2>/dev/null || true
fi

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
