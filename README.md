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
            <td colspan=2 align=center><tt>subspawn-win32</tt></td>
        </tr>
        <tr>
            <td>JVM/Jar</td>
            <td colspan=3 align=center><tt>subspawn-jar</tt></td>
        </tr>
    </tbody>
</table>

Installation
-----------
For now, subspawn uses hard dependencies, but this may change.

Using JRuby 9.4 or later? A compatible version of SubSpawn is already installed!

For POSIX systems (MacOS, Linux, etc...):
```
$ gem install subspawn subspawn-posix
```

For Windows systems:
```
$ gem install subspawn subspawn-win32
```

Then:
```rb
require 'subspawn'
# or, to replace the built in spawn methods:
# require 'subspawn/replace'
```

What is in this repository
-------

Folders:
 - libfixposix (build only, subrepository, for ffi-generator)
 - ffi-generator (build only)
 - ffi-bindings-libfixposix (gem)
 - ffi-binary-libfixposix (native gem)
 - engine-hacks (native gem)
 - subspawn-common (gem)
 - subspawn-posix (gem)
 - subspawn-win32 (gem)
 - subspawn (gem)
 - jruby-jar (gem/jar building utilities)


libfixposix
-----------
The underlying library used is libfixposix. Currently the most recent and most widely distributed version in distros is 0.4.3. However, it doesn't support features we need, so we bundle 0.5.0.
In order to use libfixposix, you must configure the build, or just remove the `#if @VAR@` statements in the headers. See where ffi-generator complains to know what to remove.

ffi-generator
-------------
ffi_gen takes the libfixposix include headers and generates ruby ffi bindings for ffi-bindings-libfixposix. It it tailored specifically to this project and not generally portable at this time, but patches are welcome

ffi-bindings-libfixposix
------------------------
Raw bindings to libfixposix. binary not included, but attempts to load if present. No translation, pure pointers. Usable if you want to use libfixposix in unrelated Ruby code. Generated output is ffi.rb to map all C functions to Ruby.

ffi-binary-libfixposix
----------------------
A compiled binary gem of libfixposix in case you do not have or do not want to use a system-installed library. Use `require 'libfixposix/binary'` to get the path.

Note that to support cross-compiling, rake tasks are nonstandard. See `rake -T -a` for all options, but in essence, for local development, `rake local` will build a gem file in pkg/ as usual, that you can `gem install pkg/*.gem`. For building for publishing, try `rake cross:$TARGET` or `rake "target[x86_64-linux]" gem` (change target as appropriate). To just build the `.so` files, `rake binary` (local host) or `rake "binary[$TARGET]"` should be called.

engine-hacks
-----------
Ruby engine-specific hacks. Currently used to set `$?` in a platform-independent manner, as well as to make IO.popen "fake duplex" IO objects. C extension for MRI and TruffleRuby, JI for JRuby. Entirely independent of SubSpawn, and can be used externally.

subspawn-common
-----------
Utilities common to all subspawn platforms and API's.

subspawn-posix
-----------
The mid-level API for Unixy machines. Exposes all the capabilities of libfixposix with none of the hassle of C or FFI. Look at the included RBS file for all methods and types. Also includes minimal PTY opening helper.

subspawn-win32
-----------
The mid-level API for Windows machines. Win32 API's are exposed via FFI, then regularized via the mid-level API, like subspawn-posix. Also includes an early PTY <-> ConPTY translation layer. Yes, you heard that right, PTY.open/PTY.spawn on Windows! (Require [ConPTY from Windows 10 1803](https://devblogs.microsoft.com/commandline/windows-command-line-introducing-the-windows-pseudo-console-conpty/) or later)

Note: PTY's currently work best on CRuby. JRuby support is being worked on, this gem will eventually ship with JRuby once this is fixed.

subspawn
-----------
The unified high-level API for all Ruby platforms. Also includes post-launch utilities and a `PTY` library implementation. The main interface is `SubSpawn.spawn()` which is modeled after `Process.spawn`, but with extended features. These extended features can be brought into `Process.spawn` itself with `subspawn/replace`. This lets `Open3` and other utilities that pass args to `spawn` also benefit from the extra features of SubSpawn.


Roadmap
------------

 * 0.1 - intial release (DONE)
 * 0.2 - windows (WIP, everything except PTY's should work right now though)
 * 0.3 - install-time builds
 * 0.4 - better validation/errors

Please note that SubSpawn is still in its infancy and is being actively developed.

API guarantees:

 * Rubyspec will continue to pass (Process.spawn & PTY.spawn are compatble with Subspawn.compat*)
 * subspawn-`$PLATFORM` may change from 0.1 to 0.2, etc
 * subspawn (high-level) will otherwise use semantic versioning

# Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rake dev` to set up a working environment.

To build the binary locally for development (highly recommended): `cd ffi-binary-libfixposix && rake local`

To install these gem onto your local machine, run `bundle exec rake build` and install all the gems with `gem install */pkg/*.gem`.

Test by integrating into JRuby. Notable tests:

 * io/console. check out and run `TESTOPTS="--verbose" jruby -S rake test`
 * rspec tests. check out jruby and run `bin/jruby -S rake spec:ruby`, looking for spawn or PTY errors 

For local JRuby integration testing, consider running `rerun --no-notify --ignore 'java-jar/*' 'cd java-jar && rake'` after you export `JRUBY_DIR` to the path to your jruby source checkout

For unit testing, `subspawn` and `subspawn-posix` have rspec tests that run on MacOS & Linux, while `subspawn-win32` has rspec tests that run on Windows.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/byteit101/subspawn.

# License

SubSpawn is licensed under a tri EPL/LGPL/Ruby license. You can use it, redistribute it and/or modify it under the terms of the:

[Eclipse Public License version 2.0](https://spdx.org/licenses/EPL-2.0.html) OR [GNU Lesser General Public License version 2.1 (or later)](https://spdx.org/licenses/LGPL-2.1-or-later.html) OR [Ruby License](https://spdx.org/licenses/Ruby.html)

