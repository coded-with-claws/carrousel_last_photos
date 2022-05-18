#!/bin/bash
# En tant que user pi, crontab -e
#@reboot    rm /home/pi/diapo/diapo_mutex
#@reboot    /home/pi/diapo/start_diapo.sh
#* * * * *  /home/pi/diapo/start_diapo.sh

function main() {

  source /home/pi/diapo/diapo.conf

  if [ -f $TOOL_DIR/diapo_mutex ]
  then
    exit
  fi

  echo "[*] $0 demarre" &>$LOG_FILE
  touch $TOOL_DIR/diapo_mutex

  DIR_SYMLINK=/tmp/symlinkdiapo
  rm -fr $DIR_SYMLINK
  mkdir $DIR_SYMLINK

  # Symlink vers les deux premieres photos (qui sont mises en cache par fbi donc non modifiables)
  echo "[*] init - linker les deux premieres photos fixes $PHOTO1 et $PHOTO2 dans le repertoire DIR_SYMLINK" &>>$LOG_FILE
  ln -sf $PHOTO_DIR/$PHOTO1 ${DIR_SYMLINK}/link_001
  ln -sf $PHOTO_DIR/$PHOTO2 ${DIR_SYMLINK}/link_002

  # Preparer les liens symboliques pour les 30 dernieres photos (30 x 10s = 5min)
  echo "[*] init - linker les photos dans le repertoire $DIR_SYMLINK" &>>$LOG_FILE
  make_links

  # lancer fbi (automatiquement en background)
  sudo fbi -noverbose -T 1 -a -t $DUREE_PHOTO -cachemem 0 -blend 500 -nocomments $DIR_SYMLINK/* >/dev/null 2>&1
  PID_FBI=$(pgrep fbi)
  echo "[+] fbi demarre (PID $PID_FBI) sur le repertoire $DIR_SYMLINK" &>>$LOG_FILE
  clear

  # Boucle principale
  while [ ! -f $TOOL_DIR/STOP ]; do 
    
    # attendre jusqu'à ce qu'il ne reste que 30 sec avant la fin du diaporama
    # puis recuperer les 30 dernières photos (30 x 10s = 5min) (qui seront affichees a la prochaine iteration)
    NB_FIC=`find $DIR_SYMLINK -type l |wc -l`
    DUREE_TEMPO=$(($NB_FIC * $DUREE_PHOTO - 30))
    echo "[*] attendre $DUREE_TEMPO sec" &>>$LOG_FILE
    sleep $DUREE_TEMPO &>/dev/null
    echo "[+] fin attente" &>>$LOG_FILE
    make_links
    echo "[+] photos linkees dans le repertoire $DIR_SYMLINK" &>>$LOG_FILE

  done

  rm $TOOL_DIR/diapo_mutex

}

function make_links() {
  symlink_i=3
  find $PHOTO_DIR -maxdepth 1 -type f -printf "%C@ %p\n" | sort -n | cut -f2- -d" " | tail -$NB_PHOTO_DIAPO | tr '\n' '\0' | 
    while IFS= read -r -d '' file; do 
        i=`printf "%03d" $symlink_i`
        #echo "link_$i" 
        ln -sf "$file" ${DIR_SYMLINK}/"link_$i"
        symlink_i=$(($symlink_i + 1))
    done
}

main

