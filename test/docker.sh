#!/usr/bin/env bash
# -e https_proxy=http://192.168.1.107:8389 -e no_proxy="172.16.0.0/12,192.168.1.1/16,::1,169.254.0.0/16,10.0.0.0/8,localhost" \
docker pull ghcr.io/baijunty/hitomi:master
docker run -d --name=hitomi -p 7890:7890 \
 -v /mnt/ssd/manga:/galleries  -v /etc/timezone:/etc/timezone:ro -v /etc/localtime:/etc/localtime:ro \
  -e ZT=Asia/Shanghai --restart=always  ghcr.io/baijunty/hitomi:master