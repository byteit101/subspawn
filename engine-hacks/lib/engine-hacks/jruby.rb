
module EngineHacks

	def self.use_child_status symbol
		# No-op on JRuby
		nil
	end

	def self.child_status= value
		require 'jruby'
		JRuby.runtime.current_context.last_exit_status = status
	end

	def self.duplex_io(read, write)
		
	end
end
