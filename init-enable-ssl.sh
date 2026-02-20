#!/bin/bash
# Init script: configure SSL and domain in the PrestaShop database.
#
# Runs via docker_run.sh's /tmp/init-scripts/ support, just before Apache starts.
# At this point the DB is available and PS is installed.
#
# 1. SSL: Set PS_SSL_ENABLED=1 (Railway terminates TLS at the edge).
#    We do NOT set PS_SSL_ENABLED_EVERYWHERE — Railway's edge already forces
#    HTTPS, and the EVERYWHERE flag causes redirect loops because the container
#    receives plain HTTP from the proxy.
#
# 2. Domain: Update PS_SHOP_DOMAIN in the database from PS_DOMAIN, and remove
#    docker_updt_ps_domains.php to prevent a redirect loop. That file is injected
#    by docker_run.sh when PS_HANDLE_DYNAMIC_DOMAIN=1 and is set as DirectoryIndex
#    before index.php. It calls Tools::redirect("index.php") which resolves to "/"
#    → hits the same file again → infinite 302 loop. We handle domain updates here
#    via direct DB queries instead.

if [ -z "$DB_SERVER" ]; then
    exit 0
fi

DB_PREFIX="${DB_PREFIX:-ps_}"

# --- SSL ---
if [ "${PS_ENABLE_SSL:-0}" = "1" ]; then
    echo "* [Railway] Ensuring SSL is enabled in database..."
    mysql -h "$DB_SERVER" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWD" "$DB_NAME" \
        -e "UPDATE ${DB_PREFIX}configuration SET value='1' WHERE name = 'PS_SSL_ENABLED';" \
        2>/dev/null && echo "* [Railway] SSL flag set in database" \
        || echo "* [Railway] Warning: Could not update SSL flag (non-fatal)"
fi

# --- Domain ---
DOMAIN="${PS_DOMAIN:-}"
if [ -n "$DOMAIN" ]; then
    echo "* [Railway] Updating shop domain to: $DOMAIN"
    mysql -h "$DB_SERVER" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWD" "$DB_NAME" <<SQL 2>/dev/null
UPDATE ${DB_PREFIX}configuration SET value='$DOMAIN' WHERE name IN ('PS_SHOP_DOMAIN', 'PS_SHOP_DOMAIN_SSL');
UPDATE ${DB_PREFIX}shop_url SET domain='$DOMAIN', domain_ssl='$DOMAIN' WHERE main=1;
SQL
    echo "* [Railway] Domain updated in database"
fi

# --- Remove redirect file ---
# docker_updt_ps_domains.php causes an infinite 302 loop. We've handled domain
# updates above, so remove it and revert the DirectoryIndex change.
if [ -f /var/www/html/docker_updt_ps_domains.php ]; then
    rm -f /var/www/html/docker_updt_ps_domains.php
    echo "* [Railway] Removed docker_updt_ps_domains.php (domain handled via init script)"
fi

# Revert DirectoryIndex to the default (remove docker_updt_ps_domains.php reference)
APACHE_CONF="${APACHE_CONFDIR:-/etc/apache2}/conf-available/docker-php.conf"
if [ -f "$APACHE_CONF" ] && grep -q "docker_updt_ps_domains.php" "$APACHE_CONF" 2>/dev/null; then
    sed -i 's/docker_updt_ps_domains\.php //g' "$APACHE_CONF"
    echo "* [Railway] Reverted DirectoryIndex to default"
fi
