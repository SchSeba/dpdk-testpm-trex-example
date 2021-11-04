set -ex
export CPU=$(cat /sys/fs/cgroup/cpuset/cpuset.cpus)
echo ${CPU}

dpdk-testpmd -l ${CPU} -a ${PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_3} -a ${PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_4} -- -i --nb-cores=2 --rxd=4096 --txd=4096 --forward-mode=mac --eth-peer=0,50:00:00:00:00:01 --eth-peer=1,50:00:00:00:00:02