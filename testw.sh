#!/bin/bash

# Kontrollér om nødvendige værktøjer er installeret
for cmd in whiptail curl lsblk; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Fejl: $cmd er ikke installeret. Installer det ved hjælp af din pakkehåndterer."
        exit 1
    fi
done

# Funktion til at hente offentlig IP-adresse
get_ip() {
    curl -s ifconfig.me
}

# Funktion til at finde tidszone baseret på IP-adresse
get_timezone() {
    local ip="$1"
    local timezone=$(curl -s "http://ipinfo.io/${ip}/timezone" | jq -r .timezone)
    echo "${timezone:-"None"}"  # Returnerer "None" hvis ingen tidszone kan bestemmes
}

# Funktion til at vise en menu til at vælge tidszone
select_timezone() {
    local selected_timezone=$(whiptail --title "Vælg Tidszone" --menu "Vælg din tidszone:" 15 60 4 \
        "America/New_York" "Eastern Time" \
        "Europe/Copenhagen" "Central European Time" \
        "Asia/Tokyo" "Tokyo Time" \
        "Australia/Sydney" "Sydney Time" 3>&1 1>&2 2>&3)
    echo "${selected_timezone:-"Europe/Copenhagen"}"  # Default til CET hvis ingen valg
}

# Funktion til at liste drev og vælge et drev
select_drive() {
    # Liste drev og filtrere for at vise kun drev (uden partitioner)
    local drives=$(lsblk -d -n -o NAME,SIZE | awk '{print "/dev/" $1 " " $2}')
    
    # Hvis der ikke er nogen drev, vis en fejlmeddelelse
    if [ -z "$drives" ]; then
        whiptail --title "Fejl" --msgbox "Ingen drev blev fundet. Kontroller din hardware." 10 60
        exit 1
    fi
    
    # Konverter drev liste til Whiptail-menu format
    local drive_menu=$(echo "$drives" | awk '{print "/dev/" $1 " " $2}')
    
    local selected_drive=$(whiptail --title "Vælg Drev" --menu "Vælg eller indtast dit drev:" 15 60 10 $(echo "$drive_menu") "custom" "Brugerdefineret Drev" 3>&1 1>&2 2>&3)

    if [ "$selected_drive" = "custom" ]; then
        selected_drive=$(whiptail --title "Brugerdefineret Drev" --inputbox "Indtast dit drev:" 10 60 3>&1 1>&2 2>&3)
    fi

    echo "${selected_drive:-"/dev/sda"}"  # Default til "/dev/sda" hvis ingen valg
}

# Funktion til at vælge filsystem
select_filesystem() {
    local selected_filesystem=$(whiptail --title "Vælg Filsystem" --menu "Vælg det ønskede filsystem:" 15 60 4 \
        "ext4" "EXT4" \
        "xfs" "XFS" \
        "btrfs" "Btrfs" \
        "ntfs" "NTFS" 3>&1 1>&2 2>&3)

    echo "${selected_filesystem:-"ext4"}"  # Default til "ext4" hvis ingen valg
}

# Funktion til at få en adgangskode og bekræfte den
get_password() {
    local password1
    local password2

    while true; do
        password1=$(whiptail --title "Adgangskode" --passwordbox "Indtast din adgangskode:" 10 60 3>&1 1>&2 2>&3)
        password2=$(whiptail --title "Bekræft Adgangskode" --passwordbox "Bekræft din adgangskode:" 10 60 3>&1 1>&2 2>&3)

        if [ "$password1" != "$password2" ]; then
            whiptail --title "Fejl" --msgbox "Adgangskoderne matcher ikke. Prøv igen." 10 60
        else
            break
        fi
    done

    #echo "$password1"
}

# Spørg om installationparametre med Whiptail
username=$(whiptail --title "Brugernavn" --inputbox "Indtast dit brugernavn:" 10 60 3>&1 1>&2 2>&3)

# Få og verificer adgangskode
password=$(get_password)

# Vælg drev (med mulighed for brugerdefineret drev)
drive=$(select_drive)

# Vælg filsystem
filesystem=$(select_filesystem)

# Vælg sprog
language=$(whiptail --title "Sprog" --menu "Vælg dit sprog:" 15 60 4 \
    "en" "Engelsk" \
    "da" "Dansk"  \
    "de" "Tysk"  \
    "fr" "Fransk" 3>&1 1>&2 2>&3)

# Vælg tastatur-layout
keyboard=$(whiptail --title "Tastatur-layout" --menu "Vælg dit tastatur-layout:" 15 60 4 \
    "us" "US Layout" \
    "dk" "Dansk Layout" \
    "de" "Tysk Layout" \
    "fr" "Fransk Layout"  3>&1 1>&2 2>&3)

# Hent brugerens IP-adresse
ip_address=$(get_ip)

# Kontrollér om IP-adressen blev hentet
if [ -z "$ip_address" ]; then
    whiptail --title "Fejl" --msgbox "Kunne ikke hente IP-adresse. Kontroller din internetforbindelse." 10 60
    exit 1
fi

# Få tidszone baseret på IP-adressen
timezone=$(get_timezone "${ip_address}")

# Hvis tidszonen ikke kunne bestemmes, lad brugeren vælge manuelt
if [ "$timezone" = "None" ]; then
    timezone=$(select_timezone)
fi

# Bekræft valg med Whiptail
whiptail --title "Bekræft" --msgbox "Du har valgt:\n\nBrugernavn: $username\nAdgangskode: [Skjult]\nDrev: $drive\nFilsystem: $filesystem\nSprog: $language\nTastatur-layout: $keyboard\nTidszone: $timezone" 15 60
