#!/bin/bash

zig build build && ./zig-out/bin/gbemu -f $1
