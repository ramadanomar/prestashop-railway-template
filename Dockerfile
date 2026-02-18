FROM prestashop/prestashop:8-apache

# Copy Railway-aware entrypoint wrapper
# This handles version tracking for upgrades and delegates to the
# original PrestaShop entrypoint (docker_run.sh)
COPY railway-entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/railway-entrypoint.sh"]
