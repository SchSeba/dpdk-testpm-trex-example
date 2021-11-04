all: build-dpdk build-trex push-dpdk push-trex

build-dpdk:
	docker build -f Dockerfile-dpdk -t quay.io/schseba/dpdk:latest .

build-trex:
	docker build -f Dockerfile-trex -t quay.io/schseba/trex:latest .

push-dpdk:
	docker push quay.io/schseba/dpdk:latest

push-trex:
	docker push quay.io/schseba/trex:latest
