# frozen_string_literal: true
unless defined? LFP::LFPFile # avoid circular require loops
	require 'libfixposix'
	require 'libfixposix/ffi'
end

module LFP
	VERSION = "#{LFP::INTERFACE_VERSION}.0"
end
