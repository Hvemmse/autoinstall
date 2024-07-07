#!/bin/bash

# Funktion til at hente og vise drevvalg
choose_drive() {
    drives=$(lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT -nr)
    menu_items=()
    while read -r line; do
        name=$(echo $line | awk '{print $1}')
        size=$(echo $line | awk '{print $2}')
        fstype=$(echo $line | awk '{print $3}')
        mountpoint=$(echo $line | awk '{print $4}')
        menu_items+=("$name" "$size $fstype $mountpoint")
    done <<< "$drives"
    selected_drive=$(whiptail --title "Drev liste" --menu "Vælg et drev til installation:" 20 78 10 "${menu_items[@]}" 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
        echo "$selected_drive"
    else
        echo "Ingen drev valgt." >&2
        exit 1
    fi
}

# Indhent brugernavn
username=$(whiptail --inputbox "Indtast dit ønskede brugernavn:" 8 39 --title "Brugernavn" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    echo "Brugernavn blev ikke angivet." >&2
    exit 1
fi

# Indhent root password
root_password=$(whiptail --passwordbox "Indtast root password:" 8 39 --title "Root Password" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    echo "Root password blev ikke angivet." >&2
    exit 1
fi

# Indhent password
password=$(whiptail --passwordbox "Indtast dit ønskede password:" 8 39 --title "Password" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    echo "Password blev ikke angivet." >&2
    exit 1
fi

# Vælg drev til installation
drive=$(choose_drive)

# Indhent sprog
language=$(whiptail --inputbox "Indtast ønsket sprog (f.eks. da_DK.UTF-8):" 8 39 --title "Sprog" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    echo "Sprog blev ikke angivet." >&2
    exit 1
fi

# Indhent tidszone
timezone=$(whiptail --inputbox "Indtast ønsket tidszone (f.eks. Europe/Copenhagen):" 8 39 --title "Tidszone" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    echo "Tidszone blev ikke angivet." >&2
    exit 1
fi

# Formater og monter det valgte drev
mkfs.ext4 /dev/"$drive"
mount /dev/"$drive" /mnt

# Installer basispakkerne
pacstrap /mnt base linux linux-firmware

# Generer fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot ind i det nye system og konfigurer
arch-chroot /mnt /bin/bash <<EOF
# Sæt tidszonen
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc

# Lokaliseringsindstillinger
echo "LANG=$language" > /etc/locale.conf
echo "$language UTF-8" >> /etc/locale.gen
locale-gen

# Sæt hostname
echo "archlinux" > /etc/hostname

# Hosts file
cat <<EOL > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   archlinux.localdomain archlinux
EOL

# Opsæt root password
echo "root:$root_password" | chpasswd

# Opret brugeren og opsæt password
useradd -m -G wheel $username
echo "$username:$password" | chpasswd

# Giv sudo rettigheder
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Installer og konfigurer GRUB
pacman --noconfirm -S grub
grub-install --target=i386-pc /dev/"$drive"
grub-mkconfig -o /boot/grub/grub.cfg

# Installer NetworkManager
pacman --noconfirm -S networkmanager
systemctl enable NetworkManager
EOF

# Afmontér drevet
umount -R /mnt

echo "Installation færdig. Du kan nu genstarte systemet."
