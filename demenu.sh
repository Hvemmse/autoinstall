#!/bin/bash
# 

clear
PS3='Choice your Desktop Enviroment: '
options=("Cinnamon" "Kde" "Gnome" "Qtile" "Xfce4" "Fluxbox" "Openbox" "Exit")
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
         "Fluxbox")
            echo "fluxbox"
            chmod +x fluxbox
	    ./fluxbox
			break
            ;;
	"Openbox")
            echo "Openbox"
            chmod +x openbox
	    ./openbox
			break
            ;;
            "Lxqt")
            echo "Lxqt"
            chmod +x lxqt
	    ./lxqt
			break
	    ;;"Exit")
            break
            ;;
        *) echo "This is not an Option $REPLY";;
    esac
done
