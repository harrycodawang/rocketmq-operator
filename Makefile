# Build binary and image.
#
# Example:
#   make
#   make all
all: build-in-docker build-image
	docker images | grep rocketmq-operator
.PHONY: all

# Build the binaries in docker
#
# Example:
#   make build-in-docker
build-in-docker:
	cd build && sh build_in_docker.sh
.PHONY: build-in-docker

# Build the docker image
#
# Example:
#   make build-image
build-image:
	pushd docker/rocketmq-operator && sh ./build-image.sh && popd
.PHONY: build-image

# Test e2e case with deleting/creating k8s resources
#
# Example:
#   make e2e-k8s-resources
e2e-k8s-resources:
	sh test/e2e/k8s-resources.sh
.PHONY: e2e-k8s-resources
