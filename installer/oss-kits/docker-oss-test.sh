#!/bin/bash
if [ "$(/usr/bin/arch)" == "x86_64" ]; then
	which docker 1> /dev/null 2> /dev/null
	if [ $? -eq 0 ]; then
		if [ -S "/var/run/docker.sock" ]; then
			if [ "$(docker version --format '{{.Server.Version}}')" > "1.8" ]; then
				echo "Docker is installed and configured correctly." 1>&2
			else
				echo "Docker 1.8 or greater is required. docker-cimprov will not be installed." 1>&2
				exit 1
			fi
		else
			echo "Docker is not listening on /var/run/docker.sock. docker-cimprov will not be installed." 1>&2
			exit 1
		fi
	else
		echo "Docker is not installed. docker-cimprov will not be installed." 1>&2
		exit 1
	fi
else
	echo "A 64-bit system is required. docker-cimprov will not be installed." 1>&2
	exit 1
fi