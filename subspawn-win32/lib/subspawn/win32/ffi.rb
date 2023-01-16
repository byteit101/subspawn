require 'ffi'

module SubSpawn::Win32::FFI
	extend FFI::Library

	W = SubSpawn::Win32::FFI

	# Common types

	# uintptr or :pointer ?
	typedef :uintptr_t, :hwnd
	typedef :uintptr_t, :handle

	# TODO: I think this is corect?
	typedef :uint, :dword
	typedef :ushort, :word

	module MMHelper
		# from https://github.com/ffi/ffi/wiki/Structs

		# Use the symbol passed from the method for accessing the analogous field.
		# This method can also take a &block, but we would not use it.
		def method_missing( sym, *args )
		  # convert symbol to a string to allow regex checks
		  str = sym.to_s
		  
		  # derive the member's symbolic name
		  member = str.match( /^([a-z0-9_]+)/i )[1].to_sym
	  
		  # raise an exception via the default behavior if that symbol isn't a member!
		  super unless members.include? member
	  
		  # this ternary checks for the presence of an equals sign (=) to indicate an
		  # assignment operation and changes which method we invoke and whether or not
		  # to send the splatted arguments as well.
		  (str =~ /=$/) ? send( :[]=, member, *args ) : send( :[], member )
		end
	end

	class ProcInfo < FFI::Struct
		include MMHelper
	   #_PROCESS_INFORMATION
	   layout		:hProcess, :handle,
		:hThread, :handle,
		:dwProcessId, :dword,
		:dwThreadId, :dword

		# TODO: if this is a managed struct, we could autofree the handles. Do we want to?
		# def self.release ptr
		# 	W.free(ptr.hThread)
		# 	W.free(ptr.hProcess)
		# end
	end
	   
	   
	class StartupInfo < FFI::Struct
		include MMHelper
	   #_STARTUPINFOW
	   layout  :cb, :dword,
		:lpReserved, :pointer,
		:lpDesktop, :pointer,
		:lpTitle, :pointer,
		:dwX, :dword,
		:dwY, :dword,
		:dwXSize, :dword,
		:dwYSize, :dword,
		:dwXCountChars, :dword,
		:dwYCountChars, :dword,
		:dwFillAttribute, :dword,
		:dwFlags, :dword,
		:wShowWindow, :word,
		:cbReserved2, :word,
		:lpReserved2, :uint8_t,
		:hStdInput, :handle,
		:hStdOutput, :handle,
		:hStdError, :handle

		def initialize()
			super
			self[:cb] = self.class.size
		end
	end
  
	ffi_lib :kernel32
  
	attach_function :CloseHandle, [:handle], :bool
	attach_function :WaitForSingleObject, [:handle, :dword], :dword
	attach_function :CreateProcess, :CreateProcessW, %i{buffer_in buffer_inout pointer pointer bool dword buffer_in buffer_in pointer pointer}, :bool # TODO: specify the types, not just pointers?


	# Constants
	# TODO: are these already somewhere?
	
	INFINITE = 0xFFFFFFFF
	
	# TODO: error reporting?
	def self.free hwnd
		W.CloseHandle(hwnd) unless hwnd.nil?
	end
end
