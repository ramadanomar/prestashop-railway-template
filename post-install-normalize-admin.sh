#!/bin/bash
# Post-install script for PrestaShop on Railway
#
# This runs immediately after the PS CLI installer completes (via docker_run.sh's
# post-install-scripts support). The installer renames admin/ to admin<random> for
# security. We rename it to RAILWAY_ADMIN_PATH for predictable template URLs.
#
# IMPORTANT: We use RAILWAY_ADMIN_PATH (not PS_FOLDER_ADMIN) because PS_FOLDER_ADMIN
# must stay as "admin" to prevent docker_run.sh from renaming admin/ BEFORE the
# installer runs — which crashes the PS9 installer.
#
# Users who want a custom admin URL can change RAILWAY_ADMIN_PATH to any value.

EXPECTED_ADMIN="${RAILWAY_ADMIN_PATH:-admin-railway}"

if [ -d "/var/www/html/$EXPECTED_ADMIN" ]; then
    echo "* [Railway] Admin folder already at expected name: $EXPECTED_ADMIN"
    exit 0
fi

# Find the randomized admin directory
for dir in /var/www/html/admin*/; do
    dirname=$(basename "$dir")
    if [ "$dirname" != "admin-api" ] && [ "$dirname" != "$EXPECTED_ADMIN" ] && [ "$dirname" != "admin*" ]; then
        if [ -f "$dir/index.php" ] && [ -d "$dir/themes" ]; then
            echo "* [Railway] Post-install: Renaming admin folder $dirname -> $EXPECTED_ADMIN"
            mv "/var/www/html/$dirname" "/var/www/html/$EXPECTED_ADMIN"
            rm -rf /var/www/html/var/cache/* 2>/dev/null || true
            echo "* [Railway] Admin folder normalized successfully"
            exit 0
        fi
    fi
done

echo "* [Railway] Post-install: No admin folder to rename (this is OK on first boot)"
