# Linux Playbook
#### <font color="bf334a">Get scripts</font>

Make sure Git is installed

Check with
`git -v`

If on Debian based Linux distribution (debian/ubuntu) 
`sudo apt install git`
If on RHEL based Linux distribution (RHEL/Fedora)
`sudo dnf install git`


get the scripts `git clone https://github.com/Istavare/Blue-Team-Competition-Resources -b Linux`

make files in the script directory executable `sudo chmod +x *.sh`


##### OLD METHOD

- get scripts `wget https://raw.githubusercontent.com/CyberLions/CCDC/refs/heads/master/linux/GetScripts.sh`
- run `./GetScripts.sh`
- make files executable `sudo chmod +x *.sh`
##### Or alternatively 
- Get Git `dnf install git`
- Download the CCDC scripts `git clone https://github.com/CyberLions/CCDC.git`
- go into directory `cd CCDC/linux` 
- make files executable `sudo chmod +x *.sh`
#### <font color="c98a38">Change Passwords</font>

- Edit the password file `Change_Pass.sh` after getting accounts from Aiden

- Make a backup of the shadow file `sudo cp /etc/shadow /etc/shadow-backup` 
- Run `Change_Pass.sh`
- Use Password `AffinityCompetence62`
#### <font color="e0db47">Setup Firewall</font>

- Get nmap to figure it out `dnf install nmap`
- run nmap to find SMTP IMAP and POP3 `nmap -p- localhost`
- use the ccdc script `Stateful_IPtables.sh` this will ask for specific ports we want open
- the ports will be on the score check but the expected ports are: 22 25 143 110 587 5355 9090
- current rules can be checked with `sudo iptables -L` 
#### <font color="4ead2b">Update System</font>

- run `dnf upgrade` and this should take a while
#### <font color="2b6ec6">Threat Hunting</font>

- run ld_preload script `Check_LD_Preload.sh`
- check for executables in weird locations with script `SusExecutable.sh`
- check crontab with `sudo cat /var/spool/cron/*` 
- crontab of individual users can be checked with `crontab -l`
- systemd services are in `/etc/systemd/system/` 
- check everything manually installed with `apt-mark showmanual` look for anything suspicious 
#### <font color="8e5da3">Injects</font>

- get inventory for inject `get-inventory.sh`
- anything else required 

**Credentials**

scoreboard and netlab creds:
	team05f:y5cfNksD7f

![[Pasted image 20260114202938.png]]

system creds:
	sysadmin:changeme

	SMTP - 25
	IMAP - 143
	POP3 - 110

POP3 - Dovecot 
requires auth but been down for a while

21 monitors for 8 people lmaooooo


The scenario could have been mitigated if the system was more locked down. Keeping consistent updates and having a firewall could have prevented these unauthorized access of the data and integrity of the system. 

