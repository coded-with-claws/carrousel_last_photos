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
    DUREE_TEMPO=$(($NB_FIC * $DUREE_PHOTO))
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
	# wait a while before the end of the current fbi loop then make links for new photos (for the next fbi loop)
        echo "[*] wait $DUREE_TEMPO sec" &>>$LOG_FILE
        sleep $DUREE_TEMPO &>/dev/null
        echo "[+] wait $DUREE_TEMPO sec [DONE]" &>>$LOG_FILE
	# refresh the photo list (run it in background to keep sync'd with the fbi loop)
	# nevermind if it's not finished when fbi starts next loop, because it will start by reading the first links which are already up-to-date
        echo "[*] linking photos into directory $DIR_FBI" &>>$LOG_FILE
        make_links clean &
        watchdog
    done
  
    rm $TOOL_DIR/diapo_mutex

}

# arg1 : if set, clean must be done
function make_links() {
    clean=$1
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
    echo "[+] linking photos into directory $DIR_FBI [DONE]" &>>$LOG_FILE

    # clean the photos not used in the next loop of fbi display, and being too old (i.e. not being displayed in current loop)
    if [ ! -z $clean ]; then
	clean_old_photos
    fi
    }

function clean_old_photos() {
    find $DIR_WORK -type f -mmin +$DELAI_CLEAN -print0 | xargs -0 -n 1 basename 2>/dev/null | sort >/tmp/files_work 
    if [ -s /tmp/files_work ]; then
        readlink -z $DIR_FBI/* | xargs -0 -n 1 basename | sort >/tmp/files_fbi
        pushd . &>/dev/null
        cd $DIR_WORK
        comm -2 -3 /tmp/files_work /tmp/files_fbi | xargs -I {} rm -f "{}"
        popd &>/dev/null
    fi
    echo "[+] cleaned directory $DIR_WORK" &>>$LOG_FILE
}

function run_fbi() {
    sudo fbi -noverbose -T 1 -a -t $DUREE_PHOTO -cachemem 0 -nocomments $DIR_FBI/* >/dev/null 2>&1
}

function watchdog() {
    if ! pgrep fbi &>/dev/null; then
	echo "[*] fbi no longer running, restarting" &>>$LOG_FILE
	run_fbi
    fi
}

main

