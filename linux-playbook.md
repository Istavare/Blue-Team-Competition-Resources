# Basic Linux Playbook
### Preface

Whenever you find something malicious, stop it, but preferably document what it is. These are useful for incident response, which makes up a decent chunk of the score. Also, if parts of this guide don't work, there may be some malicious service or method stopping it. These are not all-encompassing but are still a good starting point. If commands are not working, I recommend looking up aliases.

Also use Google and AI to help figure everything out, they are super useful tools!

### Get scripts

On a Debian-based Linux distribution (Debian/Ubuntu), install with `sudo apt install git`

Get the scripts: `git clone https://github.com/Istavare/Blue-Team-Competition-Resources.git -b Linux`
Go into the directory: `cd Blue-Team-Competition-Resources/linux`
Make files in the directory executable: `sudo chmod +x *.sh`

### Change Passwords

- Edit the password file `change_passwords.sh` after getting accounts
- Run `sudo ./change_passwords.sh`

### Update System

- Run `sudo apt update && sudo apt upgrade`; this should take a while.

### Setup Firewall

- Check which ports are in use with `sudo ss -tulpn`.
- Make a note of which ports you want to remain open.
- Install UFW with the command `sudo apt install ufw`.
- Run the script using `sudo ./setup_firewall.sh`; this will ask for ports you want open.

### Threat Hunting

- Run the LD_PRELOAD script: `sudo ./check_ld_preload.sh`.
- Check for executables in unusual locations with `sudo ./suspicious_executables.sh`.
- Check crontab with `sudo cat /var/spool/cron/*`.
- The crontab of individual users can be checked with `crontab -l`.
- Systemd services are in `/etc/systemd/system/`.
- Check everything manually installed with `apt-mark showmanual`; look for anything suspicious.

### Injects

- Get an inventory of the system useful for injects with `sudo ./get_inventory.sh`.

### Everything else

Do more threat hunting and fix services as they go down / issues arise! This playbook can only cover so much so learn as you go, and ask others in your team for help.
