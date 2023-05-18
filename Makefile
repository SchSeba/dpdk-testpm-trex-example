CONTAINER_RUNTIME ?= podman
all: build-dpdk build-trex-mlx build-trex-intel build-toolbox push-dpdk push-trex push-toolbox

build-dpdk:
	${CONTAINER_RUNTIME} build -f Dockerfile-dpdk -t quay.io/schseba/dpdk:latest .

build-dpdk-rhel:
	${CONTAINER_RUNTIME} build -f Dockerfile-dpdk-rhel -t quay.io/schseba/dpdk:rhel .

build-trex-mlx:
	${CONTAINER_RUNTIME} build -f Dockerfile-trex -t quay.io/schseba/trex:mlx .
	${CONTAINER_RUNTIME} tag quay.io/schseba/trex:mlx quay.io/schseba/trex:latest

build-trex-intel:
	${CONTAINER_RUNTIME} build -f Dockerfile-trex -t quay.io/schseba/trex:intel .

build-toolbox:
	${CONTAINER_RUNTIME} build -f Dockerfile-toolbox -t quay.io/schseba/toolbox:latest .

push-dpdk:
	${CONTAINER_RUNTIME} push quay.io/schseba/dpdk:latest

push-dpdk-rhel:
	${CONTAINER_RUNTIME} push quay.io/schseba/dpdk:rhel

push-trex:
	${CONTAINER_RUNTIME} push quay.io/schseba/trex:latest
	${CONTAINER_RUNTIME} push quay.io/schseba/trex:mlx
	${CONTAINER_RUNTIME} push quay.io/schseba/trex:intel

push-toolbox:
	${CONTAINER_RUNTIME} push  quay.io/schseba/toolbox:latest