#!/usr/bin/env bash
#
# build.sh
#
# Created by Zacharyliu-CS on 07/12/2024.
# Copyright (c) 2024 liuzhenm@mail.ustc.edu.cn.
#
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
if ! type wasmtime &> /dev/null
then
  curl https://wasmtime.dev/install.sh -sSf | bash
fi
rustup target add wasm32-wasi
cd $SCRIPT_PATH/wasmtime && cargo build --release -p wasmtime-c-api
pwd
cd $SCRIPT_PATH/wasmtime/crates/c-api && cmake .
cp $SCRIPT_PATH/wasmtime-cpp/include/wasmtime.hh $SCRIPT_PATH/wasmtime/crates/c-api/include/
