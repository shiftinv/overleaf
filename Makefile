# Makefile

OVERLEAF_BASE_TAG := shiftinv/overleaf-base
OVERLEAF_TAG := shiftinv/overleaf

build-base:
	docker build -f Dockerfile-base -t $(OVERLEAF_BASE_TAG) .


build-community:
	docker build --build-arg OVERLEAF_BASE_TAG=$(OVERLEAF_BASE_TAG) -f Dockerfile -t $(OVERLEAF_TAG) .


PHONY: build-base build-community
