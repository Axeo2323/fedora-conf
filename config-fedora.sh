#! /usr/bin/env bash

###VARIABLES###
RPMFUSIONCOMP="rpmfusion-free-appstream-data rpmfusion-nonfree-appstream-data rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted"
CODEC="gstreamer1-plugins-base gstreamer1-plugins-good gstreamer1-plugins-bad-free gstreamer1-plugins-good-extras gstreamer1-plugins-bad-free-extras gstreamer1-plugins-ugly-free gstreamer1-plugin-libav gstreamer1-plugins-ugly libdvdcss gstreamer1-plugin-openh264"
LOGFILE="/tmp/config-fedora.log"
DNFVERSION="$(readlink $(which dnf))"
FC0=$(rpm -E %fedora)
FC1=$(($FC0 + 1))
###END VARIABLES###



###FUNCTIONS###
check_cmd()
{
if [[ $? -eq 0 ]]
then
    	echo -e "\033[32mOK\033[0m"
else
    	echo -e "\033[31mERROR\033[0m"
fi
}

check_repo_file()
{
	if [[ -e "/etc/yum.repos.d/$1" ]]
	then
		return 0
	else
		return 1
	fi
}

check_pkg()
{
	rpm -q "$1" > /dev/null
}
add_pkg()
{
	dnf install -y --nogpgcheck "$1" >> "$LOGFILE" 2>&1
}

del_pkg()
{
	if [[ "${DNFVERSION}" == "dnf-3" ]]
	then
		dnf autoremove -y "$1" >> "$LOGFILE" 2>&1
	fi
	if [[ "${DNFVERSION}" == "dnf5" ]]
	then
		dnf remove -y "$1" >> "$LOGFILE" 2>&1
	fi
}
swap_pkg()
{
	dnf swap -y "$1" "$2" --allowerasing > /dev/null 2>&1
}
check_flatpak()
{
	flatpak info "$1" > /dev/null 2>&1
}
add_flatpak()
{
	flatpak install flathub --noninteractive -y "$1" > /dev/null 2>&1
}
del_flatpak()
{
	flatpak uninstall --noninteractive -y "$1" > /dev/null && flatpak uninstall --unused  --noninteractive -y > /dev/null
}
check_copr()
{
	if [[ ${DNFVERSION} == "dnf-3" ]]
	then
		COPR_ENABLED=$(dnf copr list --enabled | grep -c "$1")
	fi
	if [[ ${DNFVERSION} == "dnf5" ]]
	then
		COPR_ENABLED=$(dnf copr list | grep -v '(disabled)' | grep -c "$1")
	fi
	return $COPR_ENABLED
}
add_copr()
{
	dnf copr enable -y "$1" > /dev/null 2>&1
}

refresh_cache()
{
	dnf check-update --refresh fedora-release > /dev/null 2>&1
}
refresh_cache_testing()
{
	dnf check-update --enablerepo=*updates-testing fedora-release > /dev/null 2>&1
}
check_updates_rpm()
{
	yes n | dnf upgrade
}
check_updates_testing_rpm()
{
	yes n | dnf upgrade --enablerepo=*updates-testing
}
check_updates_flatpak()
{
	yes n | flatpak update
}

need_reboot()
{
	if [[ ${DNFVERSION} == "dnf-3" ]]
	then
		needs-restarting -r >> "$LOGFILE" 2>&1
		NEEDRESTART="$?"
	fi
	if [[ ${DNFVERSION} == "dnf5" ]]
	then
		dnf needs-restarting -r >> "$LOGFILE" 2>&1
		NEEDRESTART="$?"
	fi
	return $NEEDRESTART
}
ask_reboot()
{
	echo -n -e "\033[5;33m/\ NEED REBOOT\033[0m\033[33m : Reboot Now ? [y/N] : \033[0m"
	read rebootuser
	rebootuser=${rebootuser:-n}
	if [[ ${rebootuser,,} == "y" ]]
	then
		echo -e "\n\033[0;35m Reboot via systemd ... \033[0m"
		sleep 2
		systemctl reboot
		exit
	fi
	if [[ ${rebootuser,,} == "k" ]]
	then
		kexec_reboot
	fi
}

kexec_reboot()
{
	echo -e "\n\033[1;4;31mEXPERIMENTAL :\033[0;35m Reboot via kexec ... \033[0m"	
	LASTKERNEL=$(rpm -q kernel --qf "%{INSTALLTIME} %{VERSION}-%{RELEASE}.%{ARCH}\n" | sort -nr | awk 'NR==1 {print $2}')
	kexec -l /boot/vmlinuz-$LASTKERNEL --initrd=/boot/initramfs-$LASTKERNEL.img --reuse-cmdline
	sleep 0.5
	# kexec -e
	systemctl kexec
	exit
}

ask_maj()
{
	echo -n -e "\n\033[36mUpdate Now ? [y/N] : \033[0m"
	read startupdate
	startupdate=${startupdate:-n}
	echo ""
	if [[ ${startupdate,,} == "y" ]]
	then
		bash "$0"
	fi
}

upgrade_fc()
{
	CHECKFCRELEASE="https://dl.fedoraproject.org/pub/fedora/linux/releases"
	if [[ "$1" = "beta" ]]
	then
		CHECKFCRELEASE="https://dl.fedoraproject.org/pub/fedora/linux/development"
	fi

	if curl --fail -s --output /dev/null $CHECKFCRELEASE/$FC1
	then
		echo "Lancement de l'upgrade $FC0 -> $FC1"
		if dnf system-upgrade --releasever=$FC1 download
		then
			dnf system-upgrade reboot
		else
			echo -e "\033[31mERROR. Abort! \033[0m"
			exit 3;
		fi
	else
		echo -e "\033[33m$FC1 version is unstable. Abort! \033[0m"
		exit 4;
	fi
}
###END FUNCTIONS###



###SCRIPT START###

#verif
if [[ -z "$1" ]]
then
	echo "OK" > /dev/null
elif [[ "$1" == "check" ]] || [[ "$1" == "testing" ]] || [[ "$1" == "upgrade" ]] || [[ "$1" == "scriptupdate" ]]
then
	echo "OK" > /dev/null
else
	echo "Incorrect usage :"
	echo "- $(basename $0)              : Launch config and/or updates"
	echo "- $(basename $0) check        : Verify availables updates and upgrade"
	echo "- $(basename $0) testing      : Verify availables testing updates"
	echo "- $(basename $0) upgrade      : Launch an upgrade to a new Fedora release"
	echo "- $(basename $0) scriptupdate : Update the script"
	exit 1;
fi

# Upgrade Fedora
if [[ "$1" = "upgrade" ]]
then
	upgrade_fc $2
fi

# Script Update
if [[ "$1" = "scriptupdate" ]]
then
	echo $0
	wget -O- https://raw.githubusercontent.com/axeo2323/fedora-config/refs/heads/main/config-fedora.sh > "$0"
	chmod +x "$0"

	wget -O- -q https://raw.githubusercontent.com/axeo2323/fedora-config/refs/heads/main/CHANGELOG.txt | head

	exit 0;
fi

# Root check
if [[ $(id -u) -ne "0" ]]
then
	echo -e "\033[31mERROR\033[0m Launch the script with Root Privilege (su - root or sudo)"
	exit 1;
fi

# Fedora Version check
if ! check_pkg fedora-release-workstation
then
	echo -e "\033[31mERROR\033[0m You need Fedora Workstation (GNOME) to launch this script !"
	exit 2;
fi

# Infos log file
echo -e "\033[36m"
echo "If you want to follow the update : tail -f $LOGFILE"
echo -e "\033[0m"

# Date dans le log
echo '-------------------' >> "$LOGFILE"
date >> "$LOGFILE"



###PROGRAM###
ICI=$(dirname "$0")

#CHECK-UPDATE
if [[ "$1" = "check" ]]
then
	echo -n "01- - Cache refresh : "
	refresh_cache
	check_cmd

	echo "02- - RPM updates availables : "
	check_updates_rpm

	echo "03- - FLATPAK updates availables : "
	check_updates_flatpak

	ask_maj

	exit;
fi

#CHECK-UPDATES-TESTING
if [[ "$1" = "testing" ]]
then
	echo -n "01- - Cache refresh : "
	refresh_cache_testing
	check_cmd
	
	echo "02- - RPM TESTING updates availables : "
	check_updates_testing_rpm

	echo -e "\n \033[36mWARNING : Testing updates not availables with this script ! To upgrade a testing packages : " 
	echo -e "         dnf upgrade --enablerepo=*updates-testing package1 package2 \033[0m \n"

	exit;
fi

### CONF DNF
echo "01- Vérification configuration DNF"
if [[ $(grep -c 'max_parallel_downloads=' /etc/dnf/dnf.conf) -lt 1 ]]
then
	echo -n "- - - Correction parallel download : "
	echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
	check_cmd
fi
if [[ $(grep -c 'countme=' /etc/dnf/dnf.conf) -lt 1 ]]
then
	echo -n "- - - Correction stat : "
	echo "countme=false" >> /etc/dnf/dnf.conf
	check_cmd
fi
if [[ $(grep -c 'deltarpm=' /etc/dnf/dnf.conf) -lt 1 ]]
then
        echo -n "- - - Correction deltarpm on false : "
        echo "deltarpm=false" >> /etc/dnf/dnf.conf
        check_cmd
fi

echo -n "- - - Cache refresh : "
refresh_cache
check_cmd

if ! check_pkg "dnf-utils"
then
	echo -n "- - - Install dnf-utils : "
	add_pkg "dnf-utils"
	check_cmd
fi

#UPDATE RPM
echo -n "02- DNF system update : "
dnf update -y >> "$LOGFILE" 2>&1
check_cmd


#UPDATE FP
echo -n "03- FLATPAK system update : "
flatpak update --noninteractive >> "$LOGFILE"  2>&1
check_cmd

#Check if reboot needed
if ! need_reboot
then
	ask_reboot
fi

### CONFIG REPO
echo "04- Repository check"

#COPR FACETIMEHD (FOR MACBOOK)
#if check_copr 'frgt10/facetimehd-dkms'
#then
#	echo -n "- - - Activation COPR frgt10/facetimehd-dkms : "
#	add_copr "frgt10/facetimehd-dkms"
#	check_cmd
#fi

## RPMFUSION
if ! check_pkg rpmfusion-free-release
then
	echo -n "- - - Install RPM Fusion Free : "
	add_pkg "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
	check_cmd
fi
if ! check_pkg rpmfusion-nonfree-release
then
	echo -n "- - - Install RPM Fusion Nonfree : "
	add_pkg "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
	check_cmd
fi

## VIVALDI
if ! check_repo_file vivaldi.repo
then
	echo -n "- - - Install Vivaldi Repo : "
	echo "[vivaldi]
	name=vivaldi
	baseurl=https://repo.vivaldi.com/archive/rpm/x86_64
	enabled=1
	gpgcheck=1
	gpgkey=http://repo.vivaldi.com/archive/linux_signing_key.pub" 2>/dev/null > /etc/yum.repos.d/vivaldi.repo
	check_cmd
	sed -e 's/\t//g' -i /etc/yum.repos.d/vivaldi.repo
fi

## MICROSOFT
if ! check_repo_file microsoft-prod.repo
then
	echo -n "- - - Install Microsoft Prod Repo : "
	echo "[packages-microsoft-com-pro]
	name=Microsoft Production
	baseurl=https://packages.microsoft.com/rhel/9/prod/
	enabled=1
	gpgcheck=1
	gpgkey=https://packages.microsoft.com/keys/microsoft.asc" 2>/dev/null > /etc/yum.repos.d/microsoft-prod.repo
	check_cmd
	sed -e 's/\t//g' -i /etc/yum.repos.d/microsoft-prod.repo
fi

## FLATHUB
if [[ $(flatpak remotes | grep -c flathub) -ne 1 ]]
then
	echo -n "- - - Install Flathub : "
	flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null
	check_cmd
fi

## RPM FUSION DEPENDS
echo "05- Check RPM Fusion Dependancies"
for p in $RPMFUSIONCOMP
do
	if ! check_pkg "$p"
	then
		echo -n "- - - Install RPM Fusion $p dependancies : "
		add_pkg "$p"
		check_cmd
	fi
done



### SWAPPING SOFT 
echo "06- Check swapping dependancies"

## FFMPEG
if check_pkg "ffmpeg-free"
then
	echo -n "- - - Swapping ffmpeg : "
	swap_pkg "ffmpeg-free" "ffmpeg" 
	check_cmd
fi

## MESA-VA
#if check_pkg "mesa-va-drivers"
#then
#	echo -n "- - - Swapping MESA VAAPI : "
#	swap_pkg "mesa-va-drivers" "mesa-va-drivers-freeworld"
#	check_cmd
#fi

## MESA-VDPAU
#if check_pkg "mesa-vdpau-drivers"
#then
#	echo -n "- - - Swapping MESA VDPAU : "
#	swap_pkg "mesa-vdpau-drivers" "mesa-vdpau-drivers-freeworld"
#	check_cmd
#fi

## INSTALL CODECS
echo "07- Check CoDec"
for p in $CODEC
do
	if ! check_pkg "$p"
	then
		echo -n "- - - Installing CoDec $p : "
		add_pkg "$p"
		check_cmd
	fi
done

### INSTALL GNOME TWEAKS
echo "08- Check GNOME dependancies"
while read -r line
do
	if [[ "$line" == add:* ]]
	then
		p=${line#add:}
		if ! check_pkg "$p"
		then
			echo -n "- - - Installing GNOME dependancies $p : "
			add_pkg "$p"
			check_cmd
		fi
	fi
	
	if [[ "$line" == del:* ]]
	then
		p=${line#del:}
		if check_pkg "$p"
		then
			echo -n "- - - Removing GNOME dependancies $p : "
			del_pkg "$p"
			check_cmd
		fi
	fi
done < "$ICI/gnome.list"

### INSTALL/REMOVE RPMS WITH LIST
echo "09- RPM packages management"
while read -r line
do
	if [[ "$line" == add:* ]]
	then
		p=${line#add:}
		if ! check_pkg "$p"
		then
			echo -n "- - - Installing package $p : "
			add_pkg "$p"
			check_cmd
		fi
	fi
	
	if [[ "$line" == del:* ]]
	then
		p=${line#del:}
		if check_pkg "$p"
		then
			echo -n "- - - Removing package $p : "
			del_pkg "$p"
			check_cmd
		fi
	fi
done < "$ICI/packages.list"


### INSTALL/REMOVE FLATPAK WITH LIST
echo "10- FLATPAK MANAGEMENT"
while read -r line
do
	if [[ "$line" == add:* ]]
	then
		p=${line#add:}
		if ! check_flatpak "$p"
		then
			echo -n "- - - Installing flatpak $p : "
			add_flatpak "$p"
			check_cmd
		fi
	fi
	
	if [[ "$line" == del:* ]]
	then
		p=${line#del:}
		if check_flatpak "$p"
		then
			echo -n "- - - Removing flatpak $p : "
			del_flatpak "$p"
			check_cmd
		fi
	fi
done < "$ICI/flatpak.list"



###SYSTEM CONFIG
echo "11- System custom configuration"
SYSCTLFIC="/etc/sysctl.d/sio.conf"
if [[ ! -e "$SYSCTLFIC" ]]
then
	echo -n "- - - Adding a file $SYSCTLFIC : "
	touch "$SYSCTLFIC"
	check_cmd
fi
if [[ $(grep -c 'vm.swappiness' "$SYSCTLFIC") -lt 1 ]]
then
	echo -n "- - - Config swapiness at 10 : "
	echo "vm.swappiness = 10" >> "$SYSCTLFIC"
	check_cmd
fi
if [[ $(grep -c 'kernel.sysrq' "$SYSCTLFIC") -lt 1 ]]
then
	echo -n "- - - Config sysrq at 1 : "
	echo "kernel.sysrq = 1" >> "$SYSCTLFIC"
	check_cmd
fi

if ! check_pkg "pigz"
then
	echo -n "- - - Installing pigz : "
	add_pkg "pigz"
	check_cmd
fi
if [[ ! -e /usr/local/bin/gzip ]]
then
	echo -n "- - - Config gzip multithread : "
	ln -s /usr/bin/pigz /usr/local/bin/gzip
	check_cmd
fi
if [[ ! -e /usr/local/bin/gunzip ]]
then
	echo -n "- - - Config gunzip multithread : "
	ln -s /usr/local/bin/gzip /usr/local/bin/gunzip
	check_cmd
fi
if [[ ! -e /usr/local/bin/zcat ]]
then
	echo -n "- - - Config zcat multithread : "
	ln -s /usr/local/bin/gzip /usr/local/bin/zcat
	check_cmd
fi


if ! check_pkg "lbzip2"
then
	echo -n "- - - Installing lbzip2 : "
	add_pkg "lbzip2"
	check_cmd
fi
if [[ ! -e /usr/local/bin/bzip2 ]]
then
	echo -n "- - - Config bzip2 multithread : "
	ln -s /usr/bin/lbzip2 /usr/local/bin/bzip2
	check_cmd
fi
if [[ ! -e /usr/local/bin/bunzip2 ]]
then
	echo -n "- - - Config bunzip2 multithread : "
	ln -s /usr/local/bin/bzip2 /usr/local/bin/bunzip2
	check_cmd
fi
if [[ ! -e /usr/local/bin/bzcat ]]
then
	echo -n "- - - Config bzcat multithread : "
	ln -s /usr/local/bin/bzip2 /usr/local/bin/bzcat
	check_cmd
fi

#Check reboot needed
if ! need_reboot
then
	ask_reboot
fi