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

As a backup, it also inclues a JRuby fallback that is very limited, but has basic functionality. If you are using the JRuby fallback, please report a bug for your platform, and then compile libfixposix and jffi for your platform.

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

API support
-------------

There are 3 platforms, and they don't all support the same features. Here is a matrix of what features each platform supports

| Feature                   | libfixposix+ffi    | Win32 API           | JRuby Fallback (JDK) |
|---------------------------|--------------------|---------------------|----------------------|
| basic spawn               | :heavy_check_mark: | :heavy_check_mark:  | :heavy_check_mark:   |
| basic waitpid             | :x:/Built-in       | :heavy_check_mark:  | :heavy_check_mark:   |
| full waitpid              | :x:/Built-in       | :heavy_check_mark:* | :x:                  |
| working directory (cwd)   | :heavy_check_mark: | :heavy_check_mark:  | :heavy_check_mark:   |
| env                       | :heavy_check_mark: | :heavy_check_mark:  | :heavy_check_mark:   |
| set argv[0]               | :heavy_check_mark: | N/A                 | :x:                  |
| redirect stdio (file, pipe, inherit, close) | :heavy_check_mark: | :heavy_check_mark:  | :heavy_check_mark:   |
| merge stdio               | :heavy_check_mark: | :heavy_check_mark:  | :heavy_check_mark:   |
| stdio in select           | :heavy_check_mark: | ?                   | :x:                  |
| arbitrary io redirections | :heavy_check_mark: | :x:                 | :x:                  |
| arbitrary io opens        | :heavy_check_mark: | :x:                 | :x:                  |
| arbitrary io closes       | :heavy_check_mark: | ?                   | :x:                  |
| pgroup                    | :heavy_check_mark: | N/A                 | :x:                  |
| sid                       | :heavy_check_mark: | N/A                 | :x:                  |
| pty                       | :heavy_check_mark: | WIP                 | :x:                  |
| umask                     | :heavy_check_mark: | N/A                 | :x:                  |
| signals                   | :heavy_check_mark: | N/A                 | :x:                  |
| rlimits                   | :heavy_check_mark: | :x:                 | :x:                  |



There are 2 APIs: the Ruby API, and the SubSpawn API. They are mostly the same, but have a few important differences:

 * `Process.spawn` and `IO.popen` allow single-string commands. `SubSpawn.spawn` and `SubSpawn.popen` do not allow this for security reasons. Use a array of strings instead.
 * `SubSpawn.spawn` returns a `[pid, iomap]` pair, where `iomap[2]` is whatever you redirected stderr to. This allows SubSpawn to return all the io redirections at once. This is especially important for the JRuby Fallback. `iomap[:pty]` is the PTY master
 * `SubSpawn.*` functions allow extra options and redirections. In addition to `FD`, `:close`, and other `Process.spawn` redirection values, they alow specifying `:pipe`, `:pipe_r`, `:pipe_w`, `:pty`, `:tty`, `File` objects, `java.io.File` objects, and `java.nio.Path` objects. When using SubSpawn replacement, `Process.spawn` and `IO.popen` are agumented too.
 * `SubSpawn.wait*`, `SubSpawn.detach`, and `SubSpawn.last_status` mirror the same functions in `Process`. The Win32 and JRuby fallback platforms define them separarely, unless using replacement. Mixing and matching should not be done unless using libfixposix or replacement.

# Development

After checking out the repo with `--recursive`, run `bundle install` to install dependencies. Then, run `bundle exec rake dev` to set up a working environment. Note: CAST, used by the binary package to parse the libfixposix header, requires a native extension. As such, the first time you do this, it must be with CRuby/MRI, and NOT JRuby. Subsequent development can be done with any ruby.

To build the binary locally for development (highly recommended): `cd ffi-binary-libfixposix && rake local`

To install these gem onto your local machine, run `bundle exec rake build` and install all the gems with `gem install */pkg/*.gem`.

Test by integrating into JRuby. Notable tests:

 * io/console. check out and run `TESTOPTS="--verbose" jruby -S rake test`
 * rspec tests. check out jruby and run `bin/jruby -S rake spec:ruby`, looking for spawn or PTY errors 

For local JRuby integration testing, consider running `rerun --no-notify --ignore 'java-jar/*' 'cd java-jar && rake'` after you export `JRUBY_DIR` to the path to your jruby source checkout

For unit testing, `subspawn` and `subspawn-posix` have rspec tests that run on MacOS & Linux, while `subspawn-win32` has rspec tests that run on Windows.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/byteit101/subspawn.

# Binary CI

Because SubSpawn grew out of the JRuby project, we aim for parity with the JRuby FFI platforms. As such, CI builds all platforms. 


| jffi target                  | SubSpawn JRuby Support | jruby target       | byteit101's preference                          |
| ---------------------------- | ---------------------- | ------------------ | ----------------------------------------------- |
| jffi-Darwin.jar              | {arm64,x86_64}-darwin  | :heavy_check_mark: |                                                 |
| jffi-aarch64-FreeBSD.jar     | arm64-freebsd          | :heavy_check_mark: |                                                 |
| jffi-aarch64-Linux.jar       | arm64-linux            | :heavy_check_mark: |                                                 |
| jffi-aarch64-Windows.jar     | :heavy_check_mark:     | :heavy_check_mark: |                                                 |
| jffi-arm-Linux.jar           | armv6sf-linux          | :heavy_check_mark: | v6+                                             |
| jffi-i386-FreeBSD.jar        | x86-freebsd            |                    |                                                 |
| jffi-i386-Linux.jar          | x86-linux              | :heavy_check_mark: |                                                 |
| jffi-i386-OpenBSD.jar        |                        |                    |                                                 |
| jffi-i386-SunOS.jar          |                        | :heavy_check_mark: | drop                                            |
| jffi-i386-Windows.jar        | :heavy_check_mark:     | :heavy_check_mark: |                                                 |
| jffi-loongarch64-Linux.jar   | loongarch64-linux      | :heavy_check_mark: |                                                 |
| jffi-mips64el-Linux.jar      | mips64el-linux         | :heavy_check_mark: |                                                 |
| jffi-ppc-AIX.jar             |                        | :heavy_check_mark: | drop                                            |
| jffi-ppc-Linux.jar           |                        |                    | drop                                            |
| jffi-ppc64-AIX.jar           |                        | :heavy_check_mark: |                                                 |
| jffi-ppc64-Linux.jar         | ppc64-linux            | :heavy_check_mark: | investigate/drop                                |
| jffi-ppc64le-Linux.jar       | ppc64le-linux          | :heavy_check_mark: |                                                 |
| jffi-s390x-Linux.jar         | s390x-linux            | :heavy_check_mark: |                                                 |
| jffi-sparc-SunOS.jar         |                        |                    | drop                                            |
| jffi-sparcv9-Linux.jar       |                        | :heavy_check_mark: | investigate/drop                                |
| jffi-sparcv9-SunOS.jar       |                        | :heavy_check_mark: | investigate (jdk11 binaries exist, jdk17 don't) |
| jffi-x86_64-DragonFlyBSD.jar |                        | :heavy_check_mark: | Wait until RubyGems support                     |
| jffi-x86_64-FreeBSD.jar      | x86_64-freebsd         | :heavy_check_mark: |                                                 |
| jffi-x86_64-Linux.jar        | x86_64-linux           | :heavy_check_mark: |                                                 |
| jffi-x86_64-OpenBSD.jar      | x86_64-openbsd         | :heavy_check_mark: |                                                 |
| jffi-x86_64-SunOS.jar        |                        | :heavy_check_mark: | drop                                            |
| jffi-x86_64-Windows.jar      | :heavy_check_mark:     | :heavy_check_mark: |                                                 |
| *(riscv32-linux)             |                        |                    | maybe add                                       |
| *                            | riscv64-linux          |                    | add                                             |

| Architecture      |Linux |Mac |FreeBSD|AIX |Solaris|OpenBSD|DragonFlyBSD|
|-------------------|------|----|-------|----|-------|-------|------------|
| arm5              | ,T   |    |       |    |       |       |            |
| arm6              | y?   |    |       |    |       |       |            |
| arm7              | y ?  |    |       |    |       |       |            |
| arm8/aarch64      | y,9T |y,9T| j     |    |       |       |            |        
| i386              | y    |    | y<    |    | j     | j<    |            |
| x86_64            | y,9T |y,9T| y     |    | j     | j     | j          |    
| sparc             |      |    |       |    | j<    |       |            |
| sparcv9           | j-   |    |       |    | j     |       |            |    
| ppc               | j*<  |    |       |  j |       |       |            |
| ppc64             | j*   |    |       |j,9T|       |       |            |
| ppc64le           | y,9T |    |       |    |       |       |            |
| mips              |      |    |       |    |       |       |            |
| mipsel            |      |    |       |    |       |       |            |
| mips64el          | j&   |    |       |    |       |       |            |    
| s390x             | y,9T |    |       |    |       |       |            |
| loongarch64       | j@   |    |       |    |       |       |            |
| riscv32           | s    |    |       |    |       |       |            |
| riscv64           | s,T  |    |       |    |       |       |            |
| -Docker or runner-| ✔    |✔  | ✔     | ?IBM Cloud | ?Oracle Cloud |   ?   |            |


Key:
 - y = JFFI & subspawn CI
 - j = jffi only
 - s = Subspawn only
 - 9 = J9 Semeru build
 - T = Adoptium Temurin OpenJDK build
 - _ = dockcross support
 - * = crosstools-ng support (easy-ish dockcross support)
 - - - partial ct-ng support
 - < = not shipped by jruby

// https://github.com/boxcutter/bsd 

### Prebuild binary OS support

 * Linux: 3.10 and glibc 2.17+ (Mostly, see table below)
 * MacOS: 12
 * FreeBSD: 9+
 * OpenBSD: 6.8+
 * DragonFlyBSD: No support until RubyGems adds support
 * AIX: ???
 * Solaris: ???
 * Windows: 7+ (via direct FFI)


| Architecture      |Linux        |Mac |FreeBSD|AIX |Solaris|OpenBSD|DragonFlyBSD|
|-------------------|-------------|----|-------|----|-------|-------|------------|
| armv5             |             |    |       |    |       |       |            |
| armv6/armv7       | 3.12/2.17   |    |       |    |       |       |            |
| arm8/aarch64      | 3.12/2.17   | 12 | 11.4  |    |       |       |            |        
| i386              | 3.10/2.17   |    | 9.3   |    | -     | -*    |            |
| x86_64            | 3.10/2.17   | 12 | 9.3   |    | -*    | 6.8   | *Rubygems  |    
| sparc             |             |    |       |    | -     |       |            |
| sparcv9           | -*          |    |       |    | -*    |       |            |    
| ppc               | -           |    |       | -  |       |       |            |
| ppc64             | 3.10/2.17   |    |       | ?? |       |       |            |
| ppc64le           | 3.10/2.17   |    |       |    |       |       |            |
| mips              |             |    |       |    |       |       |            |
| mipsel            |             |    |       |    |       |       |            |
| mips64el          | 3.10/2.17   |    |       |    |       |       |            |    
| s390x             | 3.10/2.17   |    |       |    |       |       |            |
| loongarch64       | 5.19/2.36   |    |       |    |       |       |            |
| riscv32           |             |    |       |    |       |       |            |
| riscv64           | 5.10/2.35   |    |       |    |       |       |            |
| -Docker or runner-| ✔           |✔  | ✔     | ?IBM Cloud | ?Oracle Cloud |   ?   |            |

https://github.com/byteit101/jruby-dockcross

openbsd: add pkg-config make
mkdir /usr/libexec/
ln -s {/opt,}/usr/libexec/ld.so
# License

SubSpawn is licensed under a tri EPL/LGPL/Ruby license. You can use it, redistribute it and/or modify it under the terms of the:

[Eclipse Public License version 2.0](https://spdx.org/licenses/EPL-2.0.html) OR [GNU Lesser General Public License version 2.1 (or later)](https://spdx.org/licenses/LGPL-2.1-or-later.html) OR [Ruby License](https://spdx.org/licenses/Ruby.html)

