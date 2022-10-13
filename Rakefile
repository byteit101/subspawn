
desc 'Generate FFI interface'
task "generate:ffi" do
	cd 'ffi-generator' do
		sh 'ruby ffi_gen.rb ../libfixposix/src/include/lfp.h > ../ffi-bindings-libfixposix/lib/libfixposix/ffi.rb'
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
task "build" do
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
