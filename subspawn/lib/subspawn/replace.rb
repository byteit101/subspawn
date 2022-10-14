require 'subspawn'

module Kernel
	alias :builtin_spawn :spawn
	def spawn(*args)
		SubSpawn.spawn_compat(*args)
	end
end

module Process
	alias :builtin_spawn :spawn

	def spawn(*args)
		SubSpawn.spawn_compat(*args)
	end
end

module PTY
	alias :builtin_spawn :spawn
	alias :builtin_getpty :getpty
	def spawn(*args, &block)
		SubSpawn.pty_spawn(*args, &block)
	end
	alias :getpty :spawn
end
