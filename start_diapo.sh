#!/bin/bash
# En tant que user pi, crontab -e
#@reboot    rm /home/pi/diapo/diapo_mutex
#@reboot    /home/pi/diapo/start_diapo.sh
#* * * * *  /home/pi/diapo/start_diapo.sh

source /home/pi/diapo/diapo.conf

if [ -f $TOOL_DIR/diapo_mutex ]
then
  exit
fi

echo "[*] $0 démarré" &>$LOG_FILE
touch $TOOL_DIR/diapo_mutex

DIR_BANK1=/tmp/bank1
DIR_BANK2=/tmp/bank2
mkdir $DIR_BANK1 $DIR_BANK2
BANK_USED=$DIR_BANK1

# Cas particulier du démarrage : vider banque 1 puis récupérer les 30 dernières photos (30 x 10s = 5min)
echo "[*] init - copier les photos dans la banque $BANK_USED" &>>$LOG_FILE
rm -f ${BANK_USED}/*
find $PHOTO_DIR -type f -printf "%C@ %p\n" | sort -n | cut -f2- -d" " | tail -$NB_PHOTO_DIAPO | tr '\n' '\0' | 
  while IFS= read -r -d '' file; do 
      #echo "$file"
      ln -s "$file" ${BANK_USED}/
  done

# Boucle principale
while [ ! -f $TOOL_DIR/STOP ]; do 

  # lancer fbi (automatiquement en background)
  sudo fbi -noverbose -T 1 -a -t $DUREE_PHOTO --once --readahead -blend 500 -nocomments $BANK_USED/* >/dev/null 2>&1
  PID_FBI=$(pgrep fbi)
  echo "[+] fbi démarré (PID $PID_FBI) sur la banque $BANK_USED" &>>$LOG_FILE
  
  # attendre jusqu'à ce qu'il ne reste que 30 sec avant la fin du diaporama
  # puis récupérer les 30 dernières photos (30 x 10s = 5min) dans la prochaine banque (qui sera affichée à la prochaine itération)
  NB_FIC=`find $BANK_USED -type l |wc -l`
  DUREE_TEMPO=$(($NB_FIC * $DUREE_PHOTO - 30))
  echo "[*] attendre $DUREE_TEMPO sec" &>>$LOG_FILE
  sleep $DUREE_TEMPO &>/dev/null
  echo "[+] fin attente" &>>$LOG_FILE
  if [ $BANK_USED == $DIR_BANK1 ]
  then
    BANK_USED=$DIR_BANK2
  else
    BANK_USED=$DIR_BANK1
  fi
  rm -f ${BANK_USED}/*
  find $PHOTO_DIR -maxdepth 1 -type f -printf "%C@ %p\n" | sort -n | cut -f2- -d" " | tail -$NB_PHOTO_DIAPO | tr '\n' '\0' | 
    while IFS= read -r -d '' file; do 
        #echo "$file"
        ln -s "$file" ${BANK_USED}/
    done
  echo "[+] photos copiées dans la prochaine banque $BANK_USED" &>>$LOG_FILE

  # attendre la fin de fbi
  echo "[*] attendre fin de fbi" &>>$LOG_FILE
  tail --pid=$PID_FBI -f /dev/null
  echo "[+] fbi terminé" &>>$LOG_FILE
  
done

rm $TOOL_DIR/diapo_mutex

