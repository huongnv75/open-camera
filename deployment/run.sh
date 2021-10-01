#!/bin/bash
# ubuntu
cd ../web/
docker stop ecyber-group
docker rm ecyber-group
docker rmi ecyber-group-image:1.0
docker build --tag ecyber-group-image:1.0 .
docker run -d --name='ecyber-group' -p '8080:8080/tcp' -v "/home/huongnv75/Github/open-camera/build/streams":'/dev/shm/streams':'rw' -v "/home/huongnv75/Github/open-camera/build/config":'/config':'rw' -v "/home/huongnv75/Github/open-camera/build/customAutoLoad":'/home/Shinobi/libs/customAutoLoad':'rw' -v "/home/huongnv75/Github/open-camera/build/database":'/var/lib/mysql':'rw' -v "/home/huongnv75/Github/open-camera/build/videos":'/home/Shinobi/videos':'rw' -v "/home/huongnv75/Github/open-camera/build/plugins":'/home/Shinobi/plugins':'rw' -v '/etc/localtime':'/etc/localtime':'ro' ecyber-group-image:1.0
docker logs -f ecyber-group


docker run -d --name='ecyber-group' -p '8080:8080/tcp' -v "/home/huongnv75/Github/open-camera/build/streams":'/dev/shm/streams':'rw' -v "/home/huongnv75/Github/open-camera/build/config":'/config':'rw' -v "/home/huongnv75/Github/open-camera/build/customAutoLoad":'/home/Shinobi/libs/customAutoLoad':'rw' -v "/home/huongnv75/Github/open-camera/build/database":'/var/lib/mysql':'rw' -v "/home/huongnv75/Github/open-camera/build/videos":'/home/Shinobi/videos':'rw' -v "/home/huongnv75/Github/open-camera/build/plugins":'/home/Shinobi/plugins':'rw' -v '/etc/localtime':'/etc/localtime':'ro' -v "/home/huongnv75/Github/open-camera/web/web":'/home/Shinobi/web':'rw' ecyber-group-image:1.0
