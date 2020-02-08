#! /bin/bash

# get disks
disksize=$(fdisk -l | grep /dev/sd* | awk -F " " {'print $5'})
echo "Disk size : $disksize"

# get ram size
ram=$(free --si | grep Mem | awk -F " " {'print $2'})
echo "Total ram : $ram"