# archinstalldanish

Install script from the Arch Wiki for install on a pc with bios and Uefi boot in danish language.

Download a fresh iso from archlinux, after boot of the archiso run this codes in the shell

<code>loadkeys dk</code>
  
for the right keyboard setup

<code>pacman -Sy git</code>

to install git and update pacman mirrorlist

<code>git clone https://github.com/Hvemmse/archinstalldanish</code>

To get the files from the project.

<code>cd archinstalldanish</code>
<code>sh starthere</code>
After the script is done are you in the arch-chainroot run this code in the shell

<code>sh install</code>

Type at password for root accound and after the script is done, exit and reboot ...... 

enjoy a Arch linux danish enviroment with ligthdm greeter and cinnemon, nemo, gnome-terminal. Edit the packagefile in the project for you own packages.
