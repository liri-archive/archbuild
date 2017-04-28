all:
	@docker build -t archlinux/build .

nocache:
	@docker build -t archlinux/build --build-arg CACHEBUST=$(date +%s) .
