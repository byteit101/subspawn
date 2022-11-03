# frozen_string_literal: true
require 'pathname'

RSpec.describe SubSpawn::POSIX::PtyHelper do
	let(:pty) {SubSpawn::POSIX::PtyHelper}

	it "supports simple open" do
		ms = pty.open
		expect(ms).not_to be nil
		expect(ms).to be_an Array
		expect(ms.length).to eq 2
		m, s = ms
		expect(m).to be_an IO
		expect(s).to be_a File

		expect(m.inspect).to start_with "#<IO:masterpty:"
		expect(m.tty?).to be true
		expect(m.close_on_exec?).to be true
		expect(m.sync).to be true

		expect(s.inspect).to start_with "#<File:"
		expect(s.tty?).to be true
		expect(s.close_on_exec?).to be true
		expect(s.sync).to be true

		expect(s.path).to_not be nil
		expect(s.path).to start_with "/dev/"

		expect(s.inspect).to eq "#<File:#{s.path}>"
		expect(m.inspect).to eq "#<IO:masterpty:#{s.path}>"
		expect(Pathname.new(s.path)).to exist
		expect(File.stat(s.path).mode & 0o7777).to eq 0o600

		s.close
		m.close
	end

	it "supports block form" do
		gotten = nil
		ret = pty.open do |ms|
			expect(ms).not_to be nil
			expect(ms).to be_an Array
			expect(ms.length).to eq 2
			gotten = ms
			m, s = ms
			5
		end
		expect(gotten).not_to be nil
		expect(gotten.length).to eq 2
		expect(ret).to eq 5
		expect(gotten[0].closed?).to eq true
		expect(gotten[1].closed?).to eq true
	end

	it "supports basic copy" do
		expect(pty.open do |m, s|
				m << "hello\n"
				m.flush
				expect(s.gets).to eq "hello\n"
				expect(m.gets).to eq "hello\r\n" # echo on

				s << "typing\r\n"
				s.flush
				expect(m.gets).to eq "typing\r\r\n"

				"yes"
			end).to eq "yes"
	end
end
