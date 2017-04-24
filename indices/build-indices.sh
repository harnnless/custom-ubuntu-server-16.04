#!/bin/sh
DIST=xenial
for SUFFIX in extra.main extra.debian-installer main main.debian-installer restricted restricted.debian-installer; do
  wget http://archive.ubuntu.com/ubuntu/indices/override.$DIST.$SUFFIX
done
