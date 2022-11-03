<p align="center"><img src="doc/logo-export.svg" alt="SubSpawn Logo" height=150 /></p>

Ruby SubSpawn (Native)
================

SubSpawn is an advanced set of gems and packages to make natively spawning subprocesses from all Ruby implementations possible. It started out as a way to add `PTY.spawn` support to JRuby, but is usable by CRuby (MRI) and TruffleRuby.

There are 3 levels of API's supported: basic/ffi, mid-level, and high-level. Basic/ffi support is simply the ffi wrapper and has no other Ruby support. The mid-level API is specific to the host (POSIX, Win32), but otherwise has a more Ruby-like interface and avoids raw pointers. The high-level API is as consistent as possible across all platforms, and hews closely to standard Rubyisms.


The primary feature of SubSpawn is the ability to control advanced attributes of launched subprocesses such as specifying the controlling TTY, changing file descriptors, and `pgroup` and `setsid` configuration.

<table>
    <thead>
        <tr>
			<th>Platform</th>
            <th>Basic/FFI</th>
            <th>Mid-level</th>
            <th>High-level</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>Linux</td>
            <td rowspan=3><tt>ffi-bindings-libfixposix</tt></td>
            <td rowspan=3><tt>subspawn-posix</tt></td>
            <td rowspan=4><tt>subspawn</tt></td>
        </tr>
        <tr>
            <td>Mac OS</td>
        </tr>
        <tr>
            <td>BSD</td>
        </tr>
        <tr>
            <td>Windows</td>
            <td>Accepting pull requests!</td>
            <td>Accepting pull requests!</td>
        </tr>
        <tr>
            <td>JVM/Jar</td>
            <td colspan=3 align=center><tt>subspawn-jar</tt></td>
        </tr>
    </tbody>
</table>

Installation
-----------
If you have libfixposix installed system wide on your distribution:
```
$ gem install subspawn

> require 'subspawn'
```
If you would like to use our bundled binaries:
```
gem install subspawn ffi-binary-libfixposix

> require 'libfixposix/binary' # TODO: figure out namespacing
> require 'subspawn'
```


What is in this repository
-------

Folders:
 - libfixposix (build only, for ffi-generator)
 - ffi-generator (build only)
 - ffi-bindings-libfixposix (gem)
 - ffi-binary-libfixposix (gem)
 - subspawn-posix (gem)
 - subspawn (gem)
 - jruby-jar (gem/jar)



libfixposix
-----------

The underlying library used is libfixposix. Currently the most recent and most widely distributed version in distros is 0.4.3, so we use that. Once 0.5.0 is in most distros, consider releasing that.
In order to use libfixposix, you must configure the build, or just remove the `#if @VAR@` statements in the headers. See where ffi-generator complains to know what to remove.

ffi-generator
-------------
ffi_gen takes the libfixposix include headers and generates ruby ffi bindings for ffi-bindings-libfixposix. It it tailored specifically to this project and not generally portable at this time, but patches are welcome

ffi-bindings-libfixposix
------------------------
Raw bindings to libfixposix. binary not included, defaults to system so/dynlib. No translation, pure pointers. Usable if you want to use libfixposix in unrelated Ruby code

ffi-binary-libfixposix
----------------------
A compiled binary gem of libfixposix in case you do not have or do not want to use a system-installed library. Use `require 'libfixposix/binary'` or `require 'subspawn/binary'` (TODO figure out namespacing) to enable.

Note that to support cross-compiling, rake tasks are nonstandard. See `rake -T -a` for all options, but in essence, for local development, `rake gem:local` will build a gem file in pkg/ as usual, that you can `gem install pkg/*.gem`. For building for publishing, try `rake build:$TARGET` or `rake "target[x86_64-linux]" gem` (change target as appropriate). To just build the `.so` files, `rake binary` (local host) or `rake "binary[$TARGET]"` should be called.

subspawn-posix
-----------
The mid-level API for Unixy machines. Exposes all the capabilities of libfixposix with none of the hassle of C or FFI.


subspawn
-----------
The unified high-level API for all Ruby platforms. Also includes post-launch utilities and a `PTY` library implementation.


Roadmap
------------
0.1.0/0.4.90 - intial release
0.2 - windows
0.3 - better validation/errors



After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/process-wrapper-high.

