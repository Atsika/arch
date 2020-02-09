#! /bin/bash

#check boot mode (BIOS=0, UEFI=1)
if [ ! -f "/sys/firmware/efi/efivars" ]
then
	BOOT_MODE=0
else
	BOOT_MODE=1
fi

# update system clock
timedatectl set-ntp true

# get disk name
DISK_NAME=$(fdisk -l | grep /dev/sd* | awk -F " " {'print $2'})
# remove the ":" after name
DISK_NAME="${DISK_NAME//:}"

# get disk size
DISK_SIZE=$(fdisk -l | grep $DISK_NAME | awk -F " " {'print $5'})
DISK_SIZE=$(($DISK_SIZE/1048576)) # convert to MB
# check disk size
if [ $DISK_SIZE < 2000 ]
then
	echo "Not enough space on disk"
	exit
fi

# get ram size
SWAP_SIZE=$(free --si --mega | grep Mem | awk -F " " {'print $2'})
# get partition size
ROOT_SIZE=$(($DISK_SIZE-$SWAP_SIZE-512))

if [ $ROOT_SIZE < 2000 ]
then
	ROOT_SIZE=$(($DISK_SIZE-512))
	SWAP=0
else
	SWAP=1
fi

# wipe disk
wipefs -a $DISK_NAME
partprobe $DISK_NAME

# partition disk
if [ $BOOT_MODE = 0 ]
then
	if [ $SWAP = 1 ]
	then
		echo -e "g\nn\n\n\n+1M\nn\n\n\n+$((ROOT_SIZE))M\nn\n\n\n\nt\n1\n4\nt\n2\n20\nt\n3\n19\nw\n" | fdisk $DISK_NAME
	else
		echo -e "g\nn\n\n\n+1M\nn\n\n\n\n\nt\n1\n4\nt\n2\n20\nw\n" | fdisk $DISK_NAME 
	fi
else
	if [ $SWAP = 1 ]
	then
		echo -e "g\nn\n\n\n+512M\nn\n\n\n+$((ROOT_SIZE))M\nn\n\n\n\nt\n1\n1\nt\n2\n20\nt\n3\n19\nw\n" | fdisk $DISK_NAME
	else
		echo -e "g\nn\n\n\n+512M\nn\n\n\n\n\nt\n1\n1\nt\n2\n20\nw\n" | fdisk $DISK_NAME 
	fi
fi

if [ $BOOT_MODE = 1 ]
then
	mkfs.fat -F32 "${DISK_NAME}1"
fi

mkfs.ext4 "${DISK_NAME}2"

if [ $SWAP = 1 ]
then
	mkswap "${DISK_NAME}3"
	swapon "${DISK_NAME}3"
fi

partprobe $DISK_NAME

mount "${DISK_NAME}2" /mnt
if [ $BOOT_MODE = 1 ]
then
    mkdir -p /mnt/efi
    mount "${DISK_NAME}1" /mnt/efi
fi

if [ $BOOT_MODE = 0 ]
then
	pacstrap /mnt base linux linux-firmware grub dhcpcd
else
	pacstrap /mnt base linux linux-firmware grub dhcpcd efibootmgr
fi

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash << EOC
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
echo "LANG=fr_FR.UTF-8" >> /etc/locale.conf
export LANG=fr_FR.UTF-8
echo "KEYMAP=fr" >> /etc/vconsole.conf
locale-gen
echo "linux" >> /etc/hostname
echo "127.0.0.1		localhost" >> /etc/hosts
echo "::1			localhost" >> /etc/hosts
echo "127.0.1.1		linux.localdomain	linux" >> /etc/hosts
echo -e "root\nroot" | (passwd root)
if [ $BOOT_MODE = 0 ]
then
grub-install --target=i386-pc "${DISK_NAME}1"
else
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id="Arch Linux"
fi
grub-mkconfig -o /boot/grub/grub.cfg
exit
EOC