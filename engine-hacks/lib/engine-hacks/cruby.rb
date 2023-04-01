require 'engine-hacks/engine_hacks'
require 'English'

# TODO: this doesn't actually work
#alias $BUILTIN_CHILD_STATUS $?

module EngineHacks

	def self.use_child_status symbol
		@symbol = symbol.to_sym
		MRI::install_status! symbol
	end

	def self.child_status= value
		use_child_status :EngineHacksChildStatus unless defined? @symbol
		Thread.current[@symbol] = value
	end
	
	def self.duplex_io(read, write)
		
	end
end
