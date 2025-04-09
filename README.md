# Fedora LAMP Manager Script 🚀

This script provides a **modular, interactive way** to install, manage, and uninstall a complete LAMP stack (Linux, Apache, MariaDB, PHP) on **Fedora** systems. It’s built for developers working with **PrestaShop** or any PHP-based platform, offering smart defaults, permission automation, and rollback options.

---

## 🚩 Quick Start

Clone or download the script, then execute:

```bash
cd ~/Downloads
chmod +x lamp-manager.sh
./lamp-manager.sh | tee lamp-log.txt
```

> ✅ Logs of the session will be saved to `lamp-log.txt` for review.

---

## ⚙️ Features & Components

### ✨ Modular LAMP Stack Management
- Apache HTTP Server installation & removal
- PHP (choose between 8.1 to 8.4 via Remi repo)
- PrestaShop-required PHP extensions
- MariaDB installation, configuration & safe removal (with backup)

### 🔐 MySQL Configuration
- Secure installation wizard included
- Creates a new MySQL admin user and database with privileges
- Optional backup of databases to `~/Documents/mysql_backup` before uninstalling MariaDB

### 🔧 Smart File Permissions & SELinux Support
- Applies correct ownership: `youruser:apache`
- Directories: `2775`, Files: `664`
- Sets sticky group bit (`g+s`) for inheritance
- Applies default ACLs so new files/folders automatically get correct permissions
- Assigns SELinux context: `httpd_sys_rw_content_t` for Apache compatibility

### 🔄 Service Automation
- Apache and PHP-FPM are started and enabled at boot
- Includes a menu option to restart services at any time

### 👨‍💻 Dev-Friendly Tools
- Easily fix permissions on any new folder under `/var/www/html`
- Modular menu lets you run only what you need (e.g. install PHP only, fix one folder, or uninstall Apache alone)
- Full install option: run LAMP install + MySQL setup + permission fix in one go

### ❌ Safe Uninstall Options
- Uninstall components individually (Apache, PHP, MariaDB)
- Uninstall full LAMP stack including websites and firewall rules
- Optional database backup before removing MariaDB

---

## 📊 Requirements

- Fedora Workstation or Server (tested on Fedora 39–41)
- `sudo` privileges
- Internet connection
- Basic familiarity with command line

---

## 🔢 Menu Overview

| Option | Description                                   |
|--------|-----------------------------------------------|
| 1      | Install LAMP Stack                            |
| 2      | Setup MySQL User & Database                   |
| 3      | Set Base Permissions on `/var/www/html`       |
| 4      | Fix Permissions on a Custom Folder            |
| 5      | Restart Apache & PHP-FPM Services             |
| 6      | Run 1+2+3 (Full LAMP Setup)                   |
| 8      | Uninstall Apache Only                         |
| 9      | Uninstall PHP Only                            |
| 10     | Uninstall MariaDB (with optional DB backup)   |
| 11     | Uninstall Entire LAMP Stack & Clean Server    |
| 0      | Exit                                           |

---

## ⚠️ Recommendations

- Backup important files before using uninstall options.
- Only remove MariaDB if you’re done with your databases or you’ve backed them up.
- Run as a user with `sudo` rights for full functionality.
- After making changes, restart the system or use the script’s service restart option.

---

## 🖥️ Tested Environment

- Fedora 41 Workstation
- SELinux: Enforcing
- Apache 2.4, PHP 8.1/8.4, MariaDB 10.5+
- FirewallD enabled

---

## 🤝 Contributions & Issues

This script is open to improvements! Submit issues, feature requests, or pull requests to help make it a more powerful tool for Fedora-based LAMP stack users.

Whether you're deploying PrestaShop, WordPress, or custom PHP apps — this script saves you time, reduces human error, and helps you focus on building your project 🚀
