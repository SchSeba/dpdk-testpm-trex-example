CONTAINER_RUNTIME ?= podman
all: build-dpdk build-trex push-dpdk push-trex

build-dpdk:
	${CONTAINER_RUNTIME} build -f Dockerfile-dpdk -t quay.io/schseba/dpdk:latest .

build-dpdk-rhel:
	${CONTAINER_RUNTIME} build -f Dockerfile-dpdk-rhel -t quay.io/schseba/dpdk:rhel .

build-trex:
	${CONTAINER_RUNTIME} build -f Dockerfile-trex -t quay.io/schseba/trex:latest .

push-dpdk:
	${CONTAINER_RUNTIME} push quay.io/schseba/dpdk:latest

push-dpdk-rhel:
	${CONTAINER_RUNTIME} push quay.io/schseba/dpdk:rhel

push-trex:
	${CONTAINER_RUNTIME} push quay.io/schseba/trex:latest
