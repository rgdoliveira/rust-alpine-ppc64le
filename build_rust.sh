# Build an statically linked rustc (with host=powerpc64le-unknown-linux-musl)
#
# Usage:
# $ sudo docker run -it -v $(pwd):/mnt ubuntu:16.04
#
# # inside the docker container
# $ bash /mnt/build_rust.sh

set -ex

host=powerpc64le-unknown-linux-musl
user=rustbuild

as_user() {
    su -c 'bash -c "'"${@}"'"' $user
}

mk_user() {
    useradd -m $user
}

install_deps() {
    apt-get update

    # musl-cross-make
    apt-get install -y --no-install-recommends bzip2 ca-certificates curl g++ make patch rsync \
            wget xz-utils

    # Rust deps
    apt-get install -y --no-install-recommends cmake file git python
}

mk_cross_toolchain() {

    local td=$(mktemp -d)

    local repo=musl-cross-make
    local version=0.9.2

    pushd $td
    curl -L https://github.com/richfelker/$repo/archive/v$version.tar.gz | tar xzf -
    cd $repo-$version
    sed -i "s/https/http/g" Makefile
    TARGET=$host make
    cd build-*
    TARGET=$host make install
    rsync -av output/ /usr/local/

    popd
    rm -rf $td

    pushd /usr/local/bin
    ln -s $host-gcc musl-gcc
    ln -s $host-g++ musl-g++
    popd
}

fetch_rust() {
    as_user 'git clone --depth 1 https://github.com/rust-lang/rust ~/rust'
}

cp_libunwind() {
    cp libunwind.a /usr/local/$host/lib/libunwind.a
}

mk_rustc() {
    dir=$(pwd)
    as_user "
mkdir ~/build
cd ~/build
../rust/configure --disable-jemalloc --enable-llvm-static-stdcpp --host=$host --musl-root=/usr/local/$host
cp $dir/config.toml .
cp $dir/powerpc64le_unknown_linux_musl.rs ../rust/src/librustc_back/target/powerpc64le_unknown_linux_musl.rs
cp $dir/mod.rs ../rust/src/librustc_back/target/mod.rs
make -j10 RUST_BACKTRACE=1"
}

main() {
   mk_user
   install_deps
   mk_cross_toolchain
   fetch_rust	
   cp_libunwind
   mk_rustc
}

main
