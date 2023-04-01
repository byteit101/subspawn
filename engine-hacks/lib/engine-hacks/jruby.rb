
module EngineHacks

	def self.use_child_status symbol
		# No-op on JRuby
		nil
	end

	def self.child_status= status
		require 'jruby'
		JRuby.runtime.current_context.last_exit_status = status
	end

	def self.duplex_io(read, write)
		raise ArgumentError.new("Read argument must be IO") unless read.is_a? IO
		raise ArgumentError.new("Write argument must be IO") unless write.is_a? IO
		require 'jruby'
		readf = JRuby.ref(read).open_file
		writef = JRuby.ref(read).open_file
		raise ArgumentError.new("Read argument must be JRuby IO") if readf.nil?
		raise ArgumentError.new("Write argument must be JRuby IO") if writef.nil?
		readf.tied_io_for_writing = write
		modes = writef.class
		readf.mode = (readf.mode & ~modes::WRITABLE) | modes::SYNC | modes::DUPLEX
		writef.mode = (writef.mode & ~modes::READABLE) | modes::SYNC | modes::DUPLEX
		return read
	end
end
