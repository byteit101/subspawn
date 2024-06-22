#!/bin/bash
exec jruby "-J-Dsubspawn.backend=native" --dev  -I subspawn-common/lib -I subspawn-posix/lib -I subspawn/lib -I ffi-bindings-libfixposix/lib -I ffi-binary-libfixposix/lib -I engine-hacks/lib "$@"
