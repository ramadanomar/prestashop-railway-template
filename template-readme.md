# Deploy and Host PrestaShop on Railway

PrestaShop is a free, open-source e-commerce platform powering over 300,000 online stores worldwide. Built with PHP and Symfony, it offers a full-featured storefront, back office admin panel, product catalog, payment processing, and multi-language support out of the box.

## About Hosting PrestaShop

Hosting PrestaShop requires a PHP-enabled web server (Apache or Nginx), a MySQL or MariaDB database, persistent file storage for product images, themes, and modules, and SSL certificates for secure checkout. The initial installation involves running a CLI or web-based installer, configuring database credentials, and setting up URL rewriting. This template automates the entire process — database provisioning, SSL termination, file persistence, and auto-installation — so your store is live in minutes with zero server configuration.

## Common Use Cases

- Launch a fully customizable online store with product catalog, cart, and checkout
- Migrate from hosted e-commerce platforms (Shopify, WooCommerce) to a self-hosted solution with full control
- Build a multi-language, multi-currency storefront for international sales
- Create a marketplace or B2B wholesale portal using PrestaShop modules
- Prototype and test e-commerce workflows with demo data before going to production

## Dependencies for PrestaShop Hosting

- **MySQL** — Relational database for products, orders, customers, and configuration (provisioned automatically by Railway)
- **Persistent Volume** — File storage for uploaded images, installed modules, themes, and cache (mounted automatically at `/var/www/html`)

### Deployment Dependencies

- [PrestaShop Official Documentation](https://docs.prestashop-project.org/)
- [PrestaShop Docker Image](https://hub.docker.com/r/prestashop/prestashop)
- [PrestaShop System Requirements](https://docs.prestashop-project.org/v9-doc/basics/installation/system-requirements)

### Implementation Details

This template uses a thin custom Dockerfile on top of the official `prestashop/prestashop:9-apache` image. A Railway-aware entrypoint script handles:

- Automatic cleanup of ext4 `lost+found` directories on Railway volumes
- Admin folder normalization (PrestaShop's installer renames `admin/` to a random name; the entrypoint restores it to the configured `PS_FOLDER_ADMIN`)
- SSL detection behind Railway's reverse proxy via `X-Forwarded-Proto` header trust
- Version tracking for seamless upgrades when the base image is updated

## Why Deploy PrestaShop on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying PrestaShop on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
