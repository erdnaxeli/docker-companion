#!/bin/sh
set -e

apk update
apk upgrade
apk add yaml-dev yaml-static
crystal build --static --release src/main.cr
