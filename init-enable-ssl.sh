#!/bin/bash
# Init script: ensure SSL is enabled in the PrestaShop database
#
# Runs via docker_run.sh's /tmp/init-scripts/ support, just before Apache starts.
# At this point the DB is available and PS is installed.
#
# The PS installer may not detect SSL correctly when running behind a reverse proxy
# (Railway terminates TLS at the edge). This ensures the DB flags are set.

if [ "${PS_ENABLE_SSL:-0}" = "1" ] && [ -n "$DB_SERVER" ]; then
    DB_PREFIX="${DB_PREFIX:-ps_}"
    echo "* [Railway] Ensuring SSL is enabled in database..."
    mysql -h "$DB_SERVER" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWD" "$DB_NAME" \
        -e "UPDATE ${DB_PREFIX}configuration SET value='1' WHERE name IN ('PS_SSL_ENABLED', 'PS_SSL_ENABLED_EVERYWHERE');" \
        2>/dev/null && echo "* [Railway] SSL flags set in database" \
        || echo "* [Railway] Warning: Could not update SSL flags (non-fatal)"
fi
