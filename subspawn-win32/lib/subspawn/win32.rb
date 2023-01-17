require 'subspawn/win32/ffi'
module SubSpawn
class SpawnError < RuntimeError
end
class Win32
	module WinStr
		refine Object do
			def to_wstr
				"#{str.to_str}\0".encode("UTF-16LE")
			end
		end
		refine NilClass do
			def to_wstr
				nil
			end
		end
	end
	using WinStr

	OpenFD = Struct.new(:fd, :path, :mode, :flags)
	
	def initialize(command, *args, arg0: command)
		@path = command
		#raise SpawnError, "Command not found: #{command}" unless @path
		# TODO: we use envp, so can't check this now
		@argv = [arg0, *args.map(&:to_str)]
		@fd_map = {}
		@fd_keeps = []
		@fd_closes = []
		@fd_opens = []
		@signal_mask = @signal_default = nil
		@cwd = nil
		@sid = false
		@pgroup = nil
		@env = :default
		@ctty = nil
		@rlimits = {}
		@umask = nil
	end
	attr_writer :cwd, :ctty
	
	StdIn = 0
	StdOut= 1
	StdErr = 2
	Std = {in: StdIn, out: StdOut, err: StdErr}.freeze
	
	def validate!
		@argv.map!(&:to_str) # By spec
		raise SpawnError, "Invalid argv" unless @argv.length > 0
		@fd_map = @fd_map.map do |number, source|
			raise SpawnError, "Invalid FD map: Not a number: #{number.inspect}" unless number.is_a? Integer
			[number, fd_check(source)]
		end.to_h
		@fd_keeps.each{|x| fd_check(x)}
		@fd_closes.each{|x| fd_check(x)}
		@fd_opens.each{|x|
			fd_check(x.fd)
			raise SpawnError, "Invalid FD open: Not a number: #{x.mode.inspect}" unless x.mode.is_a? Integer
			raise SpawnError, "Invalid FD open: Not a flag: #{x.flags.inspect}" unless x.flags.is_a? Integer
			raise SpawnError, "Invalid FD open: Not a file: #{x.file.inspect}" unless File.exist? x.path or Dir.exist?(File.dirname(x.path))
		}
		
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
				@fd_opens.each {|opn|
					sfa.addopen(fd_number(opn.fd), opn.path, opn.flags, opn.mode)
				}
				@fd_map.map{|k, v| [k, fd_number(v)] }.each do |dest, src|
					sfa.adddup2(src, dest)
				end
				@fd_closes.each {|fd| sfa.addclose(fd_number(fd)) }

				unless @rlimits.empty?
					# allocate output (pid)
					FFI::MemoryPointer.new(LFP::Rlimit, @rlimits.length) do |rlimits|
						# build array
						@rlimits.each_with_index {|(key, (cur, max)), i|
							rlimit = LFP::Rlimit.new(rlimits[i])
							#puts "building rlim at #{i} to #{[cur, max, key]}"
							rlimit[:rlim_cur] = cur.to_i
							rlimit[:rlim_max] = max.to_i
							rlimit[:resource] = key.to_i
						}
						sa.setrlimit(rlimits, @rlimits.length)
					end
				end
				
				# set up signals
				sa.sigmask = @signal_mask.to_ptr if @signal_mask
				sa.sigdefault = @signal_default.to_ptr if @signal_default
				
				# set up ownership and groups
				sa.pgroup = @pgroup.to_i if @pgroup
				sa.umask = @umask.to_i if @umask
				
				# Set up terminal control
				sa.setsid if @sid
				sa.ctty = @ctty if @ctty
				
				# set up working dir
				sa.cwd = @cwd if @cwd
				
				# allocate output (pid)
				FFI::MemoryPointer.new(:int, 1) do |pid|
					argv_str = @argv.map{|a|
						raise ArgumentError, "Nulls not allowed in command: #{a.inspect}" if a.include? "\0"
						FFI::MemoryPointer.from_string a
					} + [nil] # null end of argv
					FFI::MemoryPointer.new(:pointer, argv_str.length) do |argv_holder|
					
						# ARGV
						argv_holder.write_array_of_pointer argv_str
						
						# ARGP/ENV
						make_envp do |envp_holder|

							# Launch!
							ret = LFP.spawnp(pid, @path, argv_holder, envp_holder, sfa, sa)
							if ret != 0
								raise SystemCallError.new("Spawn Error: #{ret}", LFP.errno)
							end
							out_pid = pid.read_int
						end
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


	def spawn_w32!
		validate!
		startupinfo = W::StartupInfo.new # ffi gem zeros memory for us
		proc_info = W::ProcInfo.new
		out_pid = nil
		# set up file descriptors
		
		# TODO: SetHandleInformation(Inherit) etc
		#@fd_keeps.each {|fd| sfa.addkeep(fd_number(fd)) }
		#@fd_closes.each {|fd| sfa.addclose(fd_number(fd)) }

		startupinfo.dwFlags = W::STARTF_USESTDHANDLES
		startupinfo.hStdInput = handle_for(0)
		startupinfo.hStdOutput = handle_for(1)
		startupinfo.hStdError = handle_for(2)

		# TODO: does windows have rlimits?
		
		# set up ownership and groups
		sa.pgroup = @pgroup.to_i if @pgroup
		#sa.umask = @umask.to_i if @umask
		
		# Set up terminal control
		#sa.setsid if @sid
		#TODO: PTY!
		#sa.ctty = @ctty if @ctty

		# TODO: allow configuring inherit handles. CRuby force this to true, so we will copy that for now
		hndl_inheritance = true
		sa = W::SecurityAttributes.new
		sa.bInheritHandle = hndl_inheritance
		
		flags = 0
		flags |= W::CREATE_UNICODE_ENVIRONMENT # ENVP
		flags |= W::NORMAL_PRIORITY_CLASS # TODO: allow configuring priority

		# ARGV
		argv_str = build_argstr
		# TODO: move this validation to validate!
		raise SpawnError, "Argument string is too long. #{argv_str.size} must be less than (1 << 15)" if argv_str.size >= (1 << 15)
		
		# ARGP/ENV
		make_envp do |envp_holder|

			# Launch!
			# Note that @path can be null on windows, but we will always enforce otherwise
			ret = W.CreateProcess(
				@path.to_wstr, # DONE
				argv_str,  #DONE
				sa, # proc_sec, DONE, but unexposed
				sa, # thread_sec, DONE, but unexposed
				hndl_inheritance, # DONE, but unexposed
				flags, # DONE, but unexposed
				envp_holder, # DONE
				@cwd.to_wstr, # DONE
				startupinfo,
				proc_info # DONE
			)
			if !ret
				# TODO: CRuby does map_errno(GetLastError()) Do we need to do that for does FFI.errno do that already?
				raise SystemCallError.new("Spawn Error: CreateProcess", FFI.errno)
			end
			W.CloseHandle(proc_info.hProcess)
			W.CloseHandle(proc_info.hThread)
			# being a spawn clone, we don't normally expose the thread, but assign it if anyone wants it
			@out_thread = proc_info.dwThreadId
			out_pid = proc_info.dwProcessId
		end
		out_pid
	end
	
	# TODO: allow io on left?
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
	alias :name= :name

	def args(args)
		@argv = [@argv[0], *args.map(&:to_str)]
		self
	end
	alias :args= :args
	def command(cmd)
		@path = cmd
		self
	end
	alias :command= :command

	def env_reset!
		@env = :default
		self
	end
	def env(key, value)
		@env = ENV.to_h.dup if @env == :default
		@env[key.to_s] = value.to_s
		self
	end
	def env=(hash)
		@env = hash.to_h
		self
	end

	# TODO: I don't think windows has a umask equivalent?
#	alias :umask :umask=

	def pwd(path)
		@cwd = path
		self
	end
	alias :cwd :pwd
	alias :pwd= :cwd=
	alias :chdir :pwd
	alias :chdir= :cwd=
	
	def pgroup(pid)
		raise ArgumentError, "Invalid pgroup: #{pid}" if pid < 0 or !pid.is_a?(Integer)
		@pgroup = pid.to_i
		self
	end
	alias :pgroup= :pgroup
	
	def ctty(path)
		@ctty = path
		self
	end
	alias :tty= :ctty=
	alias :tty :ctty
	

	# TODO: I don't think windows has rlimit?
	alias :setrlimit :rlimit
	
	def validate
		validate! rescue false
	end
	
	

	# generator for candidates for an executable name
	# usage:
	# SubSpawn::POSIX.each_which("ls", ENV) {|path| ...}
	# SubSpawn::POSIX.each_which("ls", ENV).to_a
	def self.expand_which(name, env=ENV)
		return self.to_enum(:expand_which, name, env) unless block_given?
		# only allow relative paths if they traverse, and if they traverse, only allow relative paths
		if name.include? "/"
			yield File.absolute_path(name)
		else
			env['PATH'].split(File::PATH_SEPARATOR).each do |path|
				yield File.join(path, name)
			end
		end
	end

	def self.shell_command(string)
		# MRI scans for "basic" commands and if so, just un-expands the shell
		# we could do that too, and there are 2 tests about that in rubyspec
		# but we shall ignore them for now
		# TODO: implement that
		["sh", "-c", string.to_str]
	end

	COMPLETE_VERSION = {
		subspawn_win32: SubSpawn::Win32::VERSION,
	}

	private
	def none
		@@none ||= Object.new
	end

	def make_envp
		if @env == :default
			yield nil # weirdly easy on windows
		else
			strings = @env.select{|k, v|
				!k.nil? and !v.nil?
			}.map{|k,v|
				k = k.to_str
				str = "#{k}=#{v.to_str}"  # rubyspec says to convert to_str
				raise ArgumentError, "Nulls not allowed in environment variable: #{str.inspect}" if str.include? "\0" # By Spec
				raise ArgumentError, "Variable key cannot include '=': #{str.inspect}" if k.include? "=" # By Spec
				"#{str}\0"
			} + "\0" # null end of argp
			yield strings.to_wstr
		end
	end
	def build_argstr
		# TODO: quote this way, or are other characters 
		@argv.map{|a|
			raise ArgumentError, "Nulls not allowed in command: #{a.inspect}" if a.include? "\0"
			quote_arg(a)
		}.join(" ").to_wstr
	end
	# windows quoting is horrible and not consistent
	# TODO: test this throughly
	# https://stackoverflow.com/questions/31838469/how-do-i-convert-argv-to-lpcommandline-parameter-of-createprocess
	def quote_arg(str)
		# if no whitespace or quote characters, this is a "simple" argument
		return str unless str =~ / \t\n\v"/ # TODO: no \r?
		backslashes = nil
		base = str.each_char.map do |c|
			if c != "\\"
				if backslashes.nil? # we are just a lone character
					c
				else # we are terminating a backslash sequence
					if c == '"'
						backslashes + backslashes + "\\" + c # double escape
					else
						backslashes + c # no escaping necessary (UNC path, etc)
					end.tap{ backslashes = nil } # clear saved escapes
				end
			else
				backslashes << c
			end
		end.join("")
		%Q{"#{base}#{backslashes}#{backslashes}"} # A quote goes next, so double escape again
	end
	def handle_for(fdi)
		fd = fd_number(@fd_map[fdi] || fdi)
		hndl = W.get_osfhandle(fd)

		if hndl == INVALID_HANDLE_VALUE || hndl == HANDLE_NEGATIVE_TWO
			if @fd_map.nil?
				hndl = W.GetStdHandle(W::STD_HANDLE[fdi])
			else
				raise SystemCallError.new("Invalid FD/handle for input fd #{fdi}", FFI.errno)
			end
		end
		hndl
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

end
end



