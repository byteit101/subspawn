require 'libfixposix'
require 'subspawn/posix/version'
require 'subspawn/posix/ffi_helper'
require 'subspawn/posix/signals'
module SubSpawn
class SpawnError < RuntimeError
end
class POSIX

	OpenFD = Struct.new(:fd, :path, :mode, :flags)
	
	def initialize(command, *args, arg0: command)
		@path = self.class.which(command)
		raise SpawnError, "Command not found: #{command}" unless @path
		@argv = [arg0, *args.map(&:to_s)]
		@fd_map = {}
		@fd_keeps = []
		@fd_closes = []
		@fd_opens = []
		@signal_mask = @signal_default = nil
		@uid = @gid = @cwd = nil
		@sid = false
		@pgroup = nil
		@env = :default
		@ctty = nil
		@rlimits = {}
		@umask = nil
	end
	attr_writer :uid, :gid, :cwd, :ctty
	
	StdIn = 0
	StdOut= 1
	StdErr = 2
	Std = {in: StdIn, out: StdOut, err: StdErr}.freeze
	
	def validate!
		@argv.map!(&:to_s)
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
					rlimit = Internal::Rlimit.new
					@rlimits.each {|key, (cur, max)|
						rlimit[:rlim_cur] = cur.to_i
						rlimit[:rlim_max] = max.to_i
						sfa.setrlimit(key.to_i, rlimit)
					}
				end
				
				# set up signals
				sa.sigmask = @signal_mask.to_ptr if @signal_mask
				sa.sigdefault = @signal_default.to_ptr if @signal_default
				
				# set up ownership and groups
				sa.uid = @uid.to_i if @uid
				sa.gid = @gid.to_i if @gid
				sa.pgroup = @pid.to_i if @pid
				sa.umask = @umask.to_i if @umask
				
				# Set up terminal control
				sa.setsid if @sid
				sa.ctty = @ctty if @ctty
				
				# set up working dir
				sa.cwd = @cwd if @cwd
				
				# allocate output (pid)
				FFI::MemoryPointer.new(:int, 1) do |pid|
					argv_str = @argv.map{|a|FFI::MemoryPointer.from_string a} + [nil] # null end of argv
					FFI::MemoryPointer.new(:pointer, argv_str.length) do |argv_holder|
					
						# ARGV
						argv_holder.write_array_of_pointer argv_str
						
						# ARGP/ENV
						make_envp do |envp_holder|

							# Launch!
							ret = LFP.spawnp(pid, @path, argv_holder, envp_holder, sfa, sa)
							if ret != 0
								SystemCallError.new("Spawn Error: #{ret}", LFP.errno)
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
	# usage:
	# signal_mask = SigSet.empty.add(:usr1).delete("USR2")
	# signal_mask(:full, exclude: [9])
	def signal_mask(sigmask = nil, add: [], delete: [])
		@signal_mask = sigmask.is_a?(Symbol) ? SigSet.send(sigmask) : sigmask
		@signal_mask.add(add).delete(delete)
		self
	end
	alias :signal_mask= :signal_mask
	alias :sigmask= :signal_mask
	alias :sigmask :signal_mask

	# usage:
	# signal_default = SigSet.empty.add(:usr1).delete("USR2")
	# signal_default(:full, exclude: [9])
	def signal_default(sigmask = nil, add: [], delete: [])
		@signal_default = sigmask.is_a?(Symbol) ? SigSet.send(sigmask) : sigmask
		@signal_default.add(add).delete(delete)
		self
	end
	alias :signal_default= :signal_default

	def umask=(value)
		@umask = value.nil? ? nil : value.to_i
		self
	end
	alias :umask :umask=

	def owner(uid: none, gid: none) # TODO: broken
		@uid = uid unless uid.equal? none
		@gid = gid unless gid.equal? none
		self
	end
	def pwd(path)
		@cwd = path
		self
	end
	alias :cwd :pwd
	alias :pwd= :cwd=
	alias :chdir :pwd
	alias :chdir= :cwd=
	
	def sid!
		@sid = true
		self
	end
	def pgroup(pid)
		@pgroup = pid
		self
	end
	alias :pgroup= :pgroup
	
	def ctty(path)
		@ctty = path
		self
	end
	alias :tty= :ctty=
	alias :tty :ctty
	

	def rlimit(key, cur, max=cur)
		key = if key.is_a? Integer
			key.to_i
		else# TODO: is upcase ok?
			Process.const_get("RLIMIT_#{key.to_s.upcase}")
			#raise SpawnError, "Invaild rlimit key: #{key}"
		end
		raise SpawnError, "rlimit value was nil" if cur.nil?
		cur = ensure_rlimit(key, cur)
		max = ensure_rlimit(key, max || cur)
		@rlimits[key] = [cur, max]
		self
	end
	alias :setrlimit :rlimit
	
	def validate
		validate! rescue false
	end
	
	
	# TODO: keep which here?
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
	def ensure_rlimit(key, value)
		#if key.nil?
		#	Process.getrlimit(key).last # if here, we are requesting max, as it was nil
		#end
		return value.to_i if value.is_a? Integer
		Process.const_get("RLIMIT_#{value.to_s.upcase}") # TODO: is upcase ok?
	end

	def make_envp
		if @env == :default
			yield LFP.get_environ
		else
			strings = @env.map{|k,v|FFI::MemoryPointer.from_string "#{k}=#{v}"} + [nil] # null end of argp
			FFI::MemoryPointer.new(:pointer, strings.length) do |argp_holder|
				argp_holder.write_array_of_pointer strings
				yield argp_holder
			end
		end
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
end



