
#docker run --rm dockcross/android-arm64 > ./dockcross-android-arm64
#docker run --rm dockcross/android-arm > ./dockcross-android-arm # arm7

# Just the linuxes here
#docker run --rm dockcross/linux-s390x > ./dockcross-linux-s390x
docker run --rm dockcross/linux-ppc64le > ./dockcross-linux-ppc64le
docker run --rm dockcross/linux-arm64 > ./dockcross-linux-arm64
docker run --rm dockcross/linux-armv7 > ./dockcross-linux-armv7
docker run --rm dockcross/linux-armv6 > ./dockcross-linux-armv6
docker run --rm dockcross/linux-riscv32 > ./dockcross-linux-riscv32
docker run --rm dockcross/linux-riscv64 > ./dockcross-linux-riscv64
docker run --rm dockcross/linux-x86 > ./dockcross-linux-x86
docker run --rm dockcross/linux-x64 > ./dockcross-linux-x64

chmod +x ./dockcross-*
