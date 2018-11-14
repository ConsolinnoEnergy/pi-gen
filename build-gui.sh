#!/bin/bash -e

YAD_TITLE="Pi-Gen"

# check / request for root
[ "$UID" -eq 0 ] || exec gksu bash "$0" "$@"

progressbar () {
    tail -f $0 | yad --title=$YAD_TITLE --text="$@" --progress --pulsate --auto-close
}

# start zip select dialog
FILE_SELECTED=$(yad --title=$YAD_TITLE --file-selection --file-filter=*.zip --width=800 --height=600 --center)

DEVICE_EXPORT_PATH="device-export"
DEVICES_PATH="devices"
rm $DEVICE_EXPORT_PATH -Rf

if [ -z $FILE_SELECTED ]; then
  exit 0
fi
unzip $FILE_SELECTED -d $DEVICE_EXPORT_PATH

#Cleanup extracted data if valid data not found inside
if [ ! -d $DEVICE_EXPORT_PATH/$DEVICES_PATH ]; then
  rm $DEVICE_EXPORT_PATH -Rf
  exit 0
fi

for i in $DEVICE_EXPORT_PATH/$DEVICES_PATH/* ; do
  rm stage3 -Rf
  cp $i/stage3 stage3 -r
  echo "copy $i/stage3"
  find stage3/ -name "*.sh" -exec chmod +x {} \;

  #compile image for current selected device
  ./build.sh

  #show usb drive list / hint to insert usb drive
  DEVS=""
  DEVS=$(ls -l /dev/disk/by-path/*usb* | grep -v "part" | awk '{print $NF}' | awk -F "/" '{print $NF}')

  for k in $DEVS; do
    USBDRIVESIZE=`grep -m 1 "$k" /proc/partitions | awk '{print $3}'`
    USBDRIVES="$USBDRIVES!$k-$USBDRIVESIZE"
  done

  DEST_DRIVE=$(yad --title=$YAD_TITLE --form --field="USB Key:CB" $USBDRIVES --center)
  retval="$?"

  if [ "$retval" = "0" ]; then
    USBDRIVE=`echo $DEST_DRIVE | cut -d "|" -f 1 | cut -d "-" -f 1`

    if [ -z $DEST_DRIVE ] || [ "$DEST_DRIVE" = "sda" ]; then
      echo "Do not write on sda or on /dev (DEST_DRIVE is empty)"
      exit 0
    fi

    #umount drive
    umount `mount | grep $USBDRIVE | awk '{print $1}'`

    #do the copy
    #lookup last img file
    LAST_IMG=$(find work/*/export-image/ -name "*.img" | sort -rn | head -n 1)
    if [ -f $LAST_IMG ]; then
      echo "write last build to sdcard"
      #progressbar "Copying to USB Key Now \n\nPlease Wait \n" &
      dd if=$LAST_IMG of=/dev/$USBDRIVE bs=4M
      rm $LAST_IMG
    else
      exit 0
    fi
    sync

    yad --title=$YAD_TITLE --center --text="Copy to USB key completed. Insert next one or end process."
  fi

done
