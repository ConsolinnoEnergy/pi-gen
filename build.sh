#!/bin/bash -e
# shellcheck disable=SC2119,SC1091
run_sub_stage()
{
	log "Begin ${SUB_STAGE_DIR}"
	pushd "${SUB_STAGE_DIR}" > /dev/null
	for i in {00..99}; do
		if [ -f "${i}-debconf" ]; then
			log "Begin ${SUB_STAGE_DIR}/${i}-debconf"
			on_chroot << EOF
debconf-set-selections <<SELEOF
$(cat "${i}-debconf")
SELEOF
EOF

		log "End ${SUB_STAGE_DIR}/${i}-debconf"
		fi
		if [ -f "${i}-packages-nr" ]; then
			log "Begin ${SUB_STAGE_DIR}/${i}-packages-nr"
			PACKAGES="$(sed -f "${SCRIPT_DIR}/remove-comments.sed" < "${i}-packages-nr")"
			if [ -n "$PACKAGES" ]; then
				on_chroot << EOF
apt-get install --no-install-recommends -y $PACKAGES
EOF
			fi
			log "End ${SUB_STAGE_DIR}/${i}-packages-nr"
		fi
		if [ -f "${i}-packages" ]; then
			log "Begin ${SUB_STAGE_DIR}/${i}-packages"
			PACKAGES="$(sed -f "${SCRIPT_DIR}/remove-comments.sed" < "${i}-packages")"
			if [ -n "$PACKAGES" ]; then
				on_chroot << EOF
apt-get install -y $PACKAGES
EOF
			fi
			log "End ${SUB_STAGE_DIR}/${i}-packages"
		fi
		if [ -d "${i}-patches" ]; then
			log "Begin ${SUB_STAGE_DIR}/${i}-patches"
			pushd "${STAGE_WORK_DIR}" > /dev/null
			if [ "${CLEAN}" = "1" ]; then
				rm -rf .pc
				rm -rf ./*-pc
			fi
			QUILT_PATCHES="${SUB_STAGE_DIR}/${i}-patches"
			SUB_STAGE_QUILT_PATCH_DIR="$(basename "$SUB_STAGE_DIR")-pc"
			mkdir -p "$SUB_STAGE_QUILT_PATCH_DIR"
			ln -snf "$SUB_STAGE_QUILT_PATCH_DIR" .pc
			if [ -e "${SUB_STAGE_DIR}/${i}-patches/EDIT" ]; then
				echo "Dropping into bash to edit patches..."
				bash
			fi
			quilt upgrade
			RC=0
			quilt push -a || RC=$?
			case "$RC" in
				0|2)
					;;
				*)
					false
					;;
			esac
			popd > /dev/null
			log "End ${SUB_STAGE_DIR}/${i}-patches"
		fi
		if [ -x ${i}-run.sh ]; then
			log "Begin ${SUB_STAGE_DIR}/${i}-run.sh"
			./${i}-run.sh
			log "End ${SUB_STAGE_DIR}/${i}-run.sh"
		fi
		if [ -f ${i}-run-chroot.sh ]; then
			log "Begin ${SUB_STAGE_DIR}/${i}-run-chroot.sh"
			on_chroot < ${i}-run-chroot.sh
			log "End ${SUB_STAGE_DIR}/${i}-run-chroot.sh"
		fi
	done
	popd > /dev/null
	log "End ${SUB_STAGE_DIR}"
}


run_stage(){
	log "Begin ${STAGE_DIR}"
	STAGE="$(basename "${STAGE_DIR}")"
	pushd "${STAGE_DIR}" > /dev/null
	unmount "${WORK_DIR}/${STAGE}"
	STAGE_WORK_DIR="${WORK_DIR}/${STAGE}"
	ROOTFS_DIR="${STAGE_WORK_DIR}"/rootfs
	if [ ! -f SKIP_IMAGES ]; then
		if [ -f "${STAGE_DIR}/EXPORT_IMAGE" ]; then
			EXPORT_DIRS="${EXPORT_DIRS} ${STAGE_DIR}"
		fi
	fi
	if [ ! -f SKIP ] || [ ! -d $STAGE_WORK_DIR ]; then
		if [ "${CLEAN}" = "1" ]; then
			if [ -d "${ROOTFS_DIR}" ]; then
				rm -rf "${ROOTFS_DIR}"
			fi
		fi
		if [ -x prerun.sh ]; then
			log "Begin ${STAGE_DIR}/prerun.sh"
			./prerun.sh
			log "End ${STAGE_DIR}/prerun.sh"
		fi
		for SUB_STAGE_DIR in ${STAGE_DIR}/*; do
			if [ -d "${SUB_STAGE_DIR}" ] &&
			   [ ! -f "${SUB_STAGE_DIR}/SKIP" ]; then
				run_sub_stage
			fi
		done
	fi
	unmount "${WORK_DIR}/${STAGE}"
	PREV_STAGE="${STAGE}"
	PREV_STAGE_DIR="${STAGE_DIR}"
	PREV_ROOTFS_DIR="${ROOTFS_DIR}"
	popd > /dev/null
	log "End ${STAGE_DIR}"
}

run_build(){
	for STAGE_DIR in "${BASE_DIR}/stage"*; do
		run_stage
	done

	CLEAN=1
	log "Before export image"
	for EXPORT_DIR in ${EXPORT_DIRS}; do
		log "start export image ${EXPORT_DIR}"
		STAGE_DIR=${BASE_DIR}/export-image
		# shellcheck source=/dev/null
		source "${EXPORT_DIR}/EXPORT_IMAGE"
		EXPORT_ROOTFS_DIR=${WORK_DIR}/$(basename "${EXPORT_DIR}")/rootfs
		run_stage
		if [ "${USE_QEMU}" != "1" ]; then
			if [ -e "${EXPORT_DIR}/EXPORT_NOOBS" ]; then
				# shellcheck source=/dev/null
				source "${EXPORT_DIR}/EXPORT_NOOBS"
				STAGE_DIR="${BASE_DIR}/export-noobs"
				run_stage
			fi
		fi
	done

	if [ -x postrun.sh ]; then
		log "Begin postrun.sh"
		cd "${BASE_DIR}"
		./postrun.sh
		log "End postrun.sh"
	fi
}

write_img(){
	#ask for transcend in loop
	while true
	do
		read -p "Please insert SDCard with minimum 2 GB Space, the inserted SDCard will be formated. Press [w] when ready or [c] for cancel." answer
	  case $answer in
			#lookup harddrives for usb devices from "SD transcend"
	   	[w]* ) USB_HDD_DEVICE=$(lsblk -l --paths --scsi -n -o tran,name,model | grep -n "usb.*SD  Transcend" | grep -P '/dev/sd.' -o | head -1);
							if [ -z "$USB_HDD_DEVICE" ]; then
								echo "No usb hdd found"
								break;
							fi
							IMG_PATH=$(find $WORK_DIR/export-image/ -name *.img | sort | head -1)
							if [ ! -f $IMG_PATH ]; then
								echo "No input file found"
								break;
							fi
							echo "writing $IMG_PATH to $USB_HDD_DEVICE"
							dd bs=4M if=$IMG_PATH of=$USB_HDD_DEVICE status=progress
							sync
	           	break;;

	   	[c]* ) break;;

	    * )     echo "Dude, just enter [w] or [c], please."; break ;;
	  esac
	done
}

if [ "$(id -u)" != "0" ]; then
	echo "Please run as root" 1>&2
	exit 1
fi


if [ -f config ]; then
	source config
fi

if [ -z "${IMG_NAME}" ]; then
	echo "IMG_NAME not set" 1>&2
	exit 1
fi

export USE_QEMU="${USE_QEMU:-0}"
export IMG_DATE="${IMG_DATE:-"$(date +%Y-%m-%d)"}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR="${BASE_DIR}/scripts"
export WORK_DIR="${WORK_DIR:-"${BASE_DIR}/work/${IMG_DATE}-${IMG_NAME}"}"
export DEPLOY_DIR=${DEPLOY_DIR:-"${BASE_DIR}/deploy"}
export LOG_FILE="${WORK_DIR}/build.log"

export BASE_DIR

export CLEAN
export IMG_NAME
export APT_PROXY

export STAGE
export STAGE_DIR
export STAGE_WORK_DIR
export PREV_STAGE
export PREV_STAGE_DIR
export ROOTFS_DIR
export PREV_ROOTFS_DIR
export IMG_SUFFIX
export NOOBS_NAME
export NOOBS_DESCRIPTION
export EXPORT_DIR
export EXPORT_ROOTFS_DIR

export QUILT_PATCHES
export QUILT_NO_DIFF_INDEX=1
export QUILT_NO_DIFF_TIMESTAMPS=1
export QUILT_REFRESH_ARGS="-p ab"

# shellcheck source=scripts/common
source "${SCRIPT_DIR}/common"
# shellcheck source=scripts/dependencies_check
source "${SCRIPT_DIR}/dependencies_check"

dependencies_check "${BASE_DIR}/depends"

mkdir -p "${WORK_DIR}"
log "Begin ${BASE_DIR}"

#check zip input, otherwise use default route
DEVICE_DEFINITIONS=$1
if [ -n "$DEVICE_DEFINITIONS" ] && [ -f "$DEVICE_DEFINITIONS" ]; then
	rm device-export -Rf
	mkdir -p device-export
	unzip $DEVICE_DEFINITIONS -d device-export
	if [ ! -d "device-export/devices" ]; then
		rm device-export -Rf
		echo "Wrong export format"
		exit 1
	else
		for DEVICE in "device-export/devices/"*; do
			rm stage3 -Rf
			rm ${WORK_DIR}/export-noobs -Rf
			rm ${WORK_DIR}/export-image -Rf
			touch stage0/SKIP
			touch stage1/SKIP
			touch stage2/SKIP
			touch stage2/SKIP_IMAGES
			cp $DEVICE/stage3 stage3 -R
			find stage3/ -name "*.sh" -exec chmod +x {} \;
			run_build
			rm stage3 -Rf
			rm stage0/SKIP
			rm stage1/SKIP
			rm stage2/SKIP
			rm stage2/SKIP_IMAGES
			#prompt for usb device and write to transcend flash
			write_img
		done
		exit 0
	fi
else
	run_build
fi

log "End ${BASE_DIR}"
