
```bash
# 1. Load IFB module for inbound shaping
modprobe ifb
modprobe sch_ingress
ip link add ifb0 type ifb
ip link set ifb0 up

# 2. Outbound shaping on ens33
tc qdisc add dev ens33 root handle 1: htb default 20
tc class add dev ens33 parent 1: classid 1:1 htb rate 10mbit ceil 10mbit
tc class add dev ens33 parent 1:1 classid 1:10 htb rate 10mbit ceil 10mbit
tc class add dev ens33 parent 1:1 classid 1:20 htb rate 1200kbit ceil 1200kbit

# 3. Redirect ingress to ifb0
tc qdisc add dev ens33 handle ffff: ingress
tc filter add dev ens33 parent ffff: protocol ip u32 match u32 0 0 \
  action mirred egress redirect dev ifb0

# 4. Inbound shaping on ifb0
tc qdisc add dev ifb0 root handle 2: htb default 20
tc class add dev ifb0 parent 2: classid 2:1 htb rate 10mbit ceil 10mbit
tc class add dev ifb0 parent 2:1 classid 2:20 htb rate 1200kbit ceil 1200kbit
```

---

## To see the filters (who gets throttled):

```bash
tc filter show dev ens33
tc filter show dev ifb0
###
tc class show dev ens33
tc class show dev ifb0
```

This will show which IPs/ports/marks land in class `1:20` (throttled) vs `1:10` (full speed). **Run `cat reload.sh` first** — that's your source of truth.
