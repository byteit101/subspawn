require 'subspawn/win32/version'
require 'subspawn/win32/ffi'
module SubSpawn
class SpawnError < RuntimeError
end
class Win32
	W = SubSpawn::Win32::FFI

	module WinStr
		refine Object do
			def to_wstr
				"#{self.to_str}\0".encode("UTF-16LE")
			end
			def to_wstrp
				::FFI::MemoryPointer.from_string(to_wstr)
			end
		end
		refine NilClass do
			def to_wstr
				nil
			end
			def to_wstrp
				nil
			end
		end
	end
	using WinStr

	
	OpenFD = Struct.new(:fd, :path, :mode, :flags, :ref)
	def initialize(command, *args, arg0: command)
		@path = command
		#raise SpawnError, "Command not found: #{command}" unless @path
		# TODO: we use envp, so can't check this now
		@argv = [arg0, *args.map(&:to_str)]
		@fd_map = {}
		@fd_keeps = []
		@fd_closes = []
		@fd_opens = []
		@cwd = nil
		@pgroup = nil
		@env = :default
		@ctty = nil

		@win = {
			reqflags: 0,
			flags: 0,
			title: nil,
			desktop: nil,
			show: 0,
			confil: 0,
		}

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
			raise SpawnError, "Invalid FD open: overwrites existing mapping #{x.file.inspect}" unless @fd_map[fd_number(x.fd)].nil?
			@fd_map[fd_number(x.fd)] = x
		}

		@path = @path.gsub("/", "\\")
		@cwd = @cwd.gsub("/", "\\") unless @cwd.nil?
		
		raise SpawnError, "Invalid cwd path" unless @cwd.nil? or Dir.exist?(@cwd = ensure_file_string(@cwd))

		argv_str = build_argstr
		raise SpawnError, "Argument string is too long. #{argv_str.size} must be less than (1 << 15)" if argv_str.size >= (1 << 15)
		
		raise SpawnError, "Invalid controlling tty" unless @ctty.nil? or @ctty.respond_to? :con_pty
		
		true
	end

	def spawn!
		validate!
		startupinfo = W::StartupInfo.new # ffi gem zeros memory for us
		proc_info = W::ProcInfo.new
		out_pid = nil
		# set up file descriptors
		
		@fd_keeps.each {|fd| process_handle(fd, true) }
		@fd_closes.each {|fd| process_handle(fd, false) }

		# startup info
		use_stdio = W::STARTF_USESTDHANDLES
		startupinfo.dwFlags = use_stdio | @win[:reqflags] | @win[:flags]
		if use_stdio != 0
			startupinfo.hStdInput = handle_for(StdIn)
			startupinfo.hStdOutput = handle_for(StdOut)
			startupinfo.hStdError = handle_for(StdErr)
		end
		cap1 = startupinfo.lpDesktop = @win[:desktop].to_wstrp if @win[:desktop]
		cap2 = startupinfo.lpTitle = @win[:title].to_wstrp if @win[:title]
		startupinfo.wShowWindow = @win[:show] if @win[:show]
		startupinfo.dwFillAttribute = @win[:confill] if @win[:confill]
		if @win[:consize]
			startupinfo.dwXCountChars, startupinfo.dwYCountChars = *@win[:consize]
		end
		if @win[:winsize]
			startupinfo.dwXSize, startupinfo.dwYSize = *@win[:winsize]
		end
		if @win[:winpos]
			startupinfo.dwX, startupinfo.dwY = *@win[:winpos]
		end

		# TODO: does windows have rlimits?

		# TODO: allow configuring inherit handles. CRuby force this to true, so we will copy that for now
		hndl_inheritance = true
		sa = W::SecurityAttributes.new
		sa.bInheritHandle = hndl_inheritance
		
		flags = 0
		flags |= W::CREATE_UNICODE_ENVIRONMENT if @env != :default # ENVP
		flags |= W::NORMAL_PRIORITY_CLASS # TODO: allow configuring priority
		flags |= W::CREATE_NEW_PROCESS_GROUP if @pgroup



		# ARGV
		argv_str = build_argstr
		# TODO: move this validation to validate!
		raise SpawnError, "Argument string is too long. #{argv_str.size} must be less than (1 << 15)" if argv_str.size >= (1 << 15)

		# Add extra attributes (pty)
		numAttribs = 0
		numAttribs +=1 if @ctty != nil

		::FFI::MemoryPointer.new(:size_t, 1) do |sizeref|
			if numAttribs == 0
				sizeref.write(:size_t, 5)
			else
				W::InitializeProcThreadAttributeList(nil, numAttribs, 0, sizeref)
			end
			::FFI::MemoryPointer.new(:uint8_t, sizeref.read(:size_t)) do |attribList|

				if numAttribs > 0 && !W::InitializeProcThreadAttributeList(attribList, numAttribs,0, sizeref)
					raise SpawnError, "Couldn't initialize attribute list"
				end
				startupinfo.lpAttributeList = nil
				if numAttribs > 0
					flags |= W::EXTENDED_STARTUPINFO_PRESENT
					startupinfo.lpAttributeList = attribList
				end
				unless @ctty.nil?
					if !W::UpdateProcThreadAttribute(attribList, 0, W::PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, @ctty.con_pty.raw_handle, W::SIZEOF_HPCON, nil, nil)
						raise SpawnError, "Couldn't add pty to list"
					end
				end
				# ARGP/ENV
				envp_holder = make_envp
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
						raise SystemCallError.new("Spawn Error: CreateProcess: #{self.class.errno}", self.class.errno)
					end
					W.CloseHandle(proc_info.hProcess)
					W.CloseHandle(proc_info.hThread)
					# being a spawn clone, we don't normally expose the thread, but assign it if anyone wants it
					@out_thread = proc_info.dwThreadId
					out_pid = proc_info.dwProcessId

					# close our half of the files
					@fd_map.values.select{|x|x.is_a? OpenFD}.map{|x|x.ref.close; x.ref = nil}

				if numAttribs > 0
					W::DeleteProcThreadAttributeList(attribList)
				end
			end
		end
		out_pid
	end
	
	# TODO: allow io on left?
	def fd(number, io_or_fd)
		num = number.is_a?(Symbol) ? Std[number] : number.to_i
		raise ArgumentError, "Invalid file descriptor number: #{number}. Supported values = 0, 1, 2" unless [0,1,2].include? num
		@fd_map[num] = io_or_fd
		self
	end

	def fd_open(number, path, flags = 0, mode=0o666) # umask will remove bits
		num = number.is_a?(Symbol) ? Std[number] : number.to_i
		raise ArgumentError, "Invalid file descriptor number: #{number}. Supported values = 0.. or #{std.keys.inspect}" if num.nil?
		@fd_opens << OpenFD.new(number, path, mode, flags)
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

	def desktop(str)
		@win[:desktop] = str
		self
	end
	def title(str)
		@win[:title] = str
		self
	end
	def show_window(show) # TODO: translate ruby to flags
		@win[:show] = show
		@win[:reqflags] |= W::STARTF_USESHOWWINDOW
		self
	end
	def window_pos(x,y)
		@win[:winpos] = [x,y]
		@win[:reqflags] |= W::STARTF_USEPOSITION
		self
	end
	def window_size(w,h)
		@win[:winsize] = [w,h]
		@win[:reqflags] |= W::STARTF_USESIZE
		self
	end
	def console_size(x,y)
		@win[:conpos] = [x,y]
		@win[:reqflags] |= W::STARTF_USECOUNTCHARS
		self
	end
	def window_fill(attrib)
		@win[:confill] = attrib
		@win[:reqflags] |= W::STARTF_USEFILLATTRIBUTE
		self
	end
	def start_flags(flags)
		@win[:flags] = flags
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
	
	def pgroup(isnew)
		raise ArgumentError, "Invalid new_pgroup: #{isnew} (expecting boolean)" unless [true, false, nil, 0].include? isnew
		@pgroup = !!isnew
		self
	end
	alias :pgroup= :pgroup
	
	def ctty(path)
		@ctty = path
		self
	end
	alias :tty= :ctty=
	alias :tty :ctty
	
	
	def validate
		validate! rescue false
	end
	
	

	# generator for candidates for an executable name
	# usage:
	# SubSpawn::Win32.each_which("ls", ENV) {|path| ...}
	# SubSpawn::Win32.each_which("ls", ENV).to_a
	# TODO: fix this!
	def self.expand_which(name, env=ENV)
		name = name.gsub("/","\\") # windows-ify the name
		return self.to_enum(:expand_which, name, env) unless block_given?
		extensions = ["", *(ENV['PATHEXT'] || "").split(';')]
		# only allow relative paths if they traverse, and if they traverse, only allow relative paths
		if name.include? "/"
			extensions.each do |ext|
				yield File.absolute_path(name + ext)
			end
		else
			# If we were to follow
			# https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw
			# in the path search process, we should look in CWD and dirname($0) first,
			# and possibly the app paths registry key. Ignore for now
			env['PATH'].split(File::PATH_SEPARATOR).each do |path|
				extensions.each do |ext|
					yield File.join(path, name+ext)
				end
			end
		end
	end

	def self.shell_command(string)
		# MRI scans for "basic" commands and if so, just un-expands the shell
		# we could do that too, and there are 2 tests about that in rubyspec
		# but we shall ignore them for now
		# TODO: implement that
		# https://learn.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
		# I think this should work, maybe?
		["cmd.exe", "/c", string.to_str]#.gsub(/([)(%!^"><&|)])/, "^\\1")]
	end

	def self.errno
		errno = 0
		::FFI::MemoryPointer.new(:int, 1) do |errnoholder|
			W.get_errno(errnoholder)
			errno = errnoholder.read_int
		end
		return {win: W.GetLastError(), c: errno}.inspect
	end

	# Ruby raises EChild, so we have to reimplement wait/waitpid2
	def self.waitpid2(pid)
		# TODO: process limited information maybe?
		hndl = W.OpenProcess(W::PROCESS_QUERY_INFORMATION, false, pid)

		# TODO: proper error code
		raise SystemCallError.new("Missing processs") if hndl == 0 || hndl == W::INVALID_HANDLE_VALUE
		begin
			tmp = _single_exit_poll hndl
			while tmp.nil?
				sleep 0.01
				W.WaitForSingleObject(hndl, W::INFINITE)
				tmp = _single_exit_poll hndl
			end
			return [pid, tmp]
		ensure
			W.CloseHandle(hndl)
		end
	end
	def self._single_exit_poll hndl
		::FFI::MemoryPointer.new(:int, 1) do |buf|
			raise SystemCallError.new("polling fail") unless W::GetExitCodeProcess(hndl, buf)
			tmp = buf.read(:int)
			return tmp == W::STILL_ACTIVE ? nil : tmp
		end
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
			return nil # weirdly easy on windows
		else
			strings = @env.select{|k, v|
				!k.nil? and !v.nil?
			}.map{|k,v|
				k = k.to_str
				str = "#{k}=#{v.to_str}"  # rubyspec says to convert to_str
				raise ArgumentError, "Nulls not allowed in environment variable: #{str.inspect}" if str.include? "\0" # By Spec
				raise ArgumentError, "Variable key cannot include '=': #{str.inspect}" if k.include? "=" # By Spec
				"#{str}\0"
			}.join("") + "\0" # null end of argp
			return strings.to_wstr
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
		return str unless str =~ /[ \t\n\v"]/ # TODO: no \r?
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
		mapped = @fd_map[fdi] || fdi
		if mapped.is_a? OpenFD
			mapped.ref = File.new(mapped.path, mapped.flags, mapped.mode)
			mapped = mapped.ref.fileno
		end
		fd = fd_number(mapped)
		hndl = W.get_osfhandle(fd)

		if hndl == W::INVALID_HANDLE_VALUE || hndl == W::HANDLE_NEGATIVE_TWO
			if @fd_map.nil?
				hndl = W.GetStdHandle(W::STD_HANDLE[fdi])
			else
				raise SystemCallError.new("Invalid FD/handle for input fd #{fdi}", FFI.errno)
			end
		end
		# ensure the handle is inheritable
		res = W.SetHandleInformation(hndl, W::HANDLE_FLAG_INHERIT, W::HANDLE_FLAG_INHERIT)
		raise SystemCallError.new("Non-inheritable handle for input fd #{fdi} (#{self.class.errno})") unless res

		#puts "stdio[#{fdi}] = #{@fd_map[fdi]} => #{fd} => #{hndl} (#{res})"
		hndl
	end

	def process_handle(fdo, share)
		fd = fd_number(fdo)
		hndl = W.get_osfhandle(fd)

		if hndl == W::INVALID_HANDLE_VALUE || hndl == W::HANDLE_NEGATIVE_TWO
			raise SystemCallError.new("Invalid FD/handle for keep/close")
		end
		# ensure the handle is inheritable
		res = W.SetHandleInformation(hndl, W::HANDLE_FLAG_INHERIT, share ? W::HANDLE_FLAG_INHERIT : 0)
		raise SystemCallError.new("Couldn't change handle inheritance (#{self.class.errno})") unless res
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
