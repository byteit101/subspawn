require 'subspawn'
require 'engine-hacks'

EngineHacks.use_child_status :subspawn_child_status

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
	alias :builtin_backtick :`
	def `(str)
		require 'open3'
		Open3.capture2(str).first
	end
end

module Process
	class << self
		alias :builtin_spawn :spawn

		def spawn(*args)
			SubSpawn.spawn_compat(*args)
		end

		def subspawn(args, opt={})
			SubSpawn.spawn(args, opt)
		end

		# don't make a loop if waitpid isn't defined
		if SubSpawn::Platform.method(:waitpid2)
			def wait(*args)
				SubSpawn.wait *args
			end
			def waitpid(*args)
				SubSpawn.waitpid *args
			end
			def wait2(*args)
				SubSpawn.wait2 *args
			end
			def waitpid2(*args)
				SubSpawn.waitpid2 *args
			end
			def last_status
				SubSpawn.last_status
			end
			def detach pid
				SubSpawn.detach(pid)
			end
		end
	end
end

class IO
	def self.popen(*args, &block)
		SubSpawn.popen_compat(*args, &block)
	end
end
