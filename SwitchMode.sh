
cat > /root/set-dumb-ap.sh << "EOF"
#!/bin/sh

echo "[INFO] Backup config lama..."
cp /etc/config/network /etc/config/network.backup.$(date +%s)
cp /etc/config/dhcp /etc/config/dhcp.backup.$(date +%s)

echo "[INFO] Setting LAN IP jadi 192.168.1.2 ..."
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.1.2'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='192.168.1.1'
uci set network.lan.dns='192.168.1.1'

echo "[INFO] Matikan DHCP server pada LAN..."
uci set dhcp.lan.ignore='1'

echo "[INFO] Optional: disable WAN interface..."
uci delete network.wan || true
uci delete network.wan6 || true
uci delete dhcp.wan || true

echo "[INFO] Commit config..."
uci commit network
uci commit dhcp

echo "[INFO] Restart service..."
/etc/init.d/network restart
/etc/init.d/dnsmasq restart

echo "[DONE] NanoPi sekarang IP = 192.168.1.2 (akses via Asus LAN/WiFi)"
echo "[NOTE] Pastikan cucuk kabel ke port LAN (eth1) NanoPi, bukan WAN."
EOF

chmod +x /root/set-dumb-ap.sh


cat > /root/set-switch-mode.sh << "EOF"
#!/bin/sh
echo "=== [INFO] Backup config lama sebelum tukar ke Switch Mode ==="

BACKUP_DIR=/root/config-backup-$(date +%Y%m%d-%H%M%S)
mkdir -p $BACKUP_DIR
cp /etc/config/network $BACKUP_DIR/
cp /etc/config/dhcp $BACKUP_DIR/
cp /etc/config/firewall $BACKUP_DIR/
echo "[DONE] Semua config backup di: $BACKUP_DIR"

echo "=== [INFO] Set LAN IP jadi 192.168.1.2 (static) ==="
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.1.2'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='192.168.1.1'
uci set network.lan.dns='192.168.1.1'

echo "=== [INFO] Matikan DHCP server pada LAN ==="
uci set dhcp.lan.ignore='1'

echo "=== [INFO] Disable interface WAN (tak perlu lagi) ==="
uci delete network.wan || true
uci delete network.wan6 || true
uci delete dhcp.wan || true

echo "=== [INFO] Disable firewall (tak perlu NAT lagi) ==="
/etc/init.d/firewall stop
/etc/init.d/firewall disable

echo "=== [INFO] Commit perubahan ==="
uci commit network
uci commit dhcp

echo "=== [INFO] Restart network & dnsmasq ==="
/etc/init.d/network restart
/etc/init.d/dnsmasq restart

echo "=== [DONE] NanoPi sekarang dalam Switch Mode (IP: 192.168.1.2) ==="
echo "=== [NOTE] Sambungkan kabel ke LAN port NanoPi (eth1) ke LAN port Asus ==="
echo "=== [RESTORE] Kalau nak revert, copy balik config dari $BACKUP_DIR ==="
EOF

chmod +x /root/set-switch-mode.sh


cat > /root/cek-mode.sh << "EOF"
#!/bin/sh

echo "=== [INFO] Status NanoPi ==="

LAN_IP=$(uci get network.lan.ipaddr 2>/dev/null)
DHCP_IGNORE=$(uci get dhcp.lan.ignore 2>/dev/null)
WAN_PROTO=$(uci get network.wan.proto 2>/dev/null)
FW_STATUS=$(/etc/init.d/firewall enabled && echo enabled || echo disabled)

echo "LAN IP       : ${LAN_IP:-N/A}"

if [ "$DHCP_IGNORE" = "1" ]; then
    echo "DHCP Server  : disabled"
else
    echo "DHCP Server  : enabled"
fi

echo "WAN Protocol : ${WAN_PROTO:-none}"
echo "Firewall     : $FW_STATUS"

# --- Logic check mode ---
if [ "$DHCP_IGNORE" = "1" ] && [ -z "$WAN_PROTO" ] && [ "$FW_STATUS" = "disabled" ]; then
    echo ">>> MODE: SWITCH/AP <<<"
else
    echo ">>> MODE: ROUTER <<<"
fi
EOF


cat << "EOF" > /root/restore-router-mode.sh
#!/bin/sh
# Restore NanoPi R2S ke Router Mode (asal OpenWrt)

echo "=== [INFO] Restore NanoPi ke Router Mode (Router + DHCP + WAN aktif) ==="

# 1. Set semula LAN IP ke 192.168.2.1
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.2.1'
uci set network.lan.netmask='255.255.255.0'

# 2. Enable DHCP server balik
uci set dhcp.lan.ignore='0'
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'

# 3. Enable WAN interface
uci set network.wan.proto='dhcp'

# 4. Enable firewall balik
/etc/init.d/firewall enable
/etc/init.d/firewall start

# 5. Commit perubahan
uci commit network
uci commit dhcp

# 6. Restart servis penting
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart

echo "=== [DONE] NanoPi dah kembali ke Router Mode ==="
echo "👉 Akses semula melalui http://192.168.2.1"
EOF


chmod +x /root/cek-mode.sh
chmod +x /root/restore-router-mode.sh

