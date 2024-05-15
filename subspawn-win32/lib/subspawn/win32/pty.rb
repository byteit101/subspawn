# frozen_string_literal: true

require 'ffi'
require 'subspawn/win32'
require 'subspawn/common'

module SubSpawn
class Win32
module PtyHelper

	W = SubSpawn::Win32::FFI

	class MasterPtyIO < SubSpawn::Common::BidiMergedIO
		def initialize(read, write, pty)
			super(read, write)
			read.sync = true
			write.sync = true
			@con_pty = pty
		end

		def inspect
			"#<masterpty:#{@con_pty}>"
		end

		def winsize
			@conpty.winsize
		end

		def winsize= arg
			@conpty.winsize = arg
		end
		def tty?
			true
		end
		def isatty
			true
		end

		# Subspawn-specific feature
		attr_reader :con_pty
	end
	class SlavePtyIO < SubSpawn::Common::BidiMergedIO
		def initialize(read, write, pty)
			super(read, write)
			read.sync = true
			write.sync = true
			@con_pty = pty
		end

		def winsize
			@conpty.winsize
		end

		def winsize= arg
			@conpty.winsize = arg
		end
		def tty?
			true
		end
		def isatty
			true
		end

		def inspect
			"#<winpty:#{@con_pty}>"
		end

		# Subspawn-specific feature
		attr_reader :con_pty
	end

	# TODO: ensure all handles/resources are cleaned up properly
	class ConPTYHelper
		def initialize(hpc, pipes, size)
			@hpc = hpc
			@close = true
			@pipes = pipes
			@lastsize = size
		end
		def winsize
			@lastsize
		end
		def winsize=(size)
			if W::ResizePseudoConsole(@hpc, W::Coord[size]) < 0
				raise "ConPTY Resize failure"
			else
				@lastsize = size
			end
		end
		def con_pty
			self
		end
		def raw_handle
			@hpc
		end
		def no_gc!
			@close=false
		end
		def close
			if @close
				W::ClosePseudoConsole(@hpc) # TODO!
				@hpc = nil
				@pipes.reject(&:closed?).each(&:close)
			end
		end
		def closed?
			if @close
				@hpc.nil? && @pipes.all?(&:closed?)
			else
				nil # falsy
			end
		end
	end
	module IoHelper
		refine IO do
			def to_hndl
				hndl = if RUBY_ENGINE == "jruby"
					self.fileno # jruby returns the raw handle, not the fd
				else
					W.get_osfhandle(self.fileno)
				end

				if hndl == W::INVALID_HANDLE_VALUE || hndl == W::HANDLE_NEGATIVE_TWO
					raise SystemCallError.new("Invalid FD/handle for input fd #{self}", FFI.errno)
				end
				hndl
			end
		end
	end
	using IoHelper

	def self.open_internal(chmod_for_open = false, initial_size: [40,80], flags: 0)
		# TODO: does windows care about permissions? I'm going to assume no for now

		child_r, us_w = IO.pipe
		us_r, child_w = IO.pipe
		size = W::Coord[initial_size]
		hpc = nil
		::FFI::MemoryPointer.new(:uintptr_t, 1) do |ptyref|
			hr = W::CreatePseudoConsole(size, child_r.to_hndl, child_w.to_hndl, flags, ptyref)
			if hr < 0 # failure
				raise "ConPTY failure: #{hr}"
			end
			hpc = ptyref.read(:uintptr_t)
		end

		pty = ConPTYHelper.new(hpc, [child_r, child_w, us_r, us_w], initial_size.flatten)
		master = MasterPtyIO.new(us_r, us_w, pty)

		slave = SlavePtyIO.new(child_r, child_w, pty)

		#child_r.close
		#child_w.close

		[master, slave, pty]
	end

	def self.open
		*files, pty = open_internal(true)
		return files unless block_given?

		begin
			return yield files.dup # Array, not splatted
		ensure
			pty.close
			files.reject(&:closed?).each(&:close)
		end
	end

end
end
end
