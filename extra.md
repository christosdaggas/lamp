# === LAMP + DEV full-write (root keeps ownership) + MySQL user ===
#!/bin/bash

USER_NAME="christos"
WEB_DIR="/var/www/html"

# Update and upgrade system
sudo dnf update -y


# Install HTTP server and enable it
sudo dnf install -y acl httpd mod_http2 sudo 
sudo systemctl enable --now httpd

# Allow HTTP and HTTPS traffic through firewall
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# Install and enable MariaDB (MySQL)
sudo dnf install -y mariadb-server
sudo systemctl enable --now mariadb
sudo mysql_secure_installation

# Install PHP and PHP extensions
sudo dnf install -y php php-fpm php-cli php-mysqlnd php-zip php-devel php-gd php-mbstring php-curl php-xml php-bcmath php-json php-intl php-fileinfo php-opcache
sudo systemctl enable --now php-fpm
sudo systemctl restart httpd

# Install ACL and policy tools
sudo dnf install -y acl policycoreutils-python-utils

# Create 'webdev' group and add the user and apache to it
sudo groupadd -f webdev
sudo usermod -aG webdev "$USER_NAME"
sudo usermod -aG webdev apache

# Set ownership and permissions for the web directory
sudo chown -R root:webdev "$WEB_DIR"
sudo chmod -R 2775 "$WEB_DIR"

# Set Access Control Lists (ACLs) to allow specific access
sudo setfacl -R -m u:${USER_NAME}:rwx,g:apache:rwx "$WEB_DIR"
sudo setfacl -d -m u:${USER_NAME}:rwx,g:apache:rwX "$WEB_DIR"

# Set security contexts for the web directory
sudo chcon -R -t httpd_sys_rw_content_t "$WEB_DIR"

# Allow HTTPD to connect to the network and databases
sudo setsebool -P httpd_can_network_connect_db 1
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P httpd_can_network_relay 1
sudo setsebool -P nis_enabled 1

# Create PHP info file for testing
echo '<?php phpinfo();' | sudo tee ${WEB_DIR}/info.php >/dev/null
sudo systemctl restart httpd php-fpm

# Create MySQL user and grant privileges
sudo mysql -uroot <<'EOF'
CREATE USER IF NOT EXISTS 'user'@'localhost' IDENTIFIED BY '00000000';
GRANT ALL PRIVILEGES ON *.* TO 'user'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# Final message
echo "LAMP installed, /var/www/html writable for christos & apache (root keeps ownership), MySQL user 'user' ready."


=======================================================================
# === LAMP + DEV full-write (root keeps ownership) + MySQL user ===
USER_NAME="christos"
WEB_DIR="/var/www/html/"

USER_NAME="christos"
sudo setfacl -R -m u:${USER_NAME}:rwx,g:apache:rwx "$WEB_DIR"
sudo setfacl -d -m u:${USER_NAME}:rwx,g:apache:rwX "$WEB_DIR"


sudo setfacl -R -m u:${USER_NAME}:rwx,g:apache:rwx "$WEB_DIR"
sudo setfacl -d -m u:${USER_NAME}:rwx,g:apache:rwX "$WEB_DIR"
