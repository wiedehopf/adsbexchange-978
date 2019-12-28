#!/bin/bash
set -e

name="adsb-exchange-978"
repo="https://github.com/wiedehopf/$name"
ipath="/usr/local/share/$name"

mkdir -p $ipath


if ! id -u "$name" &>/dev/null
then
    adduser --system --home $ipath --no-create-home --quiet tar1090
fi


commands="git socat gcc make ld"
packages="git socat build-essential"
install=""

for PKG in $packages; do
	if ! command -v "$PKG" &>/dev/null
	then
        install=1
	fi
done

if [[ -n "$install" ]]
then
	echo "Installing required packages: $packages"
	apt-get update || true
	if ! apt-get install -y $packages
	then
		echo "Failed to install required packages: $install"
		echo "Exiting ..."
		exit 1
	fi
	hash -r || true
fi

if ! [ -f $ipath/uat2esnt ]; then
	rm -rf /tmp/dump978 &>/dev/null || true
	git clone --single-branch --depth 1 --branch master https://github.com/flightaware/dump978.git /tmp/dump978
	cd /tmp/dump978/legacy
	make uat2esnt
	cp uat2esnt $ipath
fi

if ! [ -f $ipath/readsb ]; then
	rm -rf /tmp/readsb &>/dev/null || true
	git clone --single-branch --depth 1 --branch net-only https://github.com/wiedehopf/readsb.git /tmp/readsb
	cd /tmp/readsb
    apt install libncurses5-dev
	make
	cp readsb $ipath
fi


if [[ "$1" == "test" ]]
then
	rm -r $ipath/test 2>/dev/null || true
	mkdir -p $ipath/test
	cp -r ./* $ipath/test
	cd $ipath/test

elif git clone --depth 1 $repo $ipath/git 2>/dev/null || cd $ipath/git
then
	cd $ipath/git
	git checkout -f master
	git fetch
	git reset --hard origin/master

else
	echo "Unable to download files, exiting! (Maybe try again?)"
	exit 1
fi

cp -n default "/etc/default/$name"
cp default convert.sh $ipath

cp 1090.service "/lib/systemd/system/$name.service"
cp convert.service "/lib/systemd/system/$name-convert.service"

systemctl enable "$name"
systemctl enable "$name-convert"
systemctl restart "$name"
systemctl restart "$name-convert"
