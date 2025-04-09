#!/bin/bash

##############################################
# 🚀 LAMP Manager Script (Modular + Safe)
# Author: Christos A. Daggas
# Fedora/RHEL/CentOS based systems
##############################################

install_lamp_stack() {
    echo "📦 Updating system packages..."
    sudo dnf upgrade --refresh -y

    echo "🌐 Installing Apache HTTP Server..."
    sudo dnf install httpd -y
    sudo systemctl start httpd
    sudo systemctl enable httpd

    echo ""
    echo "🧠 Select PHP version:"
    echo "1) PHP 8.1"
    echo "2) PHP 8.3"
    read -p "📌 Selection (1 or 2): " PHP_CHOICE

    case "$PHP_CHOICE" in
        1) PHP_VERSION="8.1" ;;
        2) PHP_VERSION="8.3" ;;
        *) echo "❌ Invalid selection. Exiting."; exit 1 ;;
    esac

    echo "📥 Adding Remi repository..."
    sudo dnf install -y https://rpms.remirepo.net/fedora/remi-release-41.rpm
    sudo dnf module reset php -y
    sudo dnf module enable php:remi-${PHP_VERSION} -y

    echo "🧩 Installing PHP $PHP_VERSION and extensions..."
    sudo dnf install -y php php-cli php-fpm php-mysqlnd php-zip php-devel \
    php-gd php-mbstring php-curl php-xml php-bcmath php-json php-intl \
    php-iconv php-fileinfo

    sudo systemctl start php-fpm
    sudo systemctl enable php-fpm

    echo "🗄️ Installing MariaDB (MySQL)..."
    sudo dnf install mariadb-server -y
    sudo systemctl start mariadb
    sudo systemctl enable mariadb

    echo "🔐 Running MySQL secure installation..."
    sudo mysql_secure_installation

    echo "✅ LAMP stack installed with PHP $PHP_VERSION"
}

setup_mysql() {
    read -p "👤 Enter MySQL username: " ADMIN_USER
    read -s -p "🔑 Enter password for ${ADMIN_USER}: " ADMIN_PASS
    echo ""
    read -p "🗃️ Enter database name: " ADMIN_DB

    echo "🛠 Creating MySQL user and database..."
    sudo mysql -u root -p -e "CREATE DATABASE ${ADMIN_DB};"
    sudo mysql -u root -p -e "CREATE USER '${ADMIN_USER}'@'localhost' IDENTIFIED BY '${ADMIN_PASS}';"
    sudo mysql -u root -p -e "GRANT ALL PRIVILEGES ON ${ADMIN_DB}.* TO '${ADMIN_USER}'@'localhost';"
    sudo mysql -u root -p -e "FLUSH PRIVILEGES;"

    echo "✅ MySQL user and DB created."
}

set_permissions() {
    echo "🔧 Setting permissions for /var/www/html..."
    sudo chown -R $(whoami):apache /var/www/html
    sudo find /var/www/html -type d -exec chmod 2775 {} \;
    sudo find /var/www/html -type f -exec chmod 664 {} \;
    sudo chmod g+s /var/www/html

    echo "🧬 Applying ACLs..."
    sudo setfacl -R -m g::rwx /var/www/html
    sudo setfacl -R -m o::rx /var/www/html
    sudo setfacl -R -d -m g::rwx /var/www/html
    sudo setfacl -R -d -m o::rx /var/www/html

    echo "🔒 Applying SELinux context..."
    sudo chcon -R -t httpd_sys_rw_content_t /var/www/html

    echo "✅ Base permissions applied."
}

fix_custom_folder() {
    read -p "📂 Enter folder name under /var/www/html (e.g. site): " DIR_NAME
    FULL_PATH="/var/www/html/$DIR_NAME"

    if [ ! -d "$FULL_PATH" ]; then
        echo "❌ Directory does not exist: $FULL_PATH"
        return
    fi

    echo "🔧 Fixing permissions for $FULL_PATH..."
    sudo chown -R $(whoami):apache "$FULL_PATH"
    sudo find "$FULL_PATH" -type d -exec chmod 2775 {} \;
    sudo find "$FULL_PATH" -type f -exec chmod 664 {} \;
    sudo setfacl -R -m g::rwx "$FULL_PATH"
    sudo setfacl -R -m o::rx "$FULL_PATH"
    sudo setfacl -R -d -m g::rwx "$FULL_PATH"
    sudo setfacl -R -d -m o::rx "$FULL_PATH"
    sudo chcon -R -t httpd_sys_rw_content_t "$FULL_PATH"

    echo "✅ Permissions fixed for $FULL_PATH"
}

restart_services() {
    echo "🔄 Restarting services..."
    sudo systemctl restart httpd
    sudo systemctl restart php-fpm
    echo "✅ Apache and PHP-FPM restarted."
}

uninstall_apache() {
    echo "🛑 Uninstalling Apache..."
    sudo systemctl stop httpd
    sudo systemctl disable httpd
    sudo dnf remove -y httpd
    echo "✅ Apache removed."
}

uninstall_php() {
    echo "🛑 Uninstalling PHP..."
    sudo systemctl stop php-fpm
    sudo systemctl disable php-fpm
    sudo dnf remove -y php*
    echo "✅ PHP removed."
}

uninstall_mariadb() {
    echo "🛑 Preparing to uninstall MariaDB..."

    read -p "📦 Do you want to backup your databases before uninstalling? (y/n): " BACKUP
    if [[ "$BACKUP" == "y" ]]; then
        BACKUP_DIR=~/Documents/mysql_backup
        mkdir -p "$BACKUP_DIR"
        sudo cp -r /var/lib/mysql "$BACKUP_DIR"
        sudo chown -R $(whoami): "$BACKUP_DIR"
        echo "✅ Databases backed up to $BACKUP_DIR"
    fi

    sudo systemctl stop mariadb
    sudo systemctl disable mariadb
    sudo dnf remove -y mariadb-server mariadb mariadb-libs
    echo "✅ MariaDB removed."
}

uninstall_lamp() {
    echo "⚠️ WARNING: This will completely remove Apache, PHP, MariaDB, and all website files."
    read -p "Type 'YES' to confirm full uninstall: " CONFIRM

    if [[ "$CONFIRM" != "YES" ]]; then
        echo "❌ Uninstall cancelled."
        return
    fi

    uninstall_apache
    uninstall_php
    uninstall_mariadb

    echo "🧹 Cleaning up /var/www/html..."
    sudo rm -rf /var/www/html/*

    echo "🔒 Clearing SELinux contexts..."
    sudo restorecon -Rv /var/www/html

    echo "🔥 Resetting firewall ports..."
    sudo firewall-cmd --remove-service=http --permanent
    sudo firewall-cmd --remove-service=https --permanent
    sudo firewall-cmd --reload

    echo "✅ Full LAMP uninstall complete."
}

full_install() {
    install_lamp_stack
    setup_mysql
    set_permissions
    echo "✅ Full install (LAMP + MySQL + Permissions) completed!"
}

# 🧭 MENU
while true; do
    echo ""
    echo "=============================="
    echo "        LAMP SETUP TOOL       "
    echo "=============================="
    echo "1) Install LAMP Stack"
    echo "2) Setup MySQL User & Database"
    echo "3) Set Base Permissions (/var/www/html)"
    echo "4) Fix Permissions on Custom Folder"
    echo "5) Restart Apache & PHP-FPM"
    echo "6) Run 1+2+3 (Full Install)"
    echo "8) Uninstall Apache Only"
    echo "9) Uninstall PHP Only"
    echo "10) Uninstall MariaDB (with optional DB backup)"
    echo "11) Uninstall Everything (Full LAMP Reset)"
    echo "0) Exit"
    echo "=============================="
    read -p "Choose an option: " CHOICE

    case $CHOICE in
        1) install_lamp_stack ;;
        2) setup_mysql ;;
        3) set_permissions ;;
        4) fix_custom_folder ;;
        5) restart_services ;;
        6) full_install ;;
        8) uninstall_apache ;;
        9) uninstall_php ;;
        10) uninstall_mariadb ;;
        11) uninstall_lamp ;;
        0) echo "👋 Exiting setup." && exit 0 ;;
        *) echo "❌ Invalid option." ;;
    esac
done
