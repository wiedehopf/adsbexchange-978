# adsbexchange-978
The ADS-B exchange UAT/978 feed client for use with dump978-fa


## Installation / Update:

```
sudo bash -c "$(wget -q -O - https://raw.githubusercontent.com/adsbxchange/adsbexchange-978/master/install.sh)"
```

## Set location for graphs1090 / webinterface at /ax978

```
sudo adsbexchange-978-set-location 45.234 12.232
```

## tar1090 webinterface for 978 traffic fed to adsbexchange available at /ax978

- Check URL shown at end of installation
- Both runnign the normal tar1090 install/update script as well as re-running the install script above will update the /ax978 tar1090 instance

## Removal

```
sudo bash -c "$(wget -q -O - https://raw.githubusercontent.com/adsbxchange/adsbexchange-978/master/uninstall.sh)"
```
