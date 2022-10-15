# frozen_string_literal: true


# TODO: check for binaries?
module LFP
	module LFPFile
		def self.local_so
			list = []
			list += ENV["LIBFIXPOSIX_PATH"].split(";;") if ENV["LIBFIXPOSIX_PATH"]
			list << "fixposix"
			list
		end
	end
end
require "libfixposix/ffi"
require "libfixposix/version"
begin
	require "libfixposix/binary"
rescue LoadError
	# no binary installed, use system wide or ENV var
end
