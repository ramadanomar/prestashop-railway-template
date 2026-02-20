FROM prestashop/prestashop:9-apache

# Copy Railway-aware entrypoint wrapper
# This handles version tracking for upgrades and delegates to the
# original PrestaShop entrypoint (docker_run.sh)
COPY railway-entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

# Apache config: trust X-Forwarded-Proto from Railway's reverse proxy
# so PHP sees HTTPS=on for TLS-terminated connections
COPY apache-railway-ssl.conf /etc/apache2/conf-enabled/railway-ssl.conf

# Post-install script: normalizes the admin folder name after the PS installer
# renames it to admin<random>. docker_run.sh runs scripts from this directory
# automatically after installation completes.
RUN mkdir -p /tmp/post-install-scripts
COPY post-install-normalize-admin.sh /tmp/post-install-scripts/normalize-admin.sh
RUN chmod +x /tmp/post-install-scripts/normalize-admin.sh

# Init scripts: run on every startup just before Apache starts.
# docker_run.sh runs all scripts in /tmp/init-scripts/ automatically.
RUN mkdir -p /tmp/init-scripts
COPY init-enable-ssl.sh /tmp/init-scripts/enable-ssl.sh
COPY init-normalize-admin.sh /tmp/init-scripts/normalize-admin.sh
RUN chmod +x /tmp/init-scripts/enable-ssl.sh /tmp/init-scripts/normalize-admin.sh

EXPOSE 80

ENTRYPOINT ["/railway-entrypoint.sh"]
