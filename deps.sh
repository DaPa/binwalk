#!/bin/bash

# Check for the --yes command line argument to skip yes/no prompts
if [ "$1" = "--yes" ]
then
    YES=1
else
    YES=0
fi

set -o nounset

REQUIRED_UTILS="wget tar python"
APTCMD="apt-get"
YUMCMD="yum"
APT_CANDIDATES="git build-essential libqt4-opengl mtd-utils gzip bzip2 tar arj lhasa p7zip p7zip-full cabextract cramfsprogs cramfsswap squashfs-tools zlib1g-dev liblzma-dev liblzo2-dev sleuthkit openjdk-8-jdk"
PYTHON2_APT_CANDIDATES="python-crypto python-lzo python-lzma python-pip python-opengl python-qt4 python-qt4-gl python-numpy python-scipy"
PYTHON3_APT_CANDIDATES="python3-crypto python3-pip python3-opengl python3-pyqt4 python3-pyqt4.qtopengl python3-numpy python3-scipy"
PYTHON3_YUM_CANDIDATES=""
YUM_CANDIDATES="git gcc gcc-c++ make openssl-devel qtwebkit-devel qt-devel gzip bzip2 tar arj p7zip p7zip-plugins cabextract squashfs-tools zlib zlib-devel lzo lzo-devel xz xz-compat-libs xz-libs xz-devel xz-lzma-compat python-backports-lzma lzip pyliblzma perl-Compress-Raw-Lzma"
PYTHON2_YUM_CANDIDATES="python-pip python-opengl python-qt4 numpy python-numdisplay numpy-2f python-Bottleneck scipy"
APT_CANDIDATES="$APT_CANDIDATES $PYTHON2_APT_CANDIDATES"
YUM_CANDIDATES="$YUM_CANDIDATES $PYTHON2_YUM_CANDIDATES"
PIP_COMMANDS="pip"

# Check for root privileges
if [ $UID -eq 0 ]
then
    SUDO=""
else
    SUDO="sudo"
    REQUIRED_UTILS="sudo $REQUIRED_UTILS"
fi

function install_yaffshiv
{
    git clone git@github.com:DaPa/yaffshiv.git
    (cd yaffshiv && $SUDO python2 setup.py install)
    #$SUDO rm -rf yaffshiv
}

function install_sasquatch
{
    git clone git@github.com:DaPa/sasquatch.git
    (cd sasquatch && $SUDO ./build.sh)
    #$SUDO rm -rf sasquatch
}

function install_jefferson
{
    install_pip_package cstruct
    git clone git@github.com:DaPa/jefferson.git
    (cd jefferson && $SUDO python2 setup.py install)
    #$SUDO rm -rf jefferson
}

function install_unstuff
{
    mkdir -p /tmp/unstuff
    cd /tmp/unstuff
    if [ ! -e bin/unstuff ]
    then
        #wget -O - http://my.smithmicro.com/downloads/files/stuffit520.611linux-i386.tar.gz | tar -zxv
        wget -O - http://mirror.sobukus.de/files/grimoire/z-archive/stuffit520.611linux-i386.tar.gz | tar -zxv
    fi

    $SUDO cp bin/unstuff /usr/local/bin/
    cd -
    #rm -rf /tmp/unstuff
}

function install_ubireader
{
    git clone --quiet --depth 1 --branch "v0.8.5-master" git@github.com:DaPa/ubi_reader.git
    (cd ubi_reader && $SUDO python setup.py install)
    #$SUDO rm -rf ubi_reader
}

function install_pip_package
{
    echo "install_pip_package $1 entry"
    PACKAGE="$1"

    for PIP_COMMAND in $PIP_COMMANDS
    do
        $SUDO $PIP_COMMAND install $PACKAGE
    done
    echo "install_pip_package $1 exit"
}

function find_path
{
    FILE_NAME="$1"

    echo -ne "checking for $FILE_NAME..."
    which $FILE_NAME > /dev/null
    if [ $? -eq 0 ]
    then
        echo "yes"
        return 0
    else
        echo "no"
        return 1
    fi
}

# Make sure the user really wants to do this
if [ $YES -eq 0 ]
then
    echo ""
    echo "WARNING: This script will download and install all required and optional dependencies for binwalk."
    echo "         This script has only been tested on, and is only intended for, Debian based systems."
    echo "         Some dependencies are downloaded via unsecure (HTTP) protocols."
    echo "         This script requires internet access."
    echo "         This script requires root privileges."
    echo ""
    echo -n "Continue [y/N]? "
    read YN
    if [ "$(echo "$YN" | grep -i -e 'y' -e 'yes')" == "" ]
    then
        echo "Quitting..."
        exit 1
    fi
fi

# Check to make sure we have all the required utilities installed
NEEDED_UTILS=""
for UTIL in $REQUIRED_UTILS
do
    find_path $UTIL
    if [ $? -eq 1 ]
    then
        NEEDED_UTILS="$NEEDED_UTILS $UTIL"
    fi
done

# Check for supported package managers and set the PKG_* envars appropriately
find_path $APTCMD
if [ $? -eq 1 ]
then
    find_path $YUMCMD
    if [ $? -eq 1 ]
    then
        NEEDED_UTILS="$NEEDED_UTILS $APTCMD/$YUMCMD"
    else
        PKGCMD="$YUMCMD"
        PKGCMD_OPTS="-y install"
        PKG_CANDIDATES="$YUM_CANDIDATES"
        PKG_PYTHON3_CANDIDATES="$PYTHON3_YUM_CANDIDATES"
    fi
else
    PKGCMD="$APTCMD"
    PKGCMD_OPTS="install -y"
    PKG_CANDIDATES="$APT_CANDIDATES"
    PKG_PYTHON3_CANDIDATES="$PYTHON3_APT_CANDIDATES"
fi

if [ "$NEEDED_UTILS" != "" ]
then
    echo "Please install the following required utilities: $NEEDED_UTILS"
    exit 1
fi

# Check to see if we should install modules for python3 as well
find_path python3
if [ $? -eq 0 ]
then
     PKG_CANDIDATES="$PKG_CANDIDATES $PKG_PYTHON3_CANDIDATES"
     PIP_COMMANDS="pip3 $PIP_COMMANDS"
fi

# Do the install(s)
mkdir ~/tmp
cd ~/tmp
$SUDO $PKGCMD $PKGCMD_OPTS $PKG_CANDIDATES
if [ $? -ne 0 ]
    then
    echo "Package installation failed: $PKG_CANDIDATES"
    exit 1
fi

# in ubuntu 16.04.6.x32 this needed older pip, see:
# https://stackoverflow.com/questions/65900292/how-can-i-install-a-legacy-pip-version-with-python-2-6-6-or-python-2-7-5
# $ curl -fsSL -O https://bootstrap.pypa.io/pip/2.7/get-pip.py
# $ python get-pip.py --no-python-version-warning && rm -f get-pip.py
# $ python -m pip --version
# $ curl -fsSL -O https://bootstrap.pypa.io/pip/3.5/get-pip.py
# $ python3 get-pip.py --no-python-version-warning && rm -f get-pip.py
# $ python3 -m pip --version


install_pip_package pyqtgraph
install_pip_package capstone
install_sasquatch
install_yaffshiv
install_jefferson
install_unstuff
install_ubireader

