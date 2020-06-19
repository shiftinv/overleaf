CLSI_SCHEME=basic

build-all: build build-clsi

build:
	docker build -f Dockerfile -t shiftinv/overleaf:dev .

build-clsi:
	$(MAKE) -C clsi build SCHEME=$(CLSI_SCHEME)

PHONY: build build-clsi
