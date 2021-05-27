FROM ubuntu:20.04
#FROM ubuntu:16.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -qqy --no-install-recommends \
    git wget bzip2 file unzip libtool pkg-config cmake build-essential \
    automake yasm gettext autopoint vim python python3 ninja-build subversion \
    cmake cmake-curses-gui mingw-w64-tools binutils-mingw-w64 \
    pkg-config sudo openssh-client openssh-server p7zip-full pixz \
    lftp ncftp nano jed locales mc less lv \
    wget yasm nasm \
    libz-mingw-w64 libz-mingw-w64-dev win-iconv-mingw-w64-dev \
    ccache aptitude vim emacs \
    ca-certificates && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*


RUN git config --global user.name "LLVM MinGW" && \
    git config --global user.email root@localhost

WORKDIR /build

ENV FORCE_THREADS=6
ENV TOOLCHAIN_PREFIX=/opt/llvm-mingw-12
ENV LLVM_VER=llvmorg-12.0.0

ARG TOOLCHAIN_ARCHS="i686 x86_64 armv7 aarch64"

# Build everything that uses the llvm monorepo. We need to build the mingw runtime before the compiler-rt/libunwind/libcxxabi/libcxx runtimes.
COPY build-llvm.sh strip-llvm.sh install-wrappers.sh ./
COPY build-mingw-w64.sh build-compiler-rt.sh ./
COPY build-mingw-w64-libraries.sh build-libcxx.sh ./
COPY wrappers/*.sh wrappers/*.c wrappers/*.h ./wrappers/

RUN ./build-llvm.sh --build-threads $FORCE_THREADS --llvm-version $LLVM_VER $TOOLCHAIN_PREFIX && \
    ./strip-llvm.sh $TOOLCHAIN_PREFIX && \
    ./install-wrappers.sh $TOOLCHAIN_PREFIX && \
    ./build-mingw-w64.sh --build-threads $FORCE_THREADS $TOOLCHAIN_PREFIX && \
    ./build-compiler-rt.sh --build-threads $FORCE_THREADS $TOOLCHAIN_PREFIX && \
    ./build-mingw-w64-libraries.sh --build-threads $FORCE_THREADS $TOOLCHAIN_PREFIX && \
    ./build-libcxx.sh --build-threads $FORCE_THREADS $TOOLCHAIN_PREFIX && \
    ./build-compiler-rt.sh --build-threads $FORCE_THREADS $TOOLCHAIN_PREFIX --build-sanitizers && \
    rm -rf /build/*

# Build libssp
COPY build-libssp.sh libssp-Makefile ./
RUN ./build-libssp.sh --build-threads $FORCE_THREADS $TOOLCHAIN_PREFIX && \
    rm -rf /build/*

ENV PATH=$TOOLCHAIN_PREFIX/bin:$PATH
