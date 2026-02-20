# PrestaShop on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/template/prestashop)

One-click deployment of [PrestaShop](https://www.prestashop-project.org/) on [Railway](https://railway.com).

## What's Included

- **PrestaShop 9.x** (latest stable, currently 9.0.3) with PHP 8.4 and Apache
- **MySQL** via Railway's built-in database service
- **Persistent storage** via Railway volumes for app files (database persistence handled by Railway)
- **Auto-installation** with demo data on first deploy
- **SSL/HTTPS** handled automatically by Railway's edge proxy
- **Dynamic domain support** -- works with Railway domains and custom domains

## Quick Start

1. Click the **Deploy on Railway** button above
2. Configure optional variables (language, country, admin email) or accept defaults
3. Wait 3-5 minutes for the initial installation to complete
4. Visit your Railway-provided domain to see your store

## Accessing the Admin Panel

After deployment, access the admin panel at:

```
https://your-domain.up.railway.app/admin
```

The default admin folder is `admin`. You can change this by setting the `PS_FOLDER_ADMIN` variable before first deploy for added security.

### Finding Your Admin Password

Your admin password is auto-generated during deployment. To retrieve it:

1. Go to your Railway project dashboard
2. Click the **PrestaShop** service
3. Go to the **Variables** tab
4. Find the `ADMIN_PASSWD` variable

The default admin email is `admin@example.com` (configurable via `ADMIN_MAIL`).

## Configuration

### User-Configurable Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PS_LANGUAGE` | `en` | Default store language (ISO code) |
| `PS_COUNTRY` | `US` | Default store country (ISO code) |
| `PS_FOLDER_ADMIN` | `admin` | Admin panel URL path. Change for security. |
| `ADMIN_MAIL` | `admin@example.com` | Admin email address |

### Auto-Configured Variables (do not change)

| Variable | Description |
|----------|-------------|
| `PS_INSTALL_AUTO` | Enables automatic CLI installation |
| `PS_DOMAIN` | Set from Railway's public domain |
| `PS_HANDLE_DYNAMIC_DOMAIN` | Enables automatic domain migration |
| `PS_ENABLE_SSL` | Enables HTTPS URL generation |
| `DB_SERVER` | MySQL connection via Railway private network |
| `DB_USER` / `DB_PASSWD` | Database credentials (auto-wired from MySQL service) |
| `ADMIN_PASSWD` | Auto-generated admin password |

## Custom Domain

To use a custom domain (e.g., `mystore.com`):

1. In Railway dashboard, go to your PrestaShop service **Settings > Networking**
2. Add your custom domain
3. Configure DNS as instructed by Railway
4. PrestaShop will automatically detect and use the new domain (via `PS_HANDLE_DYNAMIC_DOMAIN`)

No need to manually update `PS_DOMAIN` -- the dynamic domain handler updates the database automatically on the first request to the new domain.

## Architecture

This template deploys two services:

- **PrestaShop** -- Custom Dockerfile based on the official `prestashop/prestashop:9-apache` image with a Railway-aware entrypoint wrapper. Volume mounted at `/var/www/html` for persistent storage of modules, themes, uploads, and configuration.

- **MySQL** -- Railway's built-in MySQL database service. Persistence and backups handled automatically by Railway.

Services communicate over Railway's private network (`*.railway.internal`), with only PrestaShop exposed publicly.

## Upgrading

When the template image is updated (e.g., PrestaShop 9.0.3 to 9.0.4), the Railway-aware entrypoint automatically:

1. Detects the version change via a `.ps-version` tracking file
2. Force-copies updated core files from the new image into the volume
3. Preserves user-installed modules, themes, and uploads

## Security Recommendations

- **Change the admin folder name**: Set `PS_FOLDER_ADMIN` to something unique before first deploy
- **Change the admin email**: Set `ADMIN_MAIL` to your real email
- **Save your admin password**: Copy `ADMIN_PASSWD` from Railway variables to a secure location

## Troubleshooting

### Site shows "Installing..." or doesn't load after deploy

The first installation takes 3-5 minutes. Wait for the deployment health check to pass (visible in Railway dashboard).

### Redirect loops or wrong domain

If you see redirect issues after changing domains, the dynamic domain handler should resolve it on the next request. If not, verify `PS_HANDLE_DYNAMIC_DOMAIN` is set to `1`.

### Database connection errors

The PrestaShop entrypoint automatically waits for MySQL to be ready. If errors persist, check that the MySQL service is running in your Railway dashboard.
