#!/bin/bash

# Kontrollér om nødvendige værktøjer er installeret
for cmd in whiptail curl jq lsblk pacman reflector grub-install grub-mkconfig mkinitcpio; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Fejl: $cmd er ikke installeret. Installer det ved hjælp af din pakkehåndterer."
        exit 1
    fi
done

# Funktion til at vælge root password
choose_root_password() {
    local rootpw
    while true; do
        rootpw=$(whiptail --title "Root Adgangskode" --passwordbox "Indtast root adgangskode:" 10 60 3>&1 1>&2 2>&3)
        local rootpw_confirm=$(whiptail --title "Root Adgangskode" --passwordbox "Bekræft root adgangskode:" 10 60 3>&1 1>&2 2>&3)
        if [ "$rootpw" = "$rootpw_confirm" ]; then
            echo "root:$rootpw" | chpasswd
            break
        else
            whiptail --title "Fejl" --msgbox "Adgangskoderne stemmer ikke overens. Prøv igen." 10 60
        fi
    done
}

# Funktion til BIOS-installation
install_bios() {
    lsblk -do NAME,MODEL,SIZE
    local drive=$(whiptail --title "Vælg Drev" --inputbox "Indtast drev (f.eks. /dev/sda):" 10 60 "/dev/sda" 3>&1 1>&2 2>&3)
    
    # Bekræft valg
    whiptail --title "Bekræft Drev" --msgbox "Du har valgt $drive. GRUB vil blive installeret på dette drev." 10 60

    echo "Installerer GRUB på $drive..."
    grub-install --target=i386-pc "$drive"
    if [ $? -ne 0 ]; then
        whiptail --title "Fejl" --msgbox "GRUB-installationen på $drive mislykkedes. Kontroller drev og prøv igen." 10 60
        exit 1
    fi
}

# Funktion til EFI-installation
install_efi() {
    lsblk -do NAME,MODEL,SIZE
    whiptail --title "Installer EFI" --msgbox "Installerer efibootmgr..." 10 60
    pacman -S --noconfirm efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    if [ $? -ne 0 ]; then
        whiptail --title "Fejl" --msgbox "GRUB-installationen i EFI-tilstand mislykkedes. Kontroller EFI-mappen og prøv igen." 10 60
        exit 1
    fi
}

# Funktion til at vælge drev og mount partitioner
partition_and_mount() {
    local drive=$(whiptail --title "Vælg Drev" --inputbox "Indtast drev (f.eks. /dev/sda):" 10 60 "/dev/sda" 3>&1 1>&2 2>&3)
    local filesystem=$(whiptail --title "Vælg Filsystem" --menu "Vælg filsystem til root partition:" 15 60 4 \
        "ext4" "EXT4 Filsystem" \
        "btrfs" "BTRFS Filsystem" \
        "xfs" "XFS Filsystem" \
        "f2fs" "F2FS Filsystem" 3>&1 1>&2 2>&3)
    
    whiptail --title "Partionering og Formatering" --msgbox "Drev $drive vil blive partitioneret og formateret med $filesystem." 10 60

    # Slet alle partitioner
    sgdisk -Z "$drive"
    
    # Opret ny partitionstabel og root partition
    sgdisk -n 1:0:+512M -t 1:ef00 "$drive"  # EFI partition
    sgdisk -n 2:0:0 -t 2:8300 "$drive"      # Root partition
    
    # Formater partitionerne
    mkfs.fat -F32 "${drive}1"
    mkfs."$filesystem" "${drive}2"
    
    # Mount partitionerne
    mount "${drive}2" /mnt
    mkdir -p /mnt/boot/efi
    mount "${drive}1" /mnt/boot/efi
}

# Funktion til at vælge tidszone
choose_timezone() {
    local timezone=$(whiptail --title "Vælg Tidszone" --inputbox "Indtast din tidszone (f.eks. Europe/Copenhagen):" 10 60 "Europe/Copenhagen" 3>&1 1>&2 2>&3)
    timedatectl list-timezones | grep "$timezone" &> /dev/null
    if [ $? -eq 0 ]; then
        ln -sf /usr/share/zoneinfo/"$timezone" /etc/localtime
    else
        whiptail --title "Fejl" --msgbox "Tidszonen kunne ikke findes. Kontrollér tidszonen og prøv igen." 10 60
        exit 1
    fi
}

# Funktion til at generere lokaliteter
generate_locales() {
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "en_US ISO-8859-1" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
}

# Funktion til at konfigurere tastaturlayout
set_keymap() {
    local keymap=$(whiptail --title "Vælg Tastaturlayout" --inputbox "Indtast tastaturlayout (f.eks. en_US):" 10 60 "en_US" 3>&1 1>&2 2>&3)
    echo "KEYMAP=$keymap" > /etc/vconsole.conf
}

# Funktion til at aktivere parallel downloads i pacman.conf
configure_pacman() {
    sed -i 's/#ParallelDownloads/ParallelDownloads/g' /etc/pacman.conf
    echo "[multilib]" >> /etc/pacman.conf
    echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
}

# Funktion til at konfigurere reflector
configure_reflector() {
    whiptail --title "Konfigurer Reflector" --msgbox "Konfigurerer reflector for at bruge HTTPS-protokollen med tyske spejle..." 10 60
    reflector --protocol https --country 'DE'
}

# Funktion til at installere pakker
install_packages() {
    whiptail --title "Installer Pakker" --msgbox "Installerer nødvendige pakker..." 10 60
    pacstrap /mnt base linux linux-firmware networkmanager grub sudo
}

# Funktion til at vælge og konfigurere hostname
configure_hostname() {
    local hostname=$(whiptail --title "Vælg Værtsnavn" --inputbox "Indtast værtsnavn:" 10 60 "archlinuxvm" 3>&1 1>&2 2>&3)
    echo "$hostname" > /mnt/etc/hostname
    echo "127.0.0.1 localhost" > /mnt/etc/hosts
    echo "::1 localhost" >> /mnt/etc/hosts
    echo "127.0.1.1 $hostname.localdomain $hostname" >> /mnt/etc/hosts
}

# Funktion til at aktivere systemtjenester
enable_services() {
    whiptail --title "Aktivér Tjenester" --msgbox "Aktiverer nødvendige systemtjenester..." 10 60
    arch-chroot /mnt systemctl enable NetworkManager
}

# Funktion til at oprette GRUB-konfiguration
create_grub_config() {
    whiptail --title "Opret GRUB Konfiguration" --msgbox "Opretter GRUB konfiguration..." 10 60
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    if [ $? -ne 0 ]; then
        whiptail --title "Fejl" --msgbox "Oprettelsen af GRUB-konfigurationen mislykkedes. Kontroller GRUB og prøv igen." 10 60
        exit 1
    fi
}

# Funktion til at konfigurere mkinitcpio
configure_mkinitcpio() {
    whiptail --title "Konfigurér mkinitcpio" --msgbox "Konfigurerer mkinitcpio..." 10 60
    arch-chroot /mnt mkinitcpio -P
}

# Funktion til at oprette bruger
create_user() {
    local user=$(whiptail --title "Opret Bruger" --inputbox "Indtast brugernavn:" 10 60 "arch" 3>&1 1>&2 2>&3)
    local userpw
    while true; do
        userpw=$(whiptail --title "Opret Bruger" --passwordbox "Indtast brugerens adgangskode:" 10 60 3>&1 1>&2 2>&3)
        local userpw_confirm=$(whiptail --title "Opret Bruger" --passwordbox "Bekræft brugerens adgangskode:" 10 60 3>&1 1>&2 2>&3)
        if [ "$userpw" = "$userpw_confirm" ]; then
            arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$user"
            echo "$user:$userpw" | arch-chroot /mnt chpasswd
            break
        else
            whiptail --title "Fejl" --msgbox "Adgangskoderne stemmer ikke overens. Prøv igen." 10 60
        fi
    done
    sed -i 's/# %wheel/%wheel/g' /mnt/etc/sudoers
}

# Funktion til at køre demenu
run_dmenu() {
    if [ -x "./demenu.sh" ]; then
        arch-chroot /mnt ./demenu.sh
    else
        whiptail --title "Fejl" --msgbox "Filen demenu.sh blev ikke fundet eller er ikke eksekverbar." 10 60
        exit 1
    fi
}

# Hovedscript
choose_root_password
partition_and_mount

if [ -d "/sys/firmware/efi/efivars" ]; then
    install_efi
else
    install_bios
fi

choose_timezone
generate_locales
set_keymap
configure_pacman
configure_reflector
install_packages
configure_hostname
enable_services
create_grub_config
configure_mkinitcpio
create_user
run_dmenu

whiptail --title "Installation Fuldført" --msgbox "Installation er fuldført. Genstart systemet for at fuldføre opsætningen." 10 60
