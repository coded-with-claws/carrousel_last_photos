#!/bin/bash
# As user "pi", crontab -e
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

    DIR_FBI=/tmp/symlinkdiapo
    DIR_WORK=/tmp/resized_copy
    rm -fr $DIR_FBI $DIR_WORK
    mkdir $DIR_FBI $DIR_WORK

    # Prepare the symbolic links for the N last photos
    echo "[*] init - linking photos into directory $DIR_FBI" &>>$LOG_FILE
    make_links
  
    NB_FIC=`find $DIR_FBI -type l |wc -l`
    # The refresh of photos will be done 10 seconds before the end of the current loop
    #DUREE_TEMPO=$(($NB_FIC * $DUREE_PHOTO - $NB_PHOTO_DIAPO))
    DUREE_TEMPO=$(($NB_FIC * $DUREE_PHOTO - 10))
    if [ $DUREE_TEMPO -lt 1 ]; then
        DUREE_TEMPO=$(($NB_FIC - 1))
    fi
    DELAI_CLEAN=$(($NB_FIC * $DUREE_PHOTO / 60))
    if [ $DELAI_CLEAN -lt 1 ]; then
        DELAI_CLEAN=5
    fi
    echo "[*] init - delay for files to be cleaned = $DELAI_CLEAN minutes" &>>$LOG_FILE
  
    # run fbi (in background)
    run_fbi
    PID_FBI=$(pgrep fbi)
    echo "[+] fbi launched (PID $PID_FBI) on the directory $DIR_FBI" &>>$LOG_FILE
  
    # Main loop
    while [ ! -f $TOOL_DIR/STOP ]; do 
  
        # attendre jusqu'à ce qu'il ne reste que 30 sec avant la fin du diaporama
        # puis recuperer les 30 dernières photos (30 x 10s = 5min) (qui seront affichees a la prochaine iteration)
        echo "[*] wait $DUREE_TEMPO sec" &>>$LOG_FILE
        sleep $DUREE_TEMPO &>/dev/null
        echo "[+] end of wait" &>>$LOG_FILE
        make_links
        echo "[+] photos linked into directory $DIR_FBI" &>>$LOG_FILE
  
        # clean the photos not used in the next loop of fbi display, and being too old (i.e. not being displayed in current loop)
        clean_old_photos
        echo "[+] cleaned directory $DIR_WORK" &>>$LOG_FILE
  
        watchdog
  
    done
  
    rm $TOOL_DIR/diapo_mutex

}

function make_links() {
    symlink_i=1
    find $PHOTO_DIR -maxdepth 1 -type f -printf "%C@ %p\n" | sort -n | cut -f2- -d" " | tail -$NB_PHOTO_DIAPO | tr '\n' '\0' | 
	while IFS= read -r -d '' file; do 
	    i=`printf "%03d" $symlink_i`
	    copy=`basename "$file"`
	    #echo "link_$i" 
	    if [ ! -f ${DIR_WORK}/"$copy" ];  then
		convert "$file" -resize $RESO_PHOTO -background black -compose Copy -gravity center -extent $RESO_PHOTO ${DIR_WORK}/"$copy"
	    fi
	    ln -sf ${DIR_WORK}/"$copy" ${DIR_FBI}/"link_$i"
	    symlink_i=$(($symlink_i + 1))
	done
    }

function clean_old_photos() {
    find $DIR_WORK -type f -mmin +$DELAI_CLEAN -print0 | xargs -0 -n 1 basename 2>/dev/null | sort >/tmp/files_work 
    readlink $DIR_FBI/* | xargs -n 1 basename | sort >/tmp/files_fbi
    pushd . &>/dev/null
    cd $DIR_WORK
    comm -2 -3 /tmp/files_work /tmp/files_fbi | xargs rm -f
    popd &>/dev/null
}

function run_fbi() {
    sudo fbi -noverbose -T 1 -a -t $DUREE_PHOTO -cachemem 0 -blend 500 -nocomments $DIR_FBI/* >/dev/null 2>&1
}

function watchdog() {
    if ! pgrep fbi >/dev/null; then
	echo "[*] fbi no longer running, restarting" &>>$LOG_FILE
	run_fbi
    fi
}

main

