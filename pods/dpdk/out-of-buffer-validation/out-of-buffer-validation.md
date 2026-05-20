# Out-Of-Buffer Validation

Goal: overload `testpmd` so the Mellanox InfiniBand hardware counter

```text
/sys/class/infiniband/mlx5_*/ports/*/hw_counters/out_of_buffer
```

starts increasing while `pktgen` is blasting traffic at it.

The `out-of-buffer-validation` pod manifests are intentionally unbalanced now:

- `testpmd` pod: `cpu: 2`
  - one lcore is the testpmd main lcore
  - one lcore is the single forwarding core
- `pktgen` pod: `cpu: 6`
  - enough lcores to drive both ports harder than testpmd can keep up with

## 1. Inside the `testpmd` pod: watch the hardware counters

Open one shell into the `testpmd` pod and run:

```bash
while true; do
  date
  for f in /sys/class/infiniband/mlx5_*/ports/*/hw_counters/*; do
    printf "%s = " "$f"
    cat "$f"
  done
  echo
  sleep 1
done
```

If you want a one-time baseline first:

```bash
for f in /sys/class/infiniband/mlx5_*/ports/*/hw_counters/out_of_buffer; do
  printf "%s = " "$f"
  cat "$f"
done
```

## 2. Inside a second shell in the `testpmd` pod: start testpmd

Check the allocated CPUs and SR-IOV devices:

```bash
echo "$(cat /sys/fs/cgroup/cpuset.cpus)"
env | grep PCIDEVICE_OPENSHIFT_IO_DPDK_NIC
```

Start `testpmd`:

```bash
/opt/scripts/run-testpmd-mac.sh
```

Inside the `testpmd>` prompt, run:

```text
set promisc all off
start
show port stats all
```

Useful checks while traffic is running:

```text
show port stats all
show port xstats all
show config fwd
show fwd stats all
```

## 3. Inside the `pktgen` pod: start pktgen

Check the allocated CPUs and SR-IOV devices:

```bash
echo "$(cat /sys/fs/cgroup/cpuset.cpus)"
env | grep PCIDEVICE_OPENSHIFT_IO_DPDK_NIC
```

Start `pktgen`:

```bash
/opt/scripts/run-pktgen.sh
```

## 4. Inside the `Pktgen:/>` prompt: blast traffic on both ports

Use small packets and line-rate transmit so `testpmd` falls behind:

```text
set 0 src mac 50:00:00:00:00:11
set 0 dst mac 60:00:00:00:00:11
set 0 src ip 16.0.0.2/24
set 0 dst ip 16.0.0.1
set 0 proto udp
set 0 size 64
set 0 rate 100
set 0 txburst 128

set 1 src mac 50:00:00:00:00:12
set 1 dst mac 60:00:00:00:00:12
set 1 src ip 17.0.0.2/24
set 1 dst ip 17.0.0.1
set 1 proto udp
set 1 size 64
set 1 rate 100
set 1 txburst 128

start all
```

Useful `pktgen` checks:

```text
page main
page stats
stop all
quit
```

## Expected result

While `pktgen` is running at full rate and `testpmd` is limited to a single
forwarding core, the `out_of_buffer` values on the `testpmd` side should start
going up.

You should also see pressure in:

- `testpmd` port stats
- `testpmd` xstats
- `pktgen` TX/RX counters

## Optional reset check

After stopping traffic:

```text
Pktgen:/> stop all
testpmd> stop
```

Then rerun the one-shot counter read in the `testpmd` pod to compare the final
values against your baseline.
