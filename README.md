# PrestaShop LAMP Stack Installer (Fedora)

This is a simple Bash script to automate the installation and configuration of a **LAMP stack** (Linux, Apache, MariaDB, PHP) optimized for running **PrestaShop** on a **Fedora**-based system.

## ⚙️ What It Does

- Updates system packages
- Installs Apache HTTP server
- Installs PHP 8.3 via Remi repository with all required PrestaShop extensions
- Installs and configures MariaDB
- Secures the MySQL installation and creates a new database + admin user
- Sets permissions and SELinux rules for `/var/www/html`
- Opens HTTP and HTTPS ports in the firewall
- Generates a `phpinfo()` test file to verify PHP is working

## 📦 Requirements

- Fedora-based Linux distribution (tested on Fedora 41+)
- Root privileges (use `sudo` to run the script)

## 🚀 How to Use

```bash
chmod +x prestashop-lamp-install.sh
./prestashop-lamp-install.sh
```

During execution, you will be prompted to:

- Provide a MySQL admin username and password
- Define a new database name

## 🔒 Security Notes

- The script runs `mysql_secure_installation`, which will ask you to secure your root password and disable anonymous access.
- SELinux and firewall settings are configured to allow Apache access and outbound connections.

## 📁 Where to Place Your PrestaShop Files

Place your PrestaShop files in:

```
/var/www/html
```

Visit `http://<your-server-ip>/phpinfo.php` to verify your PHP setup.

## 📷 Output Example

```
 ✅ LAMP STACK INSTALLED SUCCESSFULLY
 Server IP Address         : 192.168.1.100
 Apache Root               : /var/www/html
 MySQL Admin User          : prestashop_admin
 MySQL Admin Database      : prestashop_db
 PHP Info Page             : http://192.168.1.100/phpinfo.php
 Drop your PrestaShop files into /var/www/html
```

## 🛠 Author

This script was created to make PrestaShop setup easier and faster for developers and sysadmins working on Fedora servers.
