# Pktgen/Testpmd Scenario

This folder mirrors the existing `pods/dpdk/trex` layout, but uses the
`quay.io/schseba/pktgen-dpdk:latest` image so you can drive traffic directly
between `pktgen` and `testpmd`.

The default two-port MACs are:

- `pktgen` port 0: `50:00:00:00:00:11`
- `pktgen` port 1: `50:00:00:00:00:12`
- `testpmd` port 0: `60:00:00:00:00:11`
- `testpmd` port 1: `60:00:00:00:00:12`

Both manifests attach two interfaces from `dpdk-network-1` in the `seba`
namespace. Update the network name, namespace, resources, or fixed MAC
addresses if your cluster uses different values.

## Deploy

```bash
oc apply -f pods/dpdk/pktgen/testpmd.yaml
oc apply -f pods/dpdk/pktgen/pktgen.yaml
```

## Start testpmd in two-port MAC forwarding mode

```bash
oc rsh -n seba pod/testpmd
/opt/scripts/run-testpmd-mac.sh
```

Inside `testpmd`:

```text
set promisc all off
start
show port stats all
```

## Start pktgen

```bash
oc rsh -n seba pod/pktgen
/opt/scripts/run-pktgen.sh
```

You can also pass the two PCI addresses explicitly if you do not want to rely on
the SR-IOV device environment variables exported by the pod:

```bash
/opt/scripts/run-pktgen.sh 0000:86:00.2 0000:86:00.3
```

`run-pktgen.sh` builds and runs:

```text
pktgen -l <main,rx0,rx1,tx0,tx1> -n 4 -a <PCI0> -a <PCI1> -- -T -P -m "[rx0:tx0].0,[rx1:tx1].1"
```

Startup flags used by the wrapper:

- `-l`: pins the pktgen main thread plus one RX/TX worker pair per port to
  dedicated CPUs from the pod cpuset.
- `-n 4`: sets the DPDK memory channel count. Keep it aligned with your node
  topology unless you know you need a different value.
- `-a <PCI>`: attaches a VF to DPDK. The helper adds one `-a` per SR-IOV VF.
- `--`: separates EAL options from pktgen application options.
- `-T`: enables the text user interface in the terminal.
- `-P`: enables promiscuous mode so the generator can receive return traffic
  without extra NIC filtering setup.
- `-m "[rx:tx].port"`: maps an RX core and TX core to a pktgen port. The helper
  uses one mapping for port `0` and one for port `1`.

Inside `pktgen`, configure both ports so traffic enters `testpmd` on the
matching VF and gets forwarded back to the opposite `pktgen` VF:

```text
set 0 src mac 50:00:00:00:00:11
set 0 dst mac 60:00:00:00:00:11
set 0 src ip 16.0.0.2/24
set 0 dst ip 16.0.0.1
set 0 proto udp
set 0 size 64
set 0 rate 100

set 1 src mac 50:00:00:00:00:12
set 1 dst mac 60:00:00:00:00:12
set 1 src ip 17.0.0.2/24
set 1 dst ip 17.0.0.1
set 1 proto udp
set 1 size 64
set 1 rate 100

start all
```

Useful `pktgen` commands while the stream is running:

```text
page stats
page main
stop all
quit
```

Useful per-port stream options in the interactive pktgen CLI:

```text
set <port> count <packets>
set <port> rate <percent>
set <port> size <bytes>
set <port> burst <packets>
set <port> ttl <value>
set <port> sport <port>
set <port> dport <port>
set <port> vlanid <id>
enable <port> vlan
disable <port> vlan
range <port> on
range <port> off
```

What these options are useful for:

- `count`: sends a fixed number of packets instead of running forever.
- `rate`: controls link utilization as a percentage of the configured line rate.
- `size`: changes frame size; use this to compare minimum-size packets versus
  larger payloads.
- `burst`: changes how many packets each TX loop submits at a time.
- `ttl`, `sport`, `dport`: adjust L3/L4 headers when you want a flow to look
  more realistic or steer traffic differently.
- `vlanid` with `enable/disable vlan`: adds or removes 802.1Q tagging.
- `range on/off`: enables ranged traffic fields if you want pktgen to sweep IPs,
  ports, or other headers instead of sending a single fixed stream.

Additional inspection commands that are handy while tuning:

```text
page range
page seq
enable <port> pcap
disable <port> pcap
clr
restart <port>
```

Useful `testpmd` commands while receiving:

```text
show port stats all
show port xstats all
stop
quit
```

## Notes

- The helper scripts assume two SR-IOV attachments, so they use
  `PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_1` and `PCIDEVICE_OPENSHIFT_IO_DPDK_NIC_2`.
- `run-pktgen.sh` automatically picks the first five CPUs from the pod cpuset
  and maps them as `main`, `RX0`, `RX1`, `TX0`, and `TX1`.
- If the pktgen UI does not render correctly after reconnecting with `oc rsh`,
  run `page main` or `clr` to redraw the active screen.
- If you want a different traffic profile, start `pktgen` with
  `/opt/scripts/run-pktgen.sh` and then use the interactive CLI to adjust the
  stream settings.
