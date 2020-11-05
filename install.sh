#!/bin/bash
set -e

name="adsbexchange-978"
repo="https://github.com/adsbxchange/$name"
ipath="/usr/local/share/$name"

mkdir -p $ipath

current_path=$(pwd)

if ! id -u "$name" &>/dev/null
then
    adduser --system --home "$ipath" --no-create-home --quiet "$name"
fi


commands="git socat gcc make ld"
packages="git socat build-essential"
install=""

for CMD in $commands; do
	if ! command -v "$CMD" &>/dev/null
	then
        install=1
	fi
done

if [[ -n "$install" ]]
then
	echo "Installing required packages: $packages"
	apt-get update || true
	apt-get install -y $packages
	hash -r || true

    for CMD in $commands; do
        if ! command -v "$CMD" &>/dev/null
        then
            echo "Failed to install required packages!"
            echo "Exiting ..."
            exit 1
        fi
    done
fi

rm -rf /tmp/dump978 &>/dev/null || true
git clone --single-branch --depth 1 --branch master https://github.com/adsbxchange/uat2esnt.git /tmp/dump978
cd /tmp/dump978/
make uat2esnt
cp uat2esnt $ipath

rm -rf /tmp/readsb &>/dev/null || true
git clone --single-branch --depth 1  https://github.com/adsbxchange/readsb.git /tmp/readsb
cd /tmp/readsb
apt install libncurses5-dev
make
cp readsb $ipath

cd "$current_path"

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

cp feed.service "/lib/systemd/system/$name.service"
cp convert.service "/lib/systemd/system/$name-convert.service"

systemctl enable "$name"
systemctl enable "$name-convert"
systemctl restart "$name"
systemctl restart "$name-convert"


echo "Install successful"
