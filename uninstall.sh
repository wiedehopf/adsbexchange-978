#!/bin/bash

name="adsbexchange-978"
ipath="/usr/local/share/$name"


systemctl disable --now "$name"
systemctl disable --now "$name-convert"

rm -f "/lib/systemd/system/$name.service"
rm -f "/lib/systemd/system/$name-convert.service"

rm -f "/etc/default/$name"
rm -rf $ipath

bash /usr/local/share/tar1090/uninstall.sh ax978

echo "$name removed!"
