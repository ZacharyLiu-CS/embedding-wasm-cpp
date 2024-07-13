# Reference docs:

1. https://github.com/bytecodealliance/wasmtime
2. https://github.com/bytecodealliance/wasmtime-cpp
3. https://docs.wasmtime.dev/c-api/
4. https://docs.wasmtime.dev/examples-c-hello-world.html

# Quick build

1. Run bash command:

```
$ git submodule update --init --recursive
$ chmod +x third_party/build.sh && ./third_party/build.sh
```

## Write a Rust wasm module

### Pre-installation

```
$ rustup target add wasm32-unknown-unknown
$ cargo install wasm-gc
$ cargo new sum --lib
```

### Update Cargo.toml

```
[lib]
crate-type = ["cdylib"]
```

### Bring on the Code

```
#[no_mangle]
pub extern "C" fn add(x: i32, y: i32) -> i32 {
    x + y
}
#[no_mangle]
pub extern "C" fn multiple(x: i32, y: i32) -> i32 {
    x * y
}
```

### Compile to wasm

```
$ cargo build --target wasm32-unknown-unknown --release
$ ls -la target/wasm32-unknown-unknown/release/sum.wasm
```

### Call wasm function with C++ code

```
#include "wasmtime/error.h"
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <wasmtime.hh>

using namespace wasmtime;

Span<uint8_t> read_wasm_file(const char *path) {
  wasm_byte_vec_t bytes;
  // Load our input file to parse it next
  FILE *file = fopen(path, "rb");
  if (!file) {
    printf("> Error loading file!\n");
    exit(1);
  }
  fseek(file, 0L, SEEK_END);
  size_t file_size = ftell(file);
  wasm_byte_vec_new_uninitialized(&bytes, file_size);
  fseek(file, 0L, SEEK_SET);
  if (fread(bytes.data, file_size, 1, file) != 1) {
    printf("> Error loading module!\n");
    exit(1);
  }
  fclose(file);
  Span<uint8_t> raw(reinterpret_cast<uint8_t *>(bytes.data), bytes.size);
  return raw;
}

std::string read_wat_file(const char *path) {
  std::ifstream watFile;
  watFile.open(path);
  std::stringstream strStream;
  strStream << watFile.rdbuf();
  return strStream.str();
}

Result<Module> load_function(Engine &engine, const char *path) {
  wasmtime_error_t* error = wasmtime_error_new("wrong path");
  if (path == nullptr) {
    return Error(error);
  }

  const char *wasmSuffix = ".wasm";
  const char *watSuffix = ".wat";

  size_t pathLength = std::strlen(path);
  size_t wasmLength = std::strlen(wasmSuffix);
  size_t watLength = std::strlen(watSuffix);

  if (pathLength >= wasmLength) {
    if (std::strcmp(path + pathLength - wasmLength, wasmSuffix) == 0) {
      return Module::compile(engine, read_wasm_file(path)).unwrap();
    }
  }

  if (pathLength >= watLength) {
    if (std::strcmp(path + pathLength - watLength, watSuffix) == 0) {
      return Module::compile(engine, read_wat_file(path)).unwrap();
    }
  }
  return Error(error);
}

int main() {
  // Load our WebAssembly (parsed WAT in our case), and then load it into a
  // `Module` which is attached to a `Store`. After we've got that we
  // can instantiate it.
  std::cout << "Input wasm file path:" << std::endl;
  std::string file_path;
  std::cin >> file_path;
  Engine engine;

  Store store(engine);
  auto module = load_function(engine, file_path.data()).unwrap();
  auto instance = Instance::create(store, module, {}).unwrap();

  // Invoke `add and multiple` export function
  auto add = std::get<Func>(*instance.get(store, "add"));
  auto results = add.call(store, {6, 27}).unwrap();
  std::cout << "sum(6, 27) = " << results[0].i32() << "\n";
  // Invoke `multiple` export
  auto multiple = std::get<Func>(*instance.get(store, "multiple"));
  results = multiple.call(store, {6, 27}).unwrap();
  std::cout << "multiple(6, 27) = " << results[0].i32() << "\n";
}
```
### Configure the CMakeList.txt
```
set(CMAKE_CXX_FLAGS "-std=c++17 -g -Wall -pthread ")
include_directories(
  ${PROJECT_SOURCE_DIR}/third_party/wasmtime/crates/c-api/include/
  )

link_directories(
  ${PROJECT_SOURCE_DIR}/third_party/wasmtime/target/release/
  )
target_link_libraries(${PROJECT_NAME}
  wasmtime
  )

```
