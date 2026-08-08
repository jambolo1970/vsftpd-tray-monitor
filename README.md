# vsftpd Tray Monitor

Piccolo monitor per il servizio **vsftpd** su Linux, residente nella tray di
sistema. Mostra a colpo d'occhio lo stato del server FTP e l'attività di
trasferimento in corso, con notifiche sull'ultima operazione.

- **Autore:** Gianluca Bolognesi
- **Versione:** 2608
- **Licenza:** GNU General Public License v3.0 (vedi [LICENSE](LICENSE))

## Stati dell'icona

L'icona è una cartella-server che cambia colore e badge a seconda dello stato:

| Icona | Stato | Significato |
|-------|-------|-------------|
| <img src="icons/vsftpd-tray-monitor-gray.svg" alt="grigia + divieto" width="64"> grigia+divieto| fermo | il servizio vsftpd non è attivo |
| <img src="icons/vsftpd-tray-monitor-green.svg" alt="verde" width="64"> verde | attivo | servizio attivo, nessun trasferimento in corso |
| <img src="icons/vsftpd-tray-monitor-blue.svg" alt="freccia giù blue" width="64"> freccia giù blue  | download | lettura/download in corso |
| <img src="icons/vsftpd-tray-monitor-orange.svg" alt="freccia su arancione" width="64"> freccia su arancione | upload | scrittura/upload in corso |
| <img src="icons/vsftpd-tray-monitor-purple.svg" alt="doppia freccia viola" width="64"> doppia freccia viola | entrambi | download e upload contemporanei |
| <img src="icons/vsftpd-tray-monitor-red.svg" alt="rossa + ❗️" width="64"> rossa + ❗️ | errore | il servizio è in stato di errore |

L'icona torna automaticamente al verde quando l'attività termina: un
trasferimento è considerato "in corso" solo se avvenuto negli ultimi secondi.
La finestra temporale è configurabile tramite la costante `ACTIVITY_TTL` nel
sorgente.

## Interazione con la tray

- **Click sinistro:** mostra una notifica con l'ultima operazione registrata
  (tipo di operazione, file, utente e quanto tempo fa è avvenuta).
- **Click destro:** apre il menu con
  - **Informazioni** — autore e versione
  - **Chiudi programma** — chiude *solo* il monitor della tray, **non** vsftpd

Se vsftpd viene arrestato, il monitor resta nella tray e diventa grigio o
rosso a seconda della condizione. Quando vsftpd viene riavviato, il monitor
riprende a controllarlo normalmente.

## Come rileva l'attività

Lo stato del servizio viene letto con `systemctl`. L'attività di trasferimento
viene rilevata leggendo, in ordine di preferenza:

1. il transfer log di vsftpd, se leggibile
   (`/var/log/vsftpd.log`, `/var/log/xferlog` o il percorso indicato in
   `/etc/vsftpd-tray-monitor.conf`);
2. in alternativa, il journal di systemd (`journalctl -u vsftpd`).

Sono riconosciuti sia il formato nativo di vsftpd (`OK/FAIL DOWNLOAD/UPLOAD`)
sia il formato xferlog standard.

## Permessi di lettura del log

Il monitor gira come utente normale (non root) e deve poter **leggere** il
transfer log di vsftpd. Di norma questo file appartiene a `root` con permessi
`640`, quindi non è leggibile da un utente comune. Ci sono due modi per
risolvere; scegli quello adatto al tuo contesto, e va modificato il file presente nella cartella:
```/etc/logrotate.d/vsftpd ```


### Opzione A — accesso via gruppo (consigliata, `640`)

Dà accesso in lettura al solo gruppo, senza esporre il log agli altri utenti
del sistema. È la scelta più prudente, perché il transfer log contiene indirizzi
IP, nomi utente e percorsi dei file trasferiti.

```sh
sudo chgrp users /var/log/vsftpd.log
sudo chmod 640 /var/log/vsftpd.log
sudo usermod -aG users "$USER"      # se non ne fai già parte -> poi ri-login
```

Per rendere l'accesso permanente anche dopo la rotazione dei log, imposta la
direttiva `create` in `/etc/logrotate.d/vsftpd`:

```
create 640 root users
```

Lo script `install.sh` tenta di applicare automaticamente questa configurazione.

### Opzione B — lettura per tutti (`644`)

Se il file di log viene usato **anche da altre applicazioni** o servizi che
devono leggerlo, oppure se sei su una macchina personale dove sei l'unico
utente e la riservatezza del log non è una preoccupazione, puoi renderlo
leggibile a tutti:

```sh
sudo chmod 644 /var/log/vsftpd.log
```

e nel logrotate:

```
create 644 root root
```

> Attenzione: `644` rende il log leggibile a **qualunque** utente o processo
> locale. Poiché il transfer log contiene IP dei client, nomi utente e percorsi
> dei file, usa questa opzione solo se sei consapevole di questa esposizione o
> se il contenuto non è sensibile nel tuo scenario.

In sintesi: `640` + gruppo è il minimo indispensabile e non espone il log agli
altri; `644` è più comodo quando il file deve essere letto ampiamente, al
costo di renderlo visibile a tutti.

## Configurazione di vsftpd

Perché il log dei trasferimenti venga scritto, in `/etc/vsftpd.conf` devono
essere attive almeno:

```
xferlog_enable=YES
vsftpd_log_file=/var/log/vsftpd.log
# in alternativa, per il formato xferlog classico:
# xferlog_std_format=YES        -> scrive in /var/log/xferlog
```

## Dipendenze

- Python 3.6+
- systemd (per `systemctl` e `journalctl`)
- GTK 3 con PyGObject
- AppIndicator (consigliato) per l'icona di tray
- libnotify per le notifiche del click sinistro (facoltativo: senza, viene
  mostrato un dialog di fallback)

Nomi dei pacchetti a seconda della distribuzione:

- **openSUSE:** `python3-gobject`, `typelib-1_0-Gtk-3_0`,
  `typelib-1_0-AppIndicator3-0_1`, `typelib-1_0-Notify-0_7`
- **Debian/Ubuntu:** `python3-gi`, `gir1.2-gtk-3.0`,
  `gir1.2-appindicator3-0.1`, `gir1.2-notify-0.7`
- **Fedora:** `python3-gobject`, `gtk3`, `libappindicator-gtk3`,
  `libnotify`

## Installazione

```sh
sudo ./install.sh
```

L'installazione copia il programma in `/opt/vsftpd-tray-monitor`, installa le
icone, crea un file di autostart per la sessione grafica e un wrapper in
`/usr/local/bin/vsftpd-tray-monitor` per l'avvio manuale.

Avvio manuale (staccato dal terminale):

```sh
vsftpd-tray-monitor
```

## Disinstallazione

```sh
sudo ./uninstall.sh
```

## Indipendenza dal terminale

Avviando il programma manualmente dalla shell, l'esecuzione viene staccata dal
terminale (doppio fork interno più `setsid`/`nohup` nel wrapper): chiudendo il
terminale, il monitor continua a funzionare. Per l'avvio automatico all'accesso
alla sessione grafica viene installato un file autostart in
`~/.config/autostart`.

## Licenza

Questo programma è software libero: puoi ridistribuirlo e/o modificarlo secondo
i termini della GNU General Public License versione 3, come pubblicata dalla
Free Software Foundation. Vedi il file [LICENSE](LICENSE) per il testo completo.

Questo programma è distribuito nella speranza che sia utile, ma SENZA ALCUNA
GARANZIA; senza neppure la garanzia implicita di COMMERCIABILITÀ o IDONEITÀ PER
UN PARTICOLARE SCOPO.
