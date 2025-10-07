# === LAMP + DEV full-write (root keeps ownership) + MySQL user ===
USER_NAME="christos"
WEB_DIR="/var/www/html"

sudo dnf update -y

sudo dnf install -y httpd mod_http2
sudo systemctl enable --now httpd
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

sudo dnf install -y mariadb-server
sudo systemctl enable --now mariadb
sudo mysql_secure_installation

sudo dnf install -y php php-fpm php-cli php-mysqlnd php-zip php-devel php-gd \
php-mbstring php-curl php-xml php-bcmath php-json php-intl php-fileinfo php-opcache
sudo systemctl enable --now php-fpm
sudo systemctl restart httpd

sudo dnf -y install acl policycoreutils-python-utils

sudo groupadd -f webdev
sudo usermod -aG webdev "$USER_NAME"
sudo usermod -aG webdev apache

sudo chown -R root:webdev "$WEB_DIR"
sudo chmod -R 2775 "$WEB_DIR"

sudo setfacl -R -m u:${USER_NAME}:rwx,g:apache:rwx "$WEB_DIR"
sudo setfacl -d -m u:${USER_NAME}:rwx,g:apache:rwX "$WEB_DIR"

sudo chcon -R -t httpd_sys_rw_content_t "$WEB_DIR"

sudo setsebool -P httpd_can_network_connect_db 1
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P httpd_can_network_relay 1
sudo setsebool -P nis_enabled 1

echo '<?php phpinfo();' | sudo tee ${WEB_DIR}/info.php >/dev/null
sudo systemctl restart httpd php-fpm

sudo mysql -uroot <<'EOF'
CREATE USER IF NOT EXISTS 'user'@'localhost' IDENTIFIED BY '00000000';
GRANT ALL PRIVILEGES ON *.* TO 'user'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

echo "LAMP installed, /var/www/html writable for christos & apache (root keeps ownership), MySQL user 'user' ready."


=======================================================================

# === LAMP + DEV full-write + MySQL user (Fedora 42+) ===

sudo dnf update -y
sudo dnf install -y httpd mod_http2
sudo systemctl enable --now httpd
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

sudo dnf install -y mariadb-server
sudo systemctl enable --now mariadb
sudo mysql_secure_installation

sudo dnf install -y php php-fpm php-cli php-mysqlnd php-zip php-devel php-gd \
php-mbstring php-curl php-xml php-bcmath php-json php-intl php-fileinfo php-opcache
sudo systemctl enable --now php-fpm
sudo systemctl restart httpd

# === DEV full-write on /var/www/html ===
USER_NAME="christos"
WEB_DIR="/var/www/html"

sudo dnf -y install acl policycoreutils-python-utils
sudo groupadd -f webdev
sudo usermod -aG webdev "$USER_NAME"
sudo usermod -aG webdev apache
sudo chgrp -R webdev "$WEB_DIR"
sudo chmod -R 2775 "$WEB_DIR"

sudo setfacl -R -m u:${USER_NAME}:rwx,g:apache:rwx "$WEB_DIR"
sudo setfacl -d -m u:${USER_NAME}:rwx,g:apache:rwX "$WEB_DIR"

sudo chcon -R -t httpd_sys_rw_content_t "$WEB_DIR"

sudo setsebool -P httpd_can_network_connect_db 1
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P httpd_can_network_relay 1
sudo setsebool -P nis_enabled 1

echo '<?php phpinfo();' | sudo tee ${WEB_DIR}/info.php >/dev/null
sudo systemctl restart httpd php-fpm

# === MySQL user creation ===
sudo mysql -uroot <<'EOF'
CREATE USER IF NOT EXISTS 'user'@'localhost' IDENTIFIED BY '00000000';
GRANT ALL PRIVILEGES ON *.* TO 'user'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

echo "✅ LAMP installed, /var/www/html writable, MySQL user 'user' ready."




