#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="exsolution.conf"
EXSOLUTION_DAEMON="/usr/local/bin/exsolution-cli"
EXSOLUTION_REPO="https://github.com/exsolution/ext-wallet.git"
DEFAULTEXSOLUTIONPORT=21636
DEFAULTEXSOLUTIONUSER="exsolution"
NODEIP=$(curl -s4 icanhazip.com)


RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $EXSOLUTION_DAEMON)" ] || [ -e "$EXSOLUTION_DAEMOM" ] ; then
  echo -e "${GREEN}\c"
  read -e -p "Exsolution is already installed. Do you want to add another MN? [Y/N]" NEW_EXSOLUTION
  echo -e "{NC}"
  clear
else
  NEW_EXSOLUTION="new"
fi
}

function prepare_system() {

echo -e "Prepare the system to install Exsolution master node."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget pwgen curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
libminiupnpc-dev libgmp3-dev >/dev/null 2>&1
clear
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git pwgen curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev"
 exit 1
fi

clear
echo -e "Checking if swap space is needed."
PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
SWAP=$(free -g|awk '/^Swap:/{print $2}')
if [ "$PHYMEM" -lt "2" ] && [ -n "$SWAP" ]
  then
    echo -e "${GREEN}Server is running with less than 2G of RAM without SWAP, creating 2G swap file.${NC}"
    SWAPFILE=$(mktemp)
    dd if=/dev/zero of=$SWAPFILE bs=1024 count=2M
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon -a $SWAPFILE
else
  echo -e "${GREEN}Server running with at least 2G of RAM, no swap needed.${NC}"
fi
clear
}

function compile_exsolution() {
  echo -e "Clone git repo and compile it. This may take some time. Press a key to continue."
  read -n 1 -s -r -p ""

  cd $TMP_FOLDER
  git clone https://github.com/bitcoin-core/secp256k1
  cd secp256k1
  chmod +x ./autogen.sh
  ./autogen.sh
  ./configure
  make
  ./tests
  sudo make install 
  clear 

  cd $TMP_FOLDER
  git clone $EXSOLUTION_REPO
  cd exsolution/src
  ./autogen.sh
  ./configure
  make
  make install 
  compile_error exsolution
  cp -a exsolution-cli /usr/local/bin
  cd ~
  rm -rf $TMP_FOLDER
  clear
}

function enable_firewall() {
  FWSTATUS=$(ufw status 2>/dev/null|awk '/^Status:/{print $NF}')
  if [ "$FWSTATUS" = "active" ]; then
    echo -e "Setting up firewall to allow ingress on port ${GREEN}$EXSOLUTIONPORT${NC}"
    ufw allow $EXSOLUTIONPORT/tcp comment "exsolution MN port" >/dev/null
  fi
}

function systemd_exsolution() {
  cat << EOF > /etc/systemd/system/$EXSOLUTIONUSER.service
[Unit]
Description=Exsolution service
After=network.target

[Service]
ExecStart=$EXSOLUTION_DAEMON -conf=$EXSOLUTIONFOLDER/$CONFIG_FILE -datadir=$EXSOLUTIONFOLDER
ExecStop=$EXSOLUTION_DAEMON -conf=$EXSOLUTIONFOLDER/$CONFIG_FILE -datadir=$EXSOLUTIONFOLDER stop
Restart=on-abort
User=$EXSOLUTIONUSER
Group=$EXSOLUTIONUSER

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $EXSOLUTIONUSER.service
  systemctl enable $EXSOLUTIONUSER.service

  if [[ -z "$(ps axo user:15,cmd:100 | egrep ^$EXSOLUTIONUSER | grep $EXSOLUTION_DAEMON)" ]]; then
    echo -e "${RED}EXSOLUTIONd is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $EXSOLUTIONUSER.service"
    echo -e "systemctl status $EXSOLUTIONUSER.service"
    echo -e "less /var/log/syslog${NC}"
  fi
}

function ask_port() {
read -p "EXSOLUTION Port: " -i $DEFAULTEXSOLUTIONPORT -e EXSOLUTIONPORT
: ${EXSOLUTIONPORT:=$DEFAULTEXSOLUTIONPORT}
}

function ask_user() {
  read -p "Exsolution user: " -i $DEFAULTEXSOLUTIONUSER -e EXSOLUTIONUSER
  : ${EXSOLUTIONUSER:=$DEFAULTEXSOLUTIONUSER}

  if [ -z "$(getent passwd $EXSOLUTIONUSER)" ]; then
    USERPASS=$(pwgen -s 12 1)
    useradd -m $EXSOLUTIONUSER
    echo "$EXSOLUTIONUSER:$USERPASS" | chpasswd

    EXSOLUTIONHOME=$(sudo -H -u $EXSOLUTIONUSER bash -c 'echo $HOME')
    DEFAULTEXSOLUTIONFOLDER="$EXSOLUTIONHOME/.Exsolution"
    read -p "Configuration folder: " -i $DEFAULTEXSOLUTIONFOLDER -e EXSOLUTIONFOLDER
    : ${EXSOLUTIONFOLDER:=$DEFAULTEXSOLUTIONFOLDER}
    mkdir -p $EXSOLUTIONFOLDER
    chown -R $EXSOLUTIONUSER: $EXSOLUTIONFOLDER >/dev/null
  else
    clear
    echo -e "${RED}User exits. Please enter another username: ${NC}"
    ask_user
  fi
}

function check_port() {
  declare -a PORTS
  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $EXSOLUTIONPORT ]] || [[ ${PORTS[@]} =~ $[EXSOLUTIONPORT+1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function create_config() {
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $EXSOLUTIONFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$[EXSOLUTIONPORT+1]
listen=1
server=1
daemon=1
port=$EXSOLUTIONPORT
EOF
}

function create_key() {
  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -e EXSOLUTIONKEY
  if [[ -z "$EXSOLUTIONKEY" ]]; then
  sudo -u $EXSOLUTIONUSER $EXSOLUTION_DAEMON -conf=$EXSOLUTIONFOLDER/$CONFIG_FILE -datadir=$EXSOLUTIONFOLDER
  sleep 5
  if [ -z "$(ps axo user:15,cmd:100 | egrep ^$EXSOLUTIONUSER | grep $EXSOLUTION_DAEMON)" ]; then
   echo -e "${RED}exsolutiond server couldn't start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  EXSOLUTIONKEY=$(sudo -u $EXSOLUTIONUSER $EXSOLUTION_DAEMON -conf=$EXSOLUTIONFOLDER/$CONFIG_FILE -datadir=$EXSOLUTIONFOLDER masternode genkey)
  sudo -u $EXSOLUTIONUSER $EXSOLUTION_DAEMON -conf=$EXSOLUTIONFOLDER/$CONFIG_FILE -datadir=$EXSOLUTIONFOLDER stop
fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $EXSOLUTIONFOLDER/$CONFIG_FILE
  cat << EOF >> $EXSOLUTIONFOLDER/$CONFIG_FILE
maxconnections=256
masternode=1
masternodeaddr=$NODEIP:$EXSOLUTIONPORT
masternodeprivkey=$EXSOLUTIONKEY
EOF
  chown -R $EXSOLUTIONUSER: $EXSOLUTIONFOLDER >/dev/null
}

function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "Exsolution Masternode is up and running as user ${GREEN}$EXSOLUTIONUSER${NC} and it is listening on port ${GREEN}$EXSOLUTIONPORT${NC}."
 echo -e "${GREEN}$EXSOLUTIONUSER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$EXSOLUTIONFOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $EXSOLUTIONUSER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $EXSOLUTIONUSER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODEIP:$EXSOLUTIONPORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$EXSOLUTIONKEY${NC}"
 echo -e "Please check Exsolution is running with the following command: ${GREEN}systemctl status $EXSOLUTIONUSER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
  ask_user
  check_port
  create_config
  create_key
  update_config
  enable_firewall
  important_information
  systemd_exsolution
}


##### Main #####
clear

checks
if [[ ("$NEW_EXSOLUTION" == "y" || "$NEW_EXSOLUTION" == "Y") ]]; then
  setup_node
  exit 0
elif [[ "$NEW_EXSOLUTION" == "new" ]]; then
  prepare_system
  compile_exsolution
  setup_node
else
  echo -e "${GREEN}Exsolutiond already running.${NC}"
  exit 0
fi

