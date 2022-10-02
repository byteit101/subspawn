require 'pty'
require 'libfixposix'

class LFP::RawProcessBuilder
	class SpawnError < RuntimeError
	end
	
	def initialize(command, *args, arg0: command)
		@path = self.class.which(command)
		raise SpawnError, "Command not found: #{command}" unless @path
		@argv = [arg0, *args.map(&:to_s)]
		@fd_map = {}
		@fd_keeps = []
		@fd_closes = []
		# TODO: expose opens?
		@signal_mask = @signal_default = nil
		@uid = @gid = @cwd = nil
		@sid = false
		@pgroup = nil
		@env = none # TODO: ENV
		@ctty = nil
	end
	attr_writer :signal_mask, :signal_default, :uid, :gid, :cwd
	
	StdIn = 0
	StdOut= 1
	StdErr = 2
	Std = {in: StdIn, out: StdOut, err: StdErr}
	
	def validate!
		raise SpawnError, "Invalid path" unless @path.start_with? "/" # windows isn't supported, this is posix, fixed
		@argv.map!(&:to_s)
		raise SpawnError, "Invalid argv" unless @argv.length > 0
		@fd_map = @fd_map.map do |number, source|
			raise SpawnError, "Invalid FD map: Not a number: #{number.inspect}" unless number.is_a? Integer
			[number, fd_check(source)]
		end.to_h
		@fd_keeps.each{|x| fd_check(x)}
		@fd_closes.each{|x| fd_check(x)}
		
		raise SpawnError, "Invalid cwd path" unless @cwd.nil? or Dir.exist?(@cwd = ensure_file_string(@cwd))
		
		@ctty = @ctty.path if !@ctty.nil? and @ctty.is_a? File # PTY.open returns files
		raise SpawnError, "Invalid controlling tty path" unless @ctty.nil? or File.exist?(@ctty = ensure_file_string(@ctty))
		
		true
	end
	
	
	def spawn!
		validate!
		sfa = LFP::SpawnFileActions.new
		sa = LFP::Spawnattr.new
		raise "Spawn Init Error" if 0 != sfa.init
		out_pid = nil
		begin
			raise "Spawn Init Error" if 0 != sa.init
			begin
				# set up file descriptors
				
				@fd_keeps.each {|fd| sfa.addkeep(fd_number(fd)) }
				# TODO: add opens?
				@fd_map.map{|k, v| [k, fd_number(v)] }.each do |dest, src|
					sfa.adddup2(src, dest)
				end
				@fd_closes.each {|fd| sfa.addclose(fd_number(fd)) }
				
				# set up signals
				sa.sigmask = @signal_mask if @signal_mask
				sa.sigdefault = @signal_default if @signal_default
				
				# set up ownership and groups
				sa.uid = @uid.to_i if @uid
				sa.gid = @gid.to_i if @gid
				sa.pgroup = @pid.to_i if @pid
				
				# Set up terminal control
				sa.setsid if @sid
				sa.ctty = @ctty if @ctty
				
				# set up working dir
				sa.cwd = @cwd if @cwd
				
				# TODO: ENV
				
				FFI::MemoryPointer.new(:int, 1) do |pid|
					argv_str = @argv.map{|a|FFI::MemoryPointer.from_string a} + [nil] # null end of argv
					FFI::MemoryPointer.new(:pointer, argv_str.length) do |argv_holder|
					
						# ARGV
						argv_holder.write_array_of_pointer argv_str
						
						# TODO: ARGP
						envp_holder = LFP.get_environ()
						
						ret = LFP.spawn(pid, @path, argv_holder, envp_holder, sfa, sa)
						if ret != 0
							#Errno.const_get(Errno.constants.find{|x| Errno.const_get(x)::Errno == ret})
							SystemCallError.new("Spawn Error: #{ret}", errno)
						end
						out_pid = pid.read_int
					end
				end
			ensure
				sa.destroy
			end
		ensure
			sfa.destroy
		end
		out_pid
	end
	
	def fd(number, io_or_fd)
		num = number.is_a?(Symbol) ? Std[number] : number.to_i
		raise ArgumentError, "Invalid file descriptor number: #{number}. Supported values = 0.. or #{std.keys.inspect}" if num.nil?
		if fd_number(io_or_fd) == num
			fd_keep(io_or_fd)
		else
			@fd_map[num] = io_or_fd
		end
		self
	end
	def fd_keep(io_or_fd)
		@fd_keep << io_or_fd
		self
	end
	def fd_close(io_or_fd)
		@fd_closes << io_or_fd
		self
	end
	def name(string)
		@argv[0] = string.to_s
		self
	end
	def env_clear!
		# TODO
		self
	end
	def env(key, value)
		# TODO
		self
	end
	def env=(hash)
		# TODO
		self
	end
	def signal_mask(sigmask_ptr)
		@signal_mask = sigmask_ptr
		self
	end
	def signal_default(sigmask_ptr)
		@signal_default = sigmask_ptr
		self
	end
	def owner(uid: none, gid: none)
		@uid = uid unless uid.equals? none
		@gid = gid unless gid.equals? none
		self
	end
	def pwd(path)
		@cwd = path
		self
	end
	alias :cwd :pwd
	alias :pwd= :cwd=
	
	def sid!
		@sid = true
		self
	end
	def pgroup(pid)
		@pgroup = pid
		self
	end
	alias :pgroup= :pgroup
	
	def tty(path)
		@ctty = path
		self
	end
	alias :tty= :tty
	alias :ctty= :tty
	alias :ctty :tty
	
	
	def validate
		validate! rescue false
	end
	
	
	def self.which(path)
		if defined? JRUBY_VERSION # JRuby has better lookup
			which_jruby path
		else
			which_mri path
		end
	end
	private
	def none
		@@none ||= Object.new
	end
	def ensure_file_string(path)
		if defined? JRUBY_VERSION # accept File and Path java objects
			path = path.to_file if path.respond_to? :to_file
			if path.respond_to? :absolute_path
				path.absoloute_path
			else
				path.to_s
			end
		else
			path.to_s
		end
	end
	def fd_check(source)
		case source
		when Integer then source
		when IO then source
		when :in, :out, :err
			Std[source]
		else
			raise SpawnError, "Invalid FD map: Not a io or number: #{source.inspect}"
		end
	end
	def fd_number(source)
		case source
		when Integer then source
		when IO then source.fileno
		when :in, :out, :err
			Std[source]
		else
			raise SpawnError, "Invalid FD map: Not a io or number: #{source.inspect}"
		end
	end
	def self.which_jruby(cmd)
		require 'jruby'
		org.jruby.util.ShellLauncher.findPathExecutable(JRuby.runtime, cmd)&.absolute_path
	end
	# TODO: test absoloute and relative
	# https://stackoverflow.com/questions/2108727/which-in-ruby-checking-if-program-exists-in-path-from-ruby
	def self.which_mri(cmd)
	  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
	  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
		exts.each do |ext|
		  exe = File.join(path, "#{cmd}#{ext}")
		  return exe if File.executable?(exe) && !File.directory?(exe)
		end
	  end
	  nil
	end
end
