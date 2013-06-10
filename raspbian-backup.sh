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
	echo Usage:  `basename $1` PATH_TO_BLOCK_DEVICE PATH_TO_BACKUP
	echo Example: `basename $1` /dev/sdd /var/device/backup
	echo
	exit 127
}

isBlockDevice()
{
	if [ -b "$1" ]; then
		true
	else
		false
	fi
}

isPathDirectory()
{
	if [ -d "$1" ]; then
		true
	else
		false
	fi
}

isRunByRoot()
{
	if [ "$(id -u)" != "0" ]; then
		false
	else
		true
	fi
}

copyBlockDevice()
{
	local blockDevice="$1"
	local destinationPath="$2"
	local backupDate=$(date +%Y-%m-%d_%Hh%Mm)

	echo
	echo "**** NOTICE ****"
	echo "This process will take a few minutes to complete"
	fdisk -lu "$blockDevice"
	echo

	pv -tpreb "$blockDevice" | dd bs=1024 of="${destinationPath}/${backupDate}-raspberrypi.img"
	echo "Wrote file: ${destinationPath}/${backupDate}-raspberrypi.img"
	echo
}


if [ "$#" -ne 2 ]; then
	printUsage "$0"
else
	if isBlockDevice "$1" && isPathDirectory "$2"; then
		if ! isRunByRoot; then
			exitWithMessage "This script must be run as root user"
		fi

		copyBlockDevice "$1" "$2"
	else
		printUsage "$0"
	fi
fi
