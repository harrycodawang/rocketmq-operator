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

# Build and push the docker image
#
# Example:
#   make build-image
push:
	pushd docker/rocketmq-operator && sh ./build-image.sh && popd
.PHONY: push

# Trigger to e2e test
#
# Example:
#   make e2e
e2e:
	bash test/e2e/e2e.sh
.PHONY: e2e

# Trigger to test docker image
#
# Example:
#   make test-image
test-image:
	bash test/integration/test-image.sh
.PHONY: test-image

