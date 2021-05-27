FROM ubuntu:20.04
#FROM ubuntu:16.04

ENV FORCE_THREADS=6
ENV TOOLCHAIN_PREFIX=/opt/llvm-mingw-12
ENV TOOLCHAIN_TARGET_OSES="mingw32 mings32uwp"
ENV LLVM_VER=llvmorg-12.0.0


ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -qqy --no-install-recommends \
    git wget bzip2 file unzip libtool pkg-config cmake build-essential \
    automake yasm gettext autopoint vim \
	python python3 \
	python3-distutils \
	ninja-build subversion \
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

ENV ROOT_WORK_DIR=$WORKDIR

WORKDIR llvm-build
ENV BUILD_ROOT_DIR=$WORKDIR
ENV SCRIPT_ROOT_DIR=$WORKDIR/scripts

COPY bootstrap.sh ./
COPY build-llvm.sh strip-llvm.sh install-wrappers.sh $SCRIPT_ROOT_DIR
COPY build-mingw-w64.sh build-compiler-rt.sh $SCRIPT_ROOT_DIR
COPY build-mingw-w64-libraries.sh build-libcxx.sh $SCRIPT_ROOT_DIR
COPY build-libssp.sh libssp-Makefile $SCRIPT_ROOT_DIR

COPY wrappers/*.sh wrappers/*.c wrappers/*.h $SCRIPT_ROOT_DIR/wrappers/
COPY test/* $SCRIPT_ROOT_DIR/test/

COPY build-llvm.sh strip-llvm.sh install-wrappers.sh $WORKDIR/build/
COPY build-mingw-w64.sh build-compiler-rt.sh $WORKDIR/build/
COPY build-mingw-w64-libraries.sh build-libcxx.sh $WORKDIR/build/
COPY wrappers/*.sh wrappers/*.c wrappers/*.h $WORKDIR/build/wrappers/
COPY test/* $WORKDIR/build/test/

ARG TOOLCHAIN_ARCHS="i686 x86_64 armv7 aarch64"
 
# Build everything that uses the llvm monorepo. We need to build the mingw runtime before the compiler-rt/libunwind/libcxxabi/libcxx runtimes.

RUN $SCRIPT_ROOT_DIR/build-llvm.sh --llvm-version $LLVM_VER \
                            --build-threads $FORCE_THREADS \
                            $TOOLCHAIN_PREFIX
		    
#RUN ../scripts/strip-llvm.sh $TOOLCHAIN_PREFIX

RUN $SCRIPT_ROOT_DIR/install-wrappers.sh $TOOLCHAIN_PREFIX

ENV PATH=$TOOLCHAIN_PREFIX/bin:$PATH

WORKDIR $BUILD_ROOT_DIR/build
RUN $SCRIPT_ROOT_DIR/build-mingw-w64.sh \
                     --build-threads $FORCE_THREADS \
                     $TOOLCHAIN_PREFIX

WORKDIR $BUILD_ROOT_DIR
RUN $SCRIPT_ROOT_DIR/build-compiler-rt.sh \
                     --build-threads $FORCE_THREADS \
                     $TOOLCHAIN_PREFIX

WORKDIR $BUILD_ROOT_DIR/build
RUN $SCRIPT_ROOT_DIR/build-mingw-w64-libraries.sh \
                     --build-threads $FORCE_THREADS \
                     $TOOLCHAIN_PREFIX
					 
WORKDIR $BUILD_ROOT_DIR
RUN $SCRIPT_ROOT_DIR/build-libcxx.sh \
                     --build-threads $FORCE_THREADS \
                     $TOOLCHAIN_PREFIX

WORKDIR $BUILD_ROOT_DIR/build
RUN $SCRIPT_ROOT_DIR/build-compiler-rt.sh \
                     --build-threads $FORCE_THREADS \
                     $TOOLCHAIN_PREFIX

WORKDIR $BUILD_ROOT_DIR/build
COPY build-libssp.sh libssp-Makefile $WORKDIR
RUN $SCRIPT_ROOT_DIR/build-libssp.sh \
                     --build-threads $FORCE_THREADS \
                     $TOOLCHAIN_PREFIX

#RUN ./bootstrap.sh

#    rm -rf /build/*
