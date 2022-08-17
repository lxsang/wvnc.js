#! /bin/bash
# Make sure the emsdk is installed and worked
echo "Preparing libjpeg..."
if [ -d "libjpeg" ]; then
    rm -r libjpeg
fi
if [ -d "zlib" ]; then
    rm -r zlib
fi
if [ -d "libjpeg-turbo" ]; then
    rm -rf libjpeg-turbo
fi
#wget http://www.ijg.org/files/jpegsrc.v9c.tar.gz
#mkdir libjpeg
#tar xvzf jpegsrc.v9c.tar.gz -C ./libjpeg --strip-components=1
#rm jpegsrc.v9c.tar.gz
#cd libjpeg
#emconfigure ./configure
#emmake make

git clone https://github.com/libjpeg-turbo/libjpeg-turbo
git checkout 2.0.x

# export LDFLAGS=" "
cd libjpeg-turbo
mkdir build
cd build
emcmake cmake -G"Unix Makefiles" \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_SHARED=0 \
        -DWITH_SIMD=0 -DENABLE_SHARED=0 \
        -DCMAKE_C_FLAGS="-Wall -s ALLOW_MEMORY_GROWTH=1 " \
        ../ ${1+"$@"}
emmake make

## Using libjpeg-turbo
#git clone https://github.com/libjpeg-turbo/libjpeg-turbo
#mv libjpeg-turbo libjpeg
#cd libjpeg
#mkdir build
#cd build
#emcmake cmake ../
#emmake make
#cd ../
#echo "Preparing Zlib..."
#wget https://zlib.net/zlib-1.2.12.tar.gz
#mkdir zlib
#tar xvzf zlib-1.2.12.tar.gz -C ./zlib --strip-components=1
#rm zlib-1.2.12.tar.gz
#cd zlib
#emconfigure ./configure
#os=`uname -s`
#if [ "$os" = "Darwin" ]; then
#    sed -i -e 's/AR=libtool/AR=emar/g' Makefile
#    sed -i -e 's/ARFLAGS=-o/ARFLAGS=rc/g' Makefile
#fi
# TODO modify make file using sed if macos

