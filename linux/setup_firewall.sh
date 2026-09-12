#!/bin/bash

set -eEuo pipefail
trap 'echo "Firewall setup failed at line $LINENO; rules may be partially applied. Check before disconnecting." >&2' ERR

RULES=()

collect_ports() {
    local answer ports token port protocol
    local -a tokens
    echo "Allow SSH on TCP 22? (y/n; add any custom SSH port below)"
    read -r answer
    case "${answer,,}" in
        y|yes) RULES+=(22/tcp) ;;
        n|no) ;;
        *) echo "Expected y or n." >&2; exit 1 ;;
    esac
    echo "Incoming ports, space-separated (e.g. 80 443 53 1194/udp)."
    echo "Bare ports use TCP; bare 53 allows TCP and UDP. Empty means no extra ports."
    read -r ports
    read -r -a tokens <<< "$ports"
    for token in "${tokens[@]}"; do
        if [[ ! "$token" =~ ^([0-9]{1,5})(/(tcp|udp))?$ ]]; then
            echo "Invalid port: $token" >&2; exit 1
        fi
        port=$((10#${BASH_REMATCH[1]}))
        protocol=${BASH_REMATCH[3]:-tcp}
        if (( port < 1 || port > 65535 )); then
            echo "Port outside 1-65535: $token" >&2; exit 1
        fi
        RULES+=("$port/$protocol")
        if [[ "$token" != */* && "$port" == 53 ]]; then
            RULES+=(53/udp)
        fi
    done
    echo "Incoming allowances: ${RULES[*]:-(none)}"
    echo "New outbound connections are blocked; replies and existing connections remain allowed."
    echo "FTP passive ports must be listed to match your server configuration."
    echo "Existing host rules will be replaced. Keep console access available. Apply? (y/n)"
    read -r answer
    case "${answer,,}" in
        y|yes) ;;
        *) echo "Cancelled; no rules changed."; exit 0 ;;
    esac
}

configure_ufw() {
    local rule
    ufw --force reset
    ufw default deny incoming
    ufw default deny outgoing
    for rule in "${RULES[@]}"; do
        ufw allow in "$rule"
    done
    ufw --force enable
    ufw status verbose
    echo "To allow new outbound connections: sudo ufw default allow outgoing"
}

configure_iptables() {
    local firewall rule
    # Preserve forwarding, NAT, and mangle rules; configure both IP families.
    for firewall in iptables ip6tables; do
        "$firewall" -P INPUT ACCEPT
        "$firewall" -P OUTPUT ACCEPT
        "$firewall" -F INPUT
        "$firewall" -F OUTPUT
        "$firewall" -A INPUT -i lo -j ACCEPT
        "$firewall" -A OUTPUT -o lo -j ACCEPT
        "$firewall" -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        "$firewall" -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        if [[ "$firewall" == ip6tables ]]; then
            # Needed for IPv6 neighbor discovery and path MTU discovery.
            "$firewall" -A INPUT -p ipv6-icmp -j ACCEPT
            "$firewall" -A OUTPUT -p ipv6-icmp -j ACCEPT
        fi
        for rule in "${RULES[@]}"; do
            "$firewall" -A INPUT -p "${rule#*/}" --dport "${rule%/*}" -j ACCEPT
        done
        "$firewall" -P INPUT DROP
        "$firewall" -P OUTPUT DROP
        "$firewall" -L -n -v
    done
    echo "iptables rules are runtime-only; configure persistence separately before reboot."
    echo "To allow new outbound connections: sudo iptables -P OUTPUT ACCEPT; sudo ip6tables -P OUTPUT ACCEPT"
}

main() {
    if (( EUID != 0 )); then
        echo "Run with sudo: sudo $0" >&2; exit 1
    fi
    local backend
    if command -v ufw >/dev/null 2>&1; then
        backend=ufw
    elif command -v iptables >/dev/null 2>&1 && command -v ip6tables >/dev/null 2>&1; then
        backend=iptables
    else
        echo "Install UFW, or both iptables and ip6tables, before continuing." >&2
        exit 1
    fi
    collect_ports
    "configure_$backend"
    echo "Firewall configuration complete. Verify a new SSH connection and required services before disconnecting."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
