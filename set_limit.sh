#!/bin/bash

DEV="ens33"
IFB="ifb0"
LIMIT_KBIT=1200   # ~100 KB/s

echo "[+] Cleanup old rules"
tc qdisc del dev $DEV root        2>/dev/null || true
tc qdisc del dev $DEV ingress     2>/dev/null || true
tc qdisc del dev $IFB  root       2>/dev/null || true
ip link del $IFB                  2>/dev/null || true

modprobe ifb || true
ip link add $IFB type ifb         2>/dev/null || true
ip link set $IFB up

# ── EGRESS (upload) ──────────────────────────────────────────────────────────
echo "[+] Upload shaping (SSH excluded)"

tc qdisc add dev $DEV root handle 1: htb default 20
tc class add dev $DEV parent 1:  classid 1:1  htb rate 10mbit  ceil 10mbit
tc class add dev $DEV parent 1:1 classid 1:10 htb rate 10mbit  ceil 10mbit  prio 0  # SSH – free
tc class add dev $DEV parent 1:1 classid 1:20 htb rate ${LIMIT_KBIT}kbit \
                                               ceil ${LIMIT_KBIT}kbit prio 1          # rest – capped

# prio 1 → SSH wins before the HTB default catch-all (class 1:20)
tc filter add dev $DEV protocol ip parent 1: prio 1 u32 match ip dport 22 0xffff flowid 1:10
tc filter add dev $DEV protocol ip parent 1: prio 1 u32 match ip sport 22 0xffff flowid 1:10

# ── INGRESS (download) ───────────────────────────────────────────────────────
echo "[+] Download shaping (SSH excluded)"

tc qdisc add dev $DEV handle ffff: ingress

# ❶ SSH sport/dport → action ok  (packet accepted, skips IFB entirely)
tc filter add dev $DEV parent ffff: protocol ip prio 1 u32 \
    match ip sport 22 0xffff \
    action ok

tc filter add dev $DEV parent ffff: protocol ip prio 1 u32 \
    match ip dport 22 0xffff \
    action ok

# ❷ Everything else → IFB for shaping  (lower prio = runs only if SSH didn't match)
tc filter add dev $DEV parent ffff: protocol ip prio 2 u32 \
    match u32 0 0 \
    action mirred egress redirect dev $IFB

# IFB only ever sees non-SSH traffic at this point
tc qdisc add dev $IFB root handle 2: htb default 20
tc class add dev $IFB parent 2:  classid 2:1  htb rate 10mbit  ceil 10mbit
tc class add dev $IFB parent 2:1 classid 2:20 htb rate ${LIMIT_KBIT}kbit \
                                               ceil ${LIMIT_KBIT}kbit prio 1

echo "[✔] SSH unlimited — all other traffic capped at ${LIMIT_KBIT}kbit/s"
