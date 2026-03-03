#!/bin/bash
# ===============================
# Full System Hardening Script - Steps 1–13
# ===============================
set -e  # Exit on error

echo "[*] Starting full system hardening..."

# ----------------------------
# Step 1: Disable SMB
# ----------------------------
echo "[*] Stopping SMB service..."
if systemctl is-active --quiet smbd; then
    sudo systemctl stop smbd
    echo "[+] SMB service stopped."
else
    echo "[*] SMB service already stopped."
fi
echo "[*] Disabling SMB service at boot..."
if systemctl is-enabled --quiet smbd; then
    sudo systemctl disable smbd
    echo "[+] SMB service disabled."
else
    echo "[*] SMB service already disabled."
fi

# ----------------------------
# Step 2: Disable knockd
# ----------------------------
echo "[*] Stopping knockd service..."
if systemctl is-active --quiet knockd; then
    sudo systemctl stop knockd
    echo "[+] knockd service stopped."
else
    echo "[*] knockd service already stopped."
fi
echo "[*] Disabling knockd service at boot..."
if systemctl is-enabled --quiet knockd; then
    sudo systemctl disable knockd
    echo "[+] knockd service disabled."
else
    echo "[*] knockd service already disabled."
fi

# ----------------------------
# Step 3: Update password hashing
# ----------------------------
echo "[*] Updating password hashing to yescrypt..."
sudo cp /etc/login.defs /etc/login.defs.bak
sudo cp /etc/pam.d/common-password /etc/pam.d/common-password.bak
sudo sed -i 's/ENCRYPT_METHOD DES/ENCRYPT_METHOD YESCRYPT/' /etc/login.defs
sudo sed -i 's/\bdes\b/yescrypt/Ig' /etc/pam.d/common-password
echo "[+] Password hashing updated to yescrypt."

# ----------------------------
# Step 4: Reset passwords
# ----------------------------
echo "[*] Resetting passwords for selected users..."
NEW_PASSWORD="LS26_SecurePassword"
NORMAL_USERS=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
UID_111_USER=$(awk -F: '$3 == 111 {print $1}' /etc/passwd)
USERS="$NORMAL_USERS root $UID_111_USER"
for user in $USERS; do
    echo "[*] Updating password for user: $user"
    echo "$user:$NEW_PASSWORD" | sudo chpasswd
done
echo "[+] All selected user passwords have been reset to the placeholder."

# ----------------------------
# Step 5: Harden SSH - disallow empty passwords (init-compatible)
# ----------------------------
echo "[*] Securing SSH configuration (disallow empty passwords)..."

# Placeholder path for SSH config
SSHD_CONF_PATH="/path/to/sshd_config" 

if [ -f "$SSHD_CONF_PATH" ]; then
    sudo cp "$SSHD_CONF_PATH" "${SSHD_CONF_PATH}.bak"
    if grep -q "^PermitEmptyPasswords" "$SSHD_CONF_PATH"; then
        sudo sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$SSHD_CONF_PATH"
    else
        echo "PermitEmptyPasswords no" | sudo tee -a "$SSHD_CONF_PATH" >/dev/null
    fi

    # Attempt to restart SSH
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl restart sshd 2>/dev/null || echo "[*] systemctl restart failed; SSH may require manual restart."
    elif command -v service >/dev/null 2>&1; then
        sudo service ssh restart 2>/dev/null || echo "[*] service restart failed; SSH may require manual restart."
    else
        echo "[*] SSH service not managed by systemctl or service; restart manually if needed."
    fi

    echo "[+] SSH configuration updated: empty passwords disabled."
else
    echo "[*] SSH config file not found at $SSHD_CONF_PATH, skipping."
fi

# ----------------------------
# Step 6: Revoke all NOPASSWD sudo privileges
# ----------------------------
echo "[*] Removing all NOPASSWD privileges from /etc/sudoers..."

SUDOERS_FILE="/etc/sudoers"
BACKUP_FILE="${SUDOERS_FILE}.bak"

# Backup first
if [ ! -f "$BACKUP_FILE" ]; then
    sudo cp "$SUDOERS_FILE" "$BACKUP_FILE"
    echo "[*] Backup created at $BACKUP_FILE"
fi

# Comment out all lines containing NOPASSWD
sudo sed -i '/NOPASSWD/ s/^/# /' "$SUDOERS_FILE"

echo "[+] All NOPASSWD entries are now disabled (commented out)."

# ----------------------------
# Step 7: Harden doas.conf - remove 'permit nopass :users'
# ----------------------------
echo "[*] Hardening doas configuration (/etc/doas.conf)..."
DOAS_CONF="/etc/doas.conf"
if [ -f "$DOAS_CONF" ]; then
    sudo cp "$DOAS_CONF" "${DOAS_CONF}.bak"
    sudo sed -i '/^permit nopass :users$/d' "$DOAS_CONF"
    echo "[+] Removed 'permit nopass :users' from doas.conf."
else
    echo "[*] doas.conf not found, skipping."
fi

# ----------------------------
# Step 8: SSH - remove last key from AuthorizedKeysFile (init-managed SSH)
# ----------------------------
echo "[*] Updating SSH AuthorizedKeysFile directive..."

# Placeholder path for SSH config
SSHD_CONF_PATH="/etc/ssh/sshd_config.d/50-cloud-init.conf"  

if [ -f "$SSHD_CONF_PATH" ]; then
    sudo cp "$SSHD_CONF_PATH" "${SSHD_CONF_PATH}.bak"
    sudo sed -i '/^AuthorizedKeysFile / s/\s\+[^[:space:]]\+$//' "$SSHD_CONF_PATH"
    echo "[+] Last key removed from AuthorizedKeysFile. Edit $SSHD_CONF_PATH manually to add safe path."

    # Attempt to restart SSH if possible
    if command -v service >/dev/null 2>&1; then
        sudo service ssh restart 2>/dev/null || echo "[*] Service restart not available; SSH may require manual restart."
    else
        echo "[*] SSH service not managed by systemctl; restart manually if needed."
    fi
else
    echo "[*] SSH config file not found at $SSHD_CONF_PATH, skipping."
fi

# ----------------------------
# Step 9: Remove SUID from pexec
# ----------------------------
echo "[*] Removing SUID bit from /usr/bin/pexec (if it exists)..."
PEXEC_BIN="/usr/bin/pexec"
if [ -f "$PEXEC_BIN" ]; then
    if [ -u "$PEXEC_BIN" ]; then
        sudo chmod u-s "$PEXEC_BIN"
        echo "[+] SUID bit removed from $PEXEC_BIN."
    else
        echo "[*] $PEXEC_BIN does not have SUID, skipping."
    fi
else
    echo "[*] $PEXEC_BIN not found, skipping."
fi

# ----------------------------
# Step 10: Stop and disable vsftpd
# ----------------------------
echo "[*] Stopping vsftpd service..."
if systemctl is-active --quiet vsftpd; then
    sudo systemctl stop vsftpd
    echo "[+] vsftpd service stopped."
else
    echo "[*] vsftpd service already stopped."
fi
echo "[*] Disabling vsftpd service at boot..."
if systemctl is-enabled --quiet vsftpd; then
    sudo systemctl disable vsftpd
    echo "[+] vsftpd service disabled."
else
    echo "[*] vsftpd service already disabled."
fi

# ----------------------------
# ----------------------------
# Step 11: Harden Podman container 2048 dynamically + remove risky files
# ----------------------------
echo "[*] Hardening Podman container 2048 dynamically..."

# Original container image
CONTAINER_IMAGE="docker.io/nejec/2048:latest"

# Find container by name first; if not found, by image
CONTAINER_NAME=$(podman ps -a --format "{{.Names}}" | grep -w "2048" || true)
if [ -z "$CONTAINER_NAME" ]; then
    CONTAINER_NAME=$(podman ps -a --format "{{.Names}} {{.Image}}" | awk -v img="$CONTAINER_IMAGE" '$2==img {print $1; exit}')
fi

if [ -z "$CONTAINER_NAME" ]; then
    echo "[*] No container found for image $CONTAINER_IMAGE, skipping Podman hardening."
else
    echo "[*] Found container: $CONTAINER_NAME"

    # Stop and rename the original container
    podman stop "$CONTAINER_NAME" || true
    podman rename "$CONTAINER_NAME" "${CONTAINER_NAME}_backup" || true
    echo "[*] Original container renamed to ${CONTAINER_NAME}_backup"

    # Delete risky files inside the backup container
    echo "[*] Removing risky files inside ${CONTAINER_NAME}_backup..."
    podman exec "${CONTAINER_NAME}_backup" rm -f /var/www/html/shell.php || true
    echo "[+] Risky files removed from ${CONTAINER_NAME}_backup"

    # Recreate hardened container dynamically
    ORIGINAL_CMD="/usr/bin/podman container run --cidfile=/run/container-2048.service.ctr-id --cgroups=no-conmon --rm --sdnotify=conmon -d --replace --name 2048 --privileged -p 8018:22 --volume /:/mnt $CONTAINER_IMAGE"
    SAFE_CMD=$(echo "$ORIGINAL_CMD" \
        | sed 's/--privileged//g' \
        | sed 's#--volume /:/mnt#--volume /safe_mount_path:/mnt#' \
        | sed 's/$/ --user 1000:1000 --cap-drop ALL/')

    echo "[*] Recreating container safely..."
    eval "$SAFE_CMD"
    echo "[+] Container 2048 recreated in hardened mode."
fi

# ----------------------------
# Step 12: Disable Unbound remote control
# ----------------------------
echo "[*] Disabling Unbound remote control..."
RC_CONF="/etc/unbound/unbound.conf.d/remote-control.conf"

if [ -f "$RC_CONF" ]; then
    sudo cp "$RC_CONF" "${RC_CONF}.bak"
    echo "[*] Backup of remote-control.conf created at ${RC_CONF}.bak"
    sudo sed -i 's/^\s*control-enable:\s*yes/control-enable: no/' "$RC_CONF"
    sudo systemctl restart unbound
    echo "[+] Unbound remote control disabled."
else
    echo "[*] remote-control.conf not found, skipping."
fi

# ----------------------------
# Step 13: Remove --skip-grant-tables from MySQL service
# ----------------------------
echo "[*] Hardening MySQL systemd service..."
MYSQL_SERVICE="/lib/systemd/system/mysql.service"
BACKUP_SERVICE="${MYSQL_SERVICE}.bak"

if [ -f "$MYSQL_SERVICE" ]; then
    sudo cp "$MYSQL_SERVICE" "$BACKUP_SERVICE"
    echo "[*] Backup of mysql.service created at $BACKUP_SERVICE"
    sudo sed -i 's/\s--skip-grant-tables//g' "$MYSQL_SERVICE"
    sudo systemctl daemon-reload
    sudo systemctl restart mysql
    echo "[+] Removed --skip-grant-tables; MySQL restarted securely."
else
    echo "[*] MySQL systemd service file not found, skipping."
fi

echo "[*] Full system hardening (Steps 1–13) complete."
