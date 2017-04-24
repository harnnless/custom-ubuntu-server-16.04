#!/bin/sh
SRC_ISO=/home/${USER}/IBS_ISO/ubuntu-16.04.2-server-amd64.iso
HOME_DIR=$PWD
SRC_DIR=$HOME_DIR/src-iso
NEW_DIR=$HOME_DIR/new-iso
DIST=xenial
EXTRAS_DIST=$NEW_DIR/dists/$DIST/extras/binary-amd64
EXTRAS_POOL=$NEW_DIR/pool/extras
RELEASE_CONF=$HOME_DIR/apt-ftparchive/release.conf

echo "[BUILD] - Cleaning directories"
rm *.iso
sudo rm -rf $SRC_DIR $NEW_DIR temp

echo "[BUILD] - Checking directories"
mkdir -p $SRC_DIR
mkdir -p $NEW_DIR

echo "[BUILD] - Mounting ISO file"
sudo mount -o loop,ro $SRC_ISO $SRC_DIR

echo "[BUILD] - Copying all files from ISO to new directory"
rsync -av $SRC_DIR/ $NEW_DIR

echo "[BUILD] - Unmounting ISO file"
sudo umount $SRC_DIR

echo "[BUILD] - Copying config files to target"
chmod +w -R $NEW_DIR

cp grub.cfg $NEW_DIR/boot/grub/ 
cp oem.seed $NEW_DIR/preseed/
cp -r factory $NEW_DIR/

echo "[BUILD] - Generate new filesystem.squashfs with the updated ubuntu-archive-keyring.gpg"
mkdir temp
cd temp
sudo unsquashfs $NEW_DIR/install/filesystem.squashfs
cd squashfs-root
sudo cp $HOME_DIR/build-ubuntu-keyring/ubuntu-keyring-2012.05.19/keyrings/ubuntu-archive-keyring.gpg usr/share/keyrings/ubuntu-archive-keyring.gpg
sudo cp $HOME_DIR/build-ubuntu-keyring/ubuntu-keyring-2012.05.19/keyrings/ubuntu-archive-keyring.gpg etc/apt/trusted.gpg
sudo cp $HOME_DIR/build-ubuntu-keyring/ubuntu-keyring-2012.05.19/keyrings/ubuntu-archive-keyring.gpg var/lib/apt/keyrings/ubuntu-archive-keyring.gpg
rm $NEW_DIR/install/filesystem.squashfs $NEW_DIR/install/filesystem.size
sudo du -sx --block-size=1 ./ | cut -f1 > $NEW_DIR/install/filesystem.size
sudo mksquashfs ./ $NEW_DIR/install/filesystem.squashfs
sudo chown $USER:$USER $NEW_DIR/install/filesystem.squashfs

cd $HOME_DIR

echo "[BUILD] - Updating ubuntu-keyring"
cp $HOME_DIR/build-ubuntu-keyring/ubuntu-keyring*deb $NEW_DIR/pool/main/u/ubuntu-keyring

echo "[BUILD] - Copying all debs to \"${EXTRAS_POOL}\""
mkdir -p $EXTRAS_DIST
mkdir -p $EXTRAS_POOL

cd $EXTRAS_POOL
apt-get download vim htop tree

echo "[BUILD] - Generating Packages.gz for extras"
cd $NEW_DIR
apt-ftparchive packages pool/extras > dists/stable/extras/binary-amd64/Packages
gzip -c dists/stable/extras/binary-amd64/Packages | tee dists/stable/extras/binary-amd64/Packages.gz > /dev/null

apt-ftparchive -c $RELEASE_CONF generate $HOME_DIR/apt-ftparchive/apt-ftparchive-deb.conf
apt-ftparchive -c $RELEASE_CONF generate $HOME_DIR/apt-ftparchive/apt-ftparchive-udeb.conf
apt-ftparchive -c $RELEASE_CONF generate $HOME_DIR/apt-ftparchive/apt-ftparchive-extras.conf

echo "[BUILD] - Generating new Release"
apt-ftparchive release -c $RELEASE_CONF dists/$DIST > dists/$DIST/Release

echo "[BUILD] - Generating new Release.gpg"
gpg --default-key "9439790F" --output dists/$DIST/Release.gpg -ba dists/$DIST/Release

echo "[BUILD] - Generating md5sum.txt"
find . -type f -print0 | xargs -0 md5sum > md5sum.txt

chmod -w -R $NEW_DIR

echo "[BUILD] - Finished"

