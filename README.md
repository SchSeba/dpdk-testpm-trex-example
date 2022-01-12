# dpdk-testpm-trex-example

### Deployment:

#### Create the namespace

```bash
oc apply -f namespace.yaml
```

#### Performance profile

There is an example profile under the pao-config folder, you need to update it with
the right parameters depending on your environment. [PAO documentation](https://docs.openshift.com/container-platform/4.9/scalability_and_performance/cnf-performance-addon-operator-for-low-latency-nodes.html)

On a system with HyperThread enabled it's important to have both cpus in the same list of
the performance profile

For example:

```bash
[core@cnfdt05 ~]$ lscpu 
Architecture:        x86_64
CPU op-mode(s):      32-bit, 64-bit
Byte Order:          Little Endian
CPU(s):              104
On-line CPU(s) list: 0-103
Thread(s) per core:  2
Core(s) per socket:  26
Socket(s):           2
NUMA node(s):        2
Vendor ID:           GenuineIntel
CPU family:          6
Model:               85
Model name:          Intel(R) Xeon(R) Gold 6230R CPU @ 2.10GHz
Stepping:            7
CPU MHz:             999.997
BogoMIPS:            4200.00
Virtualization:      VT-x
L1d cache:           32K
L1i cache:           32K
L2 cache:            1024K
L3 cache:            36608K
NUMA node0 CPU(s):   0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62,64,66,68,70,72,74,76,78,80,82,84,86,88,90,92,94,96,98,100,102
NUMA node1 CPU(s):   1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35,37,39,41,43,45,47,49,51,53,55,57,59,61,63,65,67,69,71,73,75,77,79,81,83,85,87,89,91,93,95,97,99,101,103
Flags:               fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc art arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 sdbg fma cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm abm 3dnowprefetch cpuid_fault epb cat_l3 cdp_l3 invpcid_single intel_ppin ssbd mba ibrs ibpb stibp ibrs_enhanced tpr_shadow vnmi flexpriority ept vpid ept_ad fsgsbase tsc_adjust bmi1 hle avx2 smep bmi2 erms invpcid cqm mpx rdt_a avx512f avx512dq rdseed adx smap clflushopt clwb intel_pt avx512cd avx512bw avx512vl xsaveopt xsavec xgetbv1 xsaves cqm_llc cqm_occup_llc cqm_mbm_total cqm_mbm_local dtherm ida arat pln pts pku ospke avx512_vnni md_clear flush_l1d arch_capabilities
```

CPU siblings:
```bash
cat /sys/devices/system/cpu/cpu0/topology/core_cpus_list
0,52
```

Performance profile:

```bash
apiVersion: performance.openshift.io/v2
kind: PerformanceProfile
metadata:
  name: performance
spec:
  cpu:
    isolated: 21-51,73-103
    reserved: 0-20,52-72
  hugepages:
    defaultHugepagesSize: 1G
    pages:
    - count: 32
      size: 1G
  numa:  
    topologyPolicy: "single-numa-node"
  nodeSelector:
    node-role.kubernetes.io/worker-cnf: ""
```

Also it's important to request the topologyPolicy to be `single-numa-node`

#### SR-IOV configuration

For the sriov configuration it is important to understand the interface vendor
and match the configuration, take a look on the [openshift documentation](https://docs.openshift.com/container-platform/4.9/networking/hardware_networks/using-dpdk-and-rdma.html)

Examples exist under the [sriov-configs folder](./sriov-configs) for both mlx and intel nics.

### Trex build

To build TREX please use the following command and the push the image to a registry.
The image is also available under `quay.io/schseba/trex:latest`

```bash
make build-trex
```

### Testpmd

It is possible to build u/s dpdk using the following command, the image is also available
under `quay.io/schseba/dpdk:latest`. But for best performance it's better to use the image provided in the redhat
registry `registry.redhat.io/openshift4/dpdk-base-rhel8:latest`

```bash
build-dpdk
```

## Run testpmd

### Manual

It is possible to run testpmd by accessing the container after it's running but that can
impact the performance because the exec command is not attached to one CPU and can create interrupts

Update the networks name depending on the sriovNetwork CR applied on the cluster before and then create the pod

```
oc apply -f pods/testpmd.yaml
```

When the container is running exec into it and run the testpmd application

```bash
export CPU=$(cat /sys/fs/cgroup/cpuset/cpuset.cpus)
echo ${CPU}

dpdk-testpmd -l ${CPU} -a ${PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_3} -a ${PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_4} --socket-mem 8192,0 -- -i --nb-cores=15 --rxd=4096 --txd=4096 --rxq=15 --txq=15 --forward-mode=mac --eth-peer=0,50:00:00:00:00:01 --eth-peer=1,50:00:00:00:00:02
```

output example:
```bash
sh-4.4# export CPU=$(cat /sys/fs/cgroup/cpuset/cpuset.cpus)
sh-4.4# echo ${CPU}
22,24,26,28,30,32,34,36,74,76,78,80,82,84,86,88
sh-4.4# dpdk-testpmd -l ${CPU} -a ${PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_3} -a ${PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_4} --socket-mem 8192,0 -- -i --nb-cores=15 --rxd=4096 --txd=4096 --rxq=15 --txq=15 --forward-mode=mac --eth-peer=0,50:00:00:00:00:01 --eth-peer=1,50:00:00:00:00:02
EAL: Detected 104 lcore(s)
EAL: Detected 2 NUMA nodes
EAL: Multi-process socket /var/run/dpdk/rte/mp_socket
EAL: Selected IOVA mode 'VA'
EAL: No available hugepages reported in hugepages-2048kB
EAL: Probing VFIO support...
EAL:   cannot open VFIO container, error 2 (No such file or directory)
EAL: VFIO support could not be initialized
EAL: Probe PCI driver: mlx5_pci (15b3:1018) device: 0000:5e:00.6 (socket 0)
mlx5_pci: No available register for Sampler.
mlx5_pci: Size 0xFFFF is not power of 2, will be aligned to 0x10000.
EAL: Probe PCI driver: mlx5_pci (15b3:1018) device: 0000:5e:01.0 (socket 0)
mlx5_pci: No available register for Sampler.
mlx5_pci: Size 0xFFFF is not power of 2, will be aligned to 0x10000.
EAL: No legacy callbacks, legacy socket not created
Interactive-mode selected
Set mac packet forwarding mode
testpmd: create a new mbuf pool <mb_pool_0>: n=267456, size=2176, socket=0
testpmd: preferred mempool ops selected: ring_mp_mc
Configuring Port 0 (socket 0)
Port 0: 60:00:00:00:00:01
Configuring Port 1 (socket 0)
Port 1: 60:00:00:00:00:02
Checking link statuses...
Done
testpmd>
```

*note:* Change the `PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_*` depending on the sriovNetwork you it was attached to the pod
(it's possible to check it using `env | grep PCIDEVICE_OPENSHIFT_IO`)

*note:* it's good to check that allocated CPUs are all from the same numa and siblings, also check they are on the same
numa as the network nics and the hugepages

To check cpu list, siblings and numa

```bash
cat /sys/fs/cgroup/cpuset/cpuset.cpus
22,24,26,28,30,32,34,36,74,76,78,80,82,84,86,88
cat /sys/devices/system/cpu/cpu22/topology/core_cpus_list
22,74

ls /sys/devices/system/cpu/cpu22/ -la
total 0
drwxr-xr-x.   9 root root    0 Nov 14 15:37 .
drwxr-xr-x. 113 root root    0 Nov 14 15:37 ..
drwxr-xr-x.   6 root root    0 Nov 15 13:27 cache
drwxr-xr-x.   6 root root    0 Nov 15 13:27 cpuidle
-r--------.   1 root root 4096 Nov 15 13:27 crash_notes
-r--------.   1 root root 4096 Nov 15 13:27 crash_notes_size
lrwxrwxrwx.   1 root root    0 Nov 15 13:27 driver -> ../../../../bus/cpu/drivers/processor
lrwxrwxrwx.   1 root root    0 Nov 15 13:27 firmware_node -> ../../../LNXSYSTM:00/LNXSYBUS:00/ACPI0004:00/LNXCPU:0b
drwxr-xr-x.   2 root root    0 Nov 15 13:27 hotplug
drwxr-xr-x.   2 root root    0 Nov 15 13:27 microcode
lrwxrwxrwx.   1 root root    0 Nov 15 13:27 node0 -> ../../node/node0
-rw-r--r--.   1 root root 4096 Nov 15 13:27 online
drwxr-xr-x.   2 root root    0 Nov 15 13:27 power
lrwxrwxrwx.   1 root root    0 Nov 15 13:27 subsystem -> ../../../../bus/cpu
drwxr-xr-x.   2 root root    0 Nov 15 13:27 thermal_throttle
drwxr-xr-x.   2 root root    0 Nov 14 15:37 topology
-rw-r--r--.   1 root root 4096 Nov 15 13:27 uevent
```
```bash
node0 -> numa 0
node1 -> numa 1
```

To check numa for an interface

```bash
lspci -v -nn -mm -k -s ${PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_3}
Slot:	5e:00.6
Class:	Ethernet controller [0200]
Vendor:	Mellanox Technologies [15b3]
Device:	MT27800 Family [ConnectX-5 Virtual Function] [1018]
SVendor:	Mellanox Technologies [15b3]
SDevice:	Device [0091]
Driver:	mlx5_core
lspci: Unable to load libkmod resources: error -12
NUMANode:	0
IOMMUGroup:	160

```

When testpmd is up is good to disable the promiscuous mode by running `set promisc all off`

Last step is to run the testpmd
```bash
start
mac packet forwarding - ports=2 - cores=15 - streams=30 - NUMA support enabled, MP allocation mode: native
Logical Core 24 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=0 (socket 0) -> TX P=1/Q=0 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=0 (socket 0) -> TX P=0/Q=0 (socket 0) peer=50:00:00:00:00:01
Logical Core 26 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=1 (socket 0) -> TX P=1/Q=1 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=1 (socket 0) -> TX P=0/Q=1 (socket 0) peer=50:00:00:00:00:01
Logical Core 28 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=2 (socket 0) -> TX P=1/Q=2 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=2 (socket 0) -> TX P=0/Q=2 (socket 0) peer=50:00:00:00:00:01
Logical Core 30 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=3 (socket 0) -> TX P=1/Q=3 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=3 (socket 0) -> TX P=0/Q=3 (socket 0) peer=50:00:00:00:00:01
Logical Core 32 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=4 (socket 0) -> TX P=1/Q=4 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=4 (socket 0) -> TX P=0/Q=4 (socket 0) peer=50:00:00:00:00:01
Logical Core 34 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=5 (socket 0) -> TX P=1/Q=5 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=5 (socket 0) -> TX P=0/Q=5 (socket 0) peer=50:00:00:00:00:01
Logical Core 36 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=6 (socket 0) -> TX P=1/Q=6 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=6 (socket 0) -> TX P=0/Q=6 (socket 0) peer=50:00:00:00:00:01
Logical Core 74 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=7 (socket 0) -> TX P=1/Q=7 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=7 (socket 0) -> TX P=0/Q=7 (socket 0) peer=50:00:00:00:00:01
Logical Core 76 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=8 (socket 0) -> TX P=1/Q=8 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=8 (socket 0) -> TX P=0/Q=8 (socket 0) peer=50:00:00:00:00:01
Logical Core 78 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=9 (socket 0) -> TX P=1/Q=9 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=9 (socket 0) -> TX P=0/Q=9 (socket 0) peer=50:00:00:00:00:01
Logical Core 80 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=10 (socket 0) -> TX P=1/Q=10 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=10 (socket 0) -> TX P=0/Q=10 (socket 0) peer=50:00:00:00:00:01
Logical Core 82 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=11 (socket 0) -> TX P=1/Q=11 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=11 (socket 0) -> TX P=0/Q=11 (socket 0) peer=50:00:00:00:00:01
Logical Core 84 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=12 (socket 0) -> TX P=1/Q=12 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=12 (socket 0) -> TX P=0/Q=12 (socket 0) peer=50:00:00:00:00:01
Logical Core 86 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=13 (socket 0) -> TX P=1/Q=13 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=13 (socket 0) -> TX P=0/Q=13 (socket 0) peer=50:00:00:00:00:01
Logical Core 88 (socket 0) forwards packets on 2 streams:
  RX P=0/Q=14 (socket 0) -> TX P=1/Q=14 (socket 0) peer=50:00:00:00:00:02
  RX P=1/Q=14 (socket 0) -> TX P=0/Q=14 (socket 0) peer=50:00:00:00:00:01

  mac packet forwarding packets/burst=32
  nb forwarding cores=15 - nb forwarding ports=2
  port 0: RX queue number: 15 Tx queue number: 15
    Rx offloads=0x0 Tx offloads=0x0
    RX queue: 0
      RX desc=4096 - RX free threshold=64
      RX threshold registers: pthresh=0 hthresh=0  wthresh=0
      RX Offloads=0x0
    TX queue: 0
      TX desc=4096 - TX free threshold=0
      TX threshold registers: pthresh=0 hthresh=0  wthresh=0
      TX offloads=0x0 - TX RS bit threshold=0
  port 1: RX queue number: 15 Tx queue number: 15
    Rx offloads=0x0 Tx offloads=0x0
    RX queue: 0
      RX desc=4096 - RX free threshold=64
      RX threshold registers: pthresh=0 hthresh=0  wthresh=0
      RX Offloads=0x0
    TX queue: 0
      TX desc=4096 - TX free threshold=0
      TX threshold registers: pthresh=0 hthresh=0  wthresh=0
      TX offloads=0x0 - TX RS bit threshold=0
```

Useful commands to check status:

```bash
show port stats all

show port xstats all

show fwd stats all

show config fwd
```

To stop just run `stop` and for exiting testpmd run `quit`

### Automatic

TDB


## Start Trex

Before starting Trex you need to update the [trex yaml](pods/dpdk/trex/trex.yaml) in multiple places

* numa selection `SOCKET: "1"`
* interface environments `interfaces: ["${PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_1}","${PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_2}"]`
* networks in the pod annotation definition ` "name": "dpdk-network-1",`

Then you can apply the pod, after the pod is in running state you can execute into it.
To access the trex commandline ui run `./trex-console` and then `tui` that will open the dashboard.

To run a benchmark test it possible to use one if the profiles provided by trex under on if the following folders
* /opt/trex/astf/
* /opt/trex/stl/

Another option is to use the script provided as a configmap under /opt/tests/test.py

Example of a command for trex to send 12mpps bidirectional

```bash
tui>start -f /opt/tests/test.py -m 12mpps 
```

Output:
```bash
Global Statistitcs

connection   : localhost, Port 4501                       total_tx_L2  : 13.19 Gbps                     
version      : STL @ v2.87                                total_tx_L1  : 17.31 Gbps                     
cpu_util.    : 27.27% @ 14 cores (14 per dual port)       total_rx     : 13.61 Gbps                     
rx_cpu_util. : 0.0% / 0 pps                               total_pps    : 25.76 Mpps                     
async_util.  : 0.03% / 11.5 Kbps                          drop_rate    : 0 bps                          
total_cps.   : 0 cps                                      queue_full   : 0 pkts                         

Port Statistics

   port    |         0         |         1         |       total       
-----------+-------------------+-------------------+------------------
owner      |              root |              root |                   
link       |                UP |                UP |                   
state      |      TRANSMITTING |      TRANSMITTING |                   
speed      |           25 Gb/s |           25 Gb/s |                   
CPU util.  |            27.27% |            27.27% |                   
--         |                   |                   |                   
Tx bps L2  |         6.59 Gbps |         6.59 Gbps |        13.19 Gbps 
Tx bps L1  |         8.66 Gbps |         8.65 Gbps |        17.31 Gbps 
Tx pps     |        12.88 Mpps |        12.88 Mpps |        25.76 Mpps 
Line Util. |           34.62 % |           34.62 % |                   
---        |                   |                   |                   
Rx bps     |          6.8 Gbps |         6.81 Gbps |        13.61 Gbps 
Rx pps     |         12.5 Mpps |        12.51 Mpps |        25.01 Mpps 
----       |                   |                   |                   
opackets   |        1449180458 |        1449568714 |        2898749172 
ipackets   |        1406023842 |        1408393436 |        2814417278 
obytes     |       92747548712 |       92772397696 |      185519946408 
ibytes     |       95609632756 |       95770764892 |      191380397648 
tx-pkts    |        1.45 Gpkts |        1.45 Gpkts |         2.9 Gpkts 
rx-pkts    |        1.41 Gpkts |        1.41 Gpkts |        2.81 Gpkts 
tx-bytes   |          92.75 GB |          92.77 GB |         185.52 GB 
rx-bytes   |          95.61 GB |          95.77 GB |         191.38 GB 
-----      |                   |                   |                   
oerrors    |                 0 |                 0 |                 0 
ierrors    |         8,288,289 |         7,708,209 |        15,996,498 

status:  /

Press 'ESC' for navigation panel...
status: [OK]

tui>
```

To stop just run `stop -a`


# Sriov kernel tests

using iperf
```bash

```