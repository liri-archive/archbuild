Arch Linux for Docker
=====================

Make a container to build packages and ISOs:

```sh
./mkimage-arch.sh base-devel sudo devtools git archiso
```

Tag the container and push to Bintray:

```sh
docker tag <IMAGE_ID> liri-docker-build.bintray.io/archlinux/devel:latest
docker push liri-docker-build.bintray.io/archlinux/devel:latest
```
