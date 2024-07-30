#!/bin/bash

# Kontrollér om nødvendige værktøjer er installeret
for cmd in whiptail curl jq lsblk pacman reflector; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Fejl: $cmd er ikke installeret. Installer det ved hjælp af din pakkehåndterer."
        exit 1
    fi
done

# Funktion til at vælge root password
choose_root_password() {
    local password=$(whiptail --title "Root Adgangskode" --passwordbox "Indtast root adgangskode:" 10 60 3>&1 1>&2 2>&3)
    echo "root:$password" | chpasswd
}

# Funktion til BIOS-installation
install_bios() {
    lsblk -do NAME,MODEL,SIZE
    local drive=$(whiptail --title "Vælg Drev" --inputbox "Indtast drev (f.eks. /dev/sda):" 10 60 "/dev/sda" 3>&1 1>&2 2>&3)
    echo "Installerer GRUB på $drive..."
    grub-install --target=i386-pc "$drive"
}

# Funktion til EFI-installation
install_efi() {
    lsblk -do NAME,MODEL,SIZE
    whiptail --title "Installer EFI" --msgbox "Installerer efibootmgr..." 10 60
    pacman -S --noconfirm efibootmgr
    grub-install --target=x86_64-efi --efi-directory=boot/efi --bootloader-id=GRUB
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
    pacman -Sy --noconfirm networkmanager pulseaudio pavucontrol sudo git
}

# Funktion til at vælge og konfigurere hostname
configure_hostname() {
    local hostname=$(whiptail --title "Vælg Værtsnavn" --inputbox "Indtast værtsnavn:" 10 60 "archlinuxvm" 3>&1 1>&2 2>&3)
    echo "$hostname" > /etc/hostname
    echo "127.0.0.1 localhost" > /etc/hosts
    echo "::1 localhost" >> /etc/hosts
    echo "127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts
}

# Funktion til at aktivere systemtjenester
enable_services() {
    whiptail --title "Aktivér Tjenester" --msgbox "Aktiverer nødvendige systemtjenester..." 10 60
    systemctl enable NetworkManager
}

# Funktion til at oprette GRUB-konfiguration
create_grub_config() {
    whiptail --title "Opret GRUB Konfiguration" --msgbox "Opretter GRUB konfiguration..." 10 60
    grub-mkconfig -o /boot/grub/grub.cfg
}

# Funktion til at konfigurere mkinitcpio
configure_mkinitcpio() {
    whiptail --title "Konfigurér mkinitcpio" --msgbox "Konfigurerer mkinitcpio..." 10 60
    mkinitcpio -P
}

# Funktion til at oprette bruger
create_user() {
    local user=$(whiptail --title "Opret Bruger" --inputbox "Indtast brugernavn:" 10 60 "arch" 3>&1 1>&2 2>&3)
    local userpw=$(whiptail --title "Opret Bruger" --passwordbox "Indtast brugerens adgangskode:" 10 60 3>&1 1>&2 2>&3)
    useradd -m -G wheel -s /bin/bash "$user"
    echo "$user:$userpw" | chpasswd
    sed -i 's/# %wheel/%wheel/g' /etc/sudoers
}

# Funktion til at køre demenu
run_dmenu() {
    if [ -x "./demenu.sh" ]; then
        ./demenu.sh
    else
        whiptail --title "Fejl" --msgbox "Filen demenu.sh blev ikke fundet eller er ikke eksekverbar." 10 60
        exit 1
    fi
}

# Hovedscript
choose_root_password

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
