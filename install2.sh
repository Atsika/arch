arch-chroot /mnt /bin/bash << EOC

ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime

hwclock --systohc

locale-gen

echo "LANG=fr_FR.UTF-8" >> /etc/locale.conf

echo "KEYMAP=fr" >> /etc/vconsole.conf

echo "linux" >> /etc/hostname

echo "127.0.0.1		localhost" >> /etc/hosts
echo "::1		localhost" >> /etc/hosts
echo "127.0.1.1		linux.localdomain	linux" >> /etc/hosts

echo -e "root\nroot" | (passwd root)

pacman -S grub

grub-install "${diskname}1"

grub-mkconfig -o /boot/grub/grub.cfg

EOC