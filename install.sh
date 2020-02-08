#! /bin/bash

#check boot mode (BIOS=0, UEFI=1)
if [[ ! -f "/sys/firmware/efi/efivars" ]]
then
	bootmode=0
else
	bootmode=1
fi

# update system clock
timedatectl set-ntp true

# get disk name
diskname=$(fdisk -l | grep /dev/sd* | awk -F " " {'print $2'})

# get disk size
disksize=$(fdisk -l | grep /dev/$((diskname)) | awk -F " " {'print $5'})

# get ram size
ramsize=$(free --si | grep Mem | awk -F " " {'print $2'})
