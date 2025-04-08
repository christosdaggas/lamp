
# Fedora LAMP Stack Setup Script for PrestaShop 🚀

This script automates the installation and configuration of a full LAMP stack (Linux, Apache, MariaDB, PHP) on **Fedora** for use with **PrestaShop** or other PHP-based web applications. It applies ideal file permissions, enables SELinux compatibility, and prepares your server for web development or deployment.

---

## 🚩 Quick Start

Clone or download the script, then execute:

```bash
cd ~/Documents
chmod +x lamp-setup.sh
./lamp-setup.sh | tee lamp-install-log.txt
```

> ✅ Logs of the installation process will be saved to `lamp-install-log.txt`.

---

## ⚙️ Features & Components

### ✨ LAMP Stack Installation
- Apache HTTP Server
- PHP (choice of 8.1 or 8.3 via Remi repo)
- PHP extensions required for PrestaShop
- MariaDB (MySQL-compatible database)

### 🔐 MySQL Configuration
- Prompts for secure installation
- Creates a new admin MySQL user and database with full privileges

### 🔧 File Permissions & SELinux
- Ownership: `youruser:apache`
- Directories: `775`, Files: `664`
- Sticky group bit (`g+s`) on all dirs
- Sets default ACLs so new files/folders inherit correct permissions
- Applies proper SELinux context: `httpd_sys_rw_content_t`

### 🚀 Automation Enhancements
- Ensures Apache and PHP-FPM start and enable at boot
- Opens firewall ports for HTTP & HTTPS
- Creates `phpinfo.php` to verify installation

### 👨‍💻 Developer-Friendly Defaults
- New folders under `/var/www/html` automatically inherit web-safe permissions
- No need to re-run permission fixers when adding projects

---

## 📊 Requirements

- Fedora Workstation or Server (tested on Fedora 39–41)
- Root access / `sudo`
- Internet connection

---

## ⚠️ Recommendations

- Backup important data before running the script.
- Review the script to adjust MySQL and directory settings if needed.
- After installation, reboot your system to ensure all changes apply.

---

## 🖥️ Tested Environment

- Fedora 41 Workstation (GNOME)
- SELinux: Enforcing
- Apache 2.4, PHP 8.1/8.3, MariaDB 10.5+

---

## 🤝 Contributions & Issues

Feel free to report issues, request features, or submit pull requests to improve this script. Whether you're deploying PrestaShop or using this as a base LAMP stack, your feedback helps make it better for everyone!
