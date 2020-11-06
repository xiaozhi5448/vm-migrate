#!/bin/bash

SYSTEM_NAME=''
SYSTEM_VERSION=''
PKGMGR=''
USERNAME='root'
PASSWORD='wodemima'
PROXYHOST='192.168.56.1'
PROXYPORT='1088'
function get_banner(){
    system_name=$(cat /etc/os-release | egrep "^ID=" | awk -F= '{print $2}')
    SYSTEM_NAME=$system_name
    system_version=$(cat /etc/os-release | grep "VERSION_ID" | awk -F= '{print $2}')
    SYSTEM_VERSION=$system_version
}

function get_pkgmgr(){
    which yum &> /dev/null
    if [ $? == 0 ]
    then
        PKGMGR="yum"
    fi
    which apt &> /dev/null
    if [ $? == 0 ]
    then
        PKGMGR="apt"
    fi
}

function sudo_pass(){
    printf "%s\n" "try to modify sudoers file"
    printf "%s\n" "add write permission to /etc/sudoers"
    echo $PASSWORD | sudo -S chmod +w $1
    printf "%s\n" "add information to /etc/sudoers"
    echo $PASSWORD | sudo -S sed -i "/^root/a ${USERNAME} ALL=(ALL:ALL) NOPASSWD:ALL\n" $1
    echo $PASSWORD | sudo -S sed -i "/^\%sudo/a\%${USERNAME} ALL=(ALL:ALL) NOPASSWD:ALL\n" $1
    echo $PASSWORD | sudo -S chmod -w $1
    printf "%s\n" "config sudoers done!"
}

function install_deps(){
    printf "%s\n" "try to install dependency"
    if [ $PKGMGR == "apt" ]
    then
        sudo apt update -y && sudo apt install -y gcc make build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
        libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev\
        gcc g++ make cmake git build-essential open-vm-tools linux-headers-$(uname -r)
    elif [ $PKGMGR == "yum" ]
    then
        sudo yum update && sudo yum install -y zlib-devel bzip2-devel openssl-devel ncurses-devel\
        sqlite-devel readline-devel tk-devel libffi-devel\
        gcc gcc-c++ make cmake git kernel-devel
    fi
}

function install_proxy(){
    echo "please config v2ray or ssr first!\n"
    if [ $PKGMGR == "apt" ]
    then
        sudo apt install privoxy proxychains -y
        sudo sed -i "N;1337aforward-socks5t / ${PROXYHOST}:${PROXYPORT} ./" /etc/privoxy/config
        sudo sed -i "s/^socks4.*/socks5 ${PROXYHOST} ${PROXYPORT}/g" /etc/proxychains.conf
        proxychains curl www.google.com &> /dev/null
        if [ $? == 0 ]
        then
            echo "config proxy successfully!\n"
        else
            echo "config proxy failed!"
        fi
        sudo cp config/apt_proxy.conf /etc/apt_proxy.conf
    fi
    
}

function install_pyenv(){
    pyenv &> /dev/null
    if [ $? == 0 ]
    then
        printf "%s\n" "pyenv already installed"
        return
    fi
    
    while [[ ! -f scripts/pyenv-installer.sh ]]
    do
        proxychains curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer > scripts/pyenv-installer.sh
        if [ $? != 0 ]
        then
            read -p "get pyenv-installer failed, try again[y/n]: " opt
            if [ $opt == 'y' ]
            then
                continue
            else
                printf "%s\n" "get pyenv installer failed, exited!"
                exit
            fi
        fi
    done
    
    
    sed -i '/^ProxyChains.*/d' scripts/pyenv-installer.sh
    ls ~/.pyenv &> /dev/null
    while /bin/true
    do
        rm -rf ~/.pyenv
        proxychains sh scripts/pyenv-installer.sh
        if [ $? != 0 ]
        then
            read -p "pyenv install failed, try again[y/n]: " opt
            if [ $opt == 'y' ]
            then
                continue
            else
                printf "%s\n" "install pyenv failed!"
                exit
            fi
        else
            break
        fi
    done
    cat << EOF  >> ~/.bashrc
export PATH="/home/${USERNAME}/.pyenv/bin:\$PATH"
eval "\$(pyenv init -)"
eval "\$(pyenv virtualenv-init -)"
EOF
    mkdir -p ~/.pyenv/cache
    cp archive/Miniconda3* ~/.pyenv/cache
    printf "%s\n" "config source of pip and conda"
    sudo apt install python3-pip -y
    sudo pip3 install -U pip  -i https://pypi.tuna.tsinghua.edu.cn/simple
    pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
    sudo pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
    pyenv install miniconda3-4.3.31
    cp config/condarc ~/.condarc
    sudo cp config/condarc /root/.condarc
}

function install_java(){
    sudo mkdir -p /usr/local/java
    sudo cp archive/jdk-* /usr/local/java/
    sudo tar -xf /usr/local/java/jdk-8u261-linux-x64.tar.gz -C /usr/local/java/
    sudo tar -xf /usr/local/java/jdk-14.0.2_linux-x64_bin.tar.gz -C /usr/local/java/
    sudo ln -s /usr/local/java/jdk-14.0.2 /usr/local/java/jdk
    cat << EOF >> ~/.bashrc
export JAVA_HOME="/usr/local/java/jdk"
export PATH="/usr/local/java/jdk/bin:\$PATH"
EOF
    source ~/.bashrc
    java -version
}

function install_docker(){
    sudo apt install docker.io docker-compose -y
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["https://e4y65rvy.mirror.aliyuncs.com"]
}
EOF
    sudo usermod -aG docker $USERNAME
    sudo systemctl daemon-reload
    sudo systemctl restart docker
}

function config_zsh(){
    sudo apt install zsh -y
    chsh -s /bin/zsh
    if [ ! -f scripts/ohmyzsh-installer.sh ]
    then
        
        proxychains curl https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh > scripts/ohmyzsh-installer.sh
        sed -i '/^ProxyChains.*/d' scripts/ohmyzsh-installer.sh
    fi
    if [ -d ~/.oh-my-zsh ]
    then
        rm -rf ~/.oh-my-zsh
    fi
    while /bin/true
    do
        proxychains sh scripts/ohmyzsh-installer.sh
        if [ $? != 0 ]
        then
            read -p "install oh-my-zsh failed, continue[y/n]: " opt
            if [ $opt == "y" ]
            then
                rm -rf ~/.oh-my-zsh
                continue
            else
                return
            fi
        else
            break
        fi
    done
    proxychains git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    proxychains git clone git://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    proxychains git clone https://github.com/agkozak/zsh-z ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z
    cp config/.zshrc ~/.zshrc
    sed -i "s/xiaozhi/${USERNAME}/g" ~/.zshrc
}

# just for deepin
function config_title_bar(){
    mkdir -p ~/.local/share/deepin/themes/deepin/dark/
    mkdir -p ~/.local/share/deepin/themes/deepin/light/
    cat << EOF > ~/.local/share/deepin/themes/deepin/dark/titlebar.ini
[Active]
height=24

[Inactive]
height=24
EOF
    cat << EOF > ~/.local/share/deepin/themes/deepin/light/titlebar.ini
[Active]
height=24

[Inactive]
height=24
EOF
}
# only for deepin
function config_variety(){
    sudo  apt install variety -y
    echo 'dbus-send --dest=com.deepin.daemon.Appearance /com/deepin/daemon/Appearance --print-reply com.deepin.daemon.Appearance.SetMonitorBackground string:"HDMI-0" string:"file://$WP" ' >> ~/.config/variety/scripts/set_wallpaper
    
    
}

function config_software(){
    sudo apt install deepin-terminal=5.0.4.1-1
    sudo apt install npm -y
    sudo npm install -g jshint
    for file in $(ls debs/linux/*.deb)
    do
        sudo dpkg -i $file
        if [[ $? != 0 ]];then
            sudo apt install -f
            sudo dpkg -i $file
        fi
    done
    # burpsuite
    sudo sh debs/tools/burpsuite_community_linux_v2020_8.sh
    if [[ ! -d ~/tools ]];then
        mkdir ~/tools
    fi
    # copy file
    cp -r debs/tools/* ~/tools/
    # config vagrant
    if [[ ! -d /usr/local/vagrant ]]
    then
        
        sudo mkdir /usr/local/vagrant/
    fi
    sudo cp ~/tools/vagrant_2.2.10_linux_amd64.zip /usr/local/vagrant/
    sudo unzip /usr/local/vagrant/vagrant_2.2.10_linux_amd64.zip
    sudo ln -s /usr/local/vagrant/vagrant /usr/bin/vagrant
    # zaproxy
    sudo apt install github.zaproxy.zaproxy -y
    # postman
    if [[ ! -d /usr/local/postman ]]
    then
        sudo mkdir /usr/local/postman
    fi
    sudo cp debs/tools/Postman-linux-x64-7.23.0.tar.gz /usr/local/postman
    cd /usr/local/postman && sudo tar -xf Postman-linux-x64-7.23.0.tar.gz
    
    # typora
    sudo apt install io.typora -y
    
}


function config_nvidia(){
    sudo apt install nvidia-driver nvidia-smi -y
    if [ ! -f /etc/X11/xorg.conf ]
    then
        sudo cp config/xorg.conf /etc/X11/xorg.conf
    fi
    if [ ! -f /etc/lightdm/display_setup.sh ]
    then
        sudo cp config/display_setup.sh /etc/lightdm/display_setup.sh
        sed -i '/^\[Seat:\*\]/adisplay-setup-script=/etc/lightdm/display_setup.sh' /etc/lightdm/lightdm.conf
    fi
}

get_banner
echo "$SYSTEM_NAME:$SYSTEM_VERSION"
get_pkgmgr
echo "pkgmgr:$PKGMGR"
# install_deps
# install_docker
#sudo_pass /etc/sudoers
# install_deps
# install_proxy
# install_java
# install_docker
# config_variety
config_zsh
install_pyenv
