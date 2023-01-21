require 'ffi'
module SubSpawn::Win32::FFI
	extend FFI::Library

	W = SubSpawn::Win32::FFI

	# Common types

	# uintptr or :pointer ?
	typedef :intptr_t, :shandle
	typedef :uintptr_t, :handle
	typedef :int, :hresult

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
	   #_STARTUPINFOEXW
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
		:hStdError, :handle,
		:lpAttributeList, :pointer

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

	class Coord < FFI::Struct
		include MMHelper
		# _COORD
		layout :x, :short,
			:y, :short

		def initialize(x=0,y=0)
			super()
			self[:x] = x
			self[:y] = y
		end
		def to_a
			[x, y]
		end
		def to_ary
			[x, y]
		end
		def self.[](*keys)
			self.new(*keys.flatten)
		end
	end
  
	ffi_lib :kernel32

	attach_function :GetLastError, [], :dword
	attach_function :WaitForSingleObject, [:handle, :dword], :dword
	attach_function :GetExitCodeProcess, [:handle, :buffer_out], :bool
	attach_function :OpenProcess, [:dword, :bool, :dword], :handle
  
	attach_function :CloseHandle, [:handle], :bool
	attach_function :CreateProcess, :CreateProcessW, %i{buffer_in buffer_inout pointer pointer bool dword buffer_in buffer_in pointer pointer}, :bool # TODO: specify the types, not just pointers?
	attach_function :GetStdHandle, [:dword], :handle

	attach_function :InitializeProcThreadAttributeList, %i{buffer_out dword dword buffer_inout}, :bool

	# the first pointer/handle should really be a pointer, but we use it as a pointer
	attach_function :UpdateProcThreadAttribute, %i{buffer_inout dword handle handle size_t pointer pointer}, :bool
	attach_function :DeleteProcThreadAttributeList, [:buffer_inout], :void

	attach_function :SetHandleInformation, [:handle, :dword, :dword], :bool
	
	# PTY
	# HPCON == handle
	attach_function :ClosePseudoConsole, [:handle], :void
	attach_function :ResizePseudoConsole, [:handle, :pointer], :int
	attach_function :CreatePseudoConsole, %i{buffer_in handle handle dword buffer_out}, :int


	ffi_lib FFI::Library::LIBC

	attach_function :get_osfhandle, :_get_osfhandle, [:int], :shandle
	attach_function :get_errno, :_get_errno, [:buffer_inout], :int

	# Constants
	# TODO: are these already somewhere?

	SIZEOF_HPCON = FFI::Pointer::SIZE
	
	INFINITE = 0xFFFFFFFF
	INVALID_HANDLE_VALUE = -1 # unsure if signed or unsigned is better
	HANDLE_NEGATIVE_TWO = -2
	HANDLE_FLAG_INHERIT = 1

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

	STARTF_USESHOWWINDOW	= 0x00000001
	STARTF_USESIZE		 	= 0x00000002
	STARTF_USEPOSITION		= 0x00000004
	STARTF_USECOUNTCHARS	= 0x00000008
	STARTF_USEFILLATTRIBUTE	= 0x00000010
	STARTF_RUNFULLSCREEN	= 0x00000020
	STARTF_FORCEONFEEDBACK	= 0x00000040
	STARTF_FORCEOFFFEEDBACK	= 0x00000080
	STARTF_USESTDHANDLES	= 0x00000100
	STARTF_USEHOTKEY		= 0x00000200
	#
	STARTF_TITLEISLINKNAME	= 0x00000800
	STARTF_TITLEISAPPID		= 0x00001000
	STARTF_PREVENTPINNING	= 0x00002000
	#
	STARTF_UNTRUSTEDSOURCE	= 0x00008000

	# TODO: expose other values for the proc thread list
	PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE = 0x00020016

	# Also unsigned, but this is convienent, and ffi takes care of the rest
	STD_HANDLE = {
		0 => -10,
		1 => -11,
		2 => -12,
	}

	#PTY
	PSEUDOCONSOLE_INHERIT_CURSOR = 1

	# waiting
	STILL_ACTIVE = 259
	PROCESS_QUERY_INFORMATION = 0x00000400
	
	# TODO: error reporting?
	def self.free hwnd
		W.CloseHandle(hwnd) unless hwnd.nil?
	end
end
