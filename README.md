# qemu-arch-linux-automation

Scripts and playbooks to automate the installation, configuration and
management of Arch Linux VMs in qemu.

## Dependencies

- `qemu`
- `curl`
- `expect`

## Installation

- Add the path to the `src` directory to your `PATH` environment variable
- Create a symbolic link to `src/` directory to your `PATH` environment variable

## Usage

### Install an Arch Linux virtual machine

```text
Usage: qemu-arch install [-o <output-disk-image>] [-a <architecture>] [-s <disk-size>]
        [-m <memory>] [-h <hostname>] [-P <root-password>] [-u <non-root-username>]
        [-p <non-root-user-password>] [-z <timezone>] [-l <locale>] [-M <arch-mirror-url>]

-o <output-disk-image>          Path of the output disk image (default: ./arch.img)
-a <architecture>               Target architecture (default: x86_64)
-s <disk-size>                  Disk size (default: 8G)
-m <memory>                     RAM size in KB (default: 2048)
-h <hostname>                   VM hostname (default: qemu)
-P <root-password>              Root password. If not specified it will be prompted
-u <non-root-username>          Username for the main non-root user
-p <non-root-user-password>     Password for the non-root user. If not specified
                                it will be prompted
-z <timezone>                   System timezone (default: UTC)
-l <locale>                     System locale (default: en_US.UTF-8)
-M <arch-mirror-url>            Arch Linux download mirror URL
                                (default: http://mirror.cj2.nl/archlinux/iso/latest/)
                                Consult https://archlinux.org/download/ for a
                                full list of the available download mirrors.
```

If you want to install an extra list of packages besides the default ones, then
specify them in a file named `PKGLIST` in the same directory as the disk image file.

If you want to run a custom post-installation script after the core system has been
installed, then create a custom script named `post-install.sh` in the same directory
as the disk image file.

#### Notes

The keyring population process may currently (as of March 2022) take a long time.
This is a [known issue](https://www.reddit.com/r/archlinux/comments/rbjbcr/pacman_keyring_update_taking_too_long/).

As a workaround, if you want to speed up the OS installation process, you can
temporarily disable pacman keyring checks upon package installation by
uncommenting the relevant lines in `src/helpers/install.sh` (function:
`install_os`).

### Resizing an existing image

```bash
qemu-img resize "$imgfile" +10G
```

### Create a COW (Copy-On-Write) image on top of a disk image

```bash
qemu-img create -o backing_file="$imgfile",backing_fmt=raw -f qcow2 img1.cow
```

This is particularly useful if you want to have a "base" image and several customized
images built on it.
