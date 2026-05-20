CONTAINER_RUNTIME ?= podman

DPDK_IMAGE ?= quay.io/schseba/dpdk
OVS_DPDK_IMAGE ?= quay.io/schseba/ovs-dpdk
VPP_IMAGE ?= quay.io/schseba/vpp
TREX_IMAGE ?= quay.io/schseba/trex
PKTGEN_DPDK_IMAGE ?= quay.io/schseba/pktgen-dpdk
TOOLBOX_IMAGE ?= quay.io/schseba/toolbox

.PHONY: all build-all push-all \
	build-dpdk build-dpdk-rhel build-ovs-dpdk build-vpp build-trex build-trex-mlx build-trex-intel \
	build-pktgen-dpdk build-pkggen-dpdk build-toolbox \
	push-dpdk push-dpdk-rhel push-ovs-dpdk push-vpp push-trex push-pktgen-dpdk push-pkggen-dpdk push-toolbox

all: build-all push-all

build-all: build-dpdk build-ovs-dpdk build-vpp build-trex build-pktgen-dpdk build-toolbox

push-all: push-dpdk push-ovs-dpdk push-vpp push-trex push-pktgen-dpdk push-toolbox

build-dpdk:
	${CONTAINER_RUNTIME} build -f Dockerfile-dpdk -t ${DPDK_IMAGE}:latest .

build-dpdk-rhel:
	${CONTAINER_RUNTIME} build -f Dockerfile-dpdk-rhel -t ${DPDK_IMAGE}:rhel .

build-ovs-dpdk:
	${CONTAINER_RUNTIME} build -f Dockerfile-ovs-dpdk -t ${OVS_DPDK_IMAGE}:latest .

build-vpp:
	${CONTAINER_RUNTIME} build -f Dockerfile-vpp -t ${VPP_IMAGE}:latest .

build-trex:
	${CONTAINER_RUNTIME} build -f Dockerfile-trex -t ${TREX_IMAGE}:latest .
	${CONTAINER_RUNTIME} tag ${TREX_IMAGE}:latest ${TREX_IMAGE}:mlx
	${CONTAINER_RUNTIME} tag ${TREX_IMAGE}:latest ${TREX_IMAGE}:intel

build-trex-mlx: build-trex

build-trex-intel: build-trex

build-pktgen-dpdk:
	${CONTAINER_RUNTIME} build -f Dockerfile-pktgen-dpdk -t ${PKTGEN_DPDK_IMAGE}:latest .

build-pkggen-dpdk: build-pktgen-dpdk

build-toolbox:
	${CONTAINER_RUNTIME} build -f Dockerfile-toolbox -t ${TOOLBOX_IMAGE}:latest .

push-dpdk:
	${CONTAINER_RUNTIME} push ${DPDK_IMAGE}:latest

push-dpdk-rhel:
	${CONTAINER_RUNTIME} push ${DPDK_IMAGE}:rhel

push-ovs-dpdk:
	${CONTAINER_RUNTIME} push ${OVS_DPDK_IMAGE}:latest

push-vpp:
	${CONTAINER_RUNTIME} push ${VPP_IMAGE}:latest

push-trex:
	${CONTAINER_RUNTIME} push ${TREX_IMAGE}:latest
	${CONTAINER_RUNTIME} push ${TREX_IMAGE}:mlx
	${CONTAINER_RUNTIME} push ${TREX_IMAGE}:intel

push-pktgen-dpdk:
	${CONTAINER_RUNTIME} push ${PKTGEN_DPDK_IMAGE}:latest

push-pkggen-dpdk: push-pktgen-dpdk

push-toolbox:
	${CONTAINER_RUNTIME} push ${TOOLBOX_IMAGE}:latest