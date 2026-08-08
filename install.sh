#!/bin/sh
set -e

PREFIX="/usr"
APP="/opt/vsftpd-tray-monitor"
BIN="$APP/vsftpd-tray-monitor"
ICON="$APP/icons"

if [ "$(id -u)" -ne 0 ]; then
    echo "Eseguire con sudo: sudo ./install.sh"
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

rm -rf "$APP"
mkdir -p "$APP" "$APP/icons" "$APP/bin"

cp "$SCRIPT_DIR/bin/vsftpd-tray-monitor" "$BIN"
chmod 755 "$BIN"
cp "$SCRIPT_DIR/icons/"*.svg "$APP/icons/"
mkdir -p /usr/share/icons/hicolor/scalable/apps
cp "$SCRIPT_DIR/icons/"*.svg /usr/share/icons/hicolor/scalable/apps/

mkdir -p /usr/share/icons/hicolor/scalable/apps
cp "$SCRIPT_DIR/icons/vsftpd-tray-monitor.svg" \
   /usr/share/icons/hicolor/scalable/apps/vsftpd-tray-monitor.svg

cat > /etc/vsftpd-tray-monitor.conf <<EOF
# Percorso opzionale del transfer log di vsftpd.
# Lasciare vuoto per usare /var/log/vsftpd.log o /var/log/xferlog.
transfer_log=
EOF

cat > /usr/local/bin/vsftpd-tray-monitor <<EOF
#!/bin/sh
# Avvio staccato dal terminale: chiudendo il terminale il monitor resta attivo.
# Il binario esegue anche un doppio-fork interno; qui usiamo setsid/nohup
# come ulteriore garanzia quando lanciato a mano dalla shell.
if command -v setsid >/dev/null 2>&1; then
    setsid "$BIN" "\$@" >/dev/null 2>&1 < /dev/null &
else
    nohup "$BIN" "\$@" >/dev/null 2>&1 < /dev/null &
fi
EOF
chmod 755 /usr/local/bin/vsftpd-tray-monitor

cat > /etc/systemd/user/vsftpd-tray-monitor.service <<EOF
[Unit]
Description=vsftpd Tray Monitor
After=graphical-session.target

[Service]
Type=simple
ExecStart=$BIN
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF

mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/vsftpd-tray-monitor.desktop <<EOF
[Desktop Entry]
Type=Application
Name=vsftpd Tray Monitor
Comment=Monitor dello stato di vsftpd nella tray
Exec=$BIN
Icon=vsftpd-tray-monitor
Terminal=false
Categories=System;Network;
X-GNOME-Autostart-enabled=true
EOF

# Installazione per l'utente che ha invocato sudo.
REAL_USER="${SUDO_USER:-}"
if [ -n "$REAL_USER" ]; then
    REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    if [ -n "$REAL_HOME" ]; then
        mkdir -p "$REAL_HOME/.config/autostart"
        cp /etc/xdg/autostart/vsftpd-tray-monitor.desktop "$REAL_HOME/.config/autostart/"
        chown "$REAL_USER:" "$REAL_HOME/.config/autostart/vsftpd-tray-monitor.desktop" 2>/dev/null || true
    fi
fi

# --- Accesso in lettura al log di vsftpd -----------------------------------
# Il monitor gira come utente normale e deve poter leggere il transfer log,
# tipicamente /var/log/vsftpd.log con permessi 640 root:root. Diamo l'accesso
# via gruppo, in modo che sopravviva al logrotate (se aggiorni anche la
# direttiva "create" in /etc/logrotate.d/vsftpd).
LOGF=""
for cand in /var/log/vsftpd.log /var/log/xferlog /var/log/vsftpd/vsftpd.log; do
    if [ -f "$cand" ]; then
        LOGF="$cand"
        break
    fi
done

if [ -n "$LOGF" ] && [ -n "$REAL_USER" ]; then
    # Usa un gruppo esistente e sensato: 'users' se presente, altrimenti il
    # gruppo primario dell'utente.
    if getent group users >/dev/null 2>&1; then
        LOGGRP="users"
    else
        LOGGRP=$(id -gn "$REAL_USER")
    fi
    chgrp "$LOGGRP" "$LOGF" 2>/dev/null || true
    chmod 640 "$LOGF" 2>/dev/null || true
    # Assicura che l'utente appartenga al gruppo del log.
    if ! id -nG "$REAL_USER" | tr ' ' '\n' | grep -qx "$LOGGRP"; then
        usermod -aG "$LOGGRP" "$REAL_USER" 2>/dev/null || true
        NEED_RELOGIN=1
    fi
    # Scrive il percorso rilevato nella config del monitor.
    if [ -f /etc/vsftpd-tray-monitor.conf ]; then
        sed -i "s|^transfer_log=.*|transfer_log=$LOGF|" /etc/vsftpd-tray-monitor.conf 2>/dev/null || true
    fi
fi

echo
echo "Installazione completata."
echo "Avvio manuale: vsftpd-tray-monitor"
echo "Per l'avvio automatico è stato installato il file autostart."
echo
if [ -n "$LOGF" ]; then
    echo "Log di vsftpd rilevato: $LOGF (gruppo: ${LOGGRP:-n/d})"
    echo "Per rendere permanente l'accesso dopo il logrotate, imposta in"
    echo "  /etc/logrotate.d/vsftpd   la riga:   create 640 root ${LOGGRP:-users}"
else
    echo "ATTENZIONE: nessun transfer log di vsftpd trovato."
    echo "Verifica che in /etc/vsftpd.conf sia attivo:"
    echo "  xferlog_enable=YES"
    echo "  vsftpd_log_file=/var/log/vsftpd.log   (o xferlog_std_format=YES per /var/log/xferlog)"
fi
if [ -n "${NEED_RELOGIN:-}" ]; then
    echo
    echo "IMPORTANTE: l'utente $REAL_USER è stato aggiunto al gruppo ${LOGGRP}."
    echo "Effettua logout/login (o riavvia la sessione) perché abbia effetto."
fi
