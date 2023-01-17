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

	class SecurityAttributes < FFI::Struct
		include MMHelper
		# _SECURITY_ATTRIBUTES
		layout :nLength, :dword,
			:lpSecurityDescriptor, :pointer,
			:bInheritHandle, :bool

		def initialize()
			super
			self[:nLength] = self.class.size
		end
	end
  
	ffi_lib :kernel32
  
	attach_function :CloseHandle, [:handle], :bool
	attach_function :WaitForSingleObject, [:handle, :dword], :dword
	attach_function :CreateProcess, :CreateProcessW, %i{buffer_in buffer_inout pointer pointer bool dword buffer_in buffer_in pointer pointer}, :bool # TODO: specify the types, not just pointers?


	# Constants
	# TODO: are these already somewhere?
	
	INFINITE = 0xFFFFFFFF

	# Process flags
	DEBUG_PROCESS					= 0x00000001
	DEBUG_ONLY_THIS_PROCESS			= 0x00000002
	CREATE_SUSPENDED				= 0x00000004
	DETACHED_PROCESS				= 0x00000008
	CREATE_NEW_CONSOLE				= 0x00000010
	NORMAL_PRIORITY_CLASS			= 0x00000020 # TODO: where is this listed on MSDN?
	CREATE_NEW_PROCESS_GROUP		= 0x00000200
	CREATE_UNICODE_ENVIRONMENT		= 0x00000400
	CREATE_SEPARATE_WOW_VDM			= 0x00000800
	CREATE_SHARED_WOW_VDM			= 0x00001000
	INHERIT_PARENT_AFFINITY			= 0x00010000
	CREATE_PROTECTED_PROCESS		= 0x00040000
	EXTENDED_STARTUPINFO_PRESENT	= 0x00080000
	CREATE_SECURE_PROCESS			= 0x00400000
	CREATE_BREAKAWAY_FROM_JOB		= 0x01000000
	CREATE_PRESERVE_CODE_AUTHZ_LEVEL= 0x02000000
	CREATE_DEFAULT_ERROR_MODE		= 0x04000000
	CREATE_NO_WINDOW				= 0x08000000
	
	# TODO: error reporting?
	def self.free hwnd
		W.CloseHandle(hwnd) unless hwnd.nil?
	end
end
