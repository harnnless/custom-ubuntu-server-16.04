#!/bin/bash

set -x
exec &> >(tee -a "/var/log/factory.log")

echo "[Run Factory Script]"

echo "[Install extras]"
apt-get install -y openssh-server

echo "[End Factory Script]"
