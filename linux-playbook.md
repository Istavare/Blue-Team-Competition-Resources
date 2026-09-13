# Basic Linux Playbook
### Preface

This playbook is mostly made by me, Istavare / Daniel. AI has gone over it but it is mostly based off of my personal CCDC playbook notes I took last year.

Whenever you find something malicious, stop it, but preferably document what it is. These are useful for incident response, which makes up a decent chunk of the score. Also, if parts of this guide don't work, there may be some malicious service or method stopping it. These are not all-encompassing but are still a good starting point. If commands are not working, I recommend looking up aliases.

Also use Google and AI to help figure everything out, they are super useful tools!

### Before Making Changes

- Create a shared inventory for each Linux machine: hostname, IP address, operating system, scored or required services, ports, and the teammate responsible for it. This is built into the spreadsheet template for Red v. Blue
- Confirm which accounts are authorized and which services must remain available before changing passwords, disabling accounts, patching, or changing firewall rules. There will be time to do this early in the competition, it is urgent but don't break your own services!
- Keep documentation. Record what changed, why it changed, and how you verified and if the scored service still works.
- Store credentials only in the team-approved secure location; do not put passwords in the playbook or a public repository. I recommend storing the passwords in a shared team spreadsheet (but make sure you don't accidentally leak credentials, I did this last year!)

### Get scripts

On a Debian-based Linux distribution (Debian/Ubuntu), install with `sudo apt install git`

Get the scripts: `git clone https://github.com/Istavare/Blue-Team-Competition-Resources.git`
Go into the directory: `cd Blue-Team-Competition-Resources/linux`
Make files in the directory executable: `sudo chmod +x *.sh`

### Change Passwords

- Edit the password file `change_passwords_rvb.sh` after confirming the authorized accounts.
- Run `sudo ./change_passwords_rvb.sh`
- Record which authorized accounts have had their passwords changed.
- If required, change the service passwords in the ScoringEngine.

### Update System

- Run `sudo apt update && sudo apt upgrade`; this should take a while.

### Setup Firewall

- Check which ports are in use with `sudo ss -tulpn`.
- Compare listening ports with the service inventory and make a note of which ports must remain open.
- Install UFW with the command `sudo apt install ufw`.
- Run the script using `sudo ./setup_firewall.sh`; this will ask for ports you want open.
- After applying rules, test every required service from the appropriate machine before moving on.
- If running into network issues afterwards, you can disable the firewall temporarially with `sudo ufw disable` to see if it's causing issues with other scripts. This firewall script is pretty extreme. 
- Make sure to re-enable it later with `sudo ufw enable`

### Threat Hunting

- Run the LD_PRELOAD script: `sudo ./check_ld_preload.sh`.
- Check for executables in unusual locations with `sudo ./suspicious_executables.sh`.
- Check crontab with `sudo cat /var/spool/cron/*`.
- The crontab of individual users can be checked with `crontab -l`.
- Systemd services are in `/etc/systemd/system/`.
- Check everything manually installed with `apt-mark showmanual`; look for anything suspicious.

### Injects

- Get an inventory of the system useful for injects with `sudo ./get_inventory.sh`.
- Keep incident-response notes and screenshots in the shared team location. Include affected host, service, time, evidence, actions taken, and the result.

### Misc othing things for threat hunting

`/etc/passwd`
`/etc/sudoers.d/`
`/etc/group/`
`~/.ssh/authorized_keys/`
`systemctl list-timers --all`
`/etc/rc.local/`

### Everything else

Do more threat hunting and fix services as they go down / issues arise! This playbook can only cover so much so learn as you go, and ask others in your team for help.
