BUILD_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
CID := $(shell git rev-parse HEAD)

HUB			?=
HUB_TOKEN	?=
HUB_USER	?= scypi
IMAGE		?= $(HUB_USER)/a11y-audit-
IMAGE_TAG 	?= $(shell git describe --always)
ARCH	 	?= amd64
OS			?= linux
BUILDER   	?= podman


images: ._img-$(IMAGE_TAG)		## Build container image.
publish: image					## Publish image to remote repository
	$(BUILDER) login -u $(HUB_USER) -p $(HUB_TOKEN)
	$(BUILDER) push $(IMAGE)statics:$(IMAGE_TAG)
	$(BUILDER) push $(IMAGE)server:$(IMAGE_TAG)
	@$(BUILDER) logout $(HUB)

clean:							## Clean built images, all tags
	@$(BUILDER) rmi $$(docker images -q $(IMAGE)statics) 2>/dev/null || echo No images $(IMAGE)statics
	@$(BUILDER) rmi $$(docker images -q $(IMAGE)server) 2>/dev/null || echo No images $(IMAGE)server
	@rm -f ._img-*

help:							## Show this help.
	@egrep -h '^[0-9a-zA-Z\-]+:.*##' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: image publish clean help

._img-$(IMAGE_TAG):
	@$(BUILDER) build --platform $(OS)/$(ARCH) --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg CID=$(CID) --build-arg TARGETPLATFORM=$(OS)/$(ARCH) --target statics -t $(IMAGE)statics:$(IMAGE_TAG) .
	@$(BUILDER) build --platform $(OS)/$(ARCH) --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg CID=$(CID) --build-arg TARGETPLATFORM=$(OS)/$(ARCH) --target server -t $(IMAGE)server:$(IMAGE_TAG) .
	@touch $@


# vim: noet ts=4 sw=4 ft=make
