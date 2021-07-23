#!/bin/sh
set -e

apk update
apk upgrade
apk add yaml-dev yaml-static
shards install --production
crystal build --static --release src/main.cr
