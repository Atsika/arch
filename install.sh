#! /bin/bash

#check boot mode (BIOS=0, UEFI=1)
if [ ! -e "/sys/firmware/efi/efivars" ]
then
	BOOT_MODE=0
else
	BOOT_MODE=1
fi

# update system clock
timedatectl set-ntp true

# get disk name
DISK_NAME=$(fdisk -l | sed -n '1p' | awk -F " " {'print $2'} | sed 's/://')

# get disk size
DISK_SIZE=$(fdisk -l | grep $DISK_NAME | awk -F " " {'print $5'})
DISK_SIZE=$(($DISK_SIZE/(1024*1024))) # convert to MB
# check disk size
if [ $DISK_SIZE < 2000 ]
then
	echo "Not enough space on disk"
	exit
fi

if [ $BOOT_MODE -eq 0 ]
then
	BOOT_SIZE=1
else
	BOOT_SIZE=512
fi

# get ram size
RAM=$(free --si --mega | grep Mem | awk -F " " {'print $2'})

# get swap size
if [ $RAM <= 2000 ]
then
	SWAP_SIZE=$(($RAM*2))
elif [ $RAM <= 8000 ]
then
	SWAP_SIZE=$RAM
elif [ $RAM < 16000 ]
	SWAP_SIZE=$(($RAM/2))
else
	SWAP_SIZE=0
fi

# get / partition size
ROOT_SIZE=$(($DISK_SIZE-$SWAP_SIZE-$BOOT_SIZE))

if [ $ROOT_SIZE < 2000 || $SWAP_SIZE > $ROOT_SIZE || SWAP_SIZE -eq 0 ] # if not enough space, forget about swap
then
	ROOT_SIZE=$(($DISK_SIZE-$BOOT_SIZE))
	SWAP=0 # swap flag set to 0 means no swap
else
	SWAP=1 # 1 means swap partition
fi

# wipe disk
wipefs -a $DISK_NAME
partprobe $DISK_NAME

# partition disk
if [ $BOOT_MODE -eq 0 ] # if boot mode is BIOS
then
	if [ $SWAP -eq 1 ] # if we can afford a swap partiton
	then
		echo -e "g\nn\n\n\n+$((BOOT_SIZE))M\nn\n\n\n+$((ROOT_SIZE))M\nn\n\n\n\nt\n1\n4\nt\n2\n20\nt\n3\n19\nw\n" | fdisk $DISK_NAME
	else
		echo -e "g\nn\n\n\n+$((BOOT_SIZE))M\nn\n\n\n\n\nt\n1\n4\nt\n2\n20\nw\n" | fdisk $DISK_NAME 
	fi
else # if boot mode is UEFI
	if [ $SWAP -eq 1 ]
	then
		echo -e "g\nn\n\n\n+$((BOOT_SIZE))M\nn\n\n\n+$((ROOT_SIZE))M\nn\n\n\n\nt\n1\n1\nt\n2\n20\nt\n3\n19\nw\n" | fdisk $DISK_NAME
	else
		echo -e "g\nn\n\n\n+$((BOOT_SIZE))M\nn\n\n\n\n\nt\n1\n1\nt\n2\n20\nw\n" | fdisk $DISK_NAME 
	fi
fi

if [ $BOOT_MODE -eq 1 ] # if boot mode is UEFI
then
	mkfs.fat -F32 "${DISK_NAME}1"
fi

mkfs.ext4 "${DISK_NAME}2"

if [ $SWAP -eq 1 ]
then
	mkswap "${DISK_NAME}3"
	swapon "${DISK_NAME}3"
fi

partprobe $DISK_NAME # inform system about partition changes

# mount
mount "${DISK_NAME}2" /mnt
if [ $BOOT_MODE -eq 1 ]
then
    mkdir -p /mnt/efi
    mount "${DISK_NAME}1" /mnt/efi
fi

# bootstraping
if [ $BOOT_MODE -eq 0 ]
then
	pacstrap /mnt base linux linux-firmware grub dhcpcd vim
else
	pacstrap /mnt base linux linux-firmware grub dhcpcd vim efibootmgr
fi

genfstab -U /mnt >> /mnt/etc/fstab

IN_CHROOT="ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime\n
hwclock --systohc\n
echo LANG=fr_FR.UTF-8 >> /etc/locale.conf\n
export LANG=fr_FR.UTF-8\n
echo KEYMAP=fr >> /etc/vconsole.conf\n
locale-gen\n
echo linux >> /etc/hostname\n
echo \"127.0.0.1		localhost\" >> /etc/hosts\n
echo \"::1			localhost\" >> /etc/hosts\n
echo \"127.0.1.1		linux.localdomain	linux\" >> /etc/hosts\n
echo -e \"root\\nroot\" | (passwd root)\n
if [ $BOOT_MODE = 0 ]\n
then\n
grub-install --target=i386-pc \"${DISK_NAME}\"\n
else\n
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=\"Arch Linux\"\n
fi\n
grub-mkconfig -o /boot/grub/grub.cfg\n
exit\n"

# create script to execute in chroot
echo -e $IN_CHROOT > /mnt/in_chroot.sh

# add execution to script
chmod +x /mnt/in_chroot.sh

# chroot and exec in it
arch-chroot /mnt ./in_chroot.sh