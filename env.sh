#!/bin/sh
awk -F '=' '{ print $1 ": \"" (ENVIRON[$1] ? ENVIRON[$1] : $2) "\"" }' ./application.docker.yml >> ./config/application.yml
