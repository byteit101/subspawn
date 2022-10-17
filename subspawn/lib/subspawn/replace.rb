require 'subspawn'

module Kernel
	class << self
		alias :builtin_spawn :spawn
		def spawn(*args)
			SubSpawn.spawn_compat(*args)
		end
	end

	private
	alias :builtin_spawn :spawn
	def spawn(*args)
		SubSpawn.spawn_compat(*args)
	end
end

module Process
	class << self
		alias :builtin_spawn :spawn

		def spawn(*args)
			SubSpawn.spawn_compat(*args)
		end
	end
end

require 'pty'

module PTY
	class << self
		alias :builtin_spawn :spawn
		alias :builtin_getpty :getpty

		def spawn(*args, &block)
			SubSpawn.pty_spawn(*args, &block)
		end
		alias :getpty :spawn
	end
end
