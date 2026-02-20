#!/bin/bash
# Init script: clean up stale admin/ directory on restarts.
#
# Runs on EVERY boot (docker_run.sh calls scripts in /tmp/init-scripts/
# just before starting Apache).
#
# Problem: On restarts, docker_run.sh runs `cp -n -R -T` from the image,
# which recreates admin/ because the volume only has our renamed folder
# (e.g. admin-railway/). This leaves a stale admin/ alongside the real one.
# PrestaShop shows a security warning if a dir named "admin" exists.
#
# This script also catches edge cases where admin<random>/ wasn't renamed
# during post-install (e.g. if the container crashed mid-install).

EXPECTED="${RAILWAY_ADMIN_PATH:-admin}"

# Nothing to do if the user wants plain "admin"
if [ "$EXPECTED" = "admin" ]; then
    exit 0
fi

# If the desired admin folder exists, remove any stale admin/ alongside it
if [ -d "/var/www/html/$EXPECTED" ]; then
    if [ -d "/var/www/html/admin" ] && [ "$EXPECTED" != "admin" ]; then
        echo "* [Railway] Init: Removing stale admin/ (real admin is at $EXPECTED)"
        rm -rf /var/www/html/admin
    fi
    exit 0
fi

# If the desired admin folder doesn't exist, try to find and rename it
# (covers crash-during-install edge case)
for dir in /var/www/html/admin*/; do
    dirname=$(basename "$dir")
    if [ "$dirname" = "admin-api" ] || [ "$dirname" = "admin*" ] || [ "$dirname" = "admin" ]; then
        continue
    fi
    if [ -f "$dir/index.php" ] && [ -d "$dir/themes" ]; then
        echo "* [Railway] Init: Renaming $dirname -> $EXPECTED"
        mv "/var/www/html/$dirname" "/var/www/html/$EXPECTED"
        rm -rf /var/www/html/var/cache/* 2>/dev/null || true
        # Also remove stale admin/ if it exists
        if [ -d "/var/www/html/admin" ]; then
            rm -rf /var/www/html/admin
        fi
        echo "* [Railway] Init: Admin folder normalized"
        exit 0
    fi
done
