# frozen_string_literal: true

require 'ffi'
require 'subspawn/win32/ffi'

module SubSpawn
class Win32
module PtyHelper

	W = SubSpawn::Win32::FFI
	class PtyIO < IO
		def inspect
			"#<IO:masterpty:#{@slave_path}>"
		end

		# Subspawn-specific feature
		attr_reader :slave_path

		private
		def __subspawn_init(name)
			# All other files are opened cloexec, this one isn't yet as it came from native code
			self.close_on_exec = true
			@slave_path = name.freeze
			self.sync = true
		end
	end

	class ConPTYHelper
		def initialize(hpc, pipes)
			@hpc = hpc
			@close = true
			@pipes = pipes
		end
		def no_gc!
			@close=false
		end
		def close
			if @close
				W::ClosePseudoConsole(@hpc) # TODO!
				@pipes.reject(&:closed?).each(&:close)
			end
		end
	end
	module IoHelper
		refine IO do
			def to_hndl
				hndl = W.get_osfhandle(self.fileno)

				if hndl == INVALID_HANDLE_VALUE || hndl == HANDLE_NEGATIVE_TWO
					raise SystemCallError.new("Invalid FD/handle for input fd #{self}", FFI.errno)
				end
				hndl
			end
		end
	end

	def self.open_internal(chmod_for_open = false, initial_size: [40,80], flags: 0)
		# TODO: does windows care about permissions? I'm going to assume no for now

		child_r, us_w = IO.pipe
		us_r, child_w = IO.pipe
		size = W::Coord[initial_size]
		hpc = nil
		FFI::MemoryPointer.new(:uintptr_t, 1) do |ptyref|
			hr = W::CreatePseudoConsole(size, child_r.to_hndl, child_w.to_hndl, flags, ptyref)
			if hr < 0 # failure
				raise "ConPTY failure: #{hr}"
			end
			hpc = ptyref.read(:uintptr_t)
		end

		master = PtyIO.for_fd(m, IO::RDWR | IO::SYNC)
		master.send(:__subspawn_init, name)

		# we could shim the slave to be a fake file, or we could just re-open the path
		# which fixes #inspect, #tty?, #path, and #close_on_exec, all in one go
		# https://bugs.ruby-lang.org/issues/19036
		slave = File.open(name, IO::RDWR | IO::SYNC)
		
		child_r.close
		child_w.close

		[master, slave, name]
	end

	def self.open
		*files, name = open_internal(true)
		return files unless block_given?

		begin
			return yield files.dup # Array, not splatted
		ensure
			files.reject(&:closed?).each(&:close)
		end
	end

end
end
end
