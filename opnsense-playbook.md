# Basic OPNsense Playbook

### AI Preface

This is an AI generated playbook. This is untested but hopefully a decent guide. Take everything in here with a more than a few grains of salt. 

### Before Starting

Use the **web interface**; no scripts, Git, or pasted commands are needed. Menu labels can vary by OPNsense version. This guide has been checked against official documentation but not tested on the competition firewall.

- Record the management address, WAN/LAN interfaces, subnets, gateways, and required services/ports.
- Confirm which services depend on this firewall, including DNS, DHCP, VPNs, and port forwards.
- Keep console access available. A firewall mistake can disconnect the whole team.
- Antivirus tools are banned; do not install or run them.

### Log In and Back Up

1. Open the firewall's assigned management address in a browser and log in.
2. Go to **System > Configuration > Backups** and download the current configuration before changing anything.
3. Store it in the restricted team location; configuration backups contain sensitive settings. Label it with the host and time. See [OPNsense backup instructions](https://docs.opnsense.org/manual/backups.html).

### Secure Access

- Under **System > Access > Users**, review accounts and change authorized administrator passwords. Check privileges and unfamiliar API keys. Verify a fresh login before closing the working session. See [user management](https://docs.opnsense.org/manual/users.html).
- Under **System > Settings > Administration**, review web/SSH access. Use HTTPS and limit management access to the team management network; keep SSH disabled if it is not needed. See [administration settings](https://docs.opnsense.org/manual/settingsmenu.html).
- Keep the anti-lockout rule enabled during initial setup. Before changing it, create and test an explicit management-access rule with console recovery available. See [anti-lockout settings](https://docs.opnsense.org/manual/firewall_settings.html).

### Review Firewall Rules

- Open **Firewall > Rules** (or **Rules [new]**, depending on version). Review interface, floating, and group rules.
- Rules normally filter traffic as it enters an interface: LAN clients on LAN, external clients on WAN. Default quick rules use the first matching rule; earlier floating/group rules can take precedence.
- Identify broad allow rules and unexplained management access. Replace them with specific source, destination, protocol, and port allowances only after confirming dependencies.
- Review **Firewall > NAT** for unexpected port forwards and their associated pass rules. Preserve required public services and working outbound NAT.
- Make one change at a time, **Save**, then **Apply changes** when prompted. Test a new connection to each affected service from the correct network. See [rule behavior and ordering](https://docs.opnsense.org/manual/firewall.html).

### Watch Traffic and Investigate

- Open **Firewall > Log Files > Live View** and filter by the affected host or port. Enable logging on the specific rule being investigated if needed. Live View is not a complete traffic history; established connections may not produce new entries. See [firewall logging](https://docs.opnsense.org/manual/logging_firewall.html).
- Check **Firewall > Diagnostics > States** for existing connections. A rule change may not stop an established connection; remove only the relevant state if necessary. Clearing all states disrupts unrelated services. See [connection states](https://docs.opnsense.org/manual/firewall.html#states).
- Investigate unexpected accounts, rule changes, port forwards, and VPN access. Record the time, source/destination, matched rule, and action before changing anything.

### If Services Break

1. Undo the last change and apply it. Check the affected service from a client, not just from the firewall.
2. Confirm client IP, gateway, and DNS settings; then check the relevant interface, rules, NAT, and logs.
3. If the web interface still works, restore the known-good configuration under **System > Configuration > Backups**. Coordinate any required reboot with the team.
4. If locked out, use the local/VM console's **Restore a configuration** option to select a known-good backup. Avoid a factory reset. See [console recovery](https://docs.opnsense.org/troubleshooting/config_reset.html).

### Handoff

Save a new backup after verified changes. Record changed rules/accounts, required ports, service test results, and unresolved findings. Coordinate upgrades and reboots with the team because they interrupt routing.
