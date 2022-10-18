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

overwrite = defined? PTY

module PTY
	unless overwrite
		class ChildExited < RuntimeError
			def initialize(status)
				@status = status
			end
			attr_reader :status
		end
	end
	class << self
		if overwrite
			alias :builtin_spawn :spawn
			alias :builtin_getpty :getpty
		end

		def spawn(*args, &block)
			SubSpawn.pty_spawn(*args, &block)
		end
		alias :getpty :spawn

		def open(&blk)
			SubSpawn::Platform::PtyHelper.open(&blk)
		end

		def check(pid, do_raise=false)
			return if Process.waitpid(pid, Process::WNOHANG | Process::WUNTRACED).nil?
			return $? unless do_raise
			raise ::PTY::ChildExited.new($?)
		end
	end
end
