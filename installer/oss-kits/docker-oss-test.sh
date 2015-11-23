#!/bin/bash
echo "Checking if Docker is installed..." 1>&2
if [ "$(uname -m)" == "x86_64" ]; then
    which docker 1> /dev/null 2> /dev/null
    if [ $? -eq 0 ]; then
        if [ -S "/var/run/docker.sock" ]; then
            if [ "$(docker version --format '{{.Server.Version}}' 2>/dev/null)" > "1.8" ]; then
                echo "  Docker found. Docker agent will be installed" 1>&2
            else
                echo "  The installed version of Docker is not supported. Version 1.8 or greater is required. Docker agent will not be installed." 1>&2
                exit 1
            fi
        else
            echo "  Docker is not listening on /var/run/docker.sock. Docker agent will not be installed." 1>&2
            exit 1
        fi
    else
        echo "  Docker not found. Docker agent will not be installed." 1>&2
        exit 1
    fi
else
    echo "  Only 64-bit systems are supported. Docker agent will not be installed." 1>&2
    exit 1
fi