# frozen_string_literal: true
require 'fileutils'
require 'tempfile'
require 'pathname'

RSpec.describe SubSpawn::POSIX do
	let(:ss) {SubSpawn::POSIX::SigSet}
	Px = SubSpawn::POSIX
	F = FileUtils
	T = Tempfile.new("spec-out").path
	file = Pathname.new(T)
	after do
		F.rm_f T
		F.rm_f "#{T}.second"
	end
	before(:each) do
		F.rm_f T
	end

	def do_shell_spawn(cmd, wait: false, **kw)
		cmd = Px.new("sh", "-c", cmd, **kw)
		yield cmd if block_given?
		pid = cmd.spawn!
		expect(pid).to be_a(Integer)
		expect(pid).to be > 0
		status = Process.waitpid2(pid)
		expect(status.first).to eq pid
		return status.last.exitstatus if status.last.is_a? Process::Status
		status.last
	end

	context "Basic Spawn" do
		it "launches" do
			expect(file).to_not exist
			pid = Px.new("touch", T).spawn!
			expect(pid).to be_a(Integer)
			expect(Process.waitpid2(pid)).to eq [pid, 0]
			expect(file).to exist
			expect(file).to be_file
		end
		it "launches a shell" do
			expect(file).not_to exist
			expect(do_shell_spawn("touch #{T}")).to eq 0
			expect(file).to exist
			expect(file).to be_file
		end

		it "can change $0" do
			expect(do_shell_spawn("echo $0 > #{T}")).to eq 0
			expect(file).to be_file
			expect(File.read(T)).to eq "sh\n"

			expect(do_shell_spawn(%Q{echo "$0" > #{T}}, arg0: "custom name")).to eq 0
			expect(File.read(T)).to eq "custom name\n"

			expect(do_shell_spawn(%Q{echo "$0" > #{T}}){|p|p.name("my name")}).to eq 0
			expect(File.read(T)).to eq "my name\n"
		end
	end

	context "Owner Attributes (non-root, run as sudo to validate)", :if => Process.uid != 0 do
		it "fails to change owners (run this suite as root to validate)" do
			expect(do_shell_spawn(%Q{whoami > #{T}}){|x|x.owner(uid:0,gid:0)}).to eq 255
			expect(file).not_to exist
		end
	end
	context "Owner Attributes", :if => Process.uid == 0 do
		it "can change owner" do
			expect(do_shell_spawn(%Q{whoami > #{T}}){|x|x.owner(uid:0,gid:0)}).to eq 0
			expect(File.read(T)).to eq "root\n"
			expect(do_shell_spawn(%Q{whoami > #{T}}){|x|x.owner(uid:1000,gid:1000)}).to eq 0
			expect(File.read(T)).not_to eq "root\n"
			expect(do_shell_spawn(%Q{id > #{T}}){|x|x.owner(uid:1000,gid:1000)}).to eq 0
			expect(File.read(T)).to start_with("id=1000")
		end
	end

	context "Execution Environment" do 
		it "can change cwd" do
			expect(do_shell_spawn(%Q{echo "cwd = $(pwd)" > #{T}})).to eq 0
			expect(File.read(T)).to eq "cwd = #{File.dirname(__dir__)}\n"

			expect(do_shell_spawn(%Q{echo "cwd = $(pwd)" > #{T}}){|x|x.cwd("/etc/")}).to eq 0
			expect(File.read(T)).to eq "cwd = /etc\n"
		end
		it "can change umask" do
			expect(do_shell_spawn(%Q{echo "umask = $(umask)" > #{T}})).to eq 0
			expect(File.read(T)).to eq "umask = #{File.umask.to_s(8).rjust(4,'0')}\n"

			expect(do_shell_spawn(%Q{echo "umask = $(umask)" > #{T}}){|x|x.umask(0o467)}).to eq 0
			expect(File.read(T)).to eq "umask = 0467\n"
			expect(File.stat(T).mode & 0o7777).not_to eq 0o600

			F.rm_f T
			expect(do_shell_spawn(%Q{echo "umask = $(umask)" > #{T}}){|x|x.umask(0o077)}).to eq 0
			expect(File.read(T)).to eq "umask = 0077\n"
			expect(File.stat(T).mode & 0o7777).to eq 0o600
		end
		it "can overwrite the env" do
			expect(do_shell_spawn(%Q{env > #{T}}){|x|x.env = {"RSPEC" => "Somehow"} }).to eq 0
			expect(File.read(T)).to eq "RSPEC=Somehow\nPWD=#{File.dirname(__dir__)}\n" # bash adds pwd
		end
		it "can modify the env" do
			expect(do_shell_spawn(%Q{env > #{T}})).to eq 0
			baseenv = File.read(T)
			expect(baseenv.length).to be > 3
			expected = (baseenv.split("\n") + ["RSPEC=Somehow"]).sort

			expect(do_shell_spawn(%Q{env > #{T}}){|x|x.env("RSPEC", "Somehow") }).to eq 0
			expect(File.read(T).split("\n").sort).to eq expected
		end
	end

	context "File Descriptors" do
		it "can redirect stdout" do
			r,w = IO.pipe
			expect(do_shell_spawn(%Q{echo hello}){|x|x.fd(:out, w)}).to eq 0
			sleep 0.1
			expect(r.read_nonblock(5)).to eq "hello"
			r.close
			w.close
		end
		it "can redirect stderr" do
			r,w = IO.pipe
			expect(do_shell_spawn(%Q{echo -n hello}){|x|x.fd(:err, w); x.fd(:out, :err)}).to eq 0
			sleep 0.1
			expect(r.read_nonblock(5)).to eq "hello"

			expect(do_shell_spawn(%Q{echo hello >&2}){|x|x.fd(:err, w)}).to eq 0
			sleep 0.1
			expect(r.read_nonblock(5)).to eq "hello"

			r.close
			w.close
		end

		it "can redirect stdin" do
			r,w = IO.pipe
			w << "some std in\n\r\n"
			expect(do_shell_spawn(%Q{read foo; echo -n "got: $foo" > #{T}}){|x|x.fd(:in, r)}).to eq 0
			expect(File.read(T)).to eq "got: some std in"
			r.close
			w.close
		end

		it "can open files" do
			expect(do_shell_spawn(%Q{echo -n apple; echo -n "banana" >&6}){|x|x.fd_open(:out, T, IO::RDWR | IO::CREAT); x.fd_open(6, "#{T}.second", IO::RDWR | IO::CREAT, 0o600)}).to eq 0

			expect(File.read("#{T}.second")).to eq "banana"
			expect(File.read(T)).to eq "apple"
			expect(File.stat(T).mode & 0o7777).to eq (0o666 & ~File.umask)
			expect(File.stat("#{T}.second").mode& 0o7777).to eq 0o600
		end

		it "can close thigs" do
			expect(do_shell_spawn(%Q{echo "sadness"}){|x|x.fd_close(:out); x.fd_open(:err, T, IO::RDWR | IO::CREAT);}).to eq 1
			expect(File.read(T)).to include("I/O")
			expect(File.read(T)).to include("error")
			expect(File.read(T)).to include("echo")
			expect(File.read(T)).to include("sh: 1")
		end
	end
	context "Terminal Control" do
		require 'pty'
		it "can set process group" do
			r,w = IO.pipe
			# old group
			cmd = Px.new("sh", "-c",%q{read foo; sed < /proc/$foo/stat -n '$s/.*) [^ ]* [^ ]* \([^ ]*\).*/\1/p' > } + T)
			cmd.fd(:in, r)
			pid = cmd.spawn!
			expect(pid).to be_a(Integer)
			expect(pid).to be > 0
			w.puts pid

			status = Process.waitpid2(pid)
			expect(status).to eq [pid, 0]
			expect(File.read(T)).not_to eq(pid.to_s)
			our_pgid = File.read("/proc/#{$$}/stat").match(/.*\) [^ ]* [^ ]* ([^ ]*).*/)[1]
			expect(File.read(T).strip).to eq(our_pgid)

			# new group
			cmd = Px.new("sh", "-c",%q{read foo; sed < /proc/$foo/stat -n '$s/.*) [^ ]* [^ ]* \([^ ]*\).*/\1/p' > } + T)
			cmd.fd(:in, r)
			cmd.pgroup = 0 # pid
			pid = cmd.spawn!
			expect(pid).to be_a(Integer)
			expect(pid).to be > 0
			w.puts pid

			status = Process.waitpid2(pid)
			expect(status).to eq [pid, 0]
			p our_pgid
			expect(File.read(T).strip).to eq(pid.to_s)	

			r.close
			w.close
		end


		it "can set session id" do
			r,w = IO.pipe
			# old session
			cmd = Px.new("sh", "-c",%q{read foo; sed < /proc/$foo/stat -n '$s/.*) [^ ]* [^ ]* [^ ]* \([^ ]*\).*/\1/p' > } + T)
			cmd.fd(:in, r)
			pid = cmd.spawn!
			expect(pid).to be_a(Integer)
			expect(pid).to be > 0
			w.puts pid

			status = Process.waitpid2(pid)
			expect(status).to eq [pid, 0]
			expect(File.read(T)).not_to eq(pid.to_s)

			# new session
			cmd = Px.new("sh", "-c",%q{read foo; sed < /proc/$foo/stat -n '$s/.*) [^ ]* [^ ]* [^ ]* \([^ ]*\).*/\1/p' > } + T)
			cmd.fd(:in, r)
			cmd.sid!
			pid = cmd.spawn!
			expect(pid).to be_a(Integer)
			expect(pid).to be > 0
			w.puts pid

			status = Process.waitpid2(pid)
			expect(status).to eq [pid, 0]
			expect(File.read(T).strip).to eq(pid.to_s)	

			r.close
			w.close
		end

		it "can set tty" do
			require 'pty'
			m, s = PTY.open
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
			require 'pty'
			require 'io/console'
			m, s = PTY.open
			m.winsize = [20,20]
			m << "q" # amusingly, we don't need to set stdin for this to work. Thanks less!

			# TODO: setsid? Unsure if necessary
			expect(do_shell_spawn(%Q{less /proc/$$/stat}){|x|x.tty = s.path; x.fd(:out, s)}).to eq 0
			sleep 0.1
			expect(m.read_nonblock(3)).to eq "q\e[" # less should think this is escape time

			# TODO: failure = hang (Not great)
			m.close
			s.close
		end
	end

	context "Advanced Attributes" do
		it "can mask signals" do
			# no masking
			r,w = IO.pipe
			r2,w2 = IO.pipe
			cmd = Px.new("ruby", "-e", "
				Signal.trap('USR1'){ puts :user1 }
				Signal.trap('USR2'){ puts :user2 }
				puts :start
				STDOUT.flush
				puts gets
				STDOUT.flush
				exit
				")
			cmd.fd(:in, r)
			cmd.fd(:out, w2)
			cmd.sid!
			#cmd.fd(:err, w2)
			pid = cmd.spawn!
			expect(pid).to be_a(Integer)
			expect(pid).to be > 0
			expect(r2.read(5)).to eq("start")
			Process.kill("USR1", pid)
			sleep 0.1
			Process.kill("USR2", pid)
			sleep 0.1
			Process.kill("USR1", pid)
			sleep 0.1
			w.puts "done"
			status = Process.waitpid2(pid)
			expect(status).to eq [pid, 0]
			expect(r2.read_nonblock(1024)).to eq "\nuser1\nuser2\nuser1\ndone\n"
			[r,w,r2,w2].each(&:close)

			# with masking. TODO: I think this may be pointless?

			r,w = IO.pipe
			r2,w2 = IO.pipe
			# cmd = Px.new("ruby", "-e", "
			# 	Signal.trap('USR1'){ puts :user1 }
			# 	Signal.trap('USR2'){ puts :user2 }
			# 	puts :start
			# 	STDOUT.flush
			# 	puts gets
			# 	STDOUT.flush
			# 	exit
			# 	")
			cmd = Px.new("sh", "-c", "
				trap 'echo user1' 10;
				trap 'echo user2' 12;
				echo start
				sleep 1
				read foo
				echo \"$foo\"
				exit
				 	")
			cmd.fd(:in, r)
			cmd.fd(:out, w2)
			cmd.sigmask(:empty, add: 10)
			cmd.sid!
			#cmd.fd(:err, w2)
			pid = cmd.spawn!
			expect(pid).to be_a(Integer)
			expect(pid).to be > 0
			expect(r2.read(5)).to eq("start")
			Process.kill("USR1", pid)
			sleep 0.1
			Process.kill("USR2", pid)
			sleep 0.1
			Process.kill("USR1", pid)
			sleep 0.1
			w.puts "done"
			status = Process.waitpid2(pid)
			expect(status).to eq [pid, 0]
			expect(r2.read_nonblock(1024)).to eq "\nuser2\ndone\n"
		end

		it "can change rlimit" do
			expect(do_shell_spawn(%Q{ulimit -n > #{T}}){|x|x.rlimit(:nofile, 1024, 2048)}).to eq 0
			expect(File.read(T).strip).to eq "1024"

			expect(do_shell_spawn(%Q{ulimit -n -H > #{T}}){|x|x.rlimit(:nofile, 1024,2048)}).to eq 0
			expect(File.read(T).strip.to_i).to be > 1024


			expect(do_shell_spawn(%Q{ulimit -n > #{T}}){|x|x.rlimit(:nofile, 776,2048)}).to eq 0
			expect(File.read(T).strip).to eq "776"

			expect(do_shell_spawn(%Q{ulimit -n -H > #{T}}){|x|x.rlimit(:nofile, 776,2048)}).to eq 0
			expect(File.read(T).strip.to_i).to be > 1024
		end
		it "can use saved rlimit" do
			expect(do_shell_spawn(%Q{ulimit -n -H > #{T}}){|x|x.rlimit(:nofile, 776,Process::RLIM_SAVED_MAX)}).to eq 0
			expect(File.read(T).strip.to_i).to be > 1024

			expect(do_shell_spawn(%Q{ulimit -n -H > #{T}}){|x|x.rlimit(:nofile, 776)}).to eq 0
			expect(File.read(T).strip.to_i).to be > 1024
		end
	end
end
