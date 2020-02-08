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
# remove the ":" after name
diskname="${diskname//:}"

# get disk size
disksize=$(fdisk -l | grep $diskname | awk -F " " {'print $5'})
echo "$(($disksize/1048576))"
# get ram size
swapsize=$(free --si | grep Mem | awk -F " " {'print $2'})
echo "$(($swapsize/1048576))"

ext4size=$(($disksize-$swapsize))


