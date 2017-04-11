REGISTRY_URL=liri-docker-build.bintray.io
PREFIX=archlinux
NAME=devel
VERSION=latest

all: build

clean:
	@docker rmi $(PREFIX)/$(NAME) || /bin/true

build: clean
	@./mkimage-arch.sh base-devel sudo devtools git archiso

push: build
	@docker tag $(shell docker images -q $(PREFIX)/$(NAME)) $(REGISTRY_URL)/$(PREFIX)/$(NAME):$(VERSION)
	@docker push $(REGISTRY_URL)/$(PREFIX)/$(NAME):$(VERSION)
