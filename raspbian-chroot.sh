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

mountImage()
{
	local imagePath="$1"
	local mountPath="$2"

	mkdir -p "$mountPath"

	/sbin/kpartx -a -v "$imagePath"
	sleep 5
	mount /dev/mapper/loop0p2 "$mountPath"
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
	local mountPath="${imageName}.mnt"

	mountImage "$imageName" "$mountPath" >/dev/null 2>&1

	mount -o bind /dev "$mountPath/dev"
	mount -o bind /dev/pts "$mountPath/dev/pts"
	mount -o bind /proc "$mountPath/proc"
	mount -o bind /sys "$mountPath/sys"
	mount -o bind /run "$mountPath/run"

	# Disable everything in /etc/ld.so.preload
	sed -i 's/^\([^#]\)/#\1/g' "$mountPath/etc/ld.so.preload"

	# sets up the interfaces - works by default
	#cp /etc/network/interfaces "$mountPath/etc/network/interfaces"

	# makes networking actually work
	cp /etc/resolv.conf "$mountPath/etc/resolv.conf"

	if isArmInterpreterInstalled; then
		if ! isArmInterpreterEnabled; then
			echo 1 >/proc/sys/fs/binfmt_misc/arm
		fi
	else
		set +e
		updateBinFormat=$(`which qemu-binfmt-conf.sh` >/dev/null 2>&1)
		set -e
	fi


	binFormatFile=$(cat /proc/sys/fs/binfmt_misc/arm | grep interpreter | cut -c 13-)
	if [ $? = "0" ] && [ -f "$binFormatFile" ]; then
		echo "Copying Binary format files"
		cp "$binFormatFile" "${mountPath}/usr/bin/"
		cp "/usr/bin/qemu-arm" "${mountPath}/usr/bin/"
	else
		exitWithMessage "Failed setting Binary format for architecture, cannot chroot"
	fi

	chroot "$mountPath"

}

isAlreadyChRooted()
{
	local imageName=$(basename "$1")
	local mountPath="${imageName}.mnt"

	if [ $(mount | grep "$mountPath" | wc -l ) = 0 ]; then
		false
	else
		true
	fi

}

unChRoot()
{
	local imageName=$(basename "$1")
	local mountPath="${imageName}.mnt"

	umount -l "$mountPath/dev/pts"
	umount -l "$mountPath/dev"
	umount -l "$mountPath/proc"
	umount -l "$mountPath/sys"
	umount -l "$mountPath/run"
	umount -l "$mountPath"
	kpartx -d -v "$imageName"
}

if [ "$#" -ne 1 ]; then
	printUsage "$0"
else
	if isImageFile "$1"; then
		if ! isRunByRoot; then
			exitWithMessage "This script must be run as root user"
		fi

		if isAlreadyChRooted "$1"; then
			unChRoot "$1"
		else
			chRootImage "$1"
		fi
	else
		printUsage "$0"
	fi
fi