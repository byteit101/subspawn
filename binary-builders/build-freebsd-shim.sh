#!/bin/sh
#apk add bash
export CROSS_TRIPLE=$1
export CROSS_COMPILE=${CROSS_TRIPLE}-
shift
exec "$@"
