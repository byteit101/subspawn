require 'subspawn/common/version'

module SubSpawn::Common

class DeferredPipe
	attr_reader :fileno, :type
	attr_accessor :peer
	def initialize(fdnum, type)
		@fileno, @type = fdnum, type
		@peer = nil
		@output = nil
		@closed = false
	end
	def write(w, lookup)
		raise "Read from r" unless @type == :r
		raise "Write into w" unless w.type == :w
		@peer = w
		w.peer = self
		lookup[@fileno] = self
		lookup[w.fileno] = w
		nil
	end
	def close!
		@closed = true
	end
	def io= io
		@output = io
	end
	def lazy_resolve
		raise SubSpawn::SpawnError.new("Deferred pipe was closed") if @closed
		raise SubSpawn::SpawnError.new("Deferred pipe was not yet assigned") unless @output
		return @output
	end
end

end
