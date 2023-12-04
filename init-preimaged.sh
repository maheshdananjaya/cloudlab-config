#!/usr/bin/env bash

# WARNING: Before executing this script make sure to have setup
#   ssh-key on github and cloudlab and have share it with executing node

# TODO: Set this variable below
NO_NODES="5" # WARNING: cannot be higher than number of allocated nodes in cloudlab

if [[ "${NO_NODES}" -gt 9 ]]; then
  echo "Current script supports up to 9 nodes"
  exit 1;
fi

# [Optionally] set terminal bar --> must source ~/.bashrc to apply it
echo " " >> ~/.bashrc
echo "#My Options" >> ~/.bashrc
echo "#Terminal Bar" >> ~/.bashrc
echo "parse_git_branch() {" >> ~/.bashrc
echo "   git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/{\1}/'" >> ~/.bashrc
echo "}" >> ~/.bashrc
echo "export PS1=\"\[\033[36m\]\u\[\033[0;31m\]\$(parse_git_branch)\[\033[m\]@\[\033[32m\]\h:\[\033[33;2m\]\w\[\033[m\]\$\"" >> ~/.bashrc
echo " " >> ~/.bashrc
echo "alias nic-perf='sudo watch -n1 perfquery -x -r' " >> ~/.bashrc
echo " " >> ~/.bashrc
echo "export PATH=\"/users/maheshd/.local/bin:${PATH}\"" >> ~/.bashrc
echo " " >> ~/.bashrc
source ~/.bashrc

# silence parallel citation without the manual "will-cite" after parallel --citation
mkdir ~/.parallel
touch ~/.parallel/will-cite

# Configure (2MB) huge-pages for the KVS
echo 8192 | sudo tee /sys/devices/system/node/node*/hugepages/hugepages-2048kB/nr_hugepages
echo 10000000001 | sudo tee /proc/sys/kernel/shmmax
echo 10000000001 | sudo tee /proc/sys/kernel/shmall


ssh-keyscan -H github.com >> ~/.ssh/known_hosts

rm -rf fasst
rm -rf 1KVS
git clone https://github.com/maheshdananjaya/fasst.git fasst
cd fasst
git fetch -a
git checkout mahesh-dam
cd app/tatp
make -B
cd ../smallbank
make -B
cd

git clone https://github.com/maheshdananjaya/1KVS.git
cd 1KVS
git checkout dam
#if [[ "${HOSTNAME:5:1}" == 1 ]]; 
#then
#	./build.sh	
#else
#	./build.sh -s
#fi
#./build.sh -s
git clone https://github.com/maheshdananjaya/cloudlab.git
cd cloudlab
git checkout master

sudo wget https://www.intel.com/content/dam/develop/external/us/en/documents/mlc_v3.9a.tgz
sudo tar xvzf mlc_v3.9a.tgz


#bluefield 2
#sudo su
sudo systemctl restart systemd-networkd
sudo netplan apply
sudo echo 1 | tee /proc/sys/net/ipv4/ip_forward
sudo iptables -t nat -A POSTROUTING -o eno1 -j MASQUERADE
sudo iptables -A FORWARD -o eno1 -j ACCEPT
sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -i eno1 -j ACCEPT


#installing operating systems on blufieds
#sudo su
mkdir /tmp
cd /tmp/
wget https://content.mellanox.com/BlueField/RSHIM/rshim_2.0.6-3.ge329c69_amd64.deb
sudo dpkg -i rshim_2.0.6-3.ge329c69_amd64.deb
sudo systemctl status rshim
sudo systemctl restart rshim
#echo ubuntu_PASSWORD='$1$fkQE6cZQ$KlSSiH4HDNTui53W/1hA40' >> bf.cfg
echo "ubuntu_PASSWORD='\$1\$fkQE6cZQ\$KlSSiH4HDNTui53W/1hA40'" >> bf.cfg
wget https://content.mellanox.com/BlueField/BFBs/Ubuntu20.04/DOCA_v1.2.1_BlueField_OS_Ubuntu_20.04-5.4.0-1023-bluefield-5.5-2.1.7.0-3.8.5.12027-1.signed-aarch64.bfb
sudo bfb-install --bfb /tmp/DOCA_v1.2.1_BlueField_OS_Ubuntu_20.04-5.4.0-1023-bluefield-5.5-2.1.7.0-3.8.5.12027-1.signed-aarch64.bfb --config /tmp/bf.cfg --rshim rshim0


sleep 10 # if we try to init nic immediately it typically fails

# Setting the ip to the ib0 might not work on the first try so repeat
MAX_RETRIES=10
for i in `seq 1 ${MAX_RETRIES}`; do
  sudo ifconfig ib0 10.0.3.${HOSTNAME:5:1}/24 up
  if ibdev2netdev | grep "Up" ; then
    break
  fi
  sleep 5
done

if ibdev2netdev | grep "Up" ; then
  echo "IB0 is Up!"
else
  ibdev2netdev
  echo "IB0 is not Up --> setup failed!"
  exit 1
fi

sudo /etc/init.d/memcached stop

# [Optionally] For dbg ensure everything was configured properly
#ibdev2netdev # --> must show ib0 (up)
#ifconfig --> expected ib0 w/ expected ip
#ibv_devinfo --> PORT_ACTIVE

#############################
# WARNING only on first node!
#############################
if [[ "${HOSTNAME:5:1}" == 1 ]]; then
    sleep 20 # give some time so that all peers has setup their NICs

    git config --global user.name "dananjayamahesh"
    git config --global user.email "dananjayamahesh@gmail.com"

    # start a subnet manager
    #sudo /etc/init.d/opensmd start # there must be at least one subnet-manager in an infiniband subnet cluster

    # Add all cluster nodes to known hosts
    # WARNING: execute this only after all nodes have setup their NICs (i.e., ifconfig up above)
    for i in `seq 1 ${NO_NODES}`; do
      ssh-keyscan -H 10.0.3.${i} >> ~/.ssh/known_hosts
    done
fi
