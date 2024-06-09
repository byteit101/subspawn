module SubSpawn
class JRuby < POSIX

	StdJava = {StdIn => "Input", StdOut => "Output", StdErr => "Error"}.freeze

	PID_CACHE_SIZE = 500

	def initialize(*args)
		super
		# we must keep a manual list of the last N unwaited pids so that we can access their status results
		@pidcache = JRubyProcessLruCache.new(PID_CACHE_SIZE)
	end
	
	def validate!
		super

		fallback_fail "fd_keep" unless @fd_keeps.empty?

		fallback_fail "argv0 != command" unless @path == @argv[0]
	end
	def spawn!
		validate!
		
		pb = java.lang.ProcessBuilder.new(@path, *@argv[1..-1])


		# set the default fd mapping before we start playing with things
		pb.inheritIO
		
		# Clean up FD maps
		maps = @fd_map.map{|k, v| [k, fd_number(v)] }

		# If output and error are merged, mark as merged
		if maps.include? [StdOut, StdErr] or maps.include? [StdErr, StdOut]
			pb.redirect_error_stream(true)
		elsif !maps.empty?
			fallback_fail "non-stdio mapping"
		end

		# Redirect basic numbers
		@fd_opens.each {|opn|
			num = fd_number(opn.fd)
			# Check for unsupported configurations
			fallback_fail "non-stdio redirect" if StdJava[num].nil?
			if num == StdErr and pb.redirect_error_stream?
				num = StdOut
			end
			# Redirect it to the file
			pb.send "redirect#{StdJava[num]}".to_sym , java.io.File.new(opn.path)
		}
		@fd_closes.map {|fd| fd_number(fd) }.each {|num|
			# in theory this may not be accurate, but good enough 
			pb.send "redirect#{StdJava[num]}".to_sym, java.lang.ProcessBuilder::Redirect::DISCARD unless StdJava[num].nil?
		}
		
		
		# set up working dir
		pb.directory(java.io.File.new(@cwd)) if @cwd
			
		if @env != :default
			env = pb.environment()
			env.clear
			@env.select{|k, v|
				!k.nil? and !v.nil?
			}.each{|k,v|
				k = k.to_str
				v = v.to_str  # rubyspec says to convert to_str
				raise ArgumentError, "Nulls not allowed in environment variable: #{str.inspect}" if str.include? "\0" # By Spec
				raise ArgumentError, "Variable key cannot include '=': #{str.inspect}" if k.include? "=" # By Spec
				env[k] = v
			}
		end

		process = pb.start
		@pidcache << process
		process.pid
	end
	
	def signal_mask(*args)
		fallback_fail "signal"
	end

	def signal_default(*args)
		fallback_fail "signal"
	end
	def umask=(value)
		fallback_fail "umask"
	end
	def sid!
		fallback_fail "sid"
	end
	def pgroup(pid)
		fallback_fail "pgroup"
	end	
	def ctty(path)
		fallback_fail "tty"
	end

	def rlimit(key, cur, max=nil)
		fallback_fail "rlimit"
	end

	def fallback_fail type
		raise SpawnError.new("Missing native support, process '#{type}' control not available. See TODO: fixme link")
	end

	COMPLETE_VERSION = {
		subspawn_jruby_fallback: SubSpawn::POSIX::VERSION,
	}

	def self.waitpid2(pid, options=0)
		raise SubSpawn::UnimplementedError("PID <= 0 not yet implemented in subspawn-poxix-jruby") if pid <= 0
		raise SubSpawn::UnimplementedError("PID not found in cache. Please install libfixposix for better process support via TODO fixme link") unless @pidcache.has_pid?
		proc = @pidcache[pid]
		if (options & Process::WNOHANG) != 0
			if proc.alive?
				return nil
			else
				# TODO: process.status
				proc.exit_value
			end
		else
			proc.wait_for()
			# TODO: Process.status
			proc.exit_value
		end
	end

	private
	def none
		@@none ||= Object.new
	end
end
class JRubyProcessLruCache
	def initialize(size)
		@max_size = size
		@data = {}
	end

	def << proc
		raise SpawnError.new("Process must not be nil") if proc.nil?
		@data.delete(proc.pid)
		@data[proc.pid] = proc
		@data.shift if @data.length > @max_size
		return proc
	end

	def has_pid?(pid)
		@data.has_key?(pid)
	end

	def [](pid)
		proc = @data.delete(pid)
		# if something was found & deleted (not nil), add it back in
		@data[pid] = proc if proc
	end

	def delete(pid)
		@data.delete(pid)
	end

end
end



