
#!/bin/bash

echo "Updating system packages..."
sudo dnf upgrade --refresh -y

echo "Installing Apache HTTP Server..."
sudo dnf install httpd -y
sudo systemctl start httpd
sudo systemctl enable httpd

echo "Adding Remi repository for PHP 8.3..."
sudo dnf install -y https://rpms.remirepo.net/fedora/remi-release-41.rpm
sudo dnf module reset php -y
sudo dnf module enable php:remi-8.3 -y

echo "Installing PHP 8.3 with all PrestaShop-required extensions..."
sudo dnf install -y php php-cli php-fpm php-mysqlnd php-zip php-devel \
php-gd php-mbstring php-curl php-xml php-bcmath php-json php-intl \
php-iconv php-fileinfo

sudo systemctl start php-fpm
sudo systemctl enable php-fpm

echo "Installing MariaDB (MySQL-compatible)..."
sudo dnf install mariadb-server -y
sudo systemctl start mariadb
sudo systemctl enable mariadb

echo "Running MySQL secure installation..."
sudo mysql_secure_installation

# Δημιουργία επιπλέον MySQL admin user
echo ""
read -p "Enter name for new MySQL admin user: " ADMIN_USER
read -s -p "Enter password for ${ADMIN_USER}: " ADMIN_PASS
echo ""
read -p "Enter name for new database (will be created and assigned to user): " ADMIN_DB

echo "Creating new MySQL user and database..."
sudo mysql -u root -p -e "CREATE DATABASE ${ADMIN_DB};"
sudo mysql -u root -p -e "CREATE USER '${ADMIN_USER}'@'localhost' IDENTIFIED BY '${ADMIN_PASS}';"
sudo mysql -u root -p -e "GRANT ALL PRIVILEGES ON ${ADMIN_DB}.* TO '${ADMIN_USER}'@'localhost';"
sudo mysql -u root -p -e "FLUSH PRIVILEGES;"

echo "Setting ownership and permissions for /var/www/html..."
sudo chown -R $(whoami):apache /var/www/html
sudo chmod -R 775 /var/www/html
sudo find /var/www/html -type d -exec chmod g+s {} \;
sudo chcon -R -t httpd_sys_rw_content_t /var/www/html

echo "Setting SELinux permissions for Apache..."
sudo setsebool -P httpd_unified 1

echo "Allowing Apache to make outbound connections..."
sudo setsebool -P httpd_can_network_connect 1

echo "Opening firewall ports for HTTP and HTTPS (if firewall is active)..."
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload

echo "Creating test PHP file to validate setup..."
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/phpinfo.php > /dev/null

# Get Server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "=============================================="
echo " ✅ LAMP STACK INSTALLED SUCCESSFULLY"
echo "=============================================="
echo "Server IP Address         : $SERVER_IP"
echo "Apache Root               : /var/www/html"
echo "MySQL Admin User          : ${ADMIN_USER}"
echo "MySQL Admin Database      : ${ADMIN_DB}"
echo "PHP Info Page             : http://$SERVER_IP/phpinfo.php"
echo "=============================================="
echo "Drop your PrestaShop files into /var/www/html"
echo ""
