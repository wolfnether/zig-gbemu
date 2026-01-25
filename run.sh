#!/bin/bash

zig build build --release=fast && ./zig-out/bin/gbemu -f "$@"
