module SubSpawn::POSIX::Internal
	class Rlimit < FFI::Struct
		layout(
		# The current (soft) limit.
		:rlim_cur,	:rlim_t,
		#The hard limit.
		:rlim_max,	:rlim_t
		)
	end
end
