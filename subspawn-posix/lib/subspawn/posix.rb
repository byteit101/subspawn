mode = :native
if ENV['SUBSPAWN_BACKEND'] == "jruby" || ENV_JAVA['subspawn.backend'] == "jruby"
	mode = :jruby
end

# Try to load LFP, fallback to jruby
begin
	require 'libfixposix' if mode == :native
rescue LoadError => e
	if e.to_s.include? "fixposix." and e.to_s.include? "Could not open library"
		mode = :jruby
	else
		raise
	end
end
require 'subspawn/posix/version'
require 'subspawn/common'

# Signals, FFI, and PTY are only needed for native POSIX via LFP
if mode == :native
	require 'subspawn/posix/ffi_helper'
	require 'subspawn/posix/signals'
	require 'subspawn/posix/pty'
end

require 'subspawn/posix_base'

# Set the exported platform
SubSpawn::POSIX_Platform = if mode == :jruby
	warn "Using JRuby backend. Please see wiki TODO to fix this"
	require 'subspawn/jruby'
	SubSpawn::JRuby
else
	SubSpawn::POSIX
end
