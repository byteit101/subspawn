module SubSpawn
	module Win32
	end
end

require 'subspawn/win32/ffi'

class SubSpawn::Win32ProcessWrapper
	W = SubSpawn::Win32::FFI
	# TODO: GC pattern to free resources
	def initialize
		@hndls = []
		@startupinfo = W::StartupInfo.new # ffi gem zeros memory for us
		@proc_info = W::ProcInfo.new
	end

	def wstr(str)
		return nil if str.nil?
		"#{str.to_str}\0".encode("UTF-16LE")
	end

	def create_process(module_name=nil, argv=nil, inheritance: false, flags: 0, env: nil, cwd: nil)
		# TODO: encode
		W.CreateProcess(wstr(module_name), wstr(argv), 
			nil, # TODO
			nil, # TODO
			inheritance, flags,
			env, wstr(cwd), @startupinfo, @proc_info
		)
	end

	def wait(delay=W::INFINITE)
		W.WaitForSingleObject(@proc_info.hProcess, delay)
	end

	def close
		W.CloseHandle(@proc_info.hProcess)
		W.CloseHandle(@proc_info.hThread)
	end


end


pw = SubSpawn::Win32ProcessWrapper.new

pw.create_process(nil, "notepad")

pw.wait(5_000)

pw.close
