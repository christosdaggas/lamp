#!/bin/bash

echo "📦 Updating system packages..."
sudo dnf upgrade --refresh -y

echo "🌐 Installing Apache HTTP Server..."
sudo dnf install httpd -y
sudo systemctl start httpd
sudo systemctl enable httpd

# PHP version selection
echo ""
echo "🧠 Select PHP version:"
echo "1) PHP 8.1"
echo "2) PHP 8.3"
read -p "📌 Selection (1 ή 2): " PHP_CHOICE

case "$PHP_CHOICE" in
    1)
        PHP_VERSION="8.1"
        ;;
    2)
        PHP_VERSION="8.3"
        ;;
    *)
        echo "❌ Invalid selection. Run the script again and select 1 or 2."
        exit 1
        ;;
esac

echo "📥 Adding Remi repository..."
sudo dnf install -y https://rpms.remirepo.net/fedora/remi-release-41.rpm
sudo dnf module reset php -y
sudo dnf module enable php:remi-${PHP_VERSION} -y

echo "🧩 Installing PHP $PHP_VERSION with PrestaShop-required extensions..."
sudo dnf install -y php php-cli php-fpm php-mysqlnd php-zip php-devel \
php-gd php-mbstring php-curl php-xml php-bcmath php-json php-intl \
php-iconv php-fileinfo

sudo systemctl start php-fpm
sudo systemctl enable php-fpm

echo "🗄️ Installing MariaDB (MySQL-compatible)..."
sudo dnf install mariadb-server -y
sudo systemctl start mariadb
sudo systemctl enable mariadb

echo "🔐 Running MySQL secure installation..."
sudo mysql_secure_installation

# MySQL user & DB setup
echo ""
read -p "👤 Enter name for new MySQL admin user: " ADMIN_USER
read -s -p "🔑 Enter password for ${ADMIN_USER}: " ADMIN_PASS
echo ""
read -p "🗃️ Enter name for new database: " ADMIN_DB

echo "🛠 Creating new MySQL user and database..."
sudo mysql -u root -p -e "CREATE DATABASE ${ADMIN_DB};"
sudo mysql -u root -p -e "CREATE USER '${ADMIN_USER}'@'localhost' IDENTIFIED BY '${ADMIN_PASS}';"
sudo mysql -u root -p -e "GRANT ALL PRIVILEGES ON ${ADMIN_DB}.* TO '${ADMIN_USER}'@'localhost';"
sudo mysql -u root -p -e "FLUSH PRIVILEGES;"

# PERMISSIONS & GROUP SETUP
echo "🔧 Setting ownership and permissions for /var/www/html..."
sudo chown -R $(whoami):apache /var/www/html

echo "🔐 Setting permissions recursively (775 for dirs, 664 for files)..."
sudo find /var/www/html -type d -exec chmod 775 {} \;
sudo find /var/www/html -type f -exec chmod 664 {} \;

echo "🧲 Enabling sticky group bit on all directories..."
sudo find /var/www/html -type d -exec chmod g+s {} \;
sudo chmod g+s /var/www/html

echo "🧬 Setting default ACLs for new files/folders..."
sudo setfacl -R -d -m g::rwx /var/www/html
sudo setfacl -R -d -m o::rx /var/www/html

echo "🔒 Applying SELinux context for Apache access..."
sudo chcon -R -t httpd_sys_rw_content_t /var/www/html

# SELinux and firewall
echo "🔧 Setting SELinux booleans for Apache..."
sudo setsebool -P httpd_unified 1
sudo setsebool -P httpd_can_network_connect 1

echo "🌐 Opening firewall ports for HTTP and HTTPS..."
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload

# PHP test
echo "🧪 Creating test PHP file..."
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/phpinfo.php > /dev/null

# Server info
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "=============================================="
echo " ✅ LAMP STACK INSTALLED SUCCESSFULLY"
echo "=============================================="
echo "Server IP Address         : $SERVER_IP"
echo "Apache Root               : /var/www/html"
echo "MySQL Admin User          : ${ADMIN_USER}"
echo "MySQL Admin Database      : ${ADMIN_DB}"
echo "PHP Version Installed     : ${PHP_VERSION}"
echo "PHP Info Page             : http://$SERVER_IP/phpinfo.php"
echo "=============================================="
echo "Drop your PrestaShop files into /var/www/html"
echo ""
