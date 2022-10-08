require 'ffi'
require 'subspawn/version'
require 'subspawn/fd_parse'
if FFI::Platform.unix?
	require 'subspawn/posix'
	SubSpawn::Platform = SubSpawn::POSIX
elsif FFI::Platform.windows?
	raise "SubSpawn Win32 is not yet implemented"
else
	raise "Unknown FFI platform"
end

module SubSpawn
	# TODO: things to check: set $?
	def self.spawn_compat(command, *command2)
		# return just the pid
		delta_env = nil
		# check for env
		if command.is_a? Hash
			delta_env = command
			command = command2
		else # 2-arg ctor
			command = [command] + command2
		end
		opt = {}
		if command.last.is_a? Hash
			*command, opt = *command
		end
		if command.first.is_a? Array and command.first.length != 2
			raise ArgumentError, "First argument must be an pair TODO: check this"
		end
		raise ArgumentError, "Must provide a command to execute" if command.empty?
		raise ArgumentError, "Must provide options as a hash" unless opt.is_a? Hash
		if opt.key? :env and delta_env
			# TODO: warn?
			# unsupported
		else
			opt[:env] = delta_env
		end
		opt[:__ss_compat] = true
		# TODO: add shell here if necessary
		SubSpawn.spawn(command, opt).first
	end
	def self.spawn(command, opt={})
		unless command.is_a? Array # TODO: fix this check up with new parsing
			raise ArgumentError, "First argument must be an array" unless command.is_a? String
			# not the cleanest check, but should be better than generic exec errors
			raise SpawnError, "SubSpawn only accepts arrays #LINK TODO" if command.include? " " 
			command = [command]
		end
		fds = []
		compat = false
		env_opts = {base: ENV, set: false, deltas: nil, only: false}
		if command.first.is_a? Array
			warn "argv0 and array syntax both provided to SubSpawn. Preferring argv0" if opt[:argv0]
			command[0], tmp = *command.first
			opt[:argv0] = opt[:argv0] || tmp
		end
		base = SubSpawn::Platform.new(*command, arg0: (opt[:argv0] || command.first).to_s)
		opt.each do |key, value|
			case key
			when Array # P.s
				fds << [key,value]
			# TODO:  ,:output, :input, :error, :stderr, :stdin, :stdout, :pty, :tty ?
			when Integer, IO, :in,  :out, :err, :tty # P.s: in, out, err, IO, Integer
				fds << [[key], value]
			# TODO: , :cwd
			when :chdir # P.s: :chdir
				base.cwd = value
			when :tty, :pty
				base.tty = value
				#base.sid!# TODO: yes? no?
			when :sid
				base.sid! if value
			when :uid, :userid, :user, :owner, :ownerid # TODO: which?
				base.uid = value
			when :gid, :groupid, :group # TODO: which?
				base.gid = value
			when :env
				unless env_opts[:deltas]
					warn "Provided multiple ENV options"
				end
				env_opts[:deltas] = value
				env_opts[:set] = true
			when :setenv, :set_env, :env=
				if env_opts[:deltas]
					warn "Provided multiple ENV options"
				end
				env_opts[:deltas] = env_opts[:base] = value
				env_opts[:set] = true
				env_opts[:only] = true

			# Difference: new_pgroup is linux too?
			when :pgroup, :new_pgroup, :process_group # P.s: pgroup, :new_pgroup
				base.pgroup = value == true ? 0 : value if value
			when :flags # TODO: signals

			when /rlimit_(.*)/ # P.s
				# TODO: something
"
				resource limit: resourcename is core, cpu, data, etc.  See Process.setrlimit.
				:rlimit_resourcename => limit
				:rlimit_resourcename => [cur_limit, max_limit]
				"
			when :umask # P.s
				raise ArgumentError, "umask must be numeric" unless value.is_a? Integer
				base.umask = value
			when :unsetenv_others # P.s
				env_opts[:only] = !!value
				env_opts[:set] = true
			when :close_others # P.s
				warn "CLOEXEC is set by default, :close_others is a no-op in SubSpawn.spawn call. Consider :keep"
			when :argv0
				# Alraedy processed
			when :__ss_compat
				compat = true
			else
				# TODO: exception?
				warn "Unknown SubSpawn argument #{key.inspect}. Ignoring"
			end
		end
		if env_options[:set]
			base.env = if  env_options[:only]
				env_options[:deltas].to_h
			else
				env_options[:base].to_h.merge(env_options[:deltas].to_h)
			end
		end
		# parse and clean up fd descriptors
		fds = Internal.parse_fd_opts(fds) {|path| base.tty = path }
		# now make a graph and add temporaries
		ordering = Internal.graph_order(fds)
		# configure them in order, saving new io descriptors
		created_pipes = ordering.flat_map do |fd|
			result = fd.apply(base)
			fd.dests.map{|x| [x, result] }
		end.to_h
		# Spawn and return any new pipes
		[base.spawn!, IoHolder.new(created_pipes)]
	end
	def self.guess_mode(dests)
		read = d.include? 0 # stdin
		write = (d.include? 1 or d.include? 2) # stdout
		if read && write
			raise ArgumentError, "Invalid FD source specification: ambiguious mode (r & w)"
		elsif read
			:read
		elsif write
			:write
		else
			raise ArgumentError, "Invalid FD source specification: ambiguious mode (stdio missing)"
		end
	end

	def self.pty_spawn(*args, &block)
		pid, args = SubSpawn.spawn(args, [:in, :out, :err, :tty] => :tty)
		tty = args[:tty]
		list = [tty, tty, pid]
		if block.nil?
			return list
		else
			block.call(*list)
		end
	end

end