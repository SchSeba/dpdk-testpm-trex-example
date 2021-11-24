export CPU=$(cat /sys/fs/cgroup/cpuset/cpuset.cpus)
echo ${CPU}
dpdk-testpmd -l ${CPU} -w ${PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_3} -- -i --forward-mode txonly --eth-peer=0,60:00:00:00:00:01
