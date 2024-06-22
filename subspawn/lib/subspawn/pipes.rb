
class SubSpawn::IoHolder
	def initialize(map)
		@map = map
	end

	def [](key)
		tmp = get(key)
		tmp = tmp.to_io if tmp.respond_to? :to_io
		tmp
	end
	def get(key)
		@map[SubSpawn::Internal.parse_fd(key, true)]
	end
	def composite? key
		self.get(key).is_a? Composite
	end
	def empty?
		@map.values.reject(&:nil?).empty?
	end

	class Composite
	end

	class Pipe < Composite
		def initialize(parent, child)
			@parent, @child = parent, child
		end
		attr_reader :parent, :child
		def to_io
			@parent = @parent.lazy_resolve if @parent.respond_to? :lazy_resolve
			@parent
		end
		# NOTE: fileno may change if we are on a platform that does lazy resolution (jruby-fallback-backend)
		# in such cases, fileno is synthetic anyway
		def fileno
			@parent.fileno
		end
	end
	
	class PTY < Composite
		def initialize(master, slave)
			@master, @slave = master, slave
		end
		attr_reader :master, :slave
		alias :to_io :master
		def to_ary
			[@master, @slave]
		end
		def fileno
			@master.fileno
		end
	end
end
