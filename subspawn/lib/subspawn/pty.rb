# Multi-PTY support
require 'io/console'

class SubSpawn::NestedPTY
	def initialize(parentmaster, parentslave, input, childmaster)
		@pm = parentmaster
		@ps = parentslave
		@child = childmaster
		@input = input
		STDERR.puts({pm: @pm, ps: @ps, child: @child, input: input}.inspect)
		# TODO: tap the parentmaster winsize=
		@child.winsize = @ps.winsize
		@run = true
		@thr = Thread.new do
			valid = [input, childmaster]
			while @run
				# TODO: do we have to worry about translation as we are going through an extra PTY?
				# TODO: blocking writes? [childmaster, parentslave]
				r, w,  = IO.select(valid,nil, nil,0.5)
				next if r.nil?
				if r.include?(input)
					childmaster.write(input.readpartial(4096))
				end
				if r.include?(childmaster)
					begin
					parentslave.write(childmaster.readpartial(4096))
					rescue Errno::EIO
						valid -= [childmaster]
					end
				end
			end
		end
	end
	# can take up to 0.5s to close, async
	def close
		@run = false
	end
end

