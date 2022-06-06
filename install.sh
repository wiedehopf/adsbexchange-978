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


commands="git gcc make ld"
packages="git build-essential"
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

function getGIT() {
    # getGIT $REPO $BRANCH $TARGET-DIR
    if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]]; then
        echo "getGIT wrong usage, check your script or tell the author!" 1>&2
        return 1
    fi
    if ! cd "$3" &>/dev/null || ! git fetch --depth 2 origin "$2" || ! git reset --hard FETCH_HEAD; then
        if ! rm -rf "$3" || ! git clone --depth 2 --single-branch --branch "$2" "$1" "$3"; then
            return 1
        fi
    fi
    return 0
}

if [[ "$1" == "test" ]]; then
	rm -r $ipath/test 2>/dev/null || true
	mkdir -p $ipath/test
	cp -r ./* $ipath/test
	cd $ipath/test
else
    if ! getGIT $repo master $ipath/git || ! cd $ipath/git; then
        echo "Unable to download files, exiting! (Maybe try again?)"
        exit 1
    fi
fi

bash create-uuid.sh

if ! grep -qs -e DECODER_OPTIONS "/etc/default/$name" || ! grep -qs -e 'SOURCE="--net-connector' "/etc/default/$name"; then
    cp default "/etc/default/$name"
fi
cp default $ipath

systemctl disable --now "$name-convert" &>/dev/null || true
rm -f "/lib/systemd/system/$name-convert.service"

cp feed.service "/lib/systemd/system/$name.service"
systemctl enable "$name"
systemctl restart "$name"

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

cd "$ipath"

wget -O tar1090-install.sh https://raw.githubusercontent.com/wiedehopf/tar1090/master/install.sh
bash tar1090-install.sh "/run/$name" ax978
