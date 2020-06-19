# Makefile

OVERLEAF_TAG := shiftinv/overleaf


build-community:
	docker build -f Dockerfile -t $(OVERLEAF_TAG) .


PHONY: build-community
