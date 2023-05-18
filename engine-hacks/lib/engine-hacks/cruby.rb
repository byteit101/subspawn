require 'engine_hacks/engine_hacks'
require 'English'

# TODO: this doesn't actually work
#alias $BUILTIN_CHILD_STATUS $?

module EngineHacks

	def self.use_child_status symbol
		@symbol = symbol.to_sym
		MRI.install_status! symbol
	end

	def self.child_status= value
		if defined? @symbol
			Thread.current[@symbol] = value
		else
			nil # not installed yet
		end
	end
	
	def self.duplex_io(read, write)
		raise ArgumentError.new("Read argument must be IO") unless read.is_a? IO
		raise ArgumentError.new("Write argument must be IO") unless write.is_a? IO
		MRI.join_io(read, write)
	end
end
