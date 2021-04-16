#!/bin/bash
set -e

if [ -f /boot/adsb-config.txt ]; then
    echo --------
    echo "You are using the adsbx image, the 978 feed setup script does not need to be installed."
    echo "You should already be feeding, check here: https://adsbexchange.com/myip/"
    echo --------
    echo "Exiting."
    exit 1
fi

name="adsbexchange-978"
repo="https://github.com/adsbxchange/$name"
ipath="/usr/local/share/$name"

mkdir -p $ipath

current_path=$(pwd)

if ! id -u "$name" &>/dev/null; then
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

if [[ -n "$install" ]]; then
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

UAT_REPO="https://github.com/adsbxchange/uat2esnt.git"
UAT_VERSION="$(git ls-remote $UAT_REPO | grep HEAD | cut -f1)"
if ! grep -e "$UAT_VERSION" -qs $ipath/uat2esnt_version; then
    rm -rf /tmp/uat2esnt
    git clone --single-branch --depth 1 --branch master $UAT_REPO /tmp/uat2esnt
    cd /tmp/uat2esnt
    make -j3 uat2esnt
    rm -f $ipath/uat2esnt
    cp uat2esnt $ipath
    git rev-parse HEAD > $ipath/uat2esnt_version
else
    echo uat2esnt already current version
fi

READSB_REPO="https://github.com/adsbxchange/readsb.git"
READSB_VERSION="$(git ls-remote $READSB_REPO | grep HEAD | cut -f1)"
if ! grep -e "$READSB_VERSION" -qs $ipath/readsb_version; then
    rm -rf /tmp/readsb
    git clone --single-branch --depth 1 $READSB_REPO /tmp/readsb
    cd /tmp/readsb
    apt install -y libncurses5-dev zlib1g-dev zlib1g || true
    make -j3 AIRCRAFT_HASH_BITS=12
    rm -f $ipath/readsb
    cp readsb $ipath
    git rev-parse HEAD > $ipath/readsb_version
else
    echo feed client already current version
fi

cd "$current_path"

if [[ "$1" == "test" ]]; then
	rm -r $ipath/test 2>/dev/null || true
	mkdir -p $ipath/test
	cp -r ./* $ipath/test
	cd $ipath/test

elif git clone --depth 1 $repo $ipath/git 2>/dev/null || cd $ipath/git; then
	cd $ipath/git
	git checkout -f master
	git fetch
	git reset --hard origin/master

else
	echo "Unable to download files, exiting! (Maybe try again?)"
	exit 1
fi

bash create-uuid.sh

cp default "/etc/default/$name"
cp default convert.sh $ipath

cp feed.service "/lib/systemd/system/$name.service"
cp convert.service "/lib/systemd/system/$name-convert.service"

systemctl enable "$name"
systemctl enable "$name-convert"
systemctl restart "$name"
systemctl restart "$name-convert"

# set-location
cat >"/usr/local/bin/$name-set-location" <<"EOF"
#!/bin/bash

lat=$(echo $1 | tr -cd '[:digit:].-')
lon=$(echo $2 | tr -cd '[:digit:].-')

if ! awk "BEGIN{ exit ($lat > 90) }" || ! awk "BEGIN{ exit ($lat < -90) }"; then
	echo
	echo "Invalid latitude: $lat"
	echo "Latitude must be between -90 and 90"
	echo
	echo "Example format for latitude: 51.528308"
	echo
	echo "Usage:"
	echo "adsbexchange-978-set-location 51.52830 -0.38178"
	echo
	exit 1
fi
if ! awk "BEGIN{ exit ($lon > 180) }" || ! awk "BEGIN{ exit ($lon < -180) }"; then
	echo
	echo "Invalid longitude: $lon"
	echo "Longitude must be between -180 and 180"
	echo
	echo "Example format for latitude: -0.38178"
	echo
	echo "Usage:"
	echo "adsbexchange-978-set-location 51.52830 -0.38178"
	echo
	exit 1
fi

echo
echo "setting Latitude: $lat"
echo "setting Longitude: $lon"
echo
if ! grep -e '--lon' /etc/default/adsbexchange-978 &>/dev/null; then sed -i -e 's/DECODER_OPTIONS="/DECODER_OPTIONS="--lon -0.38178 /' /etc/default/adsbexchange-978; fi
if ! grep -e '--lat' /etc/default/adsbexchange-978 &>/dev/null; then sed -i -e 's/DECODER_OPTIONS="/DECODER_OPTIONS="--lat 51.52830 /' /etc/default/adsbexchange-978; fi
sed -i -E -e "s/--lat .?[0-9]*.?[0-9]* /--lat $lat /" /etc/default/adsbexchange-978
sed -i -E -e "s/--lon .?[0-9]*.?[0-9]* /--lon $lon /" /etc/default/adsbexchange-978
systemctl restart adsbexchange-978
EOF
chmod a+x "/usr/local/bin/$name-set-location"


echo "Install successful"
