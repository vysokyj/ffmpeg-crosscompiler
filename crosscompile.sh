#!/bin/bash

# -----------------------------------------------------------------------------------------------------------
# ARCHITECTURE

if [ $# -eq 0 ]; then
    echo "Expected triplet argument"
    exit
fi

if [ $1 = "x86_64-w64-mingw32" ] || [ $1 = "i686-w64-mingw32" ]; then
    TRIPLET=$1
else 
    echo "Unsupported triplet $1"
    exit
fi

# -----------------------------------------------------------------------------------------------------------
# LIBRARY VERSIONS

OPENCORE="opencore-amr-0.1.5"
LAME="lame-3.99.5"
LIBVORBIS="libvorbis-1.3.5"
LIBOGG="libogg-1.3.2"
LIBTHEORA="libtheora-1.1.1"
FDK_AAC="fdk-aac-0.1.5"
XVIDCORE="xvidcore-1.3.4"
X264="x264-snapshot-20171001-2245-stable"
X265="x265_2.5"
FFMPEG="ffmpeg-3.3.4"

# -----------------------------------------------------------------------------------------------------------
# ENVIRONMENT

WORKSPACE="$(pwd)"
PACKAGES="/tmp/ffmpeg-crosscompile"
SOURCES="/tmp/ffmpeg-crosscompile/${TRIPLET}"
PREFIX="/tmp/${TRIPLET}"

export CC=$TRIPLET-gcc
export CXX=$TRIPLET-g++
export CPP=$TRIPLET-cpp
export AR=$TRIPLET-ar
export RANLIB=$TRIPLET-ranlib
export ADD2LINE=$TRIPLET-addr2line
export AS=$TRIPLET-as
export LD=$TRIPLET-ld
export NM=$TRIPLET-nm
export STRIP=$TRIPLET-strip

export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"

if [ TRIPLET = "x86_64-w64-mingw32" ]; then 
ARCH="x86_64"
else
ARCH="x86"
fi

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
if [[ -n $NUMJOBS ]]; then
    MJOBS=$NUMJOBS
elif [[ -f /proc/cpuinfo ]]; then
    MJOBS=$(grep -c processor /proc/cpuinfo)
elif [[ "$OSTYPE" == "darwin"* ]]; then
	MJOBS=$(sysctl -n machdep.cpu.thread_count)
else
    MJOBS=4
fi


# -----------------------------------------------------------------------------------------------------------
# FUNCTIONS

function begin {
    echo "Start building $1"
    mkdir "${SOURCES}/${1}"
    cd "${SOURCES}/${1}"
}

function end {
    echo "Finished building $1"
    echo "---------------------------------------------------------------------------------------------------"  
    cd "${WORKSPACE}"
}


function download {
    filename=$(basename $1)
    if [ ! -f "${PACKAGES}/${filename}" ]; then wget $1 -P "${PACKAGES}" || exit ; fi
    tar -xf "${PACKAGES}/${filename}" -C "${SOURCES}" || exit
}

function apply_patch {
  local url=$1 # if you want it to use a local file instead of a url one [i.e. local file with local modifications] specify it like file://localhost/full/path/to/filename.patch
  local patch_type=$2
  if [[ -z $patch_type ]]; then
    patch_type="-p0" # some are -p1 unfortunately, git's default
  fi
  local patch_name=$(basename $url)
  local patch_done_name="$patch_name.done"
  if [[ ! -e $patch_done_name ]]; then
    if [[ -f $patch_name ]]; then
      rm $patch_name || exit 1 # remove old version in case it has been since updated on the server...
    fi
    curl -4 --retry 5 $url -O --fail || echo_and_exit "unable to download patch file $url"
    echo "applying patch $patch_name"
    patch $patch_type < "$patch_name" || exit 1
    touch $patch_done_name || exit 1
    rm -f already_ran* # if it's a new patch, reset everything too, in case it's really really really new
  #else
    #echo "patch $patch_name already applied"
  fi
}


# -----------------------------------------------------------------------------------------------------------
# PREPARE

rm -rf ${SOURCES}
#rm -rf ${PREFIX}

mkdir -p ${SOURCES}
mkdir -p ${PREFIX}

# -----------------------------------------------------------------------------------------------------------
# OPENCORE

if [ ! -f ${PREFIX}/lib/libopencore-amrnb.a ]; then
begin ${OPENCORE}
download "http://downloads.sourceforge.net/project/opencore-amr/opencore-amr/${OPENCORE}.tar.gz"
./configure --host=$TRIPLET --prefix=$PREFIX --disable-shared --enable-static
make -j $MJOBS || exit
make install
end ${OPENCORE}
fi

# -----------------------------------------------------------------------------------------------------------
# LAME

if [ ! -f ${PREFIX}/lib/libmp3lame.a ]; then
begin ${LAME}
download "http://kent.dl.sourceforge.net/project/lame/lame/3.99/${LAME}.tar.gz"
apply_patch file://${WORKSPACE}/patches/lame3.patch
./configure --host=$TRIPLET --prefix=$PREFIX --disable-shared --enable-static \
--enable-nasm \
--disable-decoder \
--disable-frontend
make -j $MJOBS || exit
make install
end ${LAME}
fi

# -----------------------------------------------------------------------------------------------------------
# LIBOGG

if [ ! -f ${PREFIX}/lib/libogg.a ]; then
begin ${LIBOGG}
download "http://downloads.xiph.org/releases/ogg/${LIBOGG}.tar.gz"
./configure --host=$TRIPLET --prefix=$PREFIX --disable-shared --enable-static
make -j $MJOBS || exit
make install
end ${LIBOGG}
fi

# -----------------------------------------------------------------------------------------------------------
# LIBVORBIS

if [ ! -f ${PREFIX}/lib/libvorbis.a ]; then
begin ${LIBVORBIS}
download "http://downloads.xiph.org/releases/vorbis/${LIBVORBIS}.tar.gz"
./configure --host=$TRIPLET --prefix=$PREFIX --disable-shared --enable-static
make -j $MJOBS || exit
make install
end ${LIBVORBIS}
fi

# -----------------------------------------------------------------------------------------------------------
# LIBTHEORA

if [ ! -f ${PREFIX}/lib/libtheora.a ]; then
begin ${LIBTHEORA}
download "https://ftp.osuosl.org/pub/xiph/releases/theora/${LIBTHEORA}.tar.xz"
./configure --host=$TRIPLET --prefix=$PREFIX --disable-shared --enable-static \
--with-ogg-libraries=${PREFIX}/lib \
--with-ogg-includes=${PREFIX}/include/ \
--with-vorbis-libraries=${PREFIX}/lib \
--with-vorbis-includes=${PREFIX}/include/ \
--disable-oggtest \
--disable-vorbistest \
--disable-examples \
--disable-asm
make -j $MJOBS || exit
make install
end ${LIBTHEORA}
fi


# -----------------------------------------------------------------------------------------------------------
# FDK-AAC

if [ ! -f ${PREFIX}/lib/libfdk-aac.a ]; then
begin ${FDK_AAC}
download "http://downloads.sourceforge.net/project/opencore-amr/fdk-aac/${FDK_AAC}.tar.gz"
./configure --host=$TRIPLET --prefix=$PREFIX --disable-shared --enable-static
make -j $MJOBS || exit
make install
end ${FDK_AAC}
fi


# -----------------------------------------------------------------------------------------------------------
# XVIDCORE

if [ ! -f ${PREFIX}/lib/xvidcore.a ]; then
begin ${XVIDCORE}
download "http://downloads.xvid.org/downloads/${XVIDCORE}.tar.gz"
cd "${SOURCES}/xvidcore/build/generic" || exit
./configure --host=$TRIPLET --prefix=$PREFIX --disable-shared --enable-static
make -j $MJOBS || exit
make install
rm "${PREFIX}/lib/xvidcore.dll.a"
rm "${PREFIX}/bin/xvidcore.dll"
end ${XVIDCORE}
fi

# -----------------------------------------------------------------------------------------------------------
# H264

#TODO: ASM needs YASM > 1.2 so --disable-asm

if [ ! -f ${PREFIX}/lib/libx264.a ]; then
begin ${X264}
download "ftp://ftp.videolan.org/pub/x264/snapshots/${X264}.tar.bz2"
./configure --prefix=$PREFIX --host=$TRIPLET --cross-prefix=$TRIPLET- \
--enable-static \
--enable-strip \
--bit-depth=10 \
--disable-asm
make -j $MJOBS || exit
make install-cli || exit
make install-lib-dev || exit
make install-lib-static || exit
end ${X264}
fi

# -----------------------------------------------------------------------------------------------------------
# H265

# https://bitbucket.org/multicoreware/x265/wiki/CrossCompile
# ENABLE_SHARED:bool=off - important!
# HIGH_BIT_DEPTH=1 is 10 bit support
# -DWINXP_SUPPORT=1 -DENABLE_ASSEMBLY=OFF 32 bit arch only?
# Note if -DENABLE_SHARED:bool=off then ffmpeg throws unable find x265 with ffmpeg...

if [ ! -f ${PREFIX}/lib/libx265.a ]; then
begin ${X265}
download "https://bitbucket.org/multicoreware/x265/downloads/${X265}.tar.gz"
cd source
if [ triplet = "i686-w64-mingw32" ]; then
cmake \
-G "Unix Makefiles" \
-DCMAKE_TOOLCHAIN_FILE="${WORKSPACE}/profiles/${TRIPLET}.cmake" \
-DCMAKE_INSTALL_PREFIX=${PREFIX} \
-DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
-DHIGH_BIT_DEPTH=ON \
-DENABLE_CLI=ON \
-DENABLE_ASSEMBLY=0 \
-DWINXP_SUPPORT=1 \
.
else
cmake \
-G "Unix Makefiles" \
-DCMAKE_TOOLCHAIN_FILE="${WORKSPACE}/profiles/${TRIPLET}.cmake" \
-DCMAKE_INSTALL_PREFIX=${PREFIX} \
-DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
-DHIGH_BIT_DEPTH=ON \
-DENABLE_CLI=ON \
-DENABLE_SHARED:bool=on \
.
fi
make -j $MJOBS || exit
make install
end ${X265}
fi

# -----------------------------------------------------------------------------------------------------------
# FFMPEG

#--extra-version=static \
#--extra-ldflags="-L$PREFIX/lib" \
#--extra-cflags="-I$PREFIX/include" \
#--extra-cflags=--static \
#--extra-cflags=-DLIBTWOLAME_STATIC \
#--extra-cflags=-DMODPLUG_STATIC \
#--extra-cflags=-DCACA_STATIC

if [ ! -f ${PREFIX}/bin/ffmpeg.exe ]; then
begin ${FFMPEG}
download "http://ffmpeg.org/releases/${FFMPEG}.tar.xz"
./configure \
--arch=$ARCH \
--target-os=mingw32 \
--cross-prefix=$TRIPLET- \
--pkg-config=pkg-config \
--prefix=${PREFIX} \
--disable-debug \
--disable-ffplay \
--disable-ffserver \
--disable-doc \
--disable-shared \
--enable-static \
--enable-runtime-cpudetect \
--enable-gpl \
--enable-nonfree \
--enable-version3 \
--enable-libopencore_amrwb \
--enable-libopencore_amrnb \
--enable-libmp3lame \
--enable-libtheora \
--enable-libvorbis \
--enable-libfdk-aac \
--enable-libx264 \
--enable-libx265
make -j $MJOBS || exit
make install

rm "${PREFIX}/lib/libx265.dll.a"
rm "${PREFIX}/bin/libx265.dll"

end ${FFMPEG}
fi

# -----------------------------------------------------------------------------------------------------------
# PACKAGE


cd "${PREFIX}"
cp "${WORKSPACE}/templates/README.txt" README.txt
echo "Architecture: ${TRIPLET}" >> README.txt
echo "" >> README.txt
echo "Included software versions:" >> README.txt
echo "" >> README.txt
echo "${OPENCORE}" >> README.txt
echo "${LAME}" >> README.txt
echo "${LIBVORBIS}" >> README.txt
echo "${LIBOGG}" >> README.txt
echo "${LIBTHEORA}" >> README.txt
echo "${FDK_AAC}" >> README.txt
echo "${XVIDCORE}" >> README.txt
echo "${X264}" >> README.txt
echo "${X265}" >> README.txt 
echo "${FFMPEG}" >> README.txt

triplet_array=(${TRIPLET//-/ })
mkdir -p "${WORKSPACE}/build"
zip -x "${PREFIX}/lib" "${PREFIX}/includes" -r "${WORKSPACE}/build/${FFMPEG}-windows-${triplet_array[0]}.zip" *







