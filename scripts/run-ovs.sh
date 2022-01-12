set -ex

export PATH=$PATH:/usr/share/openvswitch/scripts/
export DB_SOCK=/var/run/openvswitch/db.sock

ovs-vswitchd --version
ovs-ctl --no-ovs-vswitchd start

export CPU=$(cat /sys/fs/cgroup/cpuset/cpuset.cpus)
echo ${CPU}

IFS="," read -ra arr <<< $CPU

export CPU1="${arr[0]}"
unset 'arr[0]'
export CPU2="${arr[1]}"
unset 'arr[1]'
CPU=""
echo ${arr[@]}
for i in "${arr[@]}"
do
   CPU="$CPU,$i"
done
CPU="${CPU:1}"
echo $CPU
echo "Socket:" ${SOCKET}

LCORE=`python3.9 /opt/scripts/cpu-mask-convert.py ${CPU1},${CPU2}`
PMDS=`python3.9 /opt/scripts/cpu-mask-convert.py ${CPU}`

sleep 2
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask=0x${LCORE}
ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=0x${PMDS}

NODE=`lscpu | grep ${CPU1} | awk '/node0/{print "0"}{print "1"}'`
if [[ ${NODE} -eq 0 ]]
then
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="4096,0"
else
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="0,4096"
fi

sleep 2
ovs-ctl --no-ovsdb-server --db-sock="$DB_SOCK" start
sleep 3

ovs-vsctl get Open_vSwitch . dpdk_initialized
echo "OVS ready"

ovs-vsctl add-br br0 -- set bridge br0 datapath_type=netdev
ovs-vsctl add-port br0 dpdk0 -- set Interface dpdk0 \
    type=dpdk options:dpdk-devargs=${PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_1}
ovs-vsctl add-port br0 dpdk1 -- set Interface dpdk1 \
    type=dpdk options:dpdk-devargs=${PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_2}

ovs-vsctl set open_vswitch . other_config:pmd-auto-lb="true"

ovs-vsctl set Interface dpdk0 options:n_rxq=3
ovs-vsctl set Interface dpdk0 options:n_txq=3
ovs-vsctl set Interface dpdk1 options:n_rxq=3
ovs-vsctl set Interface dpdk1 options:n_txq=3

ip link set br0 up
sleep 2

ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x0800,nw_dst=18.0.0.1,dl_dst=70:00:00:00:00:03,actions=mod_dl_src=70:00:00:00:00:04,mod_dl_dst=50:00:00:00:00:02,output:2
ovs-ofctl add-flow br0 in_port=2,dl_type=0x0800,nw_dst=17.0.0.2,dl_dst=70:00:00:00:00:04,actions=mod_dl_src=70:00:00:00:00:03,mod_dl_dst=50:00:00:00:00:01,output:1

tail -f /var/log/openvswitch/ovs-vswitchd.log
