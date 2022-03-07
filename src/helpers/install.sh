function download_latest_arch_iso() {
    latest_iso=$(
        curl -s "$img_download_page" |
        grep -e '<a href="archlinux-.*\.iso">' |
        head -1 |
        sed -r -e 's/^.*<a href="(archlinux-.*\.iso)">.*/\1/'
    )

    if [ ! -f "$latest_iso" ]; then
        echo -e "${GREEN}Downloading the latest Arch Linux ISO image${NORMAL}"
        rm -f archlinux*.iso
        curl -o "${latest_iso}" "${img_download_page}/${latest_iso}"
        ln -sf "$latest_iso" "$isofile"
    else
        echo -e "${GREEN}Latest Arch Linux image already downloaded${NORMAL}"
    fi
}

function create_disk_image() {
    # Create a backing COW image
    # qemu-img create -o backing_file="$imgfile",backing_fmt=raw -f qcow2 img1.cow

    if [ ! -f "$imgfile" ]; then
        echo -e "${GREEN}Creating base disk image${NORMAL}"
        qemu-img create -f raw "$imgfile" $disk_size
    else
        echo -e "${RED}The base disk image file $imgfile already exists.${NORMAL}"
        echo -e "${RED}Remove it and re-run this script if you intend to run a new fresh installation.${NORMAL}"
    fi
}

function _get_ssh_key_name() {
    keyfiles=$(cat <<EOF
id_rsa
id_dsa
id_ecdsa
id_ed25519
id_xmss
EOF
)

    while IFS= read -r keyfile; do
        k="$HOME/.ssh/$keyfile"
        if [ -f "$k" ]; then
            echo "$k"
            return
        fi
    done <<< "$keyfiles"

    echo -e "${RED}Can't find a valid SSH key under $HOME/.ssh${NORMAL}"
    exit 1
}

function install_os() {
    ssh_keyfile="$(_get_ssh_key_name)"
    ssh_pubkey="$(cat "$ssh_keyfile.pub")"
    ssh_privkey="$(cat "$ssh_keyfile")"
    imgdir="$(cd "$(dirname "$imgfile")" && pwd)"
    logfile="$imgdir/install.log"
    pkgfile="$imgdir/PKGLIST"
    post_install_script="$imgdir/post-install.sh"
    post_install=
    packages=$(cat <<EOF
sudo
curl
wget
dhcpcd
net-tools
netctl
openssh
EOF
)

    if [ -f "$pkgfile" ]; then
        packages="$packages
$(cat "$pkgfile")"
    fi

    [ -f "$post_install_script" ] && post_install="$(cat "$post_install_script")"
    echo -e "${GREEN}Installing base operating system${NORMAL}"
    echo -e "\tISO image: $isofile"
    echo -e "\tDisk file: $imgfile"
    echo -e "\tLog file: $logfile"

    echo "--- Log started at $(date)" > "$logfile"
    expect <<EOF | tee -a "$logfile"
        set prompt "*@archiso*~*#* "
        set chroot_prompt "*root@archiso* "
        set timeout -1
        spawn qemu-system-$architecture \
            -cdrom "$isofile" \
            -boot d \
            -cpu host \
            -enable-kvm \
            -m $memory \
            -smp 2 \
            -nographic \
            -drive file=$imgfile,format=raw

        match_max 100000

        # Pass the console boot options
        # and wait for the system to boot
        expect "*Arch Linux install*"
        send -- "\t"
        expect "*archisobasedir*"
        send -- " console=ttyS0,38400\r"
        expect "archiso login: "
        send -- "root\r"
        expect \$prompt

        # Partition the disk
        send -- "fdisk /dev/sda\r"
        expect "Command (m for help): "
        send -- "n\r"
        expect "Select (default p): "
        send -- "p\r"
        expect "Partition number (1-4, default 1): "
        send -- "\r"
        expect "First sector*: "
        send -- "\r"
        expect "Last sector*: "
        send -- "\r"
        expect "Command (m for help): "
        send -- "a\r"
        expect "Command (m for help): "
        send -- "w\r"
        expect \$prompt

        # Create and mount the filesystem
        send -- "mkfs.ext4 /dev/sda1\r"
        expect \$prompt
        send -- "mount /dev/sda1 /mnt\r"
        expect \$prompt

        # Install the system
        send -- "pacstrap /mnt base linux linux-firmware archlinux-keyring\r"
        expect \$prompt

        # Generate the fstab file
        send -- "genfstab -U /mnt >> /mnt/etc/fstab\r"
        expect \$prompt

        # chroot to the newly installed system
        send -- "arch-chroot /mnt\r"
        expect \$chroot_prompt

        # Set the timezone and sync the clock
        send -- "ln -sf /usr/share/zoneinfo/$timezone /etc/localtime\r"
        expect \$chroot_prompt
        send -- "hwclock --systohc\r"
        expect \$chroot_prompt

        # Configure localization
        send -- "echo $locale UTF-8 >> /etc/locale.gen\r"
        expect \$chroot_prompt
        send -- "locale-gen\r"
        expect \$chroot_prompt
        send -- "echo LANG=en_US.UTF-8 > /etc/locale.conf\r"
        expect \$chroot_prompt

        # Set the hostname
        send -- "echo $hostname > /etc/hostname\r"
        expect \$chroot_prompt

        # Generate /etc/hosts
        send -- "echo -e '127.0.0.1  localhost\\n::1  localhost' >> /etc/hosts\r"
        expect \$chroot_prompt

        # Generate the initpcio
        send -- "mkinitcpio -P\r"
        expect \$chroot_prompt

        # Update the keyring
        # This may currently currently take a long time
        # see https://www.reddit.com/r/archlinux/comments/rbjbcr/pacman_keyring_update_taking_too_long/
        send -- "pacman-key --init\r"
        expect \$chroot_prompt
        send -- "pacman-key --populate archlinux\r"
        expect \$chroot_prompt
        send -- "pacman-key --refresh-keys\r"
        expect \$chroot_prompt

        # As a workaround, you can temporarily disable signature check on pacman.conf
        #send -- "cp /etc/pacman.conf /etc/pacman.conf.orig\r"
        #expect \$chroot_prompt
        #send -- "sed -i /etc/pacman.conf -r -e 's/^(SigLevel\\\\s*=\\\\s*).*$/\\\\1 Never/g'\r"
        #expect \$chroot_prompt

        # Install extra packages
        send -- {echo "$packages" | pacman -S --noconfirm -}
        send -- "\r"
        expect \$chroot_prompt

        # Install syslinux
        send -- "pacman -S --noconfirm syslinux\r"
        expect \$chroot_prompt
        send -- "syslinux-install_update -i -a -m\r"
        #expect \$chroot_prompt
        #send -- "dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/bios/mbr.bin of=/dev/sda\r"
        expect \$chroot_prompt
        send -- "sed -i /boot/syslinux/syslinux.cfg -e '1i SERIAL 0 115200'\r"
        expect \$chroot_prompt
        send -- "sed -i /boot/syslinux/syslinux.cfg -e 's|APPEND root=/dev/sda3|APPEND console=tty0 console=ttyS0,115200 root=/dev/sda1|g'\r"
        expect \$chroot_prompt

        # Restore the original pacman.conf
        send -- "mv /etc/pacman.conf.orig /etc/pacman.conf\r"
        expect \$chroot_prompt

        # Set the root password
        send -- "passwd\r"
        expect "New password: "
        send -- "$root_password\r"
        expect "Retype new password: "
        send -- "$root_password\r"
        expect \$chroot_prompt

        # Create a non-admin user
        send -- "useradd -d /home/$username -m $username\r"
        expect \$chroot_prompt
        send -- "passwd $username\r"
        expect "New password: "
        send -- "$user_password\r"
        expect "Retype new password: "
        send -- "$user_password\r"
        expect \$chroot_prompt

        # Enable the dhcpcd service
        send -- "ln -sf /usr/lib/systemd/system/dhcpcd.service /etc/systemd/system/multi-user.target.wants/dhcpcd.service\r"
        expect \$chroot_prompt

        # Enable and configure the SSH daemon
        send -- "ln -sf /usr/lib/systemd/system/sshd.service /etc/systemd/system/multi-user.target.wants/sshd.service\r"
        expect \$chroot_prompt
        send -- "cat <<_EOF_ >> /etc/ssh/sshd_config
RSAAuthentication yes
PubkeyAuthentication yes
_EOF_
"

        expect \$chroot_prompt

        # Copy the user SSH key
        send -- "mkdir -p /home/$username/.ssh\r"
        expect \$chroot_prompt
        send -- {echo "$ssh_pubkey" >> "/home/$username/.ssh/authorized_keys"}
        send -- "\r"
        expect \$chroot_prompt
        send -- {echo "$ssh_privkey" > "/home/$username/.ssh/$(basename $ssh_keyfile)"}
        send -- "\r"
        expect \$chroot_prompt
        send -- {chmod 0600 "/home/$username/.ssh/$(basename $ssh_keyfile)"}
        send -- "\r"
        expect \$chroot_prompt
        send -- {echo "$ssh_pubkey" > "/home/$username/.ssh/$(basename $ssh_keyfile).pub"}
        send -- "\r"
        expect \$chroot_prompt
        send -- {chown -R $username "/home/$username/.ssh"}
        send -- "\r"
        expect \$chroot_prompt

        # Run any post-install scripts
        send -- {$post_install}
        send -- "\r"
        expect \$chroot_prompt

        # Clear the pacman cache
        send -- "rm -rf /var/cache/pacman/pkg/*\r"
        expect \$chroot_prompt

        # Exit and shutdown
        send -- "exit\r"
        expect \$prompt
        send -- "umount /mnt\r"
        expect \$prompt
        send -- "shutdown -h now\r"
        expect eof

        system {echo -e "\n${GREEN}Arch Linux system installed under ${imgfile}${NORMAL}"}
EOF

    echo "--- Log closed at $(date)" >> "$logfile"
}

