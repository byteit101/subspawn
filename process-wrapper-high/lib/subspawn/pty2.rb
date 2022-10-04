require 'subspawn/posix' # TODO: better name

module SubSpawn
module PTY
	def self.spawn(command, *args, input: nil, output: nil, error: nil)
		w = SubSpawn::POSIX
		if args.empty?
			if !command.include?(" ") || !w.which(command).nil?
				:single
			else
				args = ["-c",  command]#"exec \"$@\"",
				command = "sh"
				puts "WARN! shell incoke"
				:shell
			end
		else
			:multi
		end
		m,s = ::PTY.open # TODO: our own pty?
		#puts "SPAWNING: #{command} -> #{args}"
		pid = w.new(command, *args).
			fd(w::StdIn, input || s.fileno).
			fd(:out, output || s).
			fd(2, error || s).
			tty(s.path).
			fd_close(m).
			spawn!
			
		arg = [m, m, pid]
		if block_given?
			yield arg # TODO: any closing?
		else
			arg
		end
	end
	def self.command2args(command, *args)
		w = SubSpawn::POSIX
		if args.empty?
			if !command.include?(" ") || !w.which(command).nil?
				:single
			else
				args = ["-c",  command]#"exec \"$@\"",
				command = "sh"
		#		puts "WARN! shell incoke"
				:shell
			end
		else
			:multi
		end
		[command, *args]
	end
end
end