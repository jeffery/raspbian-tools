# Raspbian Tools
Scripts to manage a RaspberryPi device which is running Raspbian (http://www.raspbian.org). These scripts have only been
tested on openSUSE 12.3 distribution.

## raspbian-backup
This is a script to backup your RaspberryPi sd card from a block device. The block device is usually mounted via an SD
card reader. After inserting the SD card into a reader, you can backup the entire RaspberryPi operating system by
executing:

    ./raspbian-backup /dev/sdd ~/var/raspbian-images

The above command is reading the /dev/sdd block device and making a backup of it into the current directory. The script 
will create the backup image with a date timestamp. e.g. 2013-06-02_22h04m-raspberrypi.img

In order to know which block device was used for your card reader, you can verify by executing the command:

    dmesg
Usually you would see some messages from the kernel:

    [230998.829647] usb 5-1: new high-speed USB device number 3 using xhci_hcd
    [230998.842124] usb 5-1: New USB device found, idVendor=04cf, idProduct=9920
    [230998.842131] usb 5-1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
    [230998.842135] usb 5-1: Product: CS8819B
    [230998.842138] usb 5-1: Manufacturer: Myson Century, Inc.
    [230998.842141] usb 5-1: SerialNumber: 000100000000
    [230998.873431] Initializing USB Mass Storage driver...
    [230998.873657] scsi12 : usb-storage 5-1:1.0
    [230998.873845] usbcore: registered new interface driver usb-storage
    [230998.873851] USB Mass Storage support registered.
    [230999.874682] scsi 12:0:0:0: Direct-Access     Myson    SD/MMC/MS Reader 1.00 PQ: 0 ANSI: 0 CCS
    [230999.875010] sd 12:0:0:0: Attached scsi generic sg4 type 0
    [230999.875409] sd 12:0:0:0: [sdd] 7862272 512-byte logical blocks: (4.02 GB/3.74 GiB)
    [230999.875638] sd 12:0:0:0: [sdd] Write Protect is off
    [230999.875643] sd 12:0:0:0: [sdd] Mode Sense: 03 00 00 00
    [230999.875874] sd 12:0:0:0: [sdd] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
    [230999.879292]  sdd: sdd1 sdd2
    [230999.880714] sd 12:0:0:0: [sdd] Attached SCSI removable disk

## raspbian-chroot
This script helps in creating a chroot environment for your RaspberryPi backup image which has Raspbian installed as the
Operating System.

It requires package qemu-linux-user and kpartx (or the equivalent for your distro of choice) to be installed. To start 
the chrooted environment, execute it with the path to an exported Raspbian image:

    ./raspbian-chroot 2013-06-02_22h04m-raspberrypi.img

