#!/bin/bash
cd ../web/
docker stop open-camera
docker rm open-camera
docker rmi shinobi-image:1.0
docker build --tag shinobi-image:1.0 .
docker run -d --name='open-camera' -p '8080:8080/tcp' -v "/dev/shm/open-camera/web/streams":'/dev/shm/streams':'rw' -v "$HOME/open-camera/web/config":'/config':'rw' -v "$HOME/open-camera/web/customAutoLoad":'/home/open-camera/web/libs/customAutoLoad':'rw' -v "$HOME/open-camera/web/database":'/var/lib/mysql':'rw' -v "$HOME/open-camera/web/videos":'/home/open-camera/web/videos':'rw' -v "$HOME/open-camera/web/plugins":'/home/open-camera/web/plugins':'rw' -v '/etc/localtime':'/etc/localtime':'ro' shinobi-image:1.0
docker logs -f open-camera
