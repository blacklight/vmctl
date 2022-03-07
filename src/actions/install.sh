export default_imgfile=arch.img
export default_architecture=x86_64
export default_disk_size=8G
export default_memory=2048
export default_hostname=qemu
export default_root_password=root
export default_username=user
export default_user_password=password
export default_timezone=UTC
export default_locale=en_US.UTF-8
export default_img_download_page='http://mirror.cj2.nl/archlinux/iso/latest/'
export isofile=archlinux-latest.iso

imgfile=
architecture=
disk_size=
memory=
hostname=
root_password=
username=
user_password=
timezone=
locale="$default_locale"
img_download_page="$default_img_download_page"

function usage() {
    echo "Install an Arch Linux system on a QEMU disk image"
    echo
    echo "Usage: $(basename "$0") install [-o <output-disk-image>] [-a <architecture>] [-s <disk-size>]"
    echo -e "\t[-m <memory>] [-h <hostname>] [-P <root-password>] [-u <non-root-username>]"
    echo -e "\t[-p <non-root-user-password>] [-z <timezone>] [-l <locale>] [-M <arch-mirror-url>]"
    echo
    echo -e "-o <output-disk-image>\t\tPath of the output disk image (default: ./arch.img)"
    echo -e "-a <architecture>\t\tTarget architecture (default: x86_64)"
    echo -e "-s <disk-size>\t\t\tDisk size (default: 8G)"
    echo -e "-m <memory>\t\t\tRAM size in KB (default: 2048)"
    echo -e "-h <hostname>\t\t\tVM hostname (default: qemu)"
    echo -e "-P <root-password>\t\tRoot password. If not specified it will be prompted"
    echo -e "-u <non-root-username>\t\tUsername for the main non-root user"
    echo -e "-p <non-root-user-password>\tPassword for the non-root user. If not specified it will be prompted"
    echo -e "-z <timezone>\t\t\tSystem timezone (default: UTC)"
    echo -e "-l <locale>\t\t\tSystem locale (default: en_US.UTF-8)"
    echo -e "-M <arch-mirror-url>\t\tArch Linux download mirror URL (default: http://mirror.cj2.nl/archlinux/iso/latest/)"
    echo -e "\t\t\t\tConsult https://archlinux.org/download/ for a full list of the available download mirrors."
    echo
    echo "If you want to install an extra list of packages besides the default ones, then"
    echo "specify them in a file named PKGLIST in the same directory as the disk image file."
    echo
    echo "If you want to run a custom post-installation script after the core system has been"
    echo "installed, then create a custom script named post-install.sh in the same directory as"
    echo "the disk image file".
    exit 1
}


optstring=':o:a:s:m:h:P:u:p:z:l:M:'
[[ "$1" == '--help' ]] && usage

while getopts ${optstring} arg; do
    case ${arg} in
        o) imgfile="${OPTARG}";;
        a) architecture="${OPTARG}";;
        s) disk_size="${OPTARG}";;
        m) memory="${OPTARG}";;
        h) hostname="${OPTARG}";;
        P) root_password="${OPTARG}";;
        u) username="${OPTARG}";;
        p) user_password="${OPTARG}";;
        z) timezone="${OPTARG}";;
        l) locale="${OPTARG}";;
        M) img_download_page="${OPTARG}";;
        ?)
            echo "Invalid option: -${OPTARG}" >&2
            usage;;
    esac
done

[ -z "$imgfile" ] && read -p "Output disk image file [$default_imgfile]: " imgfile
[ -z "$architecture" ] && read -p "Architecture [$default_architecture]: " architecture
[ -z "$disk_size" ] && read -p "Disk size [$default_disk_size]: " disk_size
[ -z "$memory" ] && read -p "Memory in KB [$default_memory]: " memory
[ -z "$hostname" ] && read -p "Hostname [$default_hostname]: " hostname
[ -z "$root_password" ] && read -sp "Root password [$default_root_password]: " root_password && echo
[ -z "$username" ] && read -p "Non-admin username [$default_username]: " username
[ -z "$user_password" ] && read -sp "Non-admin user password [$default_user_password]: " user_password && echo
[ -z "$timezone" ] && read -p "Timezone [$default_timezone]: " timezone
[ -z "$locale" ] && read -p "Locale [$default_locale]: " locale

for var in imgfile \
    architecture \
    disk_size \
    memory \
    hostname \
    root_password \
    username \
    user_password \
    timezone \
    locale
    do
        default_var=default_$var
        [ -z "${!var}" ] && declare ${var}=${!default_var}
        export $var
    done

source "$srcdir/helpers/install.sh"
download_latest_arch_iso
create_disk_image
install_os

