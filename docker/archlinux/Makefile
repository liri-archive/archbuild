REGISTRY_NAME=liridev/archlinux-base
PREFIX=archlinux
NAME=base
VERSION=latest

all: build

clean:
	@docker rmi $(PREFIX)/$(NAME) || /bin/true

build: clean
	@./mkimage-arch.sh base-devel sudo devtools git archiso

push:
	@docker tag $(shell docker images -q $(PREFIX)/$(NAME)) $(REGISTRY_NAME):$(VERSION)
	@docker push $(REGISTRY_NAME):$(VERSION)
