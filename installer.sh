#!/bin/bash

# WARNING: THIS SCRIPT USES RELATIVE FILE PATHS SO IT MUST BE RUN FROM THE SAME WORKING DIRECTORY AS THE CLONED REPO

# Function declaration

# Message displayed to user at start
greeting(){
    echo
    echo "Welcome to SimplyArch Installer v2"
    echo "Copyright (C) The SimplyArch Authors"
    echo
    echo "DISCLAIMER: THE SOFTWARE IS PROVIDED ""AS IS"", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED"
    echo
    echo "WARNING: MAKE SURE TO TYPE CORRECTLY BECAUSE THE SCRIPT WON'T PERFORM INPUT VALIDATIONS"
    echo
    echo "We'll guide you through the Arch Linux installation process"
    echo
}

# Check whether UEFI or not
check_uefi(){
    if [[ -d /sys/firmware/efi ]]
    then
        uefi_host=1
        echo
        echo "Detected UEFI system..."
        sleep 3
    else
        uefi_host=0
        echo
        echo "Detected Legacy system..."
        sleep 3
    fi
}

# Language & Keyboard setup
locales(){
    echo
    echo "1. Language & Keyboard Setup"
    echo
    echo "HINT: write en_US for English US (don't add .UTF-8)"
    echo
    read -p "> System Language: " language
    # If no input from user then default to en_US
    if [[ -z "$language" ]]
	then
		language="en_US"
	fi
    echo
    echo "EXAMPLES: us United States | us-acentos US Intl | latam Latin American Spanish | es Spanish"
    echo
    read -p "> Keyboard Distribution: " keyboard
    # If no input from user then default to us keyboard
    if [[ -z "$keyboard" ]]
	then
		keyboard="us"
	fi
    # Load selected keyboard distribution
    loadkeys "$keyboard"
}

# Account setup
user_accounts(){
    echo
    echo "2. User Accounts"
    echo
    read -p "> Choose a hostname for this computer: " hostname
    # If no input from user then default to archlinux
    if [[ -z "$hostname" ]]
	then
		hostname="archlinux"
	fi
	echo
	echo "Administrator User"
	echo "User: root"
	read -sp "> Password: " root_password
	echo
	read -sp "> Re-type password: " root_password2
	echo
	while [[ "$root_password" != "$root_password2" ]]
	do
		echo
		echo "Passwords don't match. Try again"
		echo
		read -sp "> Password: " root_password
		echo
		read -sp "> Re-type password: " root_password2
		echo
	done
	echo
	echo "Standard User"
	read -p "> User: " user
	export user
	read -sp "> Password: " user_password
	echo
	read -sp "> Re-type password: " user_password2
	echo
	while [[ "$user_password" != "$user_password2" ]]
	do
		echo
		echo "Passwords don't match. Try again"
		echo
		read -sp "> Password: " user_password
		echo
		read -sp "> Re-type password: " user_password2
		echo
	done
}

# Disk setup
disks(){
    echo "3. Disks Setup"
	echo
	echo "Make sure to have your disk previously partitioned, if you are unsure re-run this script when done"
    echo
    echo "HINT: you can use cfdisk, fdisk, parted or the tool of your preference"
    echo "For reference partition layouts check out the Arch Wiki entry at https://bit.ly/3m4I33p"
	echo
    echo "Your current partition table:"
    echo
    lsblk
    echo
    read -p "> Do you want to continue? (Y/N): " prompt
    if [[ "$prompt" == "y" || "$prompt" == "Y" || "$prompt" == "yes" || "$prompt" == "Yes" ]]
    then
        clear
        echo "3. Disks Setup"
        while ! [[ "$filesystem" =~ ^(1|2)$ ]]
        do
            echo
            echo "Choose a filesystem for your root partition:"
            echo
            echo "1. EXT4 (the preferred choice for most users)"
            echo "2. BTRFS (a FS with built-in snapshot functionality)"
            echo
            read -p "> Filesystem (1-2): " filesystem
        done
        clear
        echo "3. Disks Setup"
        echo
        echo "Your current partition table:"
        echo
        lsblk
        echo
        echo "Write the name of the partition e.g: /dev/sdaX /dev/nvme0n1pX"
        read -p "> Root partition: " root_partition
        case "$filesystem" in
            1)
                mkfs.ext4 "$root_partition"
                mount "$root_partition" /mnt
                ;;
            2)
                mkfs.btrfs -f -L "Arch Linux" "$root_partition"
                mount "$root_partition" /mnt
                btrfs sub cr /mnt/@
                umount "$root_partition"
                mount -o relatime,space_cache=v2,compress=lzo,subvol=@ "$root_partition" /mnt
                mkdir /mnt/boot
                ;;
        esac
        clear
        # Adapt to user's system accordingly
        case "$uefi_host" in
            0)
                # Use GRUB for Legacy users
                bootloader=1
                ;;
            1)
                echo "3. Disks Setup"
                echo
                echo "Your current partition table:"
                echo
                lsblk
                echo
                echo "Write the name of the partition e.g: /dev/sdaX /dev/nvme0n1pX"
                read -p "> EFI partition: " efi_partition
                echo
                echo "HINT: If you're dualbooting another OS type N otherwise Y"
                read -p "> Do you want to format this EFI partition as FAT32? (Y/N): " format_efi
                if [[ "$format_efi" == "y" || "$format_efi" == "Y" || "$format_efi" == "yes" || "$format_efi" == "Yes" ]]
                then
                    mkfs.fat -F32 "$efi_partition"
                fi
                mkdir -p /mnt/boot/efi
                mount "$efi_partition" /mnt/boot/efi
                echo
                clear
                echo "3. Disks Setup"
                while ! [[ "$bootloader" =~ ^(1|2)$ ]] 
                do
                    echo
                    echo "Choose a bootloader for your system:"
                    echo
                    echo "1. GRUB (the preferred choice for most users)"
                    echo "2. systemd-boot (for systemd enjoyers)"
                    echo
                    read -p "> Bootloader (1-2): " bootloader
                done
                ;;
        esac
        echo "3. Disks Setup"
        echo
        echo "Your current partition table:"
        echo
        lsblk
        echo
        echo "HINT: If you don't want to use a Swap partition type N below"
        echo
        echo "Write the name of the partition e.g: /dev/sdaX /dev/nvme0n1pX"
        read -p "> Swap partition: " swap
        if [[ "$swap" == "n" || "$swap" == "N" || "$swap" == "no" || "$swap" == "No" ]]
        then
            echo
            echo "Swap partition not selected"
            sleep 1
        else
            mkswap "$swap"
            swapon "$swap"
        fi
    else
        echo
        echo "Installer aborted..."
        exit
    fi
}

# Run reflector and fetch the 10 fastests mirrors
update_mirrors(){
    echo
    echo "Updating mirrors, this can take a while..."
    echo
    reflector --verbose --latest 10 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
}

# Install an AUR helper
aur_installer(){
    while ! [[ "$aur_helper" =~ ^(1|2|3)$ ]]
    do
    echo
    echo "4. AUR Installer"
    echo
    echo "Choose an AUR helper for your system:"
    echo
    echo "1. Yay"
    echo "2. Paru"
    echo "3. No AUR helper"
    echo
    read -p "> AUR helper (1-3): " aur_helper
    done
    case "$aur_helper" in
        1)
            clear
            echo
            echo "4. AUR Installer"
            echo
            echo "Installing Yay..."
            echo
            echo "cd && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si --noconfirm && cd && rm -rf yay-bin" | arch-chroot /mnt /bin/bash -c "su $user"
            ;;
        2)
            clear
            echo
            echo "4. AUR Installer"
            echo
            echo "Installing Paru..."
            echo
            echo "cd && git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si --noconfirm && cd && rm -rf paru-bin" | arch-chroot /mnt /bin/bash -c "su $user"
            ;;
    esac
}

# Performs the actual system install
arch_installer(){
    # Install the base packages
    case "$uefi_host" in
        0)
            pacstrap /mnt base base-devel linux linux-firmware linux-headers grub os-prober sudo bash-completion networkmanager nano reflector xdg-user-dirs
            ;;
        1)
            case "$bootloader" in
            1)
                pacstrap /mnt base base-devel linux linux-firmware linux-headers grub efibootmgr os-prober sudo bash-completion networkmanager nano reflector xdg-user-dirs
                ;;
            2)
                pacstrap /mnt base base-devel linux linux-firmware linux-headers sudo bash-completion networkmanager nano reflector xdg-user-dirs
                ;;
            esac
            ;;
    esac
    # Generate fstab with UUID
    genfstab -U /mnt >> /mnt/etc/fstab
    # Set language
    echo "$language.UTF-8 UTF-8" > /mnt/etc/locale.gen
	arch-chroot /mnt /bin/bash -c "locale-gen"
	echo "LANG=$language.UTF-8" > /mnt/etc/locale.conf
    # Set keyboard
    echo "KEYMAP=$keyboard" > /mnt/etc/vconsole.conf
    # Auto-detect timezone
    arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/$(curl https://ipapi.co/timezone) /etc/localtime"
	arch-chroot /mnt /bin/bash -c "hwclock --systohc"
    # Enable multilib
	sed -i '93d' /mnt/etc/pacman.conf
	sed -i '94d' /mnt/etc/pacman.conf
	sed -i "93i [multilib]" /mnt/etc/pacman.conf
	sed -i "94i Include = /etc/pacman.d/mirrorlist" /mnt/etc/pacman.conf
    # Enable Pacman easter egg
    sed -i 's/#Color/Color' /mnt/etc/pacman.conf
    sed -i '34i ILoveCandy' /mnt/etc/pacman.conf
    # Set hostname
    echo "$hostname" > /mnt/etc/hostname
	echo "127.0.0.1	localhost" > /mnt/etc/hosts
	echo "::1		localhost" >> /mnt/etc/hosts
	echo "127.0.1.1	$hostname.localdomain	$hostname" >> /mnt/etc/hosts
    # Install bootloader
    case "$uefi_host" in
    0)
        arch-chroot /mnt /bin/bash -c "grub-install --target=i386-pc ${root_partition::-1}"
        ;;
    1)
        case "$bootloader" in
        1)
            arch-chroot /mnt /bin/bash -c "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch"
            ;;
        2)
            arch-chroot /mnt /bin/bash -c "bootctl --path=/boot/efi install"
            ;;
        esac
        ;;
    esac
    # Enable Network Manager
	arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager.service"
	# Set root user password
	arch-chroot /mnt /bin/bash -c "(echo $root_password ; echo $root_password) | passwd root"
	# Setup user
	arch-chroot /mnt /bin/bash -c "useradd -m -G wheel $user"
	arch-chroot /mnt /bin/bash -c "(echo $user_password ; echo $user_password) | passwd $user"
	arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
	arch-chroot /mnt /bin/bash -c "xdg-user-dirs-update"
    # Update mirrors for installer system
    clear
    update_mirrors
    # AUR installer
    clear
    aur_installer
}

goodbye(){
    echo
    echo "Thank you for using SimplyArch Installer!"
    echo
    echo "Installation finished successfully"
    echo
    read -p "> Would you like to reboot your computer? (Y/N): " prompt
    if [[ "$prompt" == "y" || "$prompt" == "Y" || "$prompt" == "yes" || "$prompt" == "Yes" ]]
    then
        echo
        echo "System will reboot in a moment..."
		sleep 3
		clear
		umount -a
		reboot
    else
        exit
    fi
}

# Execution

clear
greeting
read -p "> Do you want to continue? (Y/N): " prompt
if [[ "$prompt" == "y" || "$prompt" == "Y" || "$prompt" == "yes" || "$prompt" == "Yes" ]]
then
    clear
    check_uefi
    clear
    locales
    clear
    user_accounts
    clear
    disks
    clear
    update_mirrors
    clear
    arch_installer
    clear
    goodbye
else
    echo
    echo "Installer aborted..."
    exit
fi
