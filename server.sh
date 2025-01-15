# Set up git config
git config --global user.name "Niranjan BR"
git config --global user.email "niranjankannan2003@gmail.com"

sudo apt-get update 
sudo apt-get upgrade
sudo apt-get install gnupg2
sudo apt-get  install golang-go
gpg --import k.asc
echo 'export GPG_TTY=$(tty)' >> ~/.bashrc
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
sudo apt-get install bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick lib32readline-dev lib32z1-dev libelf-dev liblz4-tool libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev -y
wget http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.4-2_amd64.deb 
sudo dpkg -i libtinfo5_6.4-2_amd64.deb 
rm -f libtinfo5_6.4-2_amd64.deb
wget http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.4-2_amd64.deb 
sudo dpkg -i libncurses5_6.4-2_amd64.deb 
rm -f libncurses5_6.4-2_amd64.deb
