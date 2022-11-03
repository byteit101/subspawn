# frozen_string_literal: true
require 'tempfile'

RSpec.describe SubSpawn do
	it "has all version numbers" do
		# TODO: posix should check lfp version
		expect(SubSpawn::VERSION).not_to be nil
		expect(SubSpawn::Platform::VERSION).not_to be nil
		expect(SubSpawn::Platform::VERSION).to eq SubSpawn::VERSION
		expect(SubSpawn::COMPLETE_VERSION).not_to be nil
		# TODO: this is fragile
		expect(SubSpawn::COMPLETE_VERSION).to eq({
			:platform => {
				:libfixposix=>{
					:binary=>{
						:gem=>"0.5.0.0-dev",
						:interface=>"0.5.0",
						:library=>"0.5.0"
					},
					:gem=>"0.5.0-dev.0",
					:interface=>"0.5.0-dev",
					:library=>"0.5.0"
				},
				:subspawn_posix=>"0.1.0-dev"
			},
			:subspawn => "0.1.0-dev"
			})
	end
	def nexpect thing
		Dummy.new
	end
	LSBIN=  "ls"
	context "spawn_compat call" do
		let(:o) { instance_double(SubSpawn::POSIX)}
		let(:d) { class_double("SubSpawn::Platform").as_stubbed_const() }

		it "basic" do
			expect(d).to receive(:new).with(LSBIN, "b", "c", arg0: "ls").and_return(o)
			expect(o).to receive(:spawn!)
			SubSpawn.spawn_compat("ls", "b", "c", __ss_compat_testing: true)
		end
		it "basic2" do
			expect(d).to receive(:new).with(LSBIN, arg0: "ls").and_return(o)
			expect(o).to receive(:spawn!)
			SubSpawn.spawn_compat("ls", __ss_compat_testing: true)
		end
		it "basic3" do
			expect(d).to receive(:new).with(LSBIN, arg0: "lsa").and_return(o)
			expect(o).to receive(:spawn!)
			SubSpawn.spawn_compat(["ls", "lsa"], __ss_compat_testing: true)

			expect(d).to receive(:new).with(LSBIN, "yes", arg0: "lsa").and_return(o)
			expect(o).to receive(:spawn!)
			SubSpawn.spawn_compat(["ls", "lsa"], "yes", __ss_compat_testing: true)
		end
		
		it "makes shells" do
			# a bit fragile
			expect(d).to receive(:new).with("ls c", arg0: "ls c").and_return(o)
			expect(o).to receive(:spawn!)
			expect(o).to receive(:env=)
			expect(d).to receive(:expand_which).with("ls c", {"test" => "value"}).and_return([])
			expect(d).to receive(:shell_command).with("ls c").and_return(["sh", "-c", "ls c"])
			expect(o).to receive(:args=).with(["-c", "ls c"])
			expect(o).to receive(:command=).with("sh")
			expect(o).to receive(:name=).with("sh")
			expect(d).to receive(:expand_which).with("sh", {"test" => "value"}).and_return(["/bin/sh"])
			expect(o).to receive(:command=).with("/bin/sh")
			SubSpawn.spawn_compat({"test" => "value"}, "ls c", unsetenv_others: true)
		end

		it "env" do
			expect(d).to receive(:new).with(LSBIN, arg0: "ls").and_return(o)
			expect(o).to receive(:spawn!)
			expect(o).to receive(:env=).with({"yes" => "foo1"})
			SubSpawn.spawn_compat({"yes" => "foo1"}, "ls", {unsetenv_others: true, __ss_compat_testing: true})

			expect(d).to receive(:new).with(LSBIN, arg0: "ls").and_return(o)
			expect(o).to receive(:spawn!)
			expect(o).to receive(:env=).with({"yes" => "foo2"})
			SubSpawn.spawn_compat({"yes" => "foo2"}, "ls", unsetenv_others: true, __ss_compat_testing: true)

			expect(d).to receive(:new).with(LSBIN, "yes", arg0: "ls").and_return(o)
			expect(o).to receive(:spawn!)
			expect(o).to receive(:env=).with({"yes" => "foo"})
			SubSpawn.spawn_compat({"yes" => "foo"}, "ls", "yes", unsetenv_others: true, __ss_compat_testing: true)
		end
		it "wrong" do
			expect { SubSpawn.spawn_compat({"yes" => "foo"}, ["ls"])}.to raise_error(ArgumentError)
			expect { SubSpawn.spawn_compat({"yes" => "foo"}, ["ls", "x", "y"])}.to raise_error(ArgumentError)
		end

		it "wrongmuti" do
			expect(d).to receive(:new).with(LSBIN, arg0: "ls").and_return(o)
			expect { SubSpawn.spawn_compat("ls", in: 9, 0 => 12, __ss_compat_testing: true)}.to raise_error(ArgumentError)

			expect(d).to receive(:new).with(LSBIN, arg0: "ls").and_return(o)
			expect { SubSpawn.spawn_compat("ls", in: 9, [3,0]=> 12, __ss_compat_testing: true)}.to raise_error(ArgumentError)


			expect(d).to receive(:new).with(LSBIN, arg0: "ls").and_return(o)
			expect { SubSpawn.spawn_compat("ls", [1,:in]=> 9, [3,0]=> 12, __ss_compat_testing: true)}.to raise_error(ArgumentError)

			expect(d).to receive(:new).with(LSBIN, arg0: "ls").and_return(o)
			expect { SubSpawn.spawn_compat("ls", [1,:in]=> 9, [3,0]=> [:child, 1], __ss_compat_testing: true)}.to raise_error(ArgumentError)
		end
	end
	context "real launches" do
		# TODO: call with real options
		it "expects env check errors" do
			expect { SubSpawn.spawn_compat({"\0" => "yes"}, "ls")}.to raise_error(ArgumentError)

			expect { SubSpawn.spawn_compat({"no" => "ye\0s"}, "ls")}.to raise_error(ArgumentError)

			# TODO: copy to posix
			expect { SubSpawn.spawn_compat("ls\0")}.to raise_error(ArgumentError)
		end

		it "does file redirection" do
			path = Tempfile.open("specr") do |path|
				path.path
			end
			FileUtils.rm_rf path
			w = Process.wait SubSpawn.spawn_compat("echo glark", out: path)
			expect(File.read path).to eq("glark\n")

			FileUtils.rm_rf path
			w = Process.wait SubSpawn.spawn_compat("echo glark", out: [path, "w"])
			expect(File.read path).to eq("glark\n")
			

			FileUtils.rm_rf path
			File.open(path, 'w') do |file|
				Process.wait SubSpawn.spawn_compat("echo glark>&2", :out => file, :err => [:child, :out])
			end
			expect(File.read path).to eq("glark\n")
		end

		it "fails sanely" do
			expect { SubSpawn.spawn(["/tmp/"])}.to raise_error(SystemCallError)
			expect { SubSpawn.spawn_compat("/tmp/")}.to raise_error(SystemCallError)
			expect { SubSpawn.spawn_compat("noneshuch")}.to raise_error(SystemCallError)
			expect { SubSpawn.spawn_compat("")}.to raise_error(SystemCallError)


			expect { SubSpawn.spawn_compat(__FILE__)}.to raise_error(SystemCallError)
		end

		it "launches pry-like" do
			cmd = %q{less -R -F -X}
			#expect(d).to receive(:new).with(*cmd, arg0: "less").and_return(o)
			SubSpawn::Platform::PtyHelper.open do |m, s|
				#cmd = ["sh" "-c", "less -R -F -X"]
				pid, spn = SubSpawn.spawn_compat(cmd, {0=>:pipe, [1, 2]=>s.fileno, :tty=>s.path, :sid=>true})
				expect(pid).not_to eq 0
				sleep 1
				Process.kill(9, pid)
				Process.wait pid
			end
		end

		it "launches directly" do
			SubSpawn::Platform::PtyHelper.open do |m, s|
				cmd = ["sh" "-c", "less -R -F -X"]
				cmd = %w{less -R -F -X}
				r,w = IO.pipe
				pid = SubSpawn::Platform.new(*cmd).
						fd(0, r.fileno).fd(1, s.fileno).fd(2, s.fileno).
						sid!.tty(s.path).
						spawn!

					#, {0=>r, [1, 2]=>s.fileno, :tty=>s.path, :sid=>true, :pgroup=>0})
				expect(pid).not_to eq 0
				sleep 1
				Process.kill(9, pid)
				Process.wait pid
			end
		end

		it "does child stuff" do
			# pid = SubSpawn.spawn_shell("sleep 3").first
			# p pid
			# sleep 1
			# p `pgrep -P #{pid}`.lines.to_a
			# #expect(`pgrep -P #{pid}`.lines.to_a.length).to eq 0
			# p Process.wait pid
		end
	end

	# TODO: test :keep
	# TODO: tset child redirects
end
