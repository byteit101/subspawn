# ffi-generator for libfixposix

This is a script and a header file set that is used to generate ffi bindings for libfixposix.
Nothing is genericized, and it hews closely to libfixposix.

## I just want to build it

```sh
gem install cast
ruby ffi_gen.rb ../libfixposix/src/include/lfp.h > ../ffi-bindings-libfixposix/lib/libfixposix/ffi.rb
```

## New verison testing and development

`ffi_gen` uses [cast](https://github.com/oggy/cast/) to parse and understand the headers. Once cast has the AST of the files, ffi_gen filters and deduces types. To check if the filtering and deductions are correct, set `live = true` near the bottom of the file and then send it to stdout. This will also supress the final output. Once the types are deduced, it uses the configuration passed into `builder.export` to extract the ffi signatures and classes to upcast from structs. This whole file is jank and has a single purpose of parsing and generating libfixposix. It probably won't work on other c libs, but patches are welcome if you get to to do so.

If you update libfixposix, update the `builder.export` call at the end of `ffi_gen.rb`

An important thing to note is "passthrough" types are detected from typedefs, while direct types are #defines. See the commments in `fake.h` for details.

The `fake` directory is on the include path to avoid having to parse system includes. All forward to `fake/fake.h` which is where all declarations go. You may have to modify the parser when you do.

The structure was generated with:

```
cd ../libfixposix/src/includes/
mkdir -p fake/sys
for file in $(\rgrep -h '#include' | sort -u | grep -v 'lfp/' | sed 's/# *include <\(.*\)>/\1/'); do echo "#include <fake/fake.h>" > fake/$file; done
for file in $(\rgrep -h '#  include' | sort -u | grep -v 'lfp/' | sed 's/# *include <\(.*\)>/\1/'); do echo "#include <fake/fake.h>" > fake/$file; done
mv fake/sys ../../../ffi-generator
```

This was last tested with libfixposix 0.4.3
