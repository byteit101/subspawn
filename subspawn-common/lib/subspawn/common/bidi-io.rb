require 'subspawn/common/version'

module SubSpawn::Common

	# combines two Unidirectional IO's into one "single" bidirectional IO
	class BidiMergedIO # < IO
		def initialize(read, write)
			@read, @write = read, write
		end

		READS = %i{
			autoclose?
			binmode?
			bytes
			chars
			close_read
			codepoints
			each
			each_byte
			each_char
			each_codepoint
			each_line
			eof?
			eof
			external_encoding
			fdatasync
			getbyte
			getc
			gets
			internal_encoding
			lineno
			lines
			pos
			pread
			read
			read_nonblock
			readbyte
			readchar
			readline
			readpartial
			rewind
			seek
			stat
			sysread
			sync

			autoclose=
			binmode=
			close_on_exec=
			close
			flush
			fsync
			set_encoding
		}
		WRITES = %i{
			<<
			close_write
			print
			printf
			putc
			puts
			pwrite
			syswrite
			write
			write_nonblock
			sync
			
			autoclose=
			binmode=
			close_on_exec=
			close
			flush
			fsync
			set_encoding
		}

		(READS + WRITES).uniq.each do |meth|
			if READS.include? meth
				if WRITES.include? meth # both
					define_method(meth) do |*args|
						@read.send(meth, *args)
						@write.send(meth, *args)
					end
				else # read only
					define_method(meth) do |*args|
						@read.send(meth, *args)
					end
				end
			else # write only
				define_method(meth) do |*args|
					@write.send(meth, *args)
				end
			end
		end

		def underlying_read_io
			@read
		end
		def underlying_write_io
			@write
		end

		def to_io
			self
		end

		def closed?
			@read.closed? && @write.closed?
		end
	end

	class BidiMergedIOClosable < BidiMergedIO
		def initialize(read, write, &block)
			super
			@closer= block
		end

		def close
			super
			@closer.call
		end
	end

	class ClosableIO < IO
		def initialize(underlying, &block)
			@base = underlying
			@closer = block
		end

		(BidiMergedIO::READS + BidiMergedIO::WRITES).uniq.each do |meth|
			define_method(meth) do |*args|
				@base.send(meth, *args)
			end
		end

		def to_io
			self
		end

		def close
			@base.close
			@closer.call
		end
	end
end
