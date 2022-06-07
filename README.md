# carrousel_last_photos
Carrousel displaying most recent photos on Linux Framebuffer with tool `fbi`.

These are GNU/Linux shell scripts written to display a carrousel of photos on a Raspberry Pi running on Raspberry Pi OS Lite (only console, no GUI).

The idea is to display the most recent photos (up to a given number of photos) of a folder, then check again which are the most recent photos to display, etc.
It's useful for a folder where new photos are uploaded frequently.

The default configuration is to display the 30 most recent photos, with 10 seconds for each photos (making a loop of 5 minutes).

The display is done with the tool `fbi`, which you must install on the system.

Caveat: fbi runs longer than the number of photos multiplied by the duration per photo. Hence, the script will desync with the fbi loops, along the time... This means that some photos could not be displayed because they were linked in the end of the loop and the refresh of the links is done before, and overwrites the link.

# Pre-requisites
```console
sudo apt install fbi imagemagick*
```

> yes, the character '*' is important

# Install
- Copy the files on a Raspberry Pi OS as user `pi` in the home (`/home/pi/`) and make them executable
- Add cron tasks to automatically run the show after the boot
```console
crontab -e
@reboot    rm /home/pi/diapo/diapo_mutex
@reboot    /home/pi/diapo/start_diapo.sh
* * * * *  /home/pi/diapo/start_diapo.sh
```
- Note: you can diverge from that setup if you edit diapo.conf and/or the scripts accordingly

# Configure
- It's happening inside diapo.conf
- You must already have NB_PHOTO_DIAPO available inside PHOTO_DIR (in order to create every symbolic links for fbi loop). Additional symlinks won't be created.

# Technical notes
This script may seem overengineered. Questions you may ask are :
- Why not use fbi with -once argument ? It was the first version of the script. After every batch of photos, we get back to Linux console for a bit, so it's not smooth and pretty.
- Why resizing the photos ? When we use fbi with "-autozoom" and "-cachemem 0", and change the photos (keeping the same filenames), fbi doesn't recalculate the autozoom for the new photo (will it ever be fixed ?)

