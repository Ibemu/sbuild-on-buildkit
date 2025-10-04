MAKEFILE_DIR	:= $(dir $(lastword $(MAKEFILE_LIST)))
APT_PROXY		:= $(shell apt-config dump | grep Proxy)
CACHEBUST		?= $(shell date)

.PHONY: build

build:
	env 'MAKEFILE_DIR=$(MAKEFILE_DIR)' 'APT_PROXY=$(APT_PROXY)' 'CACHEBUST=$(CACHEBUST)' \
		docker buildx bake -f '$(MAKEFILE_DIR)/docker-bake.hcl' \
			--allow security.insecure --allow fs.read='$(MAKEFILE_DIR)/Dockerfile'
