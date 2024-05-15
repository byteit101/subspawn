class SubSpawn::Win32::LazyHndl
	def self.closer(hndl)
		lambda do |obj_id|
			SubSpawn::Win32::W.CloseHandle(hndl)
		end
	end

	def initialize(pid, hndl)
		ObjectSpace.define_finalizer(self, self.class.closer(hndl))
		@hndl = hndl
		@pid = pid
	end

	attr_reader :hndl
	attr_reader :pid
end
