# frozen_string_literal: true
require 'ffi'

module LFP
	module Binary
		API_VERSION = "0.5.0" # the same as the binary, but hard coded
		GEM_VERSION = "#{API_VERSION}.0"
		NAME = if FFI::Platform.mac?
			"libfixposix.dylib"
		elsif FFI::Platform.windows?
			raise "No Win32 libfixposix"
		else # TODO: all .so?
			"libfixposix.so"
		end
		PATH = File.join(__dir__, NAME)
	end
end
