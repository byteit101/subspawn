module SubSpawn::Internal
	class FdSource
		def initialize(dests)
			@dests = dests
			raise SpwnError, "Can't provide :tty in this source list" if dests.include? :tty
		end
		attr_reader :dests

		def destroys? value
			@dests.include? value
		end
		def depends? o
			false
		end
		def before? o
			depends? o
		end
		def max
			@dests.max
		end
		def to_dbg
			[self.class, @dests]
		end
		def heads
			nil
		end
		def tails
			@dests
		end

		def raw_apply base, value
			@dests.each {|dest| 
				base.fd(dest, value)
			}
			nil # TODO: return the io for basics? would need to cache the fds
		end

		class Basic < FdSource
			def initialize(dests, int)
				super(dests)
				@value = int
			end
			def max
				[@dests.max, @value].max
			end
			def source
				@value
			end
			def depend? o
				o.dests.include? @value
			end
			def temp_source(new)
				self.class.new(@dests, new)
			end
			def before? o
				# we are before o if:
				# o destroys any of our sources
				# or we depend on o
				depends? o or o.destroys? @value
			end
			def heads
				[@value]
			end
			def tails
				@dests
			end
			def to_dbg
				[@dests, @value]
			end
			def apply base
				raw_apply base, @value
			end
		end
		class Temp < Basic
			def tails
				super.map{|x|Xchange.new(x)}
			end
		end
		# class Child < Basic # I don't think this is any different?
		# 	def to_dbg
		# 		[@dests, :child, @value]
		# 	end
		# end

		class Open < FdSource
		end

		class File < Open
			def initialize(dests, file, mode, perm)
				super(dests)
				@value = file
				@mode = mode || ::File::RDONLY
				@perm = perm || 0o644
			end
			def to_dbg
				[@dests, :file, @value, @mode, @perm]
			end
			def apply base
				first, *rest = @dests
				base.fd_open(first, @value, @mode || IO::RDONLY, @flags || 0)
				rest.each {|dest| base.fd(dest, first) }
				nil
			end
		end

		class Pipe < Open
			def initialize(dests, dir)
				super(rdests)
				@dir = dir
			end
			def apply base
				@saved ||= IO.pipe
				r, w = {read: @saved, write: @saved.reverse}[dir]
				raw_apply base, r
				@dests.each {|dest| base.fd_close(w) } # if you want the other end, pass it in yourself

				IoHolder::Pipe.new(w, r)
			end
			#attr_reader :output
		end
		class PTY < Open
			def initialize(dests)
				tty, ntty = dests.partition{|x|x == :tty}
				super(ntty)
				@settty = !tty.empty?
			end
			def apply base
				m,s = (@saved ||= PTY.open)
				@dests.each {|dest| base.fd_close(m) } # if you want the master, pass it in yourself
				raw_apply base, s
				if @settty
					base.tty = s
				end
				IoHolder::PTY.new(m,s)
			end
		end

		class Close < FdSource
			def to_dbg
				[:close, @dests]
			end

			def heads
				nil
			end
			def tails
				@dests
			end
			def apply base
				@dests.each {|dest| base.fd_close(dest) }
				nil
			end
		end

		Xchange = Struct.new(:fd)
		class Xchange
			def to_s
				"xc_#{fd}"
			end
			def to_i
				fd
			end
		end
	end
end