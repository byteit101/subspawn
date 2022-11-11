# SubSpawn Gem (High-level API)

Native process launching. See parent SubSpawn readme for details

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add subspawn subspawn-posix

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install subspawn subspawn-posix

## Usage

```rb
require 'subspawn'

Subspawn.spawn(["ls", "/"])

# or to augment the built-in ruby methoda
require 'subspawn/replace'

Process.spawn("ls", "/", :setsid=> true)
PTY.spawn(...)
PTY.subspawn(..., options...)
```

## Development

See parent SubSpawn readme
