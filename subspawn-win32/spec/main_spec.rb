# frozen_string_literal: true
require 'fileutils'
require 'tempfile'
require 'pathname'

RSpec.describe SubSpawn::Win32 do
	Wn = SubSpawn::Win32
	F = FileUtils
	T = Tempfile.new("spec-out").path+".w4-#{(rand()*10000).to_i}" # avoid locks
	file = Pathname.new(T)
	after do
		F.rm_f T
		F.rm_f "#{T}.second"
		F.rm_f "#{T}.a"
		F.rm_f "#{T}.b"
		F.rm_f "#{T}.c"
	end
	before(:each) do
		F.rm_f T
	end

	def do_shell_spawn(cmd, wait: false, extra: nil, **kw)
		shcmd = Wn.shell_command(cmd)
		if extra != nil
			shcmd = [shcmd.first, *extra, *shcmd[1..-1]]
		end
		cmd = Wn.new(*shcmd, **kw)
		cmd.command = "c:/windows/system32/cmd.exe"
		yield cmd if block_given?
		pid = cmd.spawn!
		expect(pid).to be_a(Integer)
		expect(pid).to be > 0
		status = SubSpawn::Win32.waitpid2(pid)
		expect(status).not_to be nil
		expect(status.first).to eq pid
		return status.last.exitstatus
	end
	it "has all version numbers" do
		expect(SubSpawn::Win32::VERSION).not_to be nil
		expect(SubSpawn::Win32::COMPLETE_VERSION).not_to be nil
	end

	context "Basic Spawn" do
		it "launches" do
			expect(file).to_not exist
			pid = Wn.new("c:\\windows\\system32\\cmd.exe", "/c", "type NUL >> #{T}").spawn!
			expect(pid).to be_a(Integer)
			status = SubSpawn::Win32.waitpid2(pid)
			expect(status).to eq [pid, Process.status.send(:new, pid, 0, nil)]
			expect(file).to exist
			expect(file).to be_file
		end
		it "launches a shell" do
			expect(file).not_to exist
			expect(do_shell_spawn("type NUL >> #{T}")).to eq 0
			expect(file).to exist
			expect(file).to be_file
		end
	end

	context "Execution Environment" do 
		it "can change cwd" do
			expect(do_shell_spawn(%Q{echo cwd = %CD% > #{T}})).to eq 0
			expect(File.read(T)).to eq "cwd = #{File.dirname(__dir__).gsub("/", "\\")} \n"

			expect(do_shell_spawn(%Q{echo cwd = %CD% > #{T}}){|x|x.cwd("c:/Windows")}).to eq 0
			expect(File.read(T).downcase).to eq "cwd = c:\\windows \n"
		end
		it "can overwrite the env" do
			expect(do_shell_spawn(%Q{set > #{T}}){|x|x.env = {"RSPEC" => "Somehow"} }).to eq 0
			expect(File.read(T)).to include("RSPEC=Somehow\n") # windows & wine add differing variables
		end
		it "can modify the env" do
			expect(do_shell_spawn(%Q{set > #{T}})).to eq 0
			baseenv = File.read(T)
			expect(baseenv.length).to be > 3
			expected = (baseenv.split("\n") + ["RSPEC=Somehow"]).sort

			expect(do_shell_spawn(%Q{set > #{T}}){|x|x.env("RSPEC", "Somehow") }).to eq 0
			expect(File.read(T).split("\n").sort).to eq expected
		end
	end

	context "File Descriptors" do
		it "can redirect stdout" do
			r,w = IO.pipe
			expect(do_shell_spawn(%Q{echo hello}){|x|x.fd(:out, w)}).to eq 0
			sleep 1
			expect(r.read_nonblock(5)).to eq "hello"
			r.close
			w.close
		end

		it "can redirect stderr" do
			r,w = IO.pipe
			expect(do_shell_spawn(%Q{echo hello}){|x|x.fd(:err, w); x.fd(:out, w)}).to eq 0
			sleep 1
			expect(r.read_nonblock(7)).to eq "hello\r\n"

			expect(do_shell_spawn(%Q{echo hello 1>&2}){|x|x.fd(:err, w)}).to eq 0
			sleep 1
			expect(r.read_nonblock(5)).to eq "hello"

			r.close
			w.close
		end
		
		it "can redirect stdin" do
			r,w = IO.pipe
			w << "some std in\n\r\n"
			expect(do_shell_spawn(%Q{set /p foo=ThePrompt& echo got: !foo! > #{T}}, extra: %w{/V:ON}){|x|x.fd(:in, r)}).to eq 0
			expect(File.read(T)&.strip).to eq "got: some std in"
			r.close
			w.close
		end
		it "can open files" do
			expect(do_shell_spawn(%Q{echo apple & echo banana 1>&2}){|x|x.fd_open(:out, T, IO::RDWR | IO::CREAT); x.fd_open(:err, "#{T}.second", IO::RDWR | IO::CREAT, 0o600)}).to eq 0

			expect(File.read("#{T}.second").strip).to eq "banana"
			expect(File.read(T).strip).to eq "apple"
			# TODO: do permissions do anything on windows?
			#expect(File.stat("#{T}.second").mode& 0o7777).to eq 0o600
			#expect(File.stat(T).mode & 0o7777).to eq (0o666 & ~File.umask)
		end
		# TODO: I'm not sure this is relevant on windows?
=begin
		it "can close thigs" do
			expect(do_shell_spawn(%Q{echo "sadness"}){|x|x.fd_close(:out); x.fd_open(:err, T, IO::RDWR | IO::CREAT);}).to eq 1
			expect(File.read(T)).to include("I/O")
			expect(File.read(T)).to include("error")
			expect(File.read(T)).to include("echo")
			expect(File.read(T)).to include("sh: 1")
		end
=end
	end
=begin
	context "Terminal Control" do

		it "can set tty" do
			m, s = SubSpawn::POSIX::PtyHelper.open
			r,w = IO.pipe
			# direct output
			expect(do_shell_spawn(%Q{echo -n "maybe" > /dev/tty }){|x|x.tty = s.path;}).to eq 0
			sleep 0.1
			expect(m.read_nonblock(5)).to eq "maybe"
			# test that failure
			expect(do_shell_spawn(%Q{if [ -t 1 ] ; then echo 'good!'> #{T}; else echo 'fail!'> #{T}; fi  }){|x|
				x.tty = s.path;
				x.fd(:out, w)
			}).to eq 0
			expect(File.read(T).strip).to eq("fail!")
			r.close
			w.close

			# output is tty
			expect(do_shell_spawn(%Q{if [ -t 1 ] ; then echo 'good!'> #{T}; else echo 'fail!'> #{T}; fi }){|x|
				x.tty = s.path;
				x.fd(:out, s)
			}).to eq 0
			expect(File.read(T).strip).to eq("good!")

			# huh
			expect(do_shell_spawn(%Q{if [ -t 1 ] ; then echo 'good!'> #{T}; else echo 'fail!'> #{T}; fi  }){|x| x.fd(:out, s)}).to eq 0
			expect(File.read(T).strip).to eq("good!")

			m.close
			s.close
		end

		it "can use tty" do
			require 'io/console'
			m, s = SubSpawn::POSIX::PtyHelper.open
			m.winsize = [20,20]
			m << "q" # amusingly, we don't need to set stdin for this to work. Thanks less!

			# TODO: setsid? Unsure if necessary
			expect(do_shell_spawn(%Q{less /proc/kallsyms}){|x|x.tty = s.path; x.fd(:out, s)}).to eq 0
			sleep 0.1
			expect(m.read_nonblock(3)).to eq "q\e[" # less should think this is escape time

			# TODO: failure = hang (Not great)
			m.close
			s.close
		end
	end
=end
end
