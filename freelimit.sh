#!/bin/bash

DEV="ens33"
IFB="ifb0"

echo "[+] Removing traffic shaping rules..."

# Remove egress shaping
tc qdisc del dev $DEV root 2>/dev/null || true

# Remove ingress shaping
tc qdisc del dev $DEV ingress 2>/dev/null || true

# Remove IFB shaping
tc qdisc del dev $IFB root 2>/dev/null || true

echo "[+] Removing IFB interface..."
ip link set $IFB down 2>/dev/null || true
ip link del $IFB 2>/dev/null || true

echo "[✔] Cleanup complete. Network is back to normal."

echo ""
echo "[+] Current state check:"
tc qdisc show dev $DEV 2>/dev/null || echo "No qdisc on $DEV (OK)"
