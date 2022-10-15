require 'ffi'

module SubSpawn::POSIX::Internal
	class Rlimit < FFI::Struct
		layout(
		# The current (soft) limit.
		:rlim_cur,	:rlim_t,
		#The hard limit.
		:rlim_max,	:rlim_t
		)
	end
	module SignalFn
		extend FFI::Library
		ffi_lib FFI::Library::LIBC

		attach_function :emptyset, :sigemptyset, [:pointer], :int
		attach_function :fillset, :sigfillset, [:pointer], :int
		attach_function :addset, :sigaddset, [:pointer, :int], :int
		attach_function :delset, :sigdelset, [:pointer, :int], :int
		attach_function :ismember, :sigismember, [:pointer, :int], :int


		ffi_lib %w{pthread.so.0 pthread pthread.dylib}

		attach_function :mask, :pthread_sigmask, %i{int pointer pointer}, :int
	end
end
