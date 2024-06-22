require 'subspawn/common/raw_status'
require 'engine-hacks'
module SubSpawn
# This isn't threadsafe, but I'm not going to fix it because this
# is a fallback, and you really should be using lfp
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
class JRuby < POSIX

	StdJava = {StdIn => "Input", StdOut => "Output", StdErr => "Error"}.freeze
	StdJavaProcess = {StdIn => "Output", StdOut => "Input", StdErr => "Error"}.freeze

	PID_CACHE_SIZE = 500

	# we must keep a manual list of the last N unwaited pids so that we can access their status results
	@@pidcache = JRubyProcessLruCache.new(PID_CACHE_SIZE)

	def initialize(*args)
		super
		@pipeno = -1000 # starting number for deferred pipes
		@deferred_pipes = {}
	end
	
	def validate!
		super

		fallback_fail "fd_keep" unless @fd_keeps.empty?
	end
	def spawn!
		validate!
		
		pb = java.lang.ProcessBuilder.new(@path, *@argv[1..-1])

		# set the default fd mapping before we start playing with things
		pb.inheritIO
		
		# Clean up FD maps
		maps = @fd_map.map{|k, v| [k, fd_number(v)] }

		pipe_copies = {}
		maps.each do |from, to|
			sorted = [from, to].sort
			# If output and error are merged, mark as merged
			if sorted == [StdOut, StdErr]
				pb.redirect_error_stream(true)
			elsif !StdJava[sorted[1]].nil? && sorted[0] < 0
				# pipe redirect
				pb.send "redirect#{StdJava[sorted[1]]}".to_sym, java.lang.ProcessBuilder::Redirect::PIPE
				pipe_copies[sorted[0]] = sorted[1]
			else
				fallback_fail "non-stdio mappings"
			end
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
			if num < 0 # deferred  pipe end
				@deferred_pipes[num].peer.close!
			elsif StdJava[num].nil?
				# no-op, you are not trying to close stdio, nor a pipe
			else # stdio
				# in theory this may not be accurate, but good enough 
				pb.send "redirect#{StdJava[num]}".to_sym, java.lang.ProcessBuilder::Redirect::DISCARD
			end
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

		# start and save this process
		process = pb.start
		@@pidcache << process

		# extract pipe IO for lazy pipe IO
		pipe_copies.each do |pipe, stdio|
			@deferred_pipes[pipe].peer.io = process.send("get#{StdJavaProcess[stdio]}Stream".to_sym).to_io
		end

		process.pid
	end

	# JRuby does defer pipe creation
	def pipe_defer
		r = Common::DeferredPipe.new(@pipeno -= 1, :r)
		w = Common::DeferredPipe.new(@pipeno -= 1, :w)
		r.write(w, @deferred_pipes)
		[r, w]
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

	def self.fallback_fail type
		raise SpawnError.new("Missing native support, process '#{type}' control not available. See TODO: fixme link")
	end

	COMPLETE_VERSION.clear
	COMPLETE_VERSION[:subspawn_jruby_fallback] = SubSpawn::POSIX::VERSION
	VERSION = SubSpawn::POSIX::VERSION
 
	def self.waitpid2(pid, options=0)
		fallback_fail("PID <= 0 not yet implemented in subspawn-poxix-jruby") if pid <= 0
		fallback_fail("PID not found in cache: overflow?") unless @@pidcache.has_pid? pid
		proc = @@pidcache[pid]
		# Note: this implementation doesn't save the signals, just the exit code
		if (options & Process::WNOHANG) != 0
			if proc.alive?
				return nil
			else
				@@pidcache.delete(pid)
				_set_status(Process::Status.send :new, pid, proc.exit_value, nil)
			end
		else
			proc.wait_for()
			@@pidcache.delete(pid)
			_set_status(Process::Status.send :new, pid, proc.exit_value, nil)
		end
	end

	private
	def none
		@@none ||= Object.new
	end
	def self._set_status status
		EngineHacks.child_status = status
		@last_status = status
		return status.nil? ? nil : [status.pid, status]
	end
end
end



