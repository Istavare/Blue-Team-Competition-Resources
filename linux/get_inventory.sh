#!/bin/bash

# Setup Directory
OUT_DIR="./inventory"
mkdir -p "$OUT_DIR"

# Run NMAP localhost
sudo nmap localhost >> "$OUT_DIR/nmap.txt"

# General System Info
echo "[*] Gathering System Info..."
uname -a > "$OUT_DIR/system_info.txt"
cat /etc/os-release >> "$OUT_DIR/system_info.txt"
hostnamectl >> "$OUT_DIR/system_info.txt"

#Processes and Services
echo "[*] Enumerating Processes & Services..."
ps auxf > "$OUT_DIR/processes.txt"
systemctl list-units --type=service --state=running > "$OUT_DIR/running_services.txt"
systemctl list-unit-files --type=service | grep enabled > "$OUT_DIR/enabled_services.txt"

#Network Connections
echo "[*] Enumerating Network Connections..."
ss -tulpn > "$OUT_DIR/listening_ports.txt"
ip addr > "$OUT_DIR/network_interfaces.txt"
cat /etc/resolv.conf > "$OUT_DIR/dns_settings.txt"

#Users and Groups
echo "[*] Enumerating Users & Groups..."
cat /etc/passwd > "$OUT_DIR/local_users.txt"
cat /etc/group > "$OUT_DIR/local_groups.txt"
grep '^sudo:\|^wheel:\|^adm:' /etc/group > "$OUT_DIR/admins.txt"

# Last logins
last -a -n 50 > "$OUT_DIR/last_logins_success.txt"
lastb -a -n 50 2>/dev/null > "$OUT_DIR/last_logins_failed.txt"
who -u > "$OUT_DIR/currently_logged_in.txt"

# Excessive Sudo perms
sudo cat /etc/sudoers > "$OUT_DIR/sudoers.txt"

# Sus sudoers
echo "[*] Checking for dangerous sudoers rules..."

grep -RIn --color=never -E \
'^\s*(ALL|%ALL|\*)\s+ALL=\(ALL(:ALL)?\)\s+(NOPASSWD:)?ALL' \
/etc/sudoers /etc/sudoers.d 2>/dev/null \
> "$OUT_DIR/sudoers_suspicious.txt"

#Enumerating Packages (narrow down for sus packages)
echo "[*] Enumerating Installed Packages..."
if command -v dpkg &> /dev/null; then
    dpkg -l > "$OUT_DIR/installed_software.txt"
elif command -v rpm &> /dev/null; then
    rpm -qa > "$OUT_DIR/installed_software.txt"
fi

# Crontab
echo "[*] Enumerating Cron Jobs & Startup..."

USER_CRON_OUT="$OUT_DIR/user_cron.txt"
SYSTEM_CRON_OUT="$OUT_DIR/system_cron.txt"
INIT_OUT="$OUT_DIR/init_scripts.txt"

> "$USER_CRON_OUT"

# Loop through all users with a valid shell
awk -F: '$7 !~ /(false|nologin)$/ {print $1}' /etc/passwd | while read -r user; do
    cron_output=$(crontab -l -u "$user" 2>/dev/null | sed '/^\s*#/d;/^\s*$/d')

    if [ -n "$cron_output" ]; then
        while read -r line; do
            echo "$user: $line" >> "$USER_CRON_OUT"
        done <<< "$cron_output"
    else
        echo "$user: no cronjob" >> "$USER_CRON_OUT"
    fi
done

# System-wide cron locations
ls -la /etc/cron.* > "$SYSTEM_CRON_OUT"
ls -la /etc/init.d/ > "$INIT_OUT"


# Check Bashrc
echo "[*] Enumerating BashRC files..."

BASHRC_OUT="$OUT_DIR/bashrc.txt"
> "$BASHRC_OUT"

# System-wide bashrc
if [ -f /etc/bash.bashrc ]; then
    echo "===== system: /etc/bash.bashrc =====" >> "$BASHRC_OUT"
    tail -n 5 /etc/bash.bashrc >> "$BASHRC_OUT"
    echo >> "$BASHRC_OUT"
else
    echo "===== system: /etc/bash.bashrc =====" >> "$BASHRC_OUT"
    echo "not present" >> "$BASHRC_OUT"
    echo >> "$BASHRC_OUT"
fi

# Enumerate user bashrc files
awk -F: '$7 !~ /(false|nologin)$/ {print $1 ":" $6}' /etc/passwd | while IFS=: read -r user home; do
    bashrc="$home/.bashrc"

    echo "===== $user =====" >> "$BASHRC_OUT"

    if [ -f "$bashrc" ]; then
        tail -n 5 "$bashrc" >> "$BASHRC_OUT"
    else
        echo "no .bashrc" >> "$BASHRC_OUT"
    fi

    echo >> "$BASHRC_OUT"
done


# Check LD-Preload
echo "[*] Enumerating LD-Preload"
source ./Check_LD_Preload.sh
cp /tmp/ld_preload_log.txt "$OUT_DIR/ld_preload_log.txt"

# Executable in Sus location
echo "[*] Enumerate Sus Executables"
sudo ./SusExecutable.sh > "$OUT_DIR/Sus_Executables.txt"

# SSHKEYS
echo "[*] Enumerating SSH authorized keys..."

SSH_OUT="$OUT_DIR/ssh_keys.txt"
> "$SSH_OUT"

# Enumerate users with valid shells
awk -F: '$7 !~ /(false|nologin)$/ {print $1 ":" $6}' /etc/passwd | while IFS=: read -r user home; do
    auth_keys="$home/.ssh/authorized_keys"

    if [ -f "$auth_keys" ]; then
        keys=$(sed '/^\s*#/d;/^\s*$/d' "$auth_keys")

        if [ -n "$keys" ]; then
            while read -r key; do
                echo "$user: $key" >> "$SSH_OUT"
            done <<< "$keys"
        else
            echo "$user: no ssh keys" >> "$SSH_OUT"
        fi
    else
        echo "$user: no ssh keys" >> "$SSH_OUT"
    fi
done

echo "[*] Enumerating SUID and SGID binaries..."

SUID_OUT="$OUT_DIR/SUID.txt"
SGID_OUT="$OUT_DIR/GUID.txt"

> "$SUID_OUT"
> "$SGID_OUT"

# Enumerate SUID files (4000)
find / -xdev -type f -perm -4000 2>/dev/null \
    -exec ls -l {} \; > "$SUID_OUT"

# Enumerate SGID files (2000)
find / -xdev -type f -perm -2000 2>/dev/null \
    -exec ls -l {} \; > "$SGID_OUT"


echo "[+] Enumeration Complete. Files saved to $OUT_DIR"

echo "[*] Generating IR Summary..."

SUMMARY_OUT="$OUT_DIR/Summary.txt"
> "$SUMMARY_OUT"

########################################
# 1. Suspicious Listening Ports (0.0.0.0)
########################################

# Common allowed ports (expand as needed)
ALLOWED_PORTS_REGEX=':(21|22|25|53|80|110|143|443|3306)\b'

SUSPICIOUS_PORT_COUNT=$(grep -E '0\.0\.0\.0:' "$OUT_DIR/listening_ports.txt" \
    | grep -Ev "$ALLOWED_PORTS_REGEX" \
    | wc -l)

echo "Suspicious Listening Port Count: $SUSPICIOUS_PORT_COUNT" | tee -a "$SUMMARY_OUT"

########################################
# 2. Suspicious sudoers entries
########################################

if [ -f "$OUT_DIR/sudoers_suspicious.txt" ]; then
    SUDOERS_COUNT=$(grep -c . "$OUT_DIR/sudoers_suspicious.txt")
else
    SUDOERS_COUNT=0
fi

echo "Suspicious Sudoers Count: $SUDOERS_COUNT" | tee -a "$SUMMARY_OUT"

########################################
# 3. Suspicious Installed Software
########################################

BAD_SOFTWARE=(
    nc
    netcat
    ncat
    socat
    hydra
    john
    metasploit
    msfconsole
    mimikatz
    nikto
    aircrack-ng
)

FOUND_BAD_SOFTWARE=()

for pkg in "${BAD_SOFTWARE[@]}"; do
    if grep -qi "$pkg" "$OUT_DIR/installed_software.txt"; then
        FOUND_BAD_SOFTWARE+=("$pkg")
    fi
done

if [ "${#FOUND_BAD_SOFTWARE[@]}" -gt 0 ]; then
    echo "Suspicious Software: ${FOUND_BAD_SOFTWARE[*]}" | tee -a "$SUMMARY_OUT"
else
    echo "Suspicious Software: none" | tee -a "$SUMMARY_OUT"
fi

########################################
# 4. Suspicious User Cron Jobs
########################################

CRON_COUNT=$(grep -vc 'no cronjob' "$OUT_DIR/user_cron.txt")

echo "Suspicious User Cron Count: $CRON_COUNT" | tee -a "$SUMMARY_OUT"

########################################
# 5. Suspicious BashRC Usage
########################################

SUSPICIOUS_BASHRC_USERS=$(grep -Ei 'curl|wget|bash|base64|python' "$OUT_DIR/bashrc.txt" \
    | grep -E '^===== ' -B 1 \
    | grep '^===== ' \
    | sort -u \
    | wc -l)

echo "Suspicious Bashrc Count: $SUSPICIOUS_BASHRC_USERS" | tee -a "$SUMMARY_OUT"

########################################
# 6. LD_PRELOAD Status
########################################

if grep -q "LD_PRELOAD not set." "$OUT_DIR/ld_preload_log.txt"; then
    echo "LD_Preload: not set" | tee -a "$SUMMARY_OUT"
else
    LD_PRELOAD_VALUE=$(cat "$OUT_DIR/ld_preload_log.txt")
    echo "LD_Preload: $LD_PRELOAD_VALUE" | tee -a "$SUMMARY_OUT"
fi

########################################
# 7. SSH Keys Count
########################################

SSH_KEY_COUNT=$(grep -v 'no ssh keys' "$OUT_DIR/ssh_keys.txt" | wc -l)

echo "SSH_Keys Count: $SSH_KEY_COUNT" | tee -a "$SUMMARY_OUT"

echo "[+] IR Summary written to $SUMMARY_OUT"