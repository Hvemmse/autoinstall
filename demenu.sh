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
            break
            ;;
        "Kde")
            echo "Kde"
            ./kde
            break
            ;;
        "Gnome")
            echo "$opt"
            ./gnome
            break
            ;;
        "Qtile")
            echo "$opt"
            ./qtile
            break
            ;;
        "Xfce4")
            echo "xfce"
            ./xfce4
			break
            ;;       
        "Afslut")
            break
            ;;
        *) echo "Dette er ikke en mulighed $REPLY";;
    esac
done
