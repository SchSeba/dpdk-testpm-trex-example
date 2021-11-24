set -ex
ip tuntap add tap23 mode tap multi_queue
export CPU=$(cat /sys/fs/cgroup/cpuset/cpuset.cpus)
echo ${CPU}

dpdk-testpmd -l ${CPU} --vdev net_tap0,iface=tap23 -w ${PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_3} -- -i
