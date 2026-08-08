#!/bin/sh
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Eseguire con sudo: sudo ./uninstall.sh"
    exit 1
fi

pkill -f '/opt/vsftpd-tray-monitor/vsftpd-tray-monitor' 2>/dev/null || true

rm -rf /opt/vsftpd-tray-monitor
rm -f /usr/local/bin/vsftpd-tray-monitor
rm -f /usr/share/icons/hicolor/scalable/apps/vsftpd-tray-monitor.svg
rm -f /etc/xdg/autostart/vsftpd-tray-monitor.desktop
rm -f /etc/vsftpd-tray-monitor.conf
rm -f /etc/systemd/user/vsftpd-tray-monitor.service

for home in /home/*; do
    [ -d "$home" ] || continue
    rm -f "$home/.config/autostart/vsftpd-tray-monitor.desktop"
done

echo "vsftpd Tray Monitor disinstallato."
