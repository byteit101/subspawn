# frozen_string_literal: true
require 'pathname'
require 'subspawn/win32/pty'

RSpec.describe SubSpawn::Win32::PtyHelper do
	let(:pty) {SubSpawn::Win32::PtyHelper}

	it "supports simple open" do
		ms = pty.open
		expect(ms).not_to be nil
		expect(ms).to be_an Array
		expect(ms.length).to eq 2
		m, s = ms
		expect(m).to be_a pty::MasterPtyIO
		expect(s).to be_a pty::SlavePtyIO

		expect(m.inspect).to start_with "#<masterpty:"
		expect(m.tty?).to be true # TODO
		expect(m.sync).to be true

		expect(s.inspect).to start_with "#<winpty"
		expect(s.tty?).to be true
		expect(s.sync).to be true

		expect(s.con_pty).not_to be nil
		expect(m.con_pty).not_to be nil

		expect(s.con_pty).to be_a pty::ConPTYHelper
		expect(m.con_pty).to be_a pty::ConPTYHelper
		expect(s.con_pty).to eq m.con_pty

		s.close
		m.close
		s.con_pty.close # TODO: automatic gc?
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
		expect(gotten[1].con_pty.closed?).to eq true
	end

	it "supports basic copy" do
		expect(pty.open do |m, s|
				m << "hello\n"
				m.flush
				expect(s.gets).to eq "hello\n"
				# TODO: we don't have echo in ConPTY
				#expect(m.gets).to eq "hello\r\n" # echo on

				s << "typing\r\n"
				s.flush
				expect(m.gets).to eq "typing\n" # Windows reverse-translates it?

				"yes"
			end).to eq "yes"
	end
end
