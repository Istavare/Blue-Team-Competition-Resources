#!/bin/bash

set -e

cp /etc/shadow /etc/shadow.bck

prompt_password() {
    local pass1 pass2
    while true; do
        read -r -s -p "Enter password: " pass1
        echo
        read -r -s -p "Confirm password: " pass2
        echo

        if [[ -z "$pass1" ]]; then
            echo "Password cannot be empty. Try again."
        elif [[ "$pass1" != "$pass2" ]]; then
            echo "Passwords do not match. Try again."
        else
            ADMIN_PASSWORD="$pass1"
            break
        fi
    done
}

prompt_password

# Users whose passwords WILL be changed
declare -A USERS=(
    [root]="$ADMIN_PASSWORD"
    [sysadmin]="$ADMIN_PASSWORD"
    [MissionDirector]="$ADMIN_PASSWORD"
    [CapeCom]="$ADMIN_PASSWORD"
    [FlightDirector]="$ADMIN_PASSWORD"
    [ArtemisLead]="$ADMIN_PASSWORD"
    [GuidanceOfficer]="$ADMIN_PASSWORD"
    [RetroOfficer]="$ADMIN_PASSWORD"
    [FIDOControl]="$ADMIN_PASSWORD"
    [EECOMCtrl]="$ADMIN_PASSWORD"
)

# Users that should NEVER be modified or disabled
declare -A PROTECTED_USERS=(
    [whiteteam]=1
    [blackteam]=1
)

# -------------------------------
# Change passwords
# -------------------------------

for USER in "${!USERS[@]}"; do
    if id "$USER" >/dev/null 2>&1; then
        echo "Changing password for user: $USER"
        if printf '%s\n%s\n' "${USERS[$USER]}" "${USERS[$USER]}" | passwd "$USER" >/dev/null 2>&1; then
            echo "Password successfully changed for $USER."
        else
            echo "Failed to change password for $USER."
        fi
    else
        echo "User $USER does not exist. Skipping."
    fi
done

# -------------------------------
# Disable login for other users
# -------------------------------

while IFS=: read -r username _ uid _; do
    if [[ "$uid" -ge 1000 ]] \
        && [[ -z "${USERS[$username]}" ]] \
        && [[ -z "${PROTECTED_USERS[$username]}" ]]; then

        echo "Disabling login for user: $username"
        if usermod -s /usr/sbin/nologin "$username" >/dev/null 2>&1; then
            echo "Login disabled for $username."
        else
            echo "Failed to disable login for $username."
        fi
    fi
done < /etc/passwd

echo "Process completed."
