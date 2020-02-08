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
o
n
p
1

+$((ext4size))MiB
n
p
2


t
1
83
t
2
82
a
1
w
FDISK

mkfs.ext4 "${diskname}1"

mkswap "${diskname}2"
swapon "${diskname}2"

mount "${diskname}1" /mnt

pacstrap /mnt base linux linux-firmawre

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash << EOC

ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime

hwclock --systohc

locale-gen

echo "LANG=fr_FR.UTF-8" >> /etc/locale.conf

export LANG=fr_FR.UTF-8

echo "KEYMAP=fr" >> /etc/vconsole.conf

echo "linux" >> /etc/hostname

echo "127.0.0.1		localhost" >> /etc/hosts
echo "::1			localhost" >> /etc/hosts
echo "127.0.1.1		linux.localdomain	linux" >> /etc/hosts

echo -e "root\nroot" | (passwd root)

pacman -S grub

grub-install "${diskname}1"

grub-mkconfig -o /boot/grub/grub.cfg

EOC