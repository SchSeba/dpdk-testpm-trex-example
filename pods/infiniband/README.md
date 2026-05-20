# InfiniBand SR-IOV VFs in Kubernetes - Complete End-to-End Guide

This guide provides a complete workflow for deploying InfiniBand SR-IOV VFs in Kubernetes using the SR-IOV Network Operator with MLNX_OFED OpenSM.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1: SR-IOV Operator Configuration](#step-1-sr-iov-operator-configuration)
- [Step 2: Deploy OpenSM](#step-2-deploy-opensm)
- [Step 3: Configure VF GUIDs (Host)](#step-3-configure-vf-guids-host)
- [Step 4: Deploy Test Pods](#step-4-deploy-test-pods)
- [Step 5: Running Tests](#step-5-running-tests)
- [Troubleshooting](#troubleshooting)
- [References](#references)

---

## Prerequisites

- Kubernetes/OpenShift cluster with SR-IOV Network Operator installed
- ConnectX-4 or newer HCA with InfiniBand capability
- Network access to `linux.mellanox.com` for MLNX_OFED packages
- For back-to-back testing: two IB ports connected directly (no switch required)

---

## Step 1: SR-IOV Operator Configuration

### 1.1 Create Namespace

```bash
kubectl create namespace seba
```

### 1.2 SriovNetworkNodePolicy

Create the SR-IOV policy to configure VFs with InfiniBand mode and proper MTU.

**File: `sriov-policy.yaml`**
```yaml
# this policy is need so we switch the interface to infiniband
# but after that the interface name changes from ens4f0np0 to ibs4f0 so we create the real policy for the new interface
---
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovNetworkNodePolicy
metadata:
  name: temp-nic-1
  namespace: openshift-sriov-network-operator
spec:
  deviceType: netdevice
  linkType: IB
  isRdma: true
  nicSelector:
    pfNames: ["ens4f0np0"]
  nodeSelector:
    kubernetes.io/hostname: worker-0
  numVfs: 16
  priority: 99
  resourceName: temp_nic_1
---
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovNetworkNodePolicy
metadata:
  name: ib-vfio-nic-1
  namespace: openshift-sriov-network-operator
spec:
  deviceType: vfio-pci
  linkType: IB
  nicSelector:
    pfNames: ["ibs4f0#0-9"]
  nodeSelector:
    kubernetes.io/hostname: worker-0
  numVfs: 16
  priority: 99
  resourceName: ib_vfio_nic_1
---
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovNetworkNodePolicy
metadata:
  name: ib-nic-1
  namespace: openshift-sriov-network-operator
spec:
  deviceType: netdevice
  isRdma: true
  linkType: IB
  nicSelector:
    pfNames: ["ibs4f0#10-15"]
  nodeSelector:
    kubernetes.io/hostname: worker-0
  numVfs: 16
  priority: 99
  resourceName: ib_nic_1
---
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovIBNetwork
metadata:
  name: ib-vfio-network-1
  namespace: openshift-sriov-network-operator
spec:
  ipam: |
    {
      "type": "host-local",
      "ranges": [[{"subnet": "192.168.100.0/24"}]],
      "dataDir": "/run/cni/ipam/ib-network"
    }
  networkNamespace: seba
  resourceName: ib_vfio_nic_1
  linkState: enable
---
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovIBNetwork
metadata:
  name: ib-network-1
  namespace: openshift-sriov-network-operator
spec:
  ipam: |
    {
      "type": "host-local",
      "ranges": [[{"subnet": "192.168.100.0/24"}]],
      "dataDir": "/run/cni/ipam/ib-network"
    }
  networkNamespace: seba
  resourceName: ib_nic_1
  linkState: enable
---
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovNetworkNodePolicy
metadata:
  name: temp-nic-2
  namespace: openshift-sriov-network-operator
spec:
  deviceType: netdevice
  linkType: IB
  isRdma: true
  nicSelector:
    pfNames: ["ens4f1np1"]
  nodeSelector:
    kubernetes.io/hostname: worker-0
  numVfs: 16
  priority: 99
  resourceName: temp_nic_2
---
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovNetworkNodePolicy
metadata:
  name: ib-vfio-nic-2
  namespace: openshift-sriov-network-operator
spec:
  deviceType: vfio-pci
  linkType: IB
  nicSelector:
    pfNames: ["ibs4f1#0-9"]
  nodeSelector:
    kubernetes.io/hostname: worker-0
  numVfs: 16
  priority: 99
  resourceName: ib_vfio_nic_2
---
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovNetworkNodePolicy
metadata:
  name: ib-nic-2
  namespace: openshift-sriov-network-operator
spec:
  deviceType: netdevice
  isRdma: true
  linkType: IB
  nicSelector:
    pfNames: ["ibs4f1#10-15"]
  nodeSelector:
    kubernetes.io/hostname: worker-0
  numVfs: 16
  priority: 99
  resourceName: ib_nic_2
```

> **Note:** If your interface starts as Ethernet (e.g., `ens4f0np0`), you may need a temporary policy to switch it to IB mode first. After reboot, the interface will be renamed to `ibs4f0`.

Apply the policy:
```bash
kubectl apply -f sriov-policy.yaml
```

Wait for the node to be configured (may require reboot):
```bash
kubectl get sriovnetworknodestates -n openshift-sriov-network-operator -w
```

### 1.3 SriovIBNetwork with IPAM

Create the IB network with static IP assignment for IPoIB testing.

**File: `sriov-network.yaml`**
```yaml
---
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovIBNetwork
metadata:
  name: ib-vfio-network-1
  namespace: openshift-sriov-network-operator
spec:
  ipam: |
    {
      "type": "host-local",
      "ranges": [[{"subnet": "192.168.100.0/24"}]],
      "dataDir": "/run/cni/ipam/ib-network"
    }
  networkNamespace: seba
  resourceName: ib_vfio_nic_1
  linkState: enable
---
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovIBNetwork
metadata:
  name: ib-network-1
  namespace: openshift-sriov-network-operator
spec:
  ipam: |
    {
      "type": "host-local",
      "ranges": [[{"subnet": "192.168.100.0/24"}]],
      "dataDir": "/run/cni/ipam/ib-network"
    }
  networkNamespace: seba
  resourceName: ib_nic_1
  linkState: enable
---
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovIBNetwork
metadata:
  name: ib-vfio-network-2
  namespace: openshift-sriov-network-operator
spec:
  ipam: '{}'
  networkNamespace: seba
  resourceName: ib_vfio_nic_2
  linkState: enable
  ipam: |
    {
      "type": "host-local",
      "ranges": [[{"subnet": "192.168.100.0/24"}]],
      "dataDir": "/run/cni/ipam/ib-network"
    }
---
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovIBNetwork
metadata:
  name: ib-network-2
  namespace: openshift-sriov-network-operator
spec:
  networkNamespace: seba
  resourceName: ib_nic_2
  linkState: enable
  ipam: |
    {
      "type": "host-local",
      "ranges": [[{"subnet": "192.168.100.0/24"}]],
      "dataDir": "/run/cni/ipam/ib-network"
    }
```

Apply the network:
```bash
kubectl apply -f sriov-network.yaml
```

Verify NetworkAttachmentDefinition was created:
```bash
kubectl get net-attach-def -n seba
```

### 1.4 Static VF GUID Configuration (Optional)

For advanced PKey management, you can use static GUID configuration. Create a JSON file at `/etc/sriov-operator/infiniband/guids` on the host:

```json
[
  {
    "pci_address": "0000:af:00.0",
    "guidsRange": {
      "start": "50:00:e6:03:00:b4:f0:00",
      "end": "50:00:e6:03:00:b4:f0:0f"
    }
  },
  {
    "pci_address": "0000:af:00.1",
    "guidsRange": {
      "start": "50:00:e6:03:00:b4:f1:00",
      "end": "50:00:e6:03:00:b4:f1:0f"
    }
  }
]
```

See [SR-IOV Network Operator IB VF Configuration](https://github.com/k8snetworkplumbingwg/sriov-network-operator/blob/master/doc/design/ib-vf-configuration.md) for details.

---

## Step 2: Deploy OpenSM

Standard OpenSM doesn't support SR-IOV VF port management. You need MLNX_OFED's OpenSM with `virt_enabled 2`.

### 2.1 Create OpenSM ConfigMap

**File: `opensm-configmap.yaml`**
```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: opensm-config
  namespace: seba
data:
  # NOTE: Options like honor_guid2lid, reassign_lids are passed via command line
  opensm.conf: |
    # Enable SR-IOV VF port management
    # 0 = disabled, 1 = enabled, 2 = enabled with vport awareness
    virt_enabled 2

  partitions.conf: |
    # IPoIB partition config for back-to-back setup
    # mtu=5 means 4096 bytes (IB MTU: 1=256, 2=512, 3=1024, 4=2048, 5=4096)
    # NOTE: Don't specify rate to avoid multicast validation failures
    Default=0x7fff, ipoib, mtu=5:
    	ALL=full;
```

### 2.2 Deploy OpenSM Pod

**File: `opensm.yaml`**

The pod auto-discovers the GUID from the interface name - just set the `IB_INTERFACE` environment variable:

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: opensm
  namespace: seba
  labels:
    app: opensm
spec:
  hostNetwork: true
  hostPID: true
  nodeSelector:
    kubernetes.io/hostname: <your-node-hostname>
  containers:
    - name: opensm
      image: quay.io/centos/centos:stream9
      env:
        # ========================================
        # Configure your IB interface name here!
        # ========================================
        - name: IB_INTERFACE
          value: "ibs4f0"
      command:
        - /bin/bash
        - -c
        - |
          set -e

          echo "=== Discovering PF GUID from interface: $IB_INTERFACE ==="
          
          # Find the RDMA device from the network interface
          RDMA_DEV=$(ls /sys/class/net/${IB_INTERFACE}/device/infiniband/ | head -1)
          echo "Found RDMA device: $RDMA_DEV"
          
          # Get the node GUID and convert to hex format
          GUID_RAW=$(cat /sys/class/infiniband/${RDMA_DEV}/node_guid)
          PF_GUID="0x$(echo $GUID_RAW | tr -d ':')"
          echo "PF GUID: $PF_GUID"

          # Install MLNX_OFED OpenSM
          cat > /etc/yum.repos.d/mlnx_ofed.repo << 'EOF'
          [mlnx_ofed]
          name=MLNX_OFED Repository
          baseurl=https://linux.mellanox.com/public/repo/mlnx_ofed/latest/rhel9.4/x86_64/
          enabled=1
          gpgcheck=0
          EOF

          dnf install -y opensm infiniband-diags libibverbs-utils

          # Copy configs
          cp /opensm-config/opensm.conf /etc/opensm/opensm.conf
          cp /opensm-config/partitions.conf /etc/opensm/partitions.conf

          # Start OpenSM with auto-discovered GUID
          echo "=== Starting OpenSM on $IB_INTERFACE ($RDMA_DEV) with GUID $PF_GUID ==="
          opensm -g $PF_GUID \
                 -F /etc/opensm/opensm.conf \
                 -P /etc/opensm/partitions.conf \
                 --reassign_lids \
                 -f stdout 2>&1 &

          # Monitor status
          sleep 15
          while true; do
            echo "=== $(date) ==="
            sminfo -C $RDMA_DEV -P 1 2>/dev/null || echo "SM not ready"
            ibstat $RDMA_DEV | grep -A 5 "Port 1:" || true
            sleep 60
          done
      securityContext:
        privileged: true
      volumeMounts:
        - name: dev
          mountPath: /dev
        - name: sys
          mountPath: /sys
        - name: opensm-config
          mountPath: /opensm-config
      resources:
        limits:
          cpu: "1"
          memory: 512Mi
  volumes:
    - name: dev
      hostPath:
        path: /dev
    - name: sys
      hostPath:
        path: /sys
    - name: opensm-config
      configMap:
        name: opensm-config
  restartPolicy: Always
```

Deploy OpenSM:
```bash
kubectl apply -f opensm-configmap.yaml
kubectl apply -f opensm.yaml
```

Verify OpenSM is running:
```bash
kubectl logs -n seba opensm -f
# Look for "SUBNET UP" message
```

---

## Step 3: VF GUID Configuration (Automatic)

The **SR-IOV Network Operator automatically assigns GUIDs** to InfiniBand VFs when they are created. You don't need to configure GUIDs manually.

### How It Works

1. The `sriov-network-config-daemon` assigns **random GUIDs** to each VF during creation
2. When a VF is allocated to a pod, it communicates with the Subnet Manager (OpenSM)
3. OpenSM assigns a LID to the VF based on its GUID
4. The VF becomes ACTIVE and ready for RDMA traffic

### Verify VF Configuration

After applying the SriovNetworkNodePolicy, verify VFs have GUIDs:

```bash
# Check VF GUIDs on the host
ip link show ibs4f0 | grep -A 1 "vf 0"
# Should show NODE_GUID and PORT_GUID assigned

# Verify VF ports are ACTIVE (after OpenSM is running)
ibstat mlx5_8 | grep -A 5 "Port 1:"
# Should show State: Active and valid Base lid
```

### Static GUID Configuration (Optional - Advanced)

For advanced use cases like PKey-based network isolation, you can provide static GUIDs via a MachineConfig:

**File: `machineconfig-ib-guids.yaml`**
```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-ib-guid-config
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
        - path: /etc/sriov-operator/infiniband/guids
          mode: 0644
          contents:
            source: data:text/plain;charset=utf-8;base64,WwogIHsKICAgICJwY2lfYWRkcmVzcyI6ICIwMDAwOmFmOjAwLjAiLAogICAgImd1aWRzUmFuZ2UiOiB7CiAgICAgICJzdGFydCI6ICI1MDowMDplNjowMzowMDpiNDpmMDowMCIsCiAgICAgICJlbmQiOiAiNTA6MDA6ZTY6MDM6MDA6YjQ6ZjA6MGYiCiAgICB9CiAgfQpd
```

The base64-encoded content is:
```json
[
  {
    "pci_address": "0000:af:00.0",
    "guidsRange": {
      "start": "50:00:e6:03:00:b4:f0:00",
      "end": "50:00:e6:03:00:b4:f0:0f"
    }
  }
]
```

See [SR-IOV Network Operator IB VF Configuration](https://github.com/k8snetworkplumbingwg/sriov-network-operator/blob/master/doc/design/ib-vf-configuration.md) for details.

---

## Step 4: Deploy Test Pods

### 4.1 Server Pod

**File: `server.yaml`**
```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: infiniband-server
  namespace: seba
  annotations:
    k8s.v1.cni.cncf.io/networks: '[{"name": "ib-network-2", "namespace": "seba"}]'
spec:
  containers:
    - name: netperf
      image: quay.io/cloud-bulldozer/k8s-netperf:latest
      command: ["/bin/bash", "-c", "dnf install -y perftest infiniband-diags; sleep INF"]
      securityContext:
        capabilities:
          add: [IPC_LOCK, NET_RAW, NET_ADMIN]
      resources:
        limits:
          cpu: "2"
          memory: 1Gi
          openshift.io/ib_nic_2: "1"   # Request IB VF
```

### 4.2 Client Pod

**File: `client.yaml`**
```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: infiniband-client
  namespace: seba
  annotations:
    k8s.v1.cni.cncf.io/networks: '[{"name": "ib-network-1", "namespace": "seba"}]'
spec:
  containers:
    - name: netperf
      image: quay.io/cloud-bulldozer/k8s-netperf:latest
      command: ["/bin/bash", "-c", "dnf install -y perftest infiniband-diags; sleep INF"]
      securityContext:
        capabilities:
          add: [IPC_LOCK, NET_RAW, NET_ADMIN]
      resources:
        limits:
          cpu: "2"
          memory: 1Gi
          openshift.io/ib_nic_1: "1"   # Request IB VF
```

Deploy the pods:
```bash
kubectl apply -f server.yaml
kubectl apply -f client.yaml
kubectl wait --for=condition=Ready pod/infiniband-server pod/infiniband-client -n seba --timeout=120s
```

---

## Step 5: Running Tests

### 5.1 Verify IB Connectivity

Check allocated VF devices:
```bash
# Server
kubectl exec -n seba infiniband-server -- bash -c 'env | grep PCIDEVICE'
kubectl exec -n seba infiniband-server -- ibstat

# Client
kubectl exec -n seba infiniband-client -- bash -c 'env | grep PCIDEVICE'
kubectl exec -n seba infiniband-client -- ibstat
```

### 5.2 RDMA Test via Pod IP (TCP Control Channel)

This uses the Kubernetes pod network for TCP control and IB for RDMA data:

```bash
# Get server pod IP
SERVER_IP=$(kubectl get pod -n seba infiniband-server -o jsonpath='{.status.podIP}')

# Start server (replace mlx5_X with your device)
kubectl exec -n seba infiniband-server -- ib_write_bw -d mlx5_18 --report_gbits &

# Run client after 5 seconds
sleep 5
kubectl exec -n seba infiniband-client -- ib_write_bw -d mlx5_8 $SERVER_IP --report_gbits
```

Expected output:
```
RDMA_Write BW Test
Mtu             : 4096[B]
Link type       : IB
Data ex. method : Ethernet

local address: LID 0x03 QPN 0x0152
remote address: LID 0x0d QPN 0x08bc

#bytes     #iterations    BW peak[Gb/sec]    BW average[Gb/sec]
65536      5000             1.98               1.98
```

### 5.3 RDMA Test via IPoIB

This uses IPoIB for both TCP control and RDMA data:

```bash
# Configure IPoIB IPs (if not using IPAM)
kubectl exec -n seba infiniband-server -- ip addr add 192.168.100.1/24 dev net1
kubectl exec -n seba infiniband-client -- ip addr add 192.168.100.2/24 dev net1

# Verify IPoIB is up
kubectl exec -n seba infiniband-server -- ip link show net1
# Should show: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 4092 state UP

# Start server
kubectl exec -n seba infiniband-server -- ib_write_bw -d mlx5_18 --report_gbits &

# Run client via IPoIB
sleep 5
kubectl exec -n seba infiniband-client -- ib_write_bw -d mlx5_8 192.168.100.1 --report_gbits
```

### 5.4 Additional RDMA Tests

```bash
# Latency test
kubectl exec -n seba infiniband-server -- ib_write_lat -d mlx5_18 &
sleep 5
kubectl exec -n seba infiniband-client -- ib_write_lat -d mlx5_8 $SERVER_IP

# Send bandwidth test
kubectl exec -n seba infiniband-server -- ib_send_bw -d mlx5_18 --report_gbits &
sleep 5
kubectl exec -n seba infiniband-client -- ib_send_bw -d mlx5_8 $SERVER_IP --report_gbits
```

---

## Troubleshooting

### VFs showing State: Down with LID 0xffff

**Cause:** Standard OpenSM doesn't support VF port management.

**Fix:** Deploy MLNX_OFED OpenSM with `virt_enabled 2` (see Step 2).

### IPoIB showing NO-CARRIER

**Cause:** Multicast join fails due to rate/mtu constraints in partition config.

**Fix:** Use minimal partition config without rate:
```
Default=0x7fff, ipoib, mtu=5:
    ALL=full;
```

Then bounce the interfaces:
```bash
# On host
ip link set ibs4f0 down && ip link set ibs4f0 up
ip link set ibs4f1 down && ip link set ibs4f1 up
```

### IPoIB MTU stuck at 2044

**Cause:** Partition config MTU constraint.

**Fix:** Set `mtu=5` in partition config (see above) and bounce interfaces.

### Cannot set IPoIB Connected Mode (64K MTU)

**Cause:** ConnectX-7 and newer use Enhanced IPoIB which doesn't support connected mode.

**Note:** Maximum IPoIB MTU in datagram mode is 4092 bytes. Raw RDMA already uses 4096 byte MTU.

### OpenSM binding to wrong GUID

**Fix:** Explicitly specify the PF GUID:
```bash
opensm -g 0x5000e60300b4fe64 -f stdout
```

---

## Files in This Directory

| File | Description |
|------|-------------|
| `opensm-configmap.yaml` | OpenSM configuration with `virt_enabled 2` and partition config |
| `opensm.yaml` | OpenSM pod deployment using MLNX_OFED |
| `server.yaml` | Test server pod with IB VF |
| `client.yaml` | Test client pod with IB VF |

---

## Summary

| Component | Configuration |
|-----------|---------------|
| **SR-IOV Policy** | `linkType: IB`, `isRdma: true`, `mtu: 4092` |
| **SR-IOV Network** | `SriovIBNetwork` with `linkState: enable` and IPAM |
| **OpenSM** | MLNX_OFED version with `virt_enabled 2` |
| **Partition Config** | `Default=0x7fff, ipoib, mtu=5: ALL=full;` |
| **VF GUIDs** | Unique per-VF, set via `ip link set ... vf ... node_guid/port_guid` |
| **IPoIB MTU** | 4092 (datagram mode max) |
| **RDMA MTU** | 4096 |

---

## References

- [SR-IOV Network Operator](https://github.com/k8snetworkplumbingwg/sriov-network-operator)
- [IB VF GUID Configuration Design](https://github.com/k8snetworkplumbingwg/sriov-network-operator/blob/master/doc/design/ib-vf-configuration.md)
- [NVIDIA MLNX_OFED Documentation](https://docs.nvidia.com/networking/display/mlnxofedv24070610)
- [OpenSM User Manual](https://docs.nvidia.com/networking/display/opensaboratory)
- [IPoIB Kernel Documentation](https://www.kernel.org/doc/html/v6.9/infiniband/ipoib.html)
