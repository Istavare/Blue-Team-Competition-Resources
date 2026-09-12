# Basic Linux Playbook
### Preface

Whenever you find something malicous, stop it, but preferably document what it is. These are useful for incident response which makes up a decent chunk of score. Also if parts of this guide don't work, there may be some malicious service or method stopping it. These are not all encompassing but still a good starting point. If commands are not working, I recommend looking up aliases.

Also use Google and AI to help figure everything out, they are super useful tools!

### Get scripts

On Debian based Linux distribution (debian/ubuntu) install with `sudo apt install git`

get the scripts `git clone https://github.com/Istavare/Blue-Team-Competition-Resources.git -b Linux`
go into the directory `cd Blue-Team-Competition-Resources/linux` 
make files in the directory executable `sudo chmod +x *.sh`

### Change Passwords

- Edit the password file `change_passwords.sh` after getting accounts
- Run `sudo ./change_passwords.sh`

### Update System

- run `sudo apt update && sudo apt upgrade` this should take a while 

### Setup Firewall

- check which ports are in use with 'sudo ss -tulpn'
- make a note somewhere of what ports you want to remain open
- install UFW with the command `sudo apt install ufw` 
- run the scipt using `sudo ./setup_firewall.sh` this will ask for ports you want open

### Threat Hunting

- run ld_preload script `sudo ./check_ld_preload.sh`
- check for executables in weird locations with `sudo ./suspicious_executables.sh`
- check crontab with `sudo cat /var/spool/cron/*` 
- crontab of individual users can be checked with `crontab -l`
- systemd services are in `/etc/systemd/system/` 
- check everything manually installed with `apt-mark showmanual` look for anything suspicious 

### Injects

- get inventory of the system useful for injects with `sudo ./get_inventory.sh`