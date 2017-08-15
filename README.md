# custom-ubuntu-server-16.04 HOWTO

1.Generate GPG keyring
```
gpg --gen-key
```

2.Regenerate ubuntu-keyring with ubuntu archive / cdimage signing key[1]

3.Build all indices
```
cd indices
./build-indices.sh
```
4.1.Modify ```$SRC_ISO``` to locate the path of your original image
```
vim ./build-debian-cd.sh
```
4.2.Build debian-cd style folder
```
./build-debian-cd.sh
```

5.Build an ISO
```
./build-iso.sh new-iso
```

[1][HOW TO CUSTOMIZE UBUNTU 14.04 INSTALLATION CD](https://jack6liu.wordpress.com/2014/12/28/how-to-customize-ubuntu-14-04-installation-c/)
