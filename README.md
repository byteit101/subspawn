process builder monorepo
-----------------



Parts:
 - libfixposix (build only, for ffi-generator)
 - ffi-generator (build only)
 - ffi-bindings-libfixposix (gem)
 - ffi-binary-libfixposix (gem)
 - process-wrapper-mid (gem)
 - process-library-high (gem)
 - jruby-jar (gem/jar)



libfixposix
-----------

The underlying library used is libfixposix. Currently the most recent and most widely distributed version in distros is 0.4.3, so we use that. Once 0.5.0 is in most distros, consider releasing that.
In order to use libfixposix, you must configure the build, or just remove the `#if @VAR@` statements in the headers. See where ffi-generator complains to know what to remove.

