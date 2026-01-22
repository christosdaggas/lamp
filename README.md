
# Fedora LAMP DEV Manager Script 🚀

This script provides an interactive way to install and manage a developer-focused LAMP stack (Apache, MariaDB, PHP-FPM) on Fedora 43. It is optimized for PrestaShop and other PHP apps, and includes VHost automation, SSL (Let’s Encrypt + self-signed), repeatable permissions (ACL + SELinux), backups/restores, and live log tailing.

---

## Quick Start ⚡

```bash
cd ~/Downloads
chmod +x lamp-setup.sh
./lamp-setup.sh | tee lamp-log.txt
```

Logs will be written to `lamp-log.txt`.

---

## What It Installs and Configures 🧱

### Apache + PHP-FPM (Fedora repositories)

* Apache HTTPD with HTTP/2 and SSL modules (`mod_http2`, `mod_ssl`)
* PHP-FPM using a Unix socket (`/run/php-fpm/www.sock`)
* Ensures required Apache proxy modules for PHP-FPM (`mod_proxy`, `mod_proxy_fcgi`)
* PrestaShop-friendly PHP extensions:

  * `mysqlnd/mysqli`, `zip`, `intl`, `mbstring`, `curl`, `xml`, `gd`, `bcmath`, `opcache`
* Enables and starts services at boot (`httpd`, `php-fpm`)
* Opens firewall services: HTTP/HTTPS (if firewalld is available)

### MariaDB (DEV mode)

* Installs and enables MariaDB
* Configures MariaDB to listen on `0.0.0.0` (remote access enabled)
* Opens firewall port `3306/tcp` (if firewalld is available)

Warning: Remote DB access from any IP is a security risk. This is intended for development workflows only.

---

## Permissions Model 🔐

Permissions are applied only inside `/var/www/html` (and subfolders). Your personal files are not affected.

The script applies:

* `root:apache` ownership on `/var/www/html`
* setgid on directories so new folders inherit group `apache`
* default ACLs so both your user and Apache can read/write/delete content
* SELinux context for writable web content: `httpd_sys_rw_content_t` (when SELinux is enabled)
* systemd `UMask=0002` for `httpd` and `php-fpm` so service-created files remain group-writable

---

## VHosts Management 🧭

### Create project VHost

* Creates a vhost config under `/etc/httpd/conf.d/20-<domain>.conf`
* Creates the project docroot under `/var/www/html/<folder>`
* Optionally adds a local `/etc/hosts` entry (`127.0.0.1 domain`) for local-only testing
* Applies permissions to the new project folder

---

## SSL Features 🔒

### Self-signed SSL (Local/Internal Testing)

* Generates a self-signed certificate per domain:

  * certs: `/etc/pki/tls/certs`
  * keys: `/etc/pki/tls/private`
* Appends a `:443` vhost block to the selected vhost config if it doesn’t already exist
* Enables HTTP/2 on the SSL vhost

### Let’s Encrypt SSL (Public subdomains / Client preview)

* Uses `certbot` with the Apache plugin to issue and install certificates automatically
* Supports HTTP → HTTPS redirect

Prerequisites:

* The domain must resolve publicly (DNS A/AAAA) to your public IP
* Port `80` must be reachable from the internet (NAT/port forward if needed)

---

## Backup and Restore 💾

### Backup project

Backups are created under:

* `~/lamp_backups/<domain>_<timestamp>/`

Includes:

* `files.zip` containing only the docroot contents (safe to restore into any vhost)
* optional `db.sql` export (if you provide DB name and credentials)
* `meta.txt` with domain/docroot/timestamp

### Smart Restore

* Lists backups inside `~/lamp_backups/`
* Lets you pick a backup and choose a destination vhost
* Replaces destination docroot contents, then restores DB if `db.sql` exists
* Re-applies permissions after restoring

---

## Live Log Tailer 👀

* Select a vhost and tail the corresponding Apache error log:

  * `/var/log/httpd/<domain>_error.log`
* Shows last 20 lines and follows live output (`tail -f`)

---

## Requirements ✅

* Fedora 43 (recommended/target)
* `sudo` privileges
* Internet access (dnf installs, certbot, etc.)
* SELinux supported (works in Enforcing; script applies contexts/booleans where needed)
* firewalld recommended (script automatically opens required ports/services when present)

---

## Menu Overview 🧾

| Option | Description                                          |
| -----: | ---------------------------------------------------- |
|      1 | Full Install (Apache, PHP-FPM, MariaDB, Permissions) |
|      2 | Create New VHost                                     |
|      3 | Issue Self-signed SSL                                |
|      4 | Issue Let’s Encrypt SSL                              |
|      5 | Backup Project (Files + optional DB)                 |
|      6 | View Live Error Logs (tail -f)                       |
|      7 | Smart Restore (Files + optional DB)                  |
|      8 | Re-apply permissions on `/var/www/html`              |
|      9 | Restart services (httpd/php-fpm/mariadb)             |
|      0 | Exit                                                 |

---

## Recommendations 💡

* Run option 1 once on a fresh machine.
* For each new project:

  1. Create a vhost (option 2)
  2. Deploy PrestaShop/app into the project docroot
  3. Create DB/user via your preferred method (MariaDB remote is enabled by default)
  4. Use Let’s Encrypt (option 4) if the subdomain is publicly reachable
* Use Backup/Restore (options 5 and 7) before major upgrades, module installs, or content migrations.

---

## Tested Environment 🧪

* Fedora 43
* SELinux: Enforcing
* firewalld enabled
* Apache httpd + PHP-FPM + MariaDB from Fedora repos

```
::contentReference[oaicite:0]{index=0}
```
