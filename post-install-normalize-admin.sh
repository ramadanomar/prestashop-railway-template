#!/bin/bash
# Post-install script for PrestaShop on Railway
#
# This runs immediately after the PS CLI installer completes (via docker_run.sh's
# post-install-scripts support). The installer renames admin/ to admin<random> for
# security. We rename it back to PS_FOLDER_ADMIN for predictable template URLs.
#
# Users who want security-through-obscurity can change PS_FOLDER_ADMIN to a custom
# value — this script will normalize to whatever that variable is set to.

EXPECTED_ADMIN="${PS_FOLDER_ADMIN:-admin}"

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
