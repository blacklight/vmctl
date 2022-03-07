# vmctl

`vmctl` is a script that automates the installation, provisioning and
management of Arch Linux virtual machines.

## Dependencies

- `qemu`
- `curl`
- `expect`

## Installation

Just copy the `vmctl` script anywhere in your `PATH`, or clone the repository
and create a symbolic link to `vmctl` in your `PATH`.

## Usage

### Install an Arch Linux virtual machine

The `vmctl install` command can be used to create an Arch Linux virtual machine
on the fly, wherever you are. It does the following:

- It downloads the latest Arch Linux installer ISO image if none was downloaded
  or a new one is available.
- It creates a `qemu` disk file.
- It boots a new KVM that uses the ISO file as as CDROM and automates the
  installation of Arch Linux in the virtual machine (no user prompt required).
- It can install extra packages and run custom post-installation provisioning scripts.

```text
Usage: vmctl install [-o <output-disk-image>] [-a <architecture>] [-s <disk-size>]
        [-m <memory>] [-h <hostname>] [-P <root-password>] [-u <non-root-username>]
        [-p <non-root-user-password>] [-z <timezone>] [-l <locale>] [-M <arch-mirror-url>]

-o      <output-disk-image>             Path of the output disk image (default: ./arch.img)
-a      <architecture>                  Target architecture (default: x86_64)
-s      <disk-size>                     Disk size (default: 8G)
-m      <memory>                        RAM size in KB (default: 2048)
-h      <hostname>                      VM hostname (default: qemu)
-P      <root-password>                 Root password. If not specified it will be prompted
-u      <non-root-username>             Username for the main non-root user
-p      <non-root-user-password>        Password for the non-root user. If not specified it will be prompted
-z      <timezone>                      System timezone (default: UTC)
-l      <locale>                        System locale (default: en_US.UTF-8)
-M      <arch-mirror-url>               Arch Linux download mirror URL (default: http://mirror.cj2.nl/archlinux/iso/latest/)
                                        Consult https://archlinux.org/download/ for a full list of the available download mirrors.
```

If a required option is not specified on the command line then it will be
interactively prompted to the user (defaults are available for most of the
options).

Non-interactive example:

```bash
vmctl install \
    -h my_vm \
    -a x86_64 \
    -s 16G \
    -m 2048 \
    -P root \
    -u myuser \
    -p password \
    -z Europe/Amsterdam \
    -o arch-base.img
```

If you want to install an extra list of packages besides the default ones, then
specify them in a file named `PKGLIST` in the same directory as the disk image file.

If you want to run a custom post-installation script after the core system has been
installed, then create a custom script named `post-install.sh` in the same directory
as the disk image file.

#### Notes

The keyring population process may currently (as of March 2022) take a long time.
This is a [known issue](https://www.reddit.com/r/archlinux/comments/rbjbcr/pacman_keyring_update_taking_too_long/).

### Resize an existing image

```bash
qemu-img resize "$imgfile" +10G
```

### Create a COW (Copy-On-Write) image on top of a disk image

```bash
qemu-img create -o backing_file="$imgfile",backing_fmt=raw -f qcow2 img1.cow
```

This is particularly useful if you want to have a "base" image and several customized
images built on it.

### Convert a raw qemu image to a VirtualBox

```bash
qemu-img convert -O vdi disk.img disk.vdi
```
