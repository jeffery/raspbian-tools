#!/bin/sh
: '
Project: https://github.com/jeffery/raspbian-tools
Date: 31-05-2013

Copyright (C) 2013  Jeffery Fernandez <jeffery@fernandez.net.au>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/.
'

set -e

exitWithMessage()
{
	# Pipe std out to std error
	echo "$1" 1>&2
	exit 1;
}

printUsage()
{
	echo
	echo Usage:  `basename $1` PATH_TO_IMG
	echo Example: `basename $1` /tmp/2013-05-30-raspberrypi.img
	echo
	exit 127
}

isRunByRoot()
{
	if [ "$(id -u)" != "0" ]; then
		false
	else
		true
	fi
}

isImageFile()
{
	if [ -r "$1" ]; then
		true
	else
		false
	fi
}

getPrimaryPartitionDeviceMapName()
{
	local imagePath="$1"
	secondPartitionMap=$(/sbin/kpartx -l "$imagePath" | sed -n 2p | awk -F ' :' ' { print $1 }')
	if [ $? = 0 ]; then
		echo $secondPartitionMap && exit 0
	else
		exitWithMessage "Failed recognising primary partition of image $imagePath"
	fi
}

mountImage()
{
	local imagePath="$1"
	local mountPath="$2"

	mkdir -p "$mountPath"

	deviceMapName=$(getPrimaryPartitionDeviceMapName "$imagePath")
	if [ $? = 0 ]; then
		echo "Primary partition will be mapped to /dev/mapper/$deviceMapName"
		/sbin/kpartx -a -s "$imagePath"
		if [ $? = 0 ]; then
			echo "Mounting image primary partition /dev/mapper/$deviceMapName to $mountPath"
			mount "/dev/mapper/$deviceMapName" "$mountPath"
			if [ $? = 0 ]; then
				true
			else
				exitWithMessage "Failed mounting /dev/mapper/$deviceMapName to $mountPath"
			fi
		else
			exitWithMessage "Failed mapping partition table"
		fi
	else
		exitWithMessage "Failed to obtain possible device map of primary partition"
	fi
}


isArmInterpreterInstalled()
{
	armInterpreter=$(cat /proc/sys/fs/binfmt_misc/arm)
	if [ $? = "0" ]; then
		true
	else
		false
	fi
}

isArmInterpreterEnabled()
{
	armEnabled=$(cat /proc/sys/fs/binfmt_misc/arm | grep "enabled")
	if [ $? = "0" ]; then
		true
	else
		false
	fi
}

chRootImage()
{
	local imageName=$(basename "$1")
	local imagePath=$(realpath "$1")
	local mountPath=$(realpath "${imageName}.mnt")

	mountImage "$imagePath" "$mountPath" || exitWithMessage "Failed to mount primary partition of image"

	echo "Mounting system partitions for chrooting"
	mount -o bind /dev "$mountPath/dev" || exitWithMessage "Failed to mount dev"
	mount -o bind /dev/pts "$mountPath/dev/pts" || exitWithMessage "Failed to mount pts"
	mount -o bind /proc "$mountPath/proc" || exitWithMessage "Failed to mount proc"
	mount -o bind /sys "$mountPath/sys" || exitWithMessage "Failed to mount sys"
	mount -o bind /run "$mountPath/run" || exitWithMessage "Failed to mount run"

	echo "Disabling everything in /etc/ld.so.preload"
	sed -i 's/^\([^#]\)/#\1/g' "$mountPath/etc/ld.so.preload"

	echo "Setting up network interfaces - TODO"
	#cp /etc/network/interfaces "$mountPath/etc/network/interfaces"

	echo "Copying resolve.conf"
	cp /etc/resolv.conf "$mountPath/etc/resolv.conf"

	echo "Enabling arm intepreter"
	if isArmInterpreterInstalled; then
		if ! isArmInterpreterEnabled; then
			echo 1 >/proc/sys/fs/binfmt_misc/arm
		fi
	else
		set +e
		updateBinFormat=$(`which qemu-binfmt-conf.sh` >/dev/null 2>&1)
		set -e
	fi

	echo "Copying Binary format files"
	binFormatFile=$(cat /proc/sys/fs/binfmt_misc/arm | grep interpreter | cut -c 13-)
	if [ $? = "0" ] && [ -f "$binFormatFile" ]; then
		cp "$binFormatFile" "${mountPath}/usr/bin/" && \
		cp "/usr/bin/qemu-arm" "${mountPath}/usr/bin/" || \
		exitWithMessage "Failed to copy qemu arm interpreters"

		echo "Start Chroot"
		chroot "$mountPath"
	else
		exitWithMessage "Failed setting Binary format for architecture, cannot chroot"
	fi
}

isAlreadyMounted()
{
	local imageName=$(basename "$1")
	local mountPath="${imageName}.mnt"

	if [ $(mount | grep "$mountPath" | wc -l ) = 0 ]; then
		false
	else
		true
	fi

}

setIfsToNewLine()
{
IFS="
"
}

unMount()
{
	local imagePath=$(realpath "$1")
	local mountPath="${imagePath}.mnt"

	setIfsToNewLine

	for mounted in $(mount | grep "$mountPath")
	do
	{
		unMountPath=$(echo "$mounted" | awk -F ' ' '{ print $3 }')
		if [ "$unMountPath" != "$mountPath" ]; then
			set +e
			testMount=$(mount | grep "$unMountPath")
			if [ $? = 0 ]; then
				set -e
				echo "Un-mounting $unMountPath"
				umount -l "$unMountPath" || exitWithMessage "Failed to un-mount $unMountPath"
			fi
		fi
	}
	done;
	echo "Un-mounting $mountPath"
	umount -l "$mountPath" || exitWithMessage "Failed to un-mount $mountPath"

	echo "Un-mapping primary partition of image $imagePath"
	kpartx -d -v "$imagePath" || exitWithMessage "Failed to un-map image Primary partition"

	echo "Done" && exit 0
}

if [ "$#" -ne 1 ]; then
	printUsage "$0"
else
	if isImageFile "$1"; then
		if ! isRunByRoot; then
			exitWithMessage "This script must be run as root user"
		fi

		if isAlreadyMounted "$1"; then
			unMount "$1"
		else
			chRootImage "$1"
		fi
	else
		printUsage "$0"
	fi
fi