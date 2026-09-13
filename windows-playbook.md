# Basic Windows Playbook
### AI preface

While the scripts are from CCDC last year, the playbook is AI generated and I would be careful using this for Red v. Blue. I don't have enough Windows knowledge to confirm whether this is a good basis to go off of. 

### Before Starting

- Confirm required services, authorized users, and service/scoring accounts. Keep console access when changing passwords or firewall rules.
- Document findings and changes, and test scored services after each change.
- Antivirus tools are banned; do not install or run them.
- These scripts have been reviewed but not tested on Windows. Practice before competition use.

### Get Scripts

With Git installed, open **64-bit Windows PowerShell as Administrator** and run:

1. `git clone https://github.com/Istavare/Blue-Team-Competition-Resources.git`
2. `cd Blue-Team-Competition-Resources`
3. `cd windows`

All scripts are directly in `windows/`. Stay in that folder and type the short commands below; no pasted code blocks or setup variables are needed. Use Tab to complete filenames. If script execution is blocked, follow the competition's approved execution-policy procedure.

### Inventory

- Run `.\get_inventory.ps1`.
- Reports and firewall/event-log backups are saved under `C:\ProgramData\CCDC`. The script prints the exact folder.
- Review service accounts, ports, users, and running processes. Keep reports in the restricted team evidence location.

### Change Passwords

- **Local accounts:** run `.\change_passwords.ps1`.
- Use option **3** to review protected accounts and **4** to add service/scoring accounts before rotating anything. This list resets when the script exits.
- Use option **1** to rotate one user at a time. `Administrator` starts protected; arrange its password change separately.
- Save credentials in the team's secure location and verify a new login. The script's XOR exports are not secure encryption, and plaintext output can be logged.
- **Domain accounts:** run `.\manage_ad_users.ps1` on an AD administrative host. Use option **1** for individual resets; avoid the plaintext bulk CSV workflow.
- Update affected service/scoring credentials and test services before moving on.

### Firewall

- Run `.\list_connections.ps1` to see ports and owning processes. Press Enter to refresh or type `exit`.
- Run `.\setup_firewall.ps1`.
- Start with **2: Backup Only**. Use **4** to allow a required port or **5** to block an unwanted port.
- If a change breaks services, use **3: Restore** from the console. Backups are in `C:\FirewallBackups`.
- **Avoid options 1 and 6 during normal setup:** option 1 removes existing rules and its defaults are incomplete for AD; option 6 blocks all traffic without automatic recovery.
- Test scored services and remote access after every change.

### Threat Hunting

- Run `.\list_scheduled_tasks.ps1` and inspect unfamiliar tasks. Tasks under Microsoft folders can also be malicious.
- Run `.\suspicious_executables.ps1` to list executable/script candidates in common locations.
- Run `.\check_rootkits.ps1` for driver/boot indicators. It saves `rootkit_findings.json` in the current folder; driver-path handling can cause false positives.
- Run `.\check_events.ps1` to view recent account, logon, process, task, and service-install events. Missing events may mean auditing is disabled.
- Use Task Scheduler, Services, and Event Viewer to inspect findings. Record evidence before disabling or removing confirmed malicious items.

### Injects and Handoff

Keep the inventory, incident notes, and service status current. Record the host, time, evidence, action, and verification result. Share unresolved findings with the next teammate.

Scripts are adapted from the prior club CCDC archive. `get_inventory.ps1` and `check_events.ps1` package the inventory and event checks into single commands.
