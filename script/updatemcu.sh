#!/bin/bash

# ==========================
# Variablen (Konfiguration)
# ==========================
CORES=$(grep -c processor /proc/cpuinfo)
kconfhost="/home/ente/printer_data/config/script/config.host"
kconfmcu2="/home/ente/printer_data/config/script/config.rpzero"
kconfmcu3="/home/ente/printer_data/config/script/config.r4"
pfadmcu2="/dev/serial/by-id/usb-Klipper_rp2040_4250305031373311-if00"
pfadmcu3="/dev/serial/by-id/usb-Klipper_rp2040_E6609CB2D3259224-if00"

declare -A MCUS=(
    ["rpi"]=$kconfhost
    ["rpzero"]=$kconfmcu2
    ["r4"]=$kconfmcu3
)

declare -A FLASH_DEVICES=(
    ["rpzero"]=$pfadmcu2
    ["r4"]=$pfadmcu3
)

# Debug-Modus aktivieren (true oder false)
DEBUG=false

# Farben für Konsolenausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ==========================
# Funktionen
# ==========================
function log {
    echo -e "${YELLOW}[DEBUG]${NC} $1"
}

# ==========================
# Debug aktivieren
# ==========================
if [ "$DEBUG" = true ]; then
    set -x  # Shell Debugging aktivieren
fi

# ==========================
# Klipper Update-Prozess
# ==========================
sudo service klipper stop
cd ~/klipper || { echo "Fehler: Klipper-Verzeichnis nicht gefunden!"; exit 1; }

for mcu in "${!MCUS[@]}"; do
    echo -e "${GREEN}Start update mcu $mcu${NC}"
    log "Cleaning build for $mcu"
    make clean KCONFIG_CONFIG=${MCUS[$mcu]}
    make clean

    log "Opening menuconfig for $mcu"
    make menuconfig KCONFIG_CONFIG=${MCUS[$mcu]}
   
    log "Starting build for $mcu with $CORES cores"
    make -j $CORES KCONFIG_CONFIG=${MCUS[$mcu]}

    #read -p "mcu $mcu firmware built. Press [Enter] to continue flashing, or [Ctrl+C] to abort"

    if [[ -n ${FLASH_DEVICES[$mcu]} ]]; then
        log "Flashing firmware to $mcu (Device: ${FLASH_DEVICES[$mcu]})"
        make flash FLASH_DEVICE=${FLASH_DEVICES[$mcu]}
    else
        log "Flashing firmware to $mcu without specific device"
        make flash KCONFIG_CONFIG=${MCUS[$mcu]}
    fi

    echo -e "${GREEN}Finish update mcu $mcu${NC}"
    echo ""
done

sudo cp ./scripts/klipper-mcu.service /etc/systemd/system/
sudo systemctl enable klipper-mcu.service
sudo usermod -a -G tty ente
sudo service klipper start

# ==========================
# Debug deaktivieren
# ==========================
if [ "$DEBUG" = true ]; then
    set +x
fi
