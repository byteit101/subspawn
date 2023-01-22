require 'ffi'

desc 'Generate FFI interface'
task "generate:ffi" do
	cd 'libfixposix/src/include/lfp' do
		# values don't matter for @ vars, but clockid_t isn't defined on mac, so we can't use
		# it anywhere. Signed int on Linux
		File.write("time.h", File.read("time.h.in").gsub("@HAVE_CLOCKID_T@", "1").gsub("@HAVE_CLOCK_GETTIME@", "1").gsub("clockid_t", "int"))
	end
	cd 'ffi-generator' do
		sh 'ruby ffi_gen.rb ../libfixposix/src/include/lfp.h > ../ffi-bindings-libfixposix/lib/libfixposix/ffi.rb'
	end

	cd 'libfixposix/src/include/lfp' do
		# let it be re-configured for this system
		rm_rf "time.h"
	end
	# only needed once, really
	cd 'libfixposix' do
		sh 'autoreconf -i -f'
	end
end

desc "Build all gems (doesn't install)"
task "build" do
	cd "ffi-binary-libfixposix" do
		sh 'rake binary'
	end

	# bindings require binary to build
	require_relative './ffi-binary-libfixposix/lib/libfixposix/binary/version'
	ENV["LIBFIXPOSIX_PATH"] = LFP::Binary::PATH
	puts "LIBFIXPOSIX_PATH=#{LFP::Binary::PATH}"

	cd "ffi-bindings-libfixposix" do
		sh "rake build"
		raise "Path error!" if Dir["pkg/*.gem"].to_s.include? "ERROR"
	end
	cd "ffi-binary-libfixposix" do
		sh 'rake local'
	end
	cd "subspawn-posix" do
		sh 'rake build'
	end
	cd "subspawn-win32" do
		sh 'rake build'
	end
	cd "subspawn" do
		sh 'rake build'
	end
end

desc 'Set up development environment'
task "dev" => "generate:ffi"

task default: :dev


desc "Clean up everything"
task "clean" do
	cd "ffi-bindings-libfixposix" do
		sh 'rake clobber'
	end
	cd "ffi-binary-libfixposix" do
		sh 'rake clobber'
	end
	cd "subspawn-posix" do
		sh 'rake clobber'
	end
	cd "subspawn-win32" do
		sh 'rake clobber'
	end
	cd "subspawn" do
		sh 'rake clobber'
	end
end

desc "CI test"
task "ci-test" => %w{clean generate:ffi build} do
	cd "subspawn-posix" do
		sh 'rspec'
	end
	cd "subspawn" do
		sh 'rspec'
	end
end


desc "CI actions"
task "ci-run" => %w{clean generate:ffi build} do
	rm_rf "ci-output"

	cd "ffi-binary-libfixposix" do
		sh "rake clobber" # delete "old" local build files
		if RbConfig::CONFIG["target_os"].include? "darwin"
			# macs only build mac stuff
			%w{x86_64 arm64}.each do |cpu|
				target = "#{cpu}-darwin"
				sh "rake clobber binary[#{target}] target[#{target}]"
				destdir = "../ci-output/lib/#{target}/"
				mkdir_p destdir
				cp LFP::Binary::PATH, destdir
				mkdir_p "../ci-output/pkg/"
				cp Dir["../ffi-binary-libfixposix/pkg/*.gem"], "../ci-output/pkg/"
			end
		else
			configs = {
				linux: %w{x86 x86_64 armv6 armv7 arm64},
				freebsd: %w{x86 x86_64}
			}
			#target_os = RbConfig::CONFIG["target_os"].match(/^([^\d]+)/)[1] # strip any trailing versions, like darwin19
			#config = configs[target_os.to_sym]
			#raise "Target OS not found in configuration: #{target_os}" unless config
			configs.flat_map { |os, cpus| cpus.map{|cpu| "#{cpu}-#{os}"} }.each do |target|
				sh "rake clobber cross:#{target} target[#{target}]"
				destdir = "../ci-output/lib/#{target}/"
				mkdir_p destdir
				cp LFP::Binary::PATH, destdir
				mkdir_p "../ci-output/pkg/"
				cp Dir["../ffi-binary-libfixposix/pkg/*.gem"], "../ci-output/pkg/"
			end
		end
	end
	unless RbConfig::CONFIG["target_os"].include? "darwin"
		# now copy the other artifacts
		%w{ffi-bindings-libfixposix subspawn-posix subspawn-win32 subspawn}.each do |folder|
			cp Dir["#{folder}/pkg/*.gem"], "ci-output/pkg/" 
		end
	end
end



desc "CI actions"
task "ci-java" do
	cd "ffi-binary-libfixposix" do
		sh "rake clobber"
		Dir["../ci-output/lib/*"].each do |path|
			cp_r path, "lib/libfixposix/binary/"
		end
		
		sh "rake target[java]"
		mkdir_p "../ci-output/pkg/"
		cp Dir["../ffi-binary-libfixposix/pkg/*java*.gem"], "../ci-output/pkg/"
		Dir["../ci-output/lib/*"].each do |host|
			rm_rf "lib/libfixposix/binary/#{File.basename host}"
		end
	end
end
