# ffi-bindings-libfixposix

Straightforward ffi bindings for libfixposix. Doesn't include a binary. See ffi-binary-libfixposix for that.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add ffi-bindings-libfixposix

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install ffi-bindings-libfixposix

## Usage

```rb
require 'libfixposix'
```
Note that binaries are picked up automatically, they don't need to be manually required. See parent SubSpawn for more information.

`lfp_foo(...)` is mapped to `LFP.foo(...)` and simple class wrappers are generated too. See ffi.rb (generated) for all methods mapped from C. Use `LFP::INTERFACE_VERSION`, `LFP::SO_VERSION`, and/or `LFP::COMPLETE_VERSION` as appropriate.

## Development

See parent SubSpawn readme
