
# A test for https://github.com/jruby/jruby/issues/7565
# Ported to use SubSpawn from the original at https://github.com/jcouball/convert_to_fd_test/blob/main/spec/test_spec.rb

require 'English'
require 'tmpdir'

class WrappedIO
	def initialize(io_writer)
		@io_writer = io_writer
		@to_io_called = false
	end

	def to_io
		@to_io_called = true
		@io_writer
	end

	def to_io_called?
		@to_io_called
	end
end

RSpec.describe 'SubSpawn#spawn' do
	context 'when called with out: set to an instance of WrappedIO' do
		it 'should not raise an error' do
			out = WrappedIO.new(STDOUT)
			expect do
				Process.wait(SubSpawn.spawn_compat('exit 0', out: out))
			end.not_to raise_error
		end

		it 'should call #to_io to get the wrapped IO object' do
			out = WrappedIO.new(STDOUT)
			Process.wait(SubSpawn.spawn_compat('exit 0', out: out))
			expect(out.to_io_called?).to eq(true)
		end

		it 'should redirect stdout of the subprocess to the wrapped IO object' do
			Dir.mktmpdir do |dir|
				Dir.chdir(dir) do
					f = File.open('out.txt', 'wb')
					out = WrappedIO.new(f)
					Process.wait(SubSpawn.spawn_compat('echo "Hello World"', out: out))
					f.close

					expect(File.read('out.txt')).to match(/Hello World/)
				end
			end
		end
	end
end
