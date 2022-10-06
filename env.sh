#!/bin/sh
awk -F '=' '{ print $1 ": \"" (ENVIRON["ADMIN_UI"] ? ENVIRON["ADMIN_UI"] : $2) "\"" }' ./application.docker.yml >> ./config/application.yml
