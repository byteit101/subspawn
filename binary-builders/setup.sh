
touched=false
if [ "x${BINARY_SET}" == "x" ]
then
	BINARY_SET=ALL
fi

#docker run --rm dockcross/android-arm64 > ./dockcross-android-arm64
#docker run --rm dockcross/android-arm > ./dockcross-android-arm # arm7

# Just the linuxes here
#docker run --rm dockcross/linux-s390x > ./dockcross-linux-s390x
#docker run --rm dockcross/linux-ppc64le > ./dockcross-linux-ppc64le
if [ ${BINARY_SET} == "ALL" ] || [ ${BINARY_SET} == "linux-arm" ]; then
	docker run --rm dockcross/linux-arm64 > ./dockcross-linux-arm64
	docker run --rm dockcross/linux-armv7 > ./dockcross-linux-armv7
	docker run --rm dockcross/linux-armv6 > ./dockcross-linux-armv6
	touched=true
fi
#docker run --rm dockcross/linux-riscv32 > ./dockcross-linux-riscv32
#docker run --rm dockcross/linux-riscv64 > ./dockcross-linux-riscv64
if [ ${BINARY_SET} == "ALL" ] || [ ${BINARY_SET} == "linux-intel" ]; then
	docker run --rm dockcross/linux-x86 > ./dockcross-linux-x86
	docker run --rm dockcross/linux-x64 > ./dockcross-linux-x64
	touched=true
fi

if [ $touched == "true" ] ; then
	chmod +x ./dockcross-*
fi
