# JRuby and CRuby both do internal things to build the status, so I think we can mostly just override it
# without checking
class Process
	class Status
		def initialize(pid, status=nil, termsig=nil)
			@pid = pid
			@stat = status
			@termsig = termsig
		end
	
		private :initialize

		# Public API (it's weird!)

		def & num
			@stat & num
		end

		def == other
			if other.is_a? Process::Status
				@stat == other.exitstatus
				# Very weird that we don't compare pids or termination options
				# but the doc says we only need to do this.
			else
				false
			end
		end

		def >> num
		  @stat >> num
		end

		# no coredumps on windows
		def coredump?
			false
		end

		def exited?
			!@stat.nil?
		end

		def exitstatus
			@stat
		end

		def inspect
			"#<Process::Status: #{to_s}>"
		end

		attr_reader :pid

		def signaled?
			!@termsig.nil?
		end

		# No stopped condition on windows
		def stopped?
			false
		end

		def stopsig
			nil
		end

		def success?
			return nil unless exited?
			return exitstatus == 0
		end

		attr_reader :termsig
	
		def to_i
			# a deeply unsettling API here, but it's platform-dependent, so lets make it slightly saner
			((@stat || 0)) | ((@termsig || 0) << 8)
		end
	
		def to_s
			tail = if exited?
				"exit #{exitstatus}"
			else # stopped or signaled, probably
				mid = "signal #{termsig}"
				name = Signal.signame(termsig)
				if name
					"SIG#{name} (#{mid})"
				else
					mid
				end
			end
			"pid #{@pid} #{tail}"
		end
	end
end
