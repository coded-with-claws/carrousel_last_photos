# carrousel_last_photos
Carrousel displaying most recent photos on Linux Framebuffer with tool `fbi`.

These are GNU/Linux shell scripts written to display a carrousel of photos on a Raspberry Pi running on Raspberry Pi OS Lite (only console, no GUI).

The idea is to display the most recent photos (up to a given number of photos) of a folder are displayed, then check again which are the most recent photos to display, etc.

It's useful for a folder where new photos are uploaded frequently.

The display is done with the tool `fbi`, which you must install on the system.

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
