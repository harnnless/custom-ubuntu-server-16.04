#!/usr/bin/env bash

set -eu
set -o pipefail

#Variable to customize
GPG_NAME=70FF1AB2

ORIG_ISO=/home/${USER}/ISO/ubuntu-16.04.5-server-amd64.iso

BASE_DIR=$PWD
EXTRAS_PKG=$BASE_DIR/extras
TARGET_DIR=$BASE_DIR/target
SEEDFILE=$BASE_DIR/auto.seed
DIST=xenial
NEW_ISO=$TARGET_DIR/ubuntu-16.04.5-server-amd64-custom.iso

# GPG
GPGKEYNAME="Custom Installation Key"
GPGKEYCOMMENT="Package Signing"
GPGKEYEMAIL="custom@example.com"
GPGKEYPHRASE="ForDemo"

if [ -f $BASE_DIR/private/mygpgkey.config ]; then
  . $BASE_DIR/private/mygpgkey.config
fi

MYGPGKEY="$GPGKEYNAME ($GPGKEYCOMMENT) <$GPGKEYEMAIL>"

TMP_DIR=$BASE_DIR/temp
BUILD=$BASE_DIR/build
MOUNT=$TMP_DIR/mount

EXTRAS_DIST=$BUILD/dists/$DIST/extras/binary-amd64
EXTRAS_POOL=$BUILD/pool/extras

echo "[BUILD] - Checking dependencies"
which gpg > /dev/null
if [ $? -eq 1 ]; then
        echo "Please install gpg to generate signing keys"
        exit
fi
if [ ! -f $ORIG_ISO ]; then
        echo "Cannot find original ubuntu image. Change ORIG_ISO path."
        exit
fi

echo "[BUILD] - Cleaning directories"
sudo rm -rf $TMP_DIR $BUILD $NEW_ISO

echo "[BUILD] - Checking directories"
if [ ! -d $TMP_DIR ]; then mkdir -p $TMP_DIR; fi
if [ ! -d $MOUNT ]; then mkdir -p $MOUNT; fi
if [ ! -d $BASE_DIR/indices ]; then mkdir -p $BASE_DIR/indices; fi
if [ ! -d $TMP_DIR/apt-ftparchive ]; then mkdir -p $TMP_DIR/apt-ftparchive; fi
if [ ! -d $BASE_DIR/keyring ]; then mkdir -p $BASE_DIR/keyring; fi
if [ ! -d $BUILD ]; then mkdir -p $BUILD; fi
if [ ! -d $TARGET_DIR ]; then mkdir -p $TARGET_DIR; fi


echo "[BUILD] - Generating keyfile"
cd $BASE_DIR/keyring
KEYRING=`find * -maxdepth 1 -name "ubuntu-keyring*" -type d -print || echo ""` 
if [ -z "$KEYRING" ]; then
  apt-get source ubuntu-keyring
  KEYRING=`find * -maxdepth 1 -name "ubuntu-keyring*" -type d -print`
  if [ -z "$KEYRING" ]; then
    echo "Cannot grab keyring source! Exiting."
    exit
  fi
fi

cd $BASE_DIR/keyring/$KEYRING/keyrings
gpg --import < ubuntu-archive-keyring.gpg >/dev/null

if ! gpg --list-keys "$GPGKEYNAME" >/dev/null ; then
  echo "No GPG Key found in your keyring."
  echo "Generating a new gpg key ($GPGKEYNAME $GPGKEYCOMMENT) with a passphrase of $GPGKEYPHRASE .."
  echo ""
  echo "%echo Generating a default key
Key-Type: DSA
Key-Length: 2048
Subkey-Type: ELG-E
Subkey-Length: 2048
Name-Real: $GPGKEYNAME
Name-Comment: $GPGKEYCOMMENT
Name-Email: $GPGKEYEMAIL
Expire-Date: 0
Passphrase: $GPGKEYPHRASE
%commit
%echo done" > $TMP_DIR/key.inc
  gpg --batch --gen-key $TMP_DIR/key.inc
fi
#GPGKEYID=`gpg --list-keys "$GPGKEYNAME" |grep -o -E "^pub[^\/]+\/(.{8})" | sed -r "s?pub.+/??"`
#if [ -z "$GPGKEYID" ]; then
#  echo "Cannot find keyid of $GPGKEYNAME"
#  exit
#fi

rm -f ubuntu-archive-keyring.gpg
gpg --output=ubuntu-archive-keyring.gpg --export 437D05B5 FBB75451 C0B21F32 EFE21092 "$GPGKEYNAME" >/dev/null
cd ..
dpkg-buildpackage -uc -us -rfakeroot -m"$MYGPGKEY" -k"$GPGKEYNAME" >/dev/null

echo "[BUILD] - Mounting ISO file"
sudo mount -o loop,ro $ORIG_ISO $MOUNT
if [ ! -f $MOUNT/md5sum.txt ]; then
  echo "Mount did not succeed. Exiting."
  exit
fi

echo "[BUILD] - Copying all files from ISO to new directory"
rsync -a $MOUNT/ $BUILD

echo "[BUILD] - Unmounting ISO file"
sudo umount $MOUNT

echo "[BUILD] - Copying config files to target"
chmod +w -R $BUILD

cp $BASE_DIR/txt.cfg $BUILD/isolinux/ 
cp $BASE_DIR/grub.cfg $BUILD/boot/grub/ 
cp $SEEDFILE $BUILD/preseed/auto.seed
if [ -s factory ]; then
  cp -r factory $BUILD/
fi

echo "[BUILD] - Generate new filesystem.squashfs with the updated ubuntu-archive-keyring.gpg"
cd $TMP_DIR
sudo unsquashfs $BUILD/install/filesystem.squashfs
cd squashfs-root
sudo cp $BASE_DIR/keyring/$KEYRING/keyrings/ubuntu-archive-keyring.gpg usr/share/keyrings/ubuntu-archive-keyring.gpg
sudo cp $BASE_DIR/keyring/$KEYRING/keyrings/ubuntu-archive-keyring.gpg etc/apt/trusted.gpg
sudo cp $BASE_DIR/keyring/$KEYRING/keyrings/ubuntu-archive-keyring.gpg var/lib/apt/keyrings/ubuntu-archive-keyring.gpg
rm $BUILD/install/filesystem.squashfs $BUILD/install/filesystem.size
sudo du -sx --block-size=1 ./ | cut -f1 > $BUILD/install/filesystem.size
sudo mksquashfs ./ $BUILD/install/filesystem.squashfs
sudo chown $USER:$USER $BUILD/install/filesystem.squashfs

cd $BASE_DIR

echo "[BUILD] - Updating ubuntu-keyring"
cp $BASE_DIR/keyring/ubuntu-keyring*deb $BUILD/pool/main/u/ubuntu-keyring
if [ $? -gt 0 ]; then
        echo "Cannot copy the modified ubuntu-keyring over to the pool/main folder. Exiting."
        exit
fi


echo "[BUILD] - Copying all debs to \"${EXTRAS_POOL}\""
mkdir -p $EXTRAS_DIST
mkdir -p $EXTRAS_POOL

cp $EXTRAS_PKG/*.deb $EXTRAS_POOL/

echo "[BUILD] - Generating Packages.gz for extras"
if [ ! -f $BASE_DIR/indices/override.xenial.extra.main ]; then
  cd $BASE_DIR/indices
  for SUFFIX in extra.main main main.debian-installer restricted restricted.debian-installer; do
    wget http://archive.ubuntu.com/ubuntu/indices/override.$DIST.$SUFFIX
  done
fi
if [ ! -f $TMP_DIR/apt-ftparchive/apt-ftparchive-deb.conf ]; then
  cp $BASE_DIR/apt-ftparchive/apt-ftparchive-deb.conf.template $TMP_DIR/apt-ftparchive/apt-ftparchive-deb.conf
  cp $BASE_DIR/apt-ftparchive/apt-ftparchive-extras.conf.template $TMP_DIR/apt-ftparchive/apt-ftparchive-extras.conf
  cp $BASE_DIR/apt-ftparchive/apt-ftparchive-udeb.conf.template $TMP_DIR/apt-ftparchive/apt-ftparchive-udeb.conf
  cp $BASE_DIR/apt-ftparchive/release.conf.template $TMP_DIR/apt-ftparchive/release.conf
  sed -i -r "s#\{BUILD_DIR\}#$BUILD#g" $TMP_DIR/apt-ftparchive/*
  sed -i -r "s#\{BASE_DIR\}#$BASE_DIR#g" $TMP_DIR/apt-ftparchive/*
fi

cd $BUILD
apt-ftparchive packages pool/extras > dists/stable/extras/binary-amd64/Packages
gzip -c dists/stable/extras/binary-amd64/Packages | tee dists/stable/extras/binary-amd64/Packages.gz > /dev/null

apt-ftparchive -c $TMP_DIR/apt-ftparchive/release.conf generate $TMP_DIR/apt-ftparchive/apt-ftparchive-deb.conf
apt-ftparchive -c $TMP_DIR/apt-ftparchive/release.conf generate $TMP_DIR/apt-ftparchive/apt-ftparchive-udeb.conf
apt-ftparchive -c $TMP_DIR/apt-ftparchive/release.conf generate $TMP_DIR/apt-ftparchive/apt-ftparchive-extras.conf

echo "[BUILD] - Generating new Release"
sudo rm $BUILD/dists/$DIST/Release*
apt-ftparchive release -c $TMP_DIR/apt-ftparchive/release.conf dists/$DIST > dists/$DIST/Release

echo "[BUILD] - Generating new Release.gpg"
rm -f 
echo "$GPGKEYPHRASE" | gpg --default-key "$GPGKEYNAME" --passphrase-fd 0 --output dists/$DIST/Release.gpg -ba dists/$DIST/Release

echo "[BUILD] - Generating md5sum.txt"
find . -type f -print0 | xargs -0 md5sum > md5sum.txt

chmod -w -R $BUILD

echo "[BUILD] - Creating ISO image"
sudo xorriso -as mkisofs \
	-iso-level 3 \
	-V "Ubuntu-Server 16.04.5 LTS amd64" \
	-isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
	-c isolinux/boot.cat \
	-b isolinux/isolinux.bin \
	-no-emul-boot \
	-boot-load-size 4 \
	-boot-info-table \
	-eltorito-alt-boot \
	-e boot/grub/efi.img \
	-no-emul-boot \
	-isohybrid-gpt-basdat \
	-o $NEW_ISO \
	$BUILD

sudo chown $USER:$USER $NEW_ISO

echo "[BUILD] - Finished"
