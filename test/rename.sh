#!/usr/bin/env bash
scan(){
    echo "scan for $1"
    for file in `dir $1` ;do
        if [ -f "$1/$file" ] ; then
            name="${file%.*}"
            echo "rename $name"
            if [ ! -e "$1/$name" ]; then
                mkdir -p "$1/$name"
            fi
            if [ "$1/$file" !eq "$1/$name"] ;then
                mv "$1/$file" "$1/$name"
            fi
        elif [ -d "$1/$file" ]; then
            scan "$1/$file"
        fi
    done
}


path=$1
if [ -z $path ];then
    path=$(pwd)
fi
scan $path
docker run -d --name=hitomi -p 7890:7890 -e https_proxy=http://192.168.1.107:8389  -v /mnt/ssd/manga:/galleries  -v /etc/timezone:/etc/timezone:ro -v /etc/localtime:/etc/localtime:ro -e ZT=Asia/Shanghai --restart=always hitomi