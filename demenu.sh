#!/bin/bash
# Bash Menu Script Example

PS3='Vælg Desktop enviroment: '
options=("Cinnamon" "Kde" "Gnome" "Qtile" "Xfce4" "Afslut")
select opt in "${options[@]}"
do
    case $opt in
        "Cinnamon")
            echo "Cinnamon"
            ./cinnamon
            ;;
        "Kde")
            echo "Kde"
            ./kde
            ;;
        "Gnome")
            echo "$opt"
            ./gnome
            ;;
        "Qtile")
            echo "$opt"
            ./qtile
            ;;
        "Xfce4")
            echo "xfce"
            ./cfxe4
            ;;       
        "Afslut")
            break
            ;;
        *) echo "Dette er ikke en mulighed $REPLY";;
    esac
done
