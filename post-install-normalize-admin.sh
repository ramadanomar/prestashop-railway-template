#!/bin/bash
# Post-install script: rename admin<random>/ to the user's desired admin path.
#
# Runs immediately after the PS CLI installer completes (docker_run.sh calls
# scripts in /tmp/post-install-scripts/ after installation).
#
# The PS9 installer's finalize() renames admin/ → admin<random>/ for security.
# We rename it to RAILWAY_ADMIN_PATH (set by our entrypoint from PS_FOLDER_ADMIN).

EXPECTED="${RAILWAY_ADMIN_PATH:-admin}"

# If they want plain "admin", nothing to do — but admin/ was already renamed
# to admin<random>/ by the installer, so we still need to rename it.
# The only case where we skip is if the target already exists.
if [ -d "/var/www/html/$EXPECTED" ]; then
    echo "* [Railway] Post-install: Admin folder already at $EXPECTED"
    exit 0
fi

# Find the randomized admin directory (admin<NNN><random>)
for dir in /var/www/html/admin*/; do
    dirname=$(basename "$dir")
    # Skip admin-api and glob non-match
    if [ "$dirname" = "admin-api" ] || [ "$dirname" = "admin*" ]; then
        continue
    fi
    # Skip plain admin/ (shouldn't exist after installer, but be safe)
    if [ "$dirname" = "admin" ]; then
        continue
    fi
    # Verify it's a real admin dir
    if [ -f "$dir/index.php" ] && [ -d "$dir/themes" ]; then
        echo "* [Railway] Post-install: Renaming $dirname -> $EXPECTED"
        mv "/var/www/html/$dirname" "/var/www/html/$EXPECTED"
        rm -rf /var/www/html/var/cache/* 2>/dev/null || true
        echo "* [Railway] Post-install: Admin folder normalized, cache cleared"
        exit 0
    fi
done

echo "* [Railway] Post-install: No admin<random> folder found to rename"
