# PrestaShop on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/template/prestashop)

One-click deployment of [PrestaShop 9](https://www.prestashop-project.org/) on [Railway](https://railway.com).

## What's Included

- **PrestaShop 9.x** (latest stable, currently 9.0.3) with PHP 8.4 and Apache
- **MySQL** via Railway's built-in database service
- **Persistent storage** via Railway volumes for app files
- **Auto-installation** with demo data on first deploy
- **SSL/HTTPS** handled automatically by Railway's edge proxy
- **Dynamic domain support** -- works with Railway domains and custom domains

## Quick Start

1. Click the **Deploy on Railway** button above
2. Wait 3-5 minutes for the initial installation to complete
3. Visit your Railway-provided domain to see your store
4. Access the admin panel at `/admin-railway/`

## Accessing the Admin Panel

After deployment, access the admin panel at:

```
https://your-domain.up.railway.app/admin-railway/
```

Default credentials:
- **Email**: `admin@example.com`
- **Password**: check the `ADMIN_PASSWD` variable in your Railway service

To find your admin password:

1. Go to your Railway project dashboard
2. Click the **PrestaShop** service
3. Go to the **Variables** tab
4. Find the `ADMIN_PASSWD` variable

> **Tip**: You can change the admin URL by setting `PS_FOLDER_ADMIN` to a different value (e.g. `my-secret-admin`). The entrypoint will automatically rename the admin folder on the next restart.

## Configuration

### User-Configurable Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PS_LANGUAGE` | `en` | Default store language (ISO code) |
| `PS_COUNTRY` | `US` | Default store country (ISO code) |
| `PS_FOLDER_ADMIN` | `admin-railway` | Admin panel URL path |
| `ADMIN_MAIL` | `admin@example.com` | Admin email address |
| `ADMIN_PASSWD` | `Railway2026!` | Admin password |

### Auto-Configured Variables (do not change)

| Variable | Description |
|----------|-------------|
| `PS_INSTALL_AUTO` | Enables automatic CLI installation |
| `PS_DOMAIN` | Set from Railway's public domain |
| `PS_HANDLE_DYNAMIC_DOMAIN` | Enables automatic domain migration |
| `PS_ENABLE_SSL` | Enables HTTPS URL generation |
| `DB_SERVER` | MySQL host via Railway private network |
| `DB_USER` / `DB_PASSWD` / `DB_NAME` | Database credentials (auto-wired from MySQL service) |

## Custom Domain

To use a custom domain (e.g., `mystore.com`):

1. In Railway dashboard, go to your PrestaShop service **Settings > Networking**
2. Add your custom domain
3. Configure DNS as instructed by Railway
4. PrestaShop will automatically detect and use the new domain (via `PS_HANDLE_DYNAMIC_DOMAIN`)

No need to manually update `PS_DOMAIN` -- the dynamic domain handler updates the database automatically on the first request to the new domain.

## Architecture

This template deploys two services:

- **PrestaShop** -- Custom Dockerfile based on the official `prestashop/prestashop:9-apache` image with a Railway-aware entrypoint. Volume mounted at `/var/www/html` for persistent storage of modules, themes, uploads, and configuration.

- **MySQL** -- Railway's built-in MySQL database service. Persistence and backups handled automatically by Railway.

Services communicate over Railway's private network (`*.railway.internal`), with only PrestaShop exposed publicly.

### What the Entrypoint Handles

The custom `railway-entrypoint.sh` adds Railway-specific logic before delegating to the official PrestaShop entrypoint:

- **Volume cleanup**: Removes `lost+found` from ext4 volumes (prevents Symfony crashes)
- **Stale lock cleanup**: Removes `install.lock` from failed installs
- **Admin folder normalization**: Renames the installer's random `admin<hash>` folder to `PS_FOLDER_ADMIN`
- **Apache MPM fix**: Ensures `mpm_prefork` is loaded (required for `mod_php`)
- **Version tracking**: Detects image upgrades and force-copies updated core files
- **SSL behind proxy**: Apache config trusts `X-Forwarded-Proto` from Railway's edge
- **Database SSL flags**: Init script ensures `PS_SSL_ENABLED` is set in the database

## Upgrading

When the template image is updated (e.g., PrestaShop 9.0.3 to 9.0.4), the entrypoint automatically:

1. Detects the version change via a `.ps-version` tracking file
2. Force-copies updated core files from the new image into the volume
3. Preserves user-installed modules, themes, and uploads

## Troubleshooting

### Site doesn't load after deploy

The first installation takes 3-5 minutes. Check deployment logs in the Railway dashboard for progress.

### Admin panel shows security warning

If you see an SSL or admin folder security warning, redeploy the service. The entrypoint fixes both issues automatically on startup.

### Redirect loops or wrong domain

The dynamic domain handler resolves this on the next request. If not, verify `PS_HANDLE_DYNAMIC_DOMAIN` is set to `1`.

### Database connection errors

The entrypoint automatically waits for MySQL to be ready. If errors persist, check that the MySQL service is running in your Railway dashboard.
