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
disksize=$(($disksize/1048576)) # convert to MB
# get ram size
swapsize=$(free --si --mega | grep Mem | awk -F " " {'print $2'})

ext4size=$(($disksize-$swapsize))

fdisk $diskname << FDISK
g
n
1

+$((ext4size))MiB
n
2


t
1
20
t
2
19
w
FDISK