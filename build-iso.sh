#!/bin/sh

IMAGE=ubuntu-16.04.2-server-amd64.iso
BUILD=$1

sudo xorriso -as mkisofs \
	-iso-level 3 \
	-V "Ubuntu-Server 16.04.2 LTS amd64" \
	-isohybrid-mbr my_isohdpfx.bin \
	-c isolinux/boot.cat \
	-b isolinux/isolinux.bin \
	-no-emul-boot \
	-boot-load-size 4 \
	-boot-info-table \
	-eltorito-alt-boot \
	-e boot/grub/efi.img \
	-no-emul-boot \
	-isohybrid-gpt-basdat \
	-o $IMAGE \
	$BUILD

sudo chown $USER:$USER $IMAGE
