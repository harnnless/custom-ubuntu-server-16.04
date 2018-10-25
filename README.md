# custom-ubuntu-server-16.04 HOWTO

0. Dependencies
```
apt install syslinux-utils rng-tools fakeroot squashfs-tools dpkg-dev isolinux xorriso
```

1. Customize Configuration
Create a file: ./private/mygpgkey.config, set gpg key options, Specify unattended answer file.
```
GPGKEYNAME="Custom Installation Key"
GPGKEYCOMMENT="Package Signing"
GPGKEYEMAIL="custom@example.com"
GPGKEYPHRASE="ForDemo"

SEEDFILE=$BASE_DIR/private/auto.seed
```

2. Copy or download deb to ./extras folder

3. Modify ```$ORIG_ISO``` to locate the path of your original image, then build
```
vim ./build-debian-cd.sh
./build-debian-cd.sh
```
