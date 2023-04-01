require 'ffi'
require 'subspawn/version'
require 'subspawn/fd_parse'
if FFI::Platform.unix?
	require 'subspawn/posix'
	SubSpawn::Platform = SubSpawn::POSIX
elsif FFI::Platform.windows?
	require 'subspawn/win32'
	SubSpawn::Platform = SubSpawn::Win32
else
	raise "Unknown FFI platform"
end
require 'subspawn/common'

module SubSpawn
	# Parse and convert the weird Ruby spawn API into something nicer
	def self.__compat_parser(is_popen, command, command2)

		delta_env = nil
		# check for env
		if command.respond_to? :to_hash
			delta_env = command.to_hash
			command = command2
		else # 2-arg ctor
			command = [command] + command2
		end
		opt = {}
		if command.last.respond_to? :to_hash
			*command, opt = *command
		end
		if command.first.is_a? Array and command.first.length != 2
			raise ArgumentError, "First argument must be an pair TODO: check this"
		end
		popen = if is_popen && command.length > 1
			command.pop
		end
		raise ArgumentError, "Must provide a command to execute" if command.empty?
		raise ArgumentError, "Must provide options as a hash" unless opt.is_a? Hash
		if opt.key? :env and delta_env
			# TODO: warn?
			raise SpawnError, "SubSpawn.spawn_compat doesn't allow :env key, try SubSpawn.spawn instead"
			# unsupported
		else
			opt[:env] = delta_env if delta_env
		end
		copt = {:__ss_compat => true }
		copt[:__ss_compat_testing] = opt.delete(:__ss_compat_testing)
		begin
			cf = nil
			if command.length == 1 and (cf = command.first).respond_to? :to_str
				# and ((cf = cf.to_str).include? " " or (Internal.which(cmd)))
				#command = ["sh", "-c", cf] # TODO: refactor
				command = [command.first.to_str]
				copt[:__ss_compat_shell] = true
			end
		rescue NoMethodError => e # by spec
			raise TypeError.new(e)
		end
		return [popen, command, opt, copt]
	end

	# Parse and convert the weird Ruby spawn API into something nicer
	def self.spawn_compat(command, *command2)
		#File.write('/tmp/spawn.trace', [command, *command2].inspect + "\n", mode: 'a+')

		__spawn_internal(*__compat_parser(false, command, command2)[1..-1]).first
	end
	# TODO: accept block mode?
	def self.spawn(command, opt={})
		__spawn_internal(command, opt, {})
	end
	def self.spawn_shell(command, opt={})
		__spawn_internal(Platform.shell_command(command), opt, {})
	end
	def self.__spawn_internal(command, opt, copt)
		unless command.respond_to? :to_ary # TODO: fix this check up with new parsing
			raise ArgumentError, "First argument must be an array" unless command.is_a? String
			# not the cleanest check, but should be better than generic exec errors
			raise SpawnError, "SubSpawn only accepts arrays #LINK TODO" if command.include? " " 
			command = [command]
		else
			command = command.to_ary.dup
		end
		unless opt.respond_to? :to_hash # TODO: fix this check up with new parsing
			raise ArgumentError, "Second argument must be a hash, did you mean to use spawn([#{command.inspect}, #{opt.inspect}]) ?"
		end
		fds = []
		env_opts = {base: ENV, set: false, deltas: nil, only: false}
		begin
			if command.first.respond_to? :to_ary
				warn "argv0 and array syntax both provided to SubSpawn. Preferring argv0" if opt[:argv0]
				command[0], tmp = *command.first.to_ary.map(&:to_str) # by spec
				opt[:argv0] = opt[:argv0] || tmp
			end
			command = command.map(&:to_str) # by spec
		rescue NoMethodError => e # by spec
			raise TypeError.new(e)
		end
		arg0 = command.first
		raise ArgumentError, "Cannot spawn with null bytes: OS uses C-style strings" if command.any? {|x|x.include? "\0"}
		base = SubSpawn::Platform.new(*command, arg0: (opt[:argv0] || arg0).to_s)
		opt.each do |key, value|
			case key
			when Array # P.s
				fds << [key,value]
			# TODO:  ,:output, :input, :error, :stderr, :stdin, :stdout, :pty, :tty ?
			when Integer, IO, :in,  :out, :err # P.s: in, out, err, IO, Integer
				fds << [[key], value]
			# TODO: , :cwd
			when :chdir # P.s: :chdir
				base.cwd = value.respond_to?(:to_path) ? value.to_path : value
			when :tty, :pty
				if value == :tty || value == :pty
					fds << [[key], value] # make a new pty this way
				else
					base.tty = value
					#base.sid!# TODO: yes? no?
				end
			when :sid
				if base.respond_to? :sid!
					base.sid! if value
				else
					warn "SubSpawn Platform (#{base.class}) doesn't support 'sid'"
				end
			when :env
				if env_opts[:deltas]
					warn "Provided multiple ENV options"
				end
				env_opts[:deltas] = value
				env_opts[:set] ||= value != nil
			when :setenv, :set_env, :env=
				if env_opts[:deltas]
					warn "Provided multiple ENV options"
				end
				env_opts[:deltas] = env_opts[:base] = value
				env_opts[:set] = value != nil
				env_opts[:only] = true

			# Difference: new_pgroup is linux too?
			when :pgroup, :new_pgroup, :process_group # P.s: pgroup, :new_pgroup
				raise TypeError, "pgroup must be boolean or integral" if value.is_a? Symbol
				base.pgroup = value == true ? 0 : value if value
			when :signal_mask # TODO: signal_default
				if base.respond_to? :signal_mask
					base.signal_mask(value)
				else
					warn "SubSpawn Platform (#{base.class}) doesn't support 'signal_mask'"
				end
			when /rlimit_(.*)/ # P.s
				unless base.respond_to? :rlimit
					warn "SubSpawn Platform (#{base.class}) doesn't support 'rlimit_*'"
				else	
					name = $1
					keys = [value].flatten
					base.rlimit(name, *keys)
				end
			when /w32_(.*)/ # NEW
				name = $1
				raise ArgumentError, "Unknown win32 argument: #{name}" unless %w{desktop title show_window window_pos window_size console_size window_fill start_flags}.include? name
				unless base.respond_to? :name
					warn "SubSpawn Platform (#{base.class}) doesn't support 'w32_#{$1}'"
				else	
					base.send(name, *value)
				end
			when :rlimit # NEW?
				raise ArgumentError, "rlimit as a hash must be a hash" unless value.respond_to? :to_h

				unless base.respond_to? :rlimit
					warn "SubSpawn Platform (#{base.class}) doesn't support 'rlimit_*'"
				else
					value.to_h.each do |key, values|
						base.rlimit(key, *[values].flatten)
					end
				end
			when :umask # P.s
				raise ArgumentError, "umask must be numeric" unless value.is_a? Integer
				unless base.respond_to? :umask
					warn "SubSpawn Platform (#{base.class}) doesn't support 'umask'"
				else
					base.umask = value
				end
			when :unsetenv_others # P.s
				env_opts[:only] = !!value
				env_opts[:set] ||= !!value
			when :close_others # P.s
				warn "CLOEXEC is set by default, :close_others is a no-op in SubSpawn.spawn call. Consider :keep"
			when :argv0
				# Alraedy processed
			else
				# TODO: exception always?
				if copt[:__ss_compat]
					raise ArgumentError, "Unknown SubSpawn argument #{key.inspect}. Ignoring"
				else
				warn "Unknown SubSpawn argument #{key.inspect}. Ignoring"
				end
			end
		end
		working_env = if env_opts[:set]
			base.env = if  env_opts[:only]
				env_opts[:deltas].to_hash
			else
				env_opts[:base].to_hash.merge(env_opts[:deltas].to_hash)
			end.to_h
		else
			ENV
		end
		# now that we have the working env, we can finally update the command
		unless copt[:__ss_compat_testing]
			if copt[:__ss_compat_shell] && Internal.which(command.first, working_env).nil? && command.first.include?(" ") # ruby specs don't allow builtins, apparently
				command = Platform.shell_command(command.first)
				base.args = command[1..-1]
				base.command = base.name = command.first
			end
			newcmd = Internal.which(command.first, working_env)
			# if newcmd is null, let the systemerror shine from below
			if command.first!= "" && !newcmd.nil? && newcmd != command.first
				base.command = newcmd
			end
		end

		# parse and clean up fd descriptors
		fds = Internal.parse_fd_opts(fds) {|path| base.tty = path }
		# now make a graph and add temporaries
		ordering = Internal.graph_order(fds)
		# configure them in order, saving new io descriptors
		created_pipes = ordering.flat_map do |fd|
			result = fd.apply(base)
			fd.all_dests.map{|x| [x, result] }
		end.to_h
		# Spawn and return any new pipes
		[base.spawn!, IoHolder.new(created_pipes)]
	end

	def self.pty_spawn_compat(*args, &block)
		pty_spawn(args, &block)
	end
	def self.pty_spawn(args, opts={}, &block)
		# TODO: setsid?
		# TODO: MRI tries to pull the shell out of the ENV var, but that seems wrong
		pid, args = SubSpawn.spawn(args, {[:in, :out, :err, :tty] => :pty, :sid => true}.merge(opts))
		tty = args[:tty]
		list = [tty, tty, pid]
		return list unless block_given?

		begin
			return block.call(*list)
		ensure
			tty.close unless tty.closed?
			# MRI waits this way to ensure the process is reaped
			if Process.waitpid(pid, Process::WNOHANG).nil?
				Process.detach(pid)
			end
		end
	end

	def self.popen(command, mode="r", opt={}, &block)
		#Many modes, and "-" is not supported at this time
		__popen_internal(command, mode, opt, {}, &block)
	end
	def self.popen_compat(command, *command2, &block)
		#Many modes, and "-" is not supported at this time
		mode, command, opt, copt = __compat_parser(true, command, command2)
		mode ||= "r"
		__popen_internal(command, mode, opt, copt, &block)
	end
	#Many modes, and "-" is not supported at this time
	def self.__popen_internal(command, mode, opt, copt, &block)
		outputs = {}
		# parse, but ignore irrelevant bits
		parsed = Internal.modestr_parse(mode) & (~(IO::TRUNC | IO::CREAT | IO::APPEND | IO::EXCL))
		looking = if parsed & IO::WRONLY != 0
			outputs[:in] = :pipe
			looking = [:in]
		elsif parsed & IO::RDWR != 0
			outputs[:out] = :pipe
			outputs[:in] = :pipe
			looking = [:out, :in] # read, write, from our POV
		else # read only
			outputs[:out] = :pipe
			looking = [:out]
		end
		# do normal spawning. Note: we only chose the internal spawn for popen_compat
		pid, rawio = __spawn_internal(command, outputs.merge(opt), copt)

		# create a proxy to close the process
		io_proxy = looking.length == 1 ? SubSpawn::Common::ClosableIO : SubSpawn::Common::BidiMergedIOClosable
		io = io_proxy.new(*looking.map{|x|rawio[x]}) do
			# MRI waits this way to ensure the process is reaped
			Process.waitpid(pid) # TODO: I think there isn't a WNOHANG here
		end

		# return or call
		return io unless block_given?
		begin
			return yield(io)
		ensure
			io.close unless io.closed?
			# MRI waits this way to ensure the process is reaped
			if Process.waitpid(pid, Process::WNOHANG).nil?
				Process.detach(pid)
			end
		end
	end

	# Windows doesn't like mixing and matching who is spawning and who is waiting, so use
	# subspawn.wait* if you used subspawn.spawn*, while using process.wait* if you used Process.spawn*
	# though if you replace process, then it's a moot point
	if SubSpawn::Platform.method(:waitpid2)
		def self.wait(*args)
			waitpid *args
		end
		def self.waitpid(*args)
			waitpid2(*args)&.first
		end
		def self.wait2(*args)
			waitpid2 *args
		end
		def self.waitpid2(*args)
			SubSpawn::Platform.waitpid2 *args
		end
		def self.last_status
			SubSpawn::Platform.last_status
		end
	else
		def self.wait(*args)
			Process.wait *args
		end
		def self.waitpid(*args)
			Process.waitpid *args
		end
		def self.wait2(*args)
			Process.wait2 *args
		end
		def self.waitpid2(*args)
			Process.waitpid2 *args
		end
		def self.last_status
			Process.last_status
		end
	end

	def self.detach(pid)
		Thread.new do
			pid, status = *SubSpawn.waitpid2(pid)
			# TODO: ensure this loop isn't necessary
			# while pid.nil?
			# 	sleep 0.01
			# 	pid, status = *SubSpawn.waitpid2(pid)
			# end
			status
		end.tap do |thr|
			thr[:pid] = pid
			# TODO: does thread.pid need to exist?
		end
	end

	COMPLETE_VERSION = {
		subspawn: SubSpawn::VERSION,
		platform: SubSpawn::Platform::COMPLETE_VERSION,
	}
end
