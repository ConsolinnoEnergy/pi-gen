#!/bin/bash -e

YAD_TITLE="Pi-Gen"

# check / request for root
[ "$UID" -eq 0 ] || exec gksu bash "$0" "$@"

# start zip select dialog
FILE_SELECTED=$(yad --title=$YAD_TITLE --file-selection --file-filter=*.zip --width=800 --height=600 --center)

DEVICE_EXPORT_PATH="device-export"
DEVICES_PATH="devices"
rm $DEVICE_EXPORT_PATH -Rf

if [ -z $FILE_SELECTED ]; then
  exit 0
fi
unzip $FILE_SELECTED -d $DEVICE_EXPORT_PATH

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

  #start usb write dd dialog

  exit 0

done
