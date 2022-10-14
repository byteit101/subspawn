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

	cd "ffi-bindings-libfixposix" do
		sh 'rake build'
	end
	cd "ffi-binary-libfixposix" do
		sh 'rake local'
	end
	cd "subspawn-posix" do
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
	cd "subspawn" do
		sh 'rake clobber'
	end
end


desc "CI actions"
task "ci:build" => %w{clean generate:ffi build} do
	rm_rf "ci-output"

	cd "ffi-binary-libfixposix" do
		configs = {
			darwin: ["x86_64"],
			linux: ["x86", "x86_64"], #, "arm"]
		}
		target_os = RbConfig::CONFIG["target_os"].match(/^([^\d]+)/)[1] # strip any trailing versions, like darwin19
		config = configs[target_os.to_sym]
		raise "Target OS not found in configuration: #{target_os}" unless config
		config.each do |config|
			sh "rake clobber build:#{config}-#{target_os}"
			destdir = "../ci-output/lib/#{config}-#{target_os}/"
			mkdir_p destdir
			cp LFP::Binary::PATH, destdir
			mkdir_p "../ci-output/pkg/"
			cp Dir["../ffi-binary-libfixposix/pkg/*.gem"], "../ci-output/pkg/"
		end
	end
	# now copy the other artifacts
	%w{ffi-bindings-libfixposix subspawn-posix subspawn}.each do |folder|
		cp Dir["#{folder}/pkg/*.gem"], "ci-output/pkg/"
	end
end
