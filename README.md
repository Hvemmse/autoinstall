# Autoinstall

Install script from the Arch Wiki for install on a pc with bios and Uefi boot in danish language.

Download a fresh iso from archlinux, after boot of the archiso run this codes in the shell

<code>loadkeys dk</code> as danish if it is your keybordlayout for installation
  
for the right keyboard setup

<code>pacman -Sy git</code>

to install git and update pacman mirrorlist

<code>git clone https://github.com/Hvemmse/autoinstall</code>

To get the files from the project.

<code>cd autoinstall</code>
<code>sh starthere</code>
After the script is done are you in the arch-chainroot run this code in the shell

<code>sh install</code>

Type at password for root accound and after the script is done, exit and reboot ...... 

enjoy a Arch linux enviroment with Cinnamon, xfce, gnome, kde or qtile

Download arch iso from here 

https://archlinux.org/download/

Update 2023 as a new option therw are 2 new versions. fullautoinstall.sh and autoinstall.sh

This Script are a form for autoinstall with this parametre. 

RootPW:	arch
default user: arch
userPw: arch

Default install /dev/sda

Hostname: archlinuxvm

bootloader uefi or bios GTP but grub

use.

<code>chmod +x fullautoinstall.sh</code>
<code>./fullautoinstall.sh</code>

<code>chmod +x autoinstall.sh</code>
<code>./fullautoinstall.sh</code>

















