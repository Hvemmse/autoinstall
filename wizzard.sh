#!/bin/bash

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "whiptail is not installed. Please install it and run the script again."
    exit 1
fi

# Get username
USERNAME=$(whiptail --inputbox "Please enter your username:" 8 39 --title "Username Input" 3>&1 1>&2 2>&3)

# Get password
PASSWORD=$(whiptail --passwordbox "Please enter your password:" 8 39 --title "Password Input" 3>&1 1>&2 2>&3)

# Select disk
DISK=$(whiptail --radiolist "Please select the disk to use:" 15 50 4 \
"/dev/sda" "Disk 1" ON \
"/dev/sdb" "Disk 2" OFF \
"/dev/sdc" "Disk 3" OFF \
"/dev/sdd" "Disk 4" OFF 3>&1 1>&2 2>&3)

# Select timezone
TIMEZONE=$(whiptail --menu "Please select your timezone:" 15 50 4 \
"UTC" "Coordinated Universal Time" \
"Europe/Copenhagen" "Copenhagen" \
"America/New_York" "New York" \
"Asia/Tokyo" "Tokyo" 3>&1 1>&2 2>&3)

# Confirmation
whiptail --title "Confirmation" --yesno "Please confirm the following details:\n\nUsername: $USERNAME\nPassword: (hidden)\nDisk: $DISK\nTimezone: $TIMEZONE\n\nIs this correct?" 15 60

if [ $? -eq 0 ]; then
    echo "Starting installation..."
else
    echo "User cancelled the setup."
    exit 1
fi

# Partition and format the disk using MBR
echo "Partitioning and formatting the disk..."
parted $DISK --script mklabel msdos
parted $DISK --script mkpart primary ext4 1MiB 100%
mkfs.ext4 "${DISK}1"
mount "${DISK}1" /mnt

# Install base system with sudo package
echo "Installing base system with pacstrap..."
pacstrap /mnt base linux linux-firmware sudo

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Copy resolv.conf for network configuration in chroot
cp /etc/resolv.conf /mnt/etc/resolv.conf

# Chroot into the new system to configure it
arch-chroot /mnt /bin/bash <<EOF
# Set the timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "archlinux" > /etc/hostname

# Add hosts entries
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   archlinux.localdomain archlinux
HOSTS

# Set root password
echo "root:rootpassword" | chpasswd

# Create user
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Allow wheel group to use sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Install and configure GRUB bootloader
pacman -S --noconfirm grub
grub-install --target=i386-pc $DISK
grub-mkconfig -o /boot/grub/grub.cfg
EOF

# Check if GRUB configuration was successful
if [ $? -eq 0 ]; then
    echo "GRUB installation and configuration successful."
else
    echo "GRUB installation failed."
    exit 1
fi

echo "Installation complete! Please reboot."
