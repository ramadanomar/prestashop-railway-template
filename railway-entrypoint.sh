#!/bin/bash
set -e

# Railway-aware entrypoint wrapper for PrestaShop
#
# This script wraps the official PrestaShop Docker entrypoint to handle:
# 1. Volume cleanup (ext4 lost+found, stale install locks, leftover install dirs)
# 2. Admin folder override (prevent docker_run.sh from breaking the PS9 installer)
# 3. Apache MPM fix (ensure mpm_prefork for mod_php)
# 4. Version tracking + upgrade detection
# 5. Delegates to docker_run.sh for the actual install and Apache startup
#
# CRITICAL: PS_FOLDER_ADMIN override
# ===================================
# The PS9 installer's finalize() method expects /var/www/html/admin/ to exist.
# If docker_run.sh renames it before the installer runs (because PS_FOLDER_ADMIN != "admin"),
# finalize() falls back to 'admin-dev' for asset installation, which doesn't exist → crash.
#
# Solution: We capture PS_FOLDER_ADMIN (the user's desired admin URL path),
# export it as RAILWAY_ADMIN_PATH for our post-install/init scripts to use,
# then force PS_FOLDER_ADMIN=admin so docker_run.sh leaves admin/ alone.
# Our post-install script renames admin<random>/ → RAILWAY_ADMIN_PATH after
# the installer finishes safely.

# --- Capture and override PS_FOLDER_ADMIN ---
export RAILWAY_ADMIN_PATH="${PS_FOLDER_ADMIN:-admin}"
export PS_FOLDER_ADMIN=admin
echo "* [Railway] Admin path: /$RAILWAY_ADMIN_PATH/ (PS_FOLDER_ADMIN overridden to 'admin' for installer compatibility)"

# --- Clean up volume artifacts ---
# Railway volumes use ext4 which creates a lost+found directory at the mount root.
# Symfony's Finder crashes when scanning /var/www/html and hits this restricted dir.
rm -rf /var/www/html/lost+found 2>/dev/null || true

# --- Clean up stale install lock ---
# If a previous install crashed, the lock file remains and blocks future installs.
if [ -f /var/www/html/install.lock ] && [ ! -f /var/www/html/config/settings.inc.php ] && [ ! -f /var/www/html/app/config/parameters.php ]; then
    echo "* [Railway] Removing stale install.lock from a previous failed installation"
    rm -f /var/www/html/install.lock
fi

# --- Remove leftover install folder ---
# If PS is already installed, the install folder must not exist (security warning).
PS_FOLDER_INSTALL="${PS_FOLDER_INSTALL:-install}"
if [ -d "/var/www/html/$PS_FOLDER_INSTALL" ] && { [ -f /var/www/html/config/settings.inc.php ] || [ -f /var/www/html/app/config/parameters.php ]; }; then
    echo "* [Railway] Removing leftover install folder ($PS_FOLDER_INSTALL)"
    rm -rf "/var/www/html/$PS_FOLDER_INSTALL"
fi

# --- Fix Apache MPM conflict ---
# Ensure only mpm_prefork is loaded (mpm_event/mpm_worker conflict with mod_php)
rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.* 2>/dev/null || true
if [ ! -f /etc/apache2/mods-enabled/mpm_prefork.load ]; then
    ln -sf /etc/apache2/mods-available/mpm_prefork.load /etc/apache2/mods-enabled/mpm_prefork.load 2>/dev/null || true
    ln -sf /etc/apache2/mods-available/mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf 2>/dev/null || true
fi

# --- Version tracking and upgrade logic ---
VERSION_FILE="/var/www/html/.ps-version"
PS_DATA_DIR="/tmp/data-ps/prestashop"
CURRENT_VERSION="${PS_VERSION:-unknown}"

if [ -f "$VERSION_FILE" ]; then
    INSTALLED_VERSION=$(cat "$VERSION_FILE")
else
    INSTALLED_VERSION=""
fi

if [ -n "$INSTALLED_VERSION" ] && [ "$INSTALLED_VERSION" != "$CURRENT_VERSION" ]; then
    echo "* [Railway] Detected version change: $INSTALLED_VERSION -> $CURRENT_VERSION"
    echo "* [Railway] Updating core PrestaShop files..."
    if [ -d "$PS_DATA_DIR" ]; then
        cp -R -T -p "$PS_DATA_DIR/" /var/www/html/
        echo "* [Railway] Core files updated successfully"
    else
        echo "* [Railway] Warning: PS data directory not found at $PS_DATA_DIR, skipping update"
    fi
fi

if [ -d "/var/www/html/config" ] || [ -d "$PS_DATA_DIR" ]; then
    echo "$CURRENT_VERSION" > "$VERSION_FILE" 2>/dev/null || true
fi

# --- Delegate to the original PrestaShop entrypoint ---
exec /tmp/docker_run.sh "$@"
