# frozen_string_literal: true


# TODO: check for binaries?
module LFP
	module LFPFile
		def self.local_so
			%w{libfixposix.so.3 libfixposix.so fixposix.so fixposix}
		end
	end
end
require_relative 'libfixposix/ffi'
require_relative "libfixposix/version"