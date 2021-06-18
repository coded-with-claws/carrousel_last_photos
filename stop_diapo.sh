#!/bin/bash

source /home/pi/diapo/diapo.conf

echo "[*] $0 démarré"

touch $TOOL_DIR/STOP
echo "[+] Fichier STOP créé"

echo "[*] Lancement killall"
sudo killall -3 $DIAPO_PROG
sudo killall -3 -r $DIAPO_SCRIPT
echo "[+] killall réalisé, attente avant vérification que l'arrêt est effectif"
sleep 1
if pgrep fbi &>/dev/null; then
  echo "[*] Lancement killall -9 sur fbi"
  sudo killall -9 $DIAPO_PROG >/dev/null 2>&1
  echo "[+] killall -9 réalisé"
fi
if pgrep $DIAPO_SCRIPT &>/dev/null; then
  echo "[*] Lancement killall -9 sur le script"
  sudo killall -9 -r $DIAPO_SCRIPT >/dev/null 2>&1
  echo "[+] killall -9 réalisé"
fi
sleep 2
rm $TOOL_DIR/STOP
echo "[+] Fichier STOP supprimé"

echo "[*] Restauration de l'affichage framebuffer"
sudo fbi -noverbose -T 1 -a -t 1 --once /tmp/none

rm $TOOL_DIR/diapo_mutex

echo "[+] Sortie..."

