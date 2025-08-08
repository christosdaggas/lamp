#!/bin/bash
# LAMP + MySQL + DEV full-write on /var/www/html (Fedora 42)
# WITH PHP VERSION SELECT + site fixers + restart/uninstall options
set -euo pipefail

# Ask for username, default to current logged in user
DEFAULT_USER=$(whoami)
read -rp "👤 Enter the Linux username to set permissions for [${DEFAULT_USER}]: " USER_NAME
USER_NAME=${USER_NAME:-$DEFAULT_USER}

WEB_DIR=/var/www/html
REMIREPO_RPM="https://rpms.remirepo.net/fedora/remi-release-42.rpm"

msg(){ echo -e "\033[1;32m$*\033[0m"; }
warn(){ echo -e "\033[1;33m$*\033[0m"; }
err(){ echo -e "\033[1;31m$*\033[0m"; }

select_php_version() {
  echo ""
  echo "🧠 Select PHP version (Remi stream):"
  echo "1) PHP 8.1"
  echo "2) PHP 8.2"
  echo "3) PHP 8.3"
  echo "4) PHP 8.4"
  read -rp "📌 Selection (1–4): " PHP_CHOICE
  case "$PHP_CHOICE" in
    1) PHP_VERSION="8.1" ;;
    2) PHP_VERSION="8.2" ;;
    3) PHP_VERSION="8.3" ;;
    4) PHP_VERSION="8.4" ;;
    *) err "❌ Invalid selection."; exit 1 ;;
  esac
  msg "📥 Adding Remi repo (Fedora 42) + enabling php:remi-${PHP_VERSION}…"
  sudo dnf install -y "$REMIREPO_RPM"
  sudo dnf module -y reset php
  sudo dnf module -y enable php:remi-${PHP_VERSION}
}

install_lamp_stack() {
  msg "📦 Updating system packages..."
  sudo dnf upgrade --refresh -y

  msg "🌐 Installing Apache..."
  sudo dnf install -y httpd mod_http2
  sudo systemctl enable --now httpd

  select_php_version

  msg "🧩 Installing PHP ${PHP_VERSION} (FPM) + common extensions…"
  sudo dnf install -y php php-fpm php-cli php-mysqlnd php-zip php-devel \
    php-gd php-mbstring php-curl php-xml php-bcmath php-json php-intl php-fileinfo php-opcache
  sudo systemctl enable --now php-fpm

  msg "🗄️ Installing MariaDB..."
  sudo dnf install -y mariadb-server
  sudo systemctl enable --now mariadb

  msg "🔐 Running mysql_secure_installation (interactive)…"
  sudo mysql_secure_installation || true

  msg "🧱 Opening firewall ports (HTTP/HTTPS)…"
  sudo firewall-cmd --add-service=http --permanent || true
  sudo firewall-cmd --add-service=https --permanent || true
  sudo firewall-cmd --reload || true

  msg "🔧 Apache base (.htaccess + index + ServerName)…"
  sudo bash -c 'cat >/etc/httpd/conf.d/10-www.conf' <<'EOF'
ServerName localhost
<Directory "/var/www/html">
    AllowOverride All
    Require all granted
    DirectoryIndex index.php index.html
</Directory>
EOF

  # Dev networking booleans (API/DB over TCP)
  sudo setsebool -P httpd_can_network_connect 1
  sudo setsebool -P httpd_can_network_connect_db 1

  # Dev php.ini to surface errors
  sudo mkdir -p /etc/php.d
  sudo bash -c 'cat >/etc/php.d/99-dev.ini' <<'EOF'
display_errors=On
display_startup_errors=On
error_reporting=E_ALL
log_errors=On
memory_limit=512M
max_execution_time=180
EOF

  # Ensure mod_rewrite is loaded
  if ! sudo httpd -M 2>/dev/null | grep -q rewrite_module; then
    echo "LoadModule rewrite_module modules/mod_rewrite.so" \
      | sudo tee /etc/httpd/conf.modules.d/99-rewrite.conf >/dev/null
  fi

  msg "✅ LAMP installed (Apache + PHP-FPM ${PHP_VERSION} + MariaDB)."
}

setup_mysql() {
  read -rp "👤 Enter MySQL username: " ADMIN_USER
  read -srp "🔑 Enter password for ${ADMIN_USER}: " ADMIN_PASS; echo
  read -rp "🗃️ Enter database name: " ADMIN_DB

  msg "🛠 Creating MySQL DB & user (idempotent)…"
  sudo mysql -uroot -e "CREATE DATABASE IF NOT EXISTS \`${ADMIN_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS '${ADMIN_USER}'@'localhost' IDENTIFIED BY '${ADMIN_PASS}';
    GRANT ALL PRIVILEGES ON \`${ADMIN_DB}\`.* TO '${ADMIN_USER}'@'localhost';
    FLUSH PRIVILEGES;"
  msg "✅ MySQL user and DB ready."
}

dev_html_fullwrite() {
  msg "🧰 Installing tools (ACL + SELinux utils)…"
  sudo dnf -y install acl policycoreutils-python-utils >/dev/null

  msg "👥 Ensure $USER_NAME is in group 'apache'…"
  if ! id -nG "$USER_NAME" | tr ' ' '\n' | grep -qx apache; then
    sudo usermod -aG apache "$USER_NAME"
    warn "👉 Logout/Login after script so group applies."
  fi

  msg "📂 POSIX ownership & modes on ${WEB_DIR}…"
  sudo chown -R "${USER_NAME}:apache" "${WEB_DIR}"
  sudo find "${WEB_DIR}" -type d -exec chmod 2775 {} \;
  sudo find "${WEB_DIR}" -type f -exec chmod 0664 {} \;

  msg "🧬 ACLs (runtime + defaults)…"
  sudo setfacl -R -m u:${USER_NAME}:rwx,g:apache:rwx "${WEB_DIR}"
  sudo setfacl -d -m u:${USER_NAME}:rwx,g:apache:rwX "${WEB_DIR}"

  msg "🔒 SELinux: make ALL of ${WEB_DIR} writable by Apache (DEV)…"
  sudo semanage fcontext -a -t httpd_sys_rw_content_t "${WEB_DIR}(/.*)?"
  sudo restorecon -Rv "${WEB_DIR}" >/dev/null

  # PHP temp dirs sanity
  if [ -d /var/lib/php ]; then
    sudo chgrp -R apache /var/lib/php || true
    sudo chmod -R 0775 /var/lib/php || true
    sudo restorecon -Rv /var/lib/php >/dev/null || true
  fi

  # Quick test page
  echo '<?php phpinfo();' | sudo tee ${WEB_DIR}/info.php >/dev/null

  sudo systemctl restart php-fpm httpd
  msg "✅ DEV mode ready."
}

fix_site() {
  read -rp "Site folder name under ${WEB_DIR} (e.g., prestashop): " SITE
  local SITE_DIR="${WEB_DIR}/${SITE}"
  [ -d "$SITE_DIR" ] || { err "No such dir: $SITE_DIR"; return 1; }

  msg "🔧 Fixing ONE site: ${SITE_DIR}"
  sudo chown -R "${USER_NAME}:apache" "$SITE_DIR"
  sudo find "$SITE_DIR" -type d -exec chmod 2775 {} \;
  sudo find "$SITE_DIR" -type f -exec chmod 0664 {} \;
  sudo setfacl -R -m u:${USER_NAME}:rwx,g:apache:rwx "$SITE_DIR"
  sudo setfacl -d -m u:${USER_NAME}:rwx,g:apache:rwX "$SITE_DIR"
  sudo restorecon -Rv "$SITE_DIR" >/dev/null
  msg "✅ Fixed ${SITE_DIR}"
}

fix_all_sites() {
  msg "🧰 Fixing ALL first-level folders under ${WEB_DIR}…"
  for d in "${WEB_DIR}"/*; do
    [ -d "$d" ] || continue
    sudo chown -R "${USER_NAME}:apache" "$d"
    sudo find "$d" -type d -exec chmod 2775 {} \;
    sudo find "$d" -type f -exec chmod 0664 {} \;
    sudo setfacl -R -m u:${USER_NAME}:rwx,g:apache:rwx "$d"
    sudo setfacl -d -m u:${USER_NAME}:rwx,g:apache:rwX "$d"
    sudo restorecon -Rv "$d" >/dev/null
    echo "✔ $d"
  done
  msg "✅ All sites fixed."
}

make_info() {
  echo '<?php phpinfo();' | sudo tee ${WEB_DIR}/info.php >/dev/null
  msg "ℹ️  Test at: http://localhost/info.php"
}

restart_services() {
  msg "🔄 Restarting Apache & PHP-FPM…"
  sudo systemctl restart httpd
  sudo systemctl restart php-fpm
  msg "✅ Services restarted."
}

uninstall_apache() {
  msg "🛑 Uninstalling Apache only…"
  sudo systemctl disable --now httpd || true
  sudo dnf remove -y httpd mod_http2 || true
  msg "✅ Apache removed."
}

uninstall_php() {
  msg "🛑 Uninstalling PHP-FPM and common extensions…"
  sudo systemctl disable --now php-fpm || true
  sudo dnf remove -y php php-fpm php-cli php-mysqlnd php-zip php-devel \
    php-gd php-mbstring php-curl php-xml php-bcmath php-json php-intl \
    php-fileinfo php-opcache || true
  msg "✅ PHP removed."
}

uninstall_mariadb() {
  warn "This will remove MariaDB server packages (data stays unless you delete /var/lib/mysql)."
  read -rp "📦 Backup /var/lib/mysql before uninstall? (y/N): " BACKUP
  if [[ "${BACKUP}" =~ ^[Yy]$ ]]; then
    local BACKUP_DIR=~/Documents/mysql_backup_$(date +%F_%H%M%S)
    mkdir -p "${BACKUP_DIR}"
    sudo cp -r /var/lib/mysql "${BACKUP_DIR}"
    sudo chown -R "${USER}:${USER}" "${BACKUP_DIR}" || true
    msg "✅ Databases backed up to ${BACKUP_DIR}"
  fi
  sudo systemctl disable --now mariadb || true
  sudo dnf remove -y mariadb-server mariadb mariadb-libs || true
  msg "✅ MariaDB removed."
}

uninstall_lamp() {
  warn "⚠️ This will remove Apache, PHP-FPM, and MariaDB."
  read -rp "Type 'YES' to confirm: " CONFIRM
  [[ "${CONFIRM}" == "YES" ]] || { err "Cancelled."; return; }

  uninstall_apache
  uninstall_php
  uninstall_mariadb

  read -rp "Also purge ${WEB_DIR} contents? (y/N): " PURGE
  if [[ "${PURGE}" =~ ^[Yy]$ ]]; then
    sudo rm -rf "${WEB_DIR:?}/"* || true
    sudo restorecon -Rv "${WEB_DIR}" >/dev/null || true
    msg "🧹 ${WEB_DIR} cleaned."
  fi

  msg "🔒 Closing firewall ports…"
  sudo firewall-cmd --remove-service=http --permanent || true
  sudo firewall-cmd --remove-service=https --permanent || true
  sudo firewall-cmd --reload || true

  msg "✅ Full LAMP uninstall complete."
}

# ---------------- MENU ----------------
while true; do
  echo ""
  echo "=============================="
  echo "  LAMP DEV SETUP (Fedora 42)  "
  echo "=============================="
  echo "1) Install LAMP Stack (select PHP version via Remi)"
  echo "2) Setup MySQL User & Database"
  echo "3) Apply DEV full-write on ${WEB_DIR} (POSIX+ACL+SELinux)"
  echo "4) Do 1 + 2 + 3 (one shot)"
  echo "5) Fix ONE site under ${WEB_DIR} (e.g. prestashop)"
  echo "6) Fix ALL sites under ${WEB_DIR}"
  echo "7) Create phpinfo() at ${WEB_DIR}/info.php"
  echo "8) Restart Apache & PHP-FPM"
  echo "9) Uninstall Apache Only"
  echo "10) Uninstall PHP Only"
  echo "11) Uninstall MariaDB (with optional DB backup)"
  echo "12) Uninstall Everything (Full LAMP Reset)"
  echo "0) Exit"
  echo "=============================="
  read -rp "Choose: " CHOICE

  case "$CHOICE" in
    1) install_lamp_stack ;;
    2) setup_mysql ;;
    3) dev_html_fullwrite ;;
    4) install_lamp_stack; setup_mysql; dev_html_fullwrite; make_info ;;
    5) fix_site ;;
    6) fix_all_sites ;;
    7) make_info ;;
    8) restart_services ;;
    9) uninstall_apache ;;
    10) uninstall_php ;;
    11) uninstall_mariadb ;;
    12) uninstall_lamp ;;
    0) echo "👋 Bye."; exit 0 ;;
    *) err "❌ Invalid option." ;;
  esac
done
