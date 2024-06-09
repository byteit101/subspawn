
touched=false
if [ "x${BINARY_SET}" == "x" ]
then
	BINARY_SET=ALL
fi

#docker run --rm dockcross/android-arm64 > ./dockcross-android-arm64
#docker run --rm dockcross/android-arm > ./dockcross-android-arm # arm7

# Just the linuxes here
if [ ${BINARY_SET} == "ALL" ] || [ ${BINARY_SET} == "linux-odd1" ]; then
	docker run --rm byteit101/jrubycrosslinux-s390x > ./dockcross-linux-s390x
	docker run --rm byteit101/jrubycrosslinux-ppc64le > ./dockcross-linux-ppc64le
	docker run --rm byteit101/jrubycrosslinux-ppc64 > ./dockcross-linux-ppc64
	touched=true
fi
if [ ${BINARY_SET} == "ALL" ] || [ ${BINARY_SET} == "linux-arm" ]; then
	docker run --rm byteit101/jrubycrosslinux-arm64 > ./dockcross-linux-arm64
	docker run --rm byteit101/jrubycrosslinux-armv6sf > ./dockcross-linux-arm
	touched=true
fi
if [ ${BINARY_SET} == "ALL" ] || [ ${BINARY_SET} == "linux-risc" ]; then
	docker run --rm byteit101/jrubycrosslinux-riscv64 > ./dockcross-linux-riscv64
	docker run --rm byteit101/jrubycrosslinux-mips64el > ./dockcross-linux-mips64el
	docker run --rm byteit101/jrubycrosslinux-loongarch64 > ./dockcross-linux-loongarch64
	touched=true
fi
if [ ${BINARY_SET} == "ALL" ] || [ ${BINARY_SET} == "linux-intel" ]; then
	docker run --rm byteit101/jrubycrosslinux-i686 > ./dockcross-linux-i686
	docker run --rm byteit101/jrubycrosslinux-x86_64 > ./dockcross-linux-x64
	touched=true
fi

if [ $touched == "true" ] ; then
	# fix the repository link
	sed -i 's/DEFAULT_DOCKCROSS_IMAGE=dockcross/DEFAULT_DOCKCROSS_IMAGE=byteit101/' ./dockcross-*
	# fix me uploading the wrong tags sometimes
	sed -i 's/DEFAULT_DOCKCROSS_IMAGE=\(.*\):20.*/DEFAULT_DOCKCROSS_IMAGE=\1:latest/' ./dockcross-*
	#DEFAULT_DOCKCROSS_IMAGE=dockcross/jrubycrosslinux-x86_64:20240521-9dc1ddc

	chmod +x ./dockcross-*
fi
