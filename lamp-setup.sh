#!/usr/bin/env bash
# Fedora 43 - LAMP DEV Installer (v3.5)
# Includes: Apache, PHP-FPM, MariaDB (remote enabled), VHosts, /etc/hosts mgmt, SELinux+ACL perms,
# Self-Signed SSL, Let's Encrypt SSL, Backup + Smart Restore, Live Log Tailer

set -euo pipefail

# Paths
WEB_DIR="/var/www/html"
VHOST_PREFIX="/etc/httpd/conf.d/20-"
SSL_CERT_DIR="/etc/pki/tls/certs"
SSL_KEY_DIR="/etc/pki/tls/private"
BACKUP_BASE="${HOME}/lamp_backups"

# Config files
APACHE_BASE_CONF="/etc/httpd/conf.d/10-www.conf"
APACHE_PHPFPM_HANDLER_CONF="/etc/httpd/conf.d/15-php-fpm.conf"
PHP_DEV_INI="/etc/php.d/99-dev-prestashop.ini"
PHPFPM_POOL_CONF="/etc/php-fpm.d/www.conf"
MYSQL_REMOTE_CONF="/etc/my.cnf.d/60-remote.cnf"

# Selected VHost state
SEL_DOMAIN=""
SEL_DOCROOT=""
SEL_CONF=""

# Messages
msg(){ echo -e "\033[1;32m[INFO] $*\033[0m"; }
warn(){ echo -e "\033[1;33m[WARN] $*\033[0m"; }
err(){ echo -e "\033[1;31m[ERROR] $*\033[0m"; }

# ============================================================
# SYSTEM HELPERS
# ============================================================
require_cmd(){ command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; exit 1; }; }
getenforce_safe(){ command -v getenforce >/dev/null 2>&1 && getenforce || echo "Disabled"; }
apache_configtest(){ sudo apachectl configtest; }
safe_reload_httpd(){ apache_configtest; sudo systemctl reload httpd; }

ask_user() {
  local default_user
  default_user="$(whoami)"
  read -rp "Linux username for DEV permissions [${default_user}]: " USER_NAME
  USER_NAME="${USER_NAME:-$default_user}"
  id "$USER_NAME" >/dev/null 2>&1 || { err "User '${USER_NAME}' does not exist."; exit 1; }
  msg "DEV user: ${USER_NAME}"
}

open_firewall_service() {
  local svc="$1"
  if command -v firewall-cmd >/dev/null 2>&1; then
    sudo firewall-cmd --add-service="$svc" --permanent >/dev/null 2>&1 || true
    sudo firewall-cmd --reload >/dev/null 2>&1 || true
  fi
}

open_firewall_port() {
  local port="$1"
  if command -v firewall-cmd >/dev/null 2>&1; then
    sudo firewall-cmd --add-port="$port" --permanent >/dev/null 2>&1 || true
    sudo firewall-cmd --reload >/dev/null 2>&1 || true
  fi
}

# ============================================================
# SAFE /etc/hosts MANAGEMENT
# ============================================================
manage_hosts_entry() {
  local action="$1" domain="$2"
  case "$action" in
    add)
      if grep -Eq "^[[:space:]]*127\.0\.0\.1[[:space:]].*([[:space:]]|^)${domain}([[:space:]]|\$)" /etc/hosts; then
        warn "Domain $domain already exists in /etc/hosts"
      else
        echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts >/dev/null
        msg "Added $domain to /etc/hosts"
      fi
      ;;
    remove)
      local tmp
      tmp="$(mktemp)"
      sudo awk -v d="$domain" '
        BEGIN { OFS="\t" }
        /^[[:space:]]*#/ { print; next }
        /^[[:space:]]*$/ { print; next }
        {
          ip=$1; n=0
          for (i=2; i<=NF; i++) if ($i != d) names[++n]=$i
          if (n==0) next
          printf "%s", ip
          for (j=1; j<=n; j++) printf "%s%s", OFS, names[j]
          printf "\n"
          for (k=1; k<=n; k++) delete names[k]
        }
      ' /etc/hosts | sudo tee "$tmp" >/dev/null
      sudo cp "$tmp" /etc/hosts
      sudo rm -f "$tmp"
      msg "Removed $domain from /etc/hosts"
      ;;
    *)
      err "manage_hosts_entry: unknown action '$action'"
      return 1
      ;;
  esac
}

# ============================================================
# INSTALLATION CORE
# ============================================================
install_apache_php() {
  msg "Installing Apache + PHP-FPM + OpenSSL..."
  sudo dnf upgrade --refresh -y
  sudo dnf install -y httpd mod_http2 mod_ssl openssl

  # Ensure proxy modules for PHP-FPM handler
  if ! sudo httpd -M 2>/dev/null | grep -q proxy_fcgi_module; then
    sudo bash -c 'cat >/etc/httpd/conf.modules.d/99-proxy-fcgi.conf' <<'EOF'
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so
EOF
  fi

  # PrestaShop-friendly PHP modules
  sudo dnf install -y \
    php php-fpm php-cli php-common \
    php-mysqlnd php-zip php-devel \
    php-gd php-mbstring php-curl php-xml \
    php-bcmath php-intl php-opcache

  open_firewall_service http
  open_firewall_service https

  # Apache base config
  sudo bash -c "cat >'${APACHE_BASE_CONF}'" <<'EOF'
ServerName localhost
<Directory "/var/www/html">
  AllowOverride All
  Require all granted
  DirectoryIndex index.php index.html
</Directory>
EOF

  # PHP-FPM socket config
  sudo sed -i \
    -e 's~^;*listen\s*=.*~listen = /run/php-fpm/www.sock~' \
    -e 's~^;*listen\.owner\s*=.*~listen.owner = apache~' \
    -e 's~^;*listen\.group\s*=.*~listen.group = apache~' \
    -e 's~^;*listen\.mode\s*=.*~listen.mode = 0660~' \
    "${PHPFPM_POOL_CONF}"

  # Apache handler for PHP
  sudo bash -c "cat >'${APACHE_PHPFPM_HANDLER_CONF}'" <<'EOF'
<FilesMatch \.php$>
  SetHandler "proxy:unix:/run/php-fpm/www.sock|fcgi://localhost"
</FilesMatch>
EOF

  # PHP dev ini
  sudo bash -c "cat >'${PHP_DEV_INI}'" <<'EOF'
display_errors=On
display_startup_errors=On
error_reporting=E_ALL
log_errors=On
memory_limit=512M
max_execution_time=300
max_input_time=300
max_input_vars=20000
upload_max_filesize=256M
post_max_size=256M
date.timezone=Europe/Athens
EOF

  if [[ "$(getenforce_safe)" != "Disabled" ]]; then
    sudo setsebool -P httpd_can_network_connect 1 || true
    sudo setsebool -P httpd_can_network_connect_db 1 || true
  fi

  apache_configtest
  sudo systemctl enable --now php-fpm httpd
  sudo systemctl restart php-fpm httpd

  msg "PHP version: $(php -v | head -n 1)"
}

install_mariadb_dev() {
  warn "DEV ONLY: MariaDB remote access is enabled (bind 0.0.0.0)."
  msg "Installing MariaDB..."
  sudo dnf install -y mariadb-server
  sudo systemctl enable --now mariadb

  sudo bash -c "cat >'${MYSQL_REMOTE_CONF}'" <<'EOF'
[mysqld]
bind-address = 0.0.0.0
skip-networking = 0
EOF

  sudo systemctl restart mariadb
  open_firewall_port 3306/tcp
}

# ============================================================
# PERMISSIONS (ONLY inside WEB_DIR)
# ============================================================
apply_web_permissions_tree() {
  local target="${1:-$WEB_DIR}"
  sudo dnf -y install acl policycoreutils-python-utils >/dev/null 2>&1

  if ! id -nG "$USER_NAME" | tr ' ' '\n' | grep -qx apache; then
    sudo usermod -aG apache "$USER_NAME"
    warn "User added to group apache. Logout/login recommended."
  fi

  if [[ "$target" == "$WEB_DIR" ]]; then
    sudo chown root:apache "$WEB_DIR"
    sudo chmod 2775 "$WEB_DIR"
  fi

  sudo chgrp -R apache "$target"
  sudo find "$target" -type d -exec chmod 2775 {} \;
  sudo find "$target" -type f -exec chmod 0664 {} \;
  sudo setfacl -R -m "u:${USER_NAME}:rwX,g:apache:rwX,m:rwX" "$target"
  sudo find "$target" -type d -exec setfacl -m "d:u:${USER_NAME}:rwx,d:g:apache:rwx,d:m:rwx" {} \;

  if [[ "$(getenforce_safe)" != "Disabled" ]]; then
    sudo semanage fcontext -a -t httpd_sys_rw_content_t "${WEB_DIR}(/.*)?" 2>/dev/null \
      || sudo semanage fcontext -m -t httpd_sys_rw_content_t "${WEB_DIR}(/.*)?"
    sudo restorecon -Rv "$target" >/dev/null 2>&1 || true
  fi
}

apply_dev_permissions() {
  apply_web_permissions_tree "$WEB_DIR"

  for svc in httpd php-fpm; do
    local dir="/etc/systemd/system/${svc}.service.d"
    sudo mkdir -p "$dir"
    echo -e "[Service]\nUMask=0002" | sudo tee "${dir}/override.conf" >/dev/null
  done

  sudo systemctl daemon-reload
  sudo systemctl restart php-fpm httpd

  echo '<?php phpinfo();' | sudo tee "${WEB_DIR}/info.php" >/dev/null
}

# ============================================================
# VHOSTS
# ============================================================
create_vhost() {
  read -rp "Domain (e.g. project.local): " VHOST
  read -rp "Folder in /var/www/html/: " FOLDER
  local DOCROOT="${WEB_DIR}/${FOLDER}"
  local CONF="${VHOST_PREFIX}${VHOST}.conf"

  sudo mkdir -p "$DOCROOT"

  sudo bash -c "cat >'${CONF}'" <<EOF
<VirtualHost *:80>
  ServerName ${VHOST}
  DocumentRoot ${DOCROOT}
  <Directory ${DOCROOT}>
    AllowOverride All
    Require all granted
  </Directory>
  ErrorLog  /var/log/httpd/${VHOST}_error.log
  CustomLog /var/log/httpd/${VHOST}_access.log combined
</VirtualHost>
EOF

  safe_reload_httpd
  apply_web_permissions_tree "$DOCROOT"

  read -rp "Add /etc/hosts entry for ${VHOST} -> 127.0.0.1? (y/N): " ADDH
  ADDH="${ADDH:-N}"
  [[ "$ADDH" =~ ^[Yy]$ ]] && manage_hosts_entry add "$VHOST"

  msg "VHost ready: http://${VHOST}/ -> ${DOCROOT}"
}

select_vhost() {
  shopt -s nullglob
  local files=(${VHOST_PREFIX}*.conf)
  [[ ${#files[@]} -eq 0 ]] && { err "No VHosts found."; return 1; }

  echo "Select VHost:"
  local i=1
  declare -A list
  for f in "${files[@]}"; do
    local d
    d="$(sudo awk '/^[[:space:]]*ServerName[[:space:]]+/ {print $2; exit}' "$f")"
    echo "$i) $d"
    list[$i]="$d|$f"
    i=$((i+1))
  done

  read -rp "Choice: " choice
  [[ -z "${list[$choice]:-}" ]] && return 1

  IFS='|' read -r SEL_DOMAIN SEL_CONF <<< "${list[$choice]}"
  SEL_DOCROOT="$(sudo awk '/^[[:space:]]*DocumentRoot[[:space:]]+/ {print $2; exit}' "$SEL_CONF")"
}

# ============================================================
# SSL
# ============================================================
issue_self_signed_ssl() {
  select_vhost || return 1

  sudo mkdir -p "$SSL_CERT_DIR" "$SSL_KEY_DIR"
  sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "${SSL_KEY_DIR}/${SEL_DOMAIN}.key" \
    -out "${SSL_CERT_DIR}/${SEL_DOMAIN}.crt" \
    -subj "/CN=${SEL_DOMAIN}"

  if ! sudo grep -qE "<VirtualHost[[:space:]]+\*:443>" "$SEL_CONF"; then
    sudo bash -c "cat >>'${SEL_CONF}'" <<EOF

<VirtualHost *:443>
  ServerName ${SEL_DOMAIN}
  DocumentRoot ${SEL_DOCROOT}
  SSLEngine on
  SSLCertificateFile ${SSL_CERT_DIR}/${SEL_DOMAIN}.crt
  SSLCertificateKeyFile ${SSL_KEY_DIR}/${SEL_DOMAIN}.key
  Protocols h2 http/1.1
  <Directory ${SEL_DOCROOT}>
    AllowOverride All
    Require all granted
  </Directory>
</VirtualHost>
EOF
  fi

  safe_reload_httpd
  msg "Self-signed SSL ready: https://${SEL_DOMAIN}/"
}

issue_lets_encrypt_ssl() {
  warn "Let's Encrypt HTTP-01 requires public DNS and port 80 reachable from the internet."
  open_firewall_service http
  open_firewall_service https

  sudo dnf install -y certbot python3-certbot-apache mod_ssl

  select_vhost || return 1

  read -rp "Email for Let's Encrypt: " EM
  [[ -n "$EM" ]] || { err "Email is required."; return 1; }

  sudo certbot --apache -d "$SEL_DOMAIN" -m "$EM" \
    --agree-tos --non-interactive --redirect

  msg "Let's Encrypt SSL ready: https://${SEL_DOMAIN}/"
}

# ============================================================
# BACKUP + LIVE LOGS + SMART RESTORE
# ============================================================
backup_project() {
  select_vhost || return 1

  local TS BDIR
  TS="$(date +%Y%m%d_%H%M%S)"
  BDIR="${BACKUP_BASE}/${SEL_DOMAIN}_${TS}"
  mkdir -p "$BDIR"

  # Store basic metadata
  cat > "${BDIR}/meta.txt" <<EOF
domain=${SEL_DOMAIN}
docroot=${SEL_DOCROOT}
timestamp=${TS}
EOF

  read -rp "Database name (leave empty to skip DB export): " DB_NAME
  if [[ -n "$DB_NAME" ]]; then
    read -rp "DB User (default root): " DBU
    DBU="${DBU:-root}"
    read -srp "DB Password (leave empty for socket auth): " DBP
    echo

    msg "Exporting database..."
    if [[ -n "$DBP" ]]; then
      sudo mysqldump -u"$DBU" -p"$DBP" --databases "$DB_NAME" > "${BDIR}/db.sql"
    else
      sudo mysqldump -u"$DBU" --databases "$DB_NAME" > "${BDIR}/db.sql"
    fi
  else
    warn "DB export skipped."
  fi

  sudo dnf install -y zip >/dev/null 2>&1 || true

  msg "Archiving files (docroot contents)..."
  # Zip only the CONTENTS of docroot so restore can target any VHost safely
  sudo bash -c "cd '$SEL_DOCROOT' && zip -r '$BDIR/files.zip' . >/dev/null"

  sudo chown -R "$USER_NAME:$USER_NAME" "$BDIR" || true
  msg "Backup ready at: $BDIR"
}

# ---------------- Live Log Tailer ----------------
view_logs() {
  select_vhost || return 1
  local LOG_FILE="/var/log/httpd/${SEL_DOMAIN}_error.log"

  if [[ ! -f "$LOG_FILE" ]]; then
    err "Log file not found: $LOG_FILE"
    return 1
  fi

  msg "Tailing logs for domain: ${SEL_DOMAIN}"
  warn "Press Ctrl+C to stop."
  sudo tail -n 20 -f "$LOG_FILE"
}

# ---------------- Smart Restore ----------------
restore_project() {
  if [[ ! -d "$BACKUP_BASE" ]]; then
    err "Backups directory not found: $BACKUP_BASE"
    return 1
  fi

  msg "Available backups in: $BACKUP_BASE"
  local i=1
  declare -A blist
  shopt -s nullglob
  for d in "$BACKUP_BASE"/*/; do
    echo "$i) $(basename "$d")"
    blist[$i]="$d"
    i=$((i+1))
  done
  shopt -u nullglob

  if [[ $i -eq 1 ]]; then
    warn "No backups found."
    return 1
  fi

  read -rp "Select backup number to restore: " bchoice
  local SELECTED_B="${blist[$bchoice]:-}"
  [[ -z "$SELECTED_B" ]] && { err "Invalid selection."; return 1; }

  msg "Select destination VHost for restore:"
  select_vhost || return 1

  warn "WARNING: Contents of ${SEL_DOCROOT} will be replaced."
  read -rp "Continue? (y/N): " CONF
  CONF="${CONF:-N}"
  [[ "$CONF" =~ ^[Yy]$ ]] || { msg "Restore cancelled."; return 0; }

  sudo dnf install -y unzip >/dev/null 2>&1 || true

  # Restore files
  if [[ -f "${SELECTED_B}files.zip" ]]; then
    msg "Restoring files into: ${SEL_DOCROOT}"

    # Wipe docroot contents safely (including hidden files) without touching the directory itself
    sudo find "$SEL_DOCROOT" -mindepth 1 -maxdepth 1 -exec rm -rf {} + >/dev/null 2>&1 || true

    sudo unzip -o "${SELECTED_B}files.zip" -d "$SEL_DOCROOT" >/dev/null
    msg "Files restored."
  else
    err "files.zip not found in backup."
  fi

  # Restore DB
  if [[ -f "${SELECTED_B}db.sql" ]]; then
    read -rp "SQL dump found. Database name to import into: " RDB
    if [[ -n "$RDB" ]]; then
      read -rp "DB User (default root): " R_USER
      R_USER="${R_USER:-root}"
      read -srp "DB Password (leave empty for socket auth): " R_PASS
      echo

      msg "Ensuring database exists: $RDB"
      if [[ -n "$R_PASS" ]]; then
        sudo mysql -u"$R_USER" -p"$R_PASS" -e "CREATE DATABASE IF NOT EXISTS \`$RDB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        msg "Importing SQL into: $RDB"
        sudo mysql -u"$R_USER" -p"$R_PASS" "$RDB" < "${SELECTED_B}db.sql"
      else
        sudo mysql -u"$R_USER" -e "CREATE DATABASE IF NOT EXISTS \`$RDB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        msg "Importing SQL into: $RDB"
        sudo mysql -u"$R_USER" "$RDB" < "${SELECTED_B}db.sql"
      fi

      msg "Database restored."
    fi
  else
    warn "No db.sql found in backup. DB restore skipped."
  fi

  # Fix permissions after restore
  apply_web_permissions_tree "$SEL_DOCROOT"
  msg "Restore completed for VHost: ${SEL_DOMAIN}"
}

# ============================================================
# MENU
# ============================================================
main_menu() {
  while true; do
    echo -e "\n--- Fedora 43 LAMP DEV---"
    echo "1) Full Install (Apache, PHP, MariaDB, Perms)"
    echo "2) Create New VHost"
    echo "3) Issue Self-Signed SSL"
    echo "4) Issue Let's Encrypt SSL"
    echo "5) Backup Project (Files + optional DB)"
    echo "6) View Live Error Logs (tail -f)"
    echo "7) Smart Restore (Files + optional DB)"
    echo "8) Re-apply permissions on /var/www/html"
    echo "9) Restart services"
    echo "0) Exit"
    read -rp "Choice: " C
    case "$C" in
      1) install_apache_php; install_mariadb_dev; apply_dev_permissions ;;
      2) create_vhost ;;
      3) issue_self_signed_ssl ;;
      4) issue_lets_encrypt_ssl ;;
      5) backup_project ;;
      6) view_logs ;;
      7) restore_project ;;
      8) apply_dev_permissions ;;
      9) sudo systemctl restart mariadb 2>/dev/null || true; sudo systemctl restart php-fpm 2>/dev/null || true; sudo systemctl restart httpd 2>/dev/null || true; msg "Services restarted." ;;
      0) exit 0 ;;
      *) err "Invalid choice." ;;
    esac
  done
}

# Entry
require_cmd dnf
require_cmd sudo
ask_user
main_menu
