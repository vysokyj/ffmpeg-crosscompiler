# ffmpeg-mingw-script

FFMPEG MinGW crosscompiler script.

Creates Windows lite version with libfdk-aac.

Integrated h264 and h265 has 10bit color support - more colors = less visible cube fragments.

## Notes

Unable to build 32 bit version - libx265 wont compile.

## Linux Prerequistites

```bash
sudo apt-get install gcc-mingw-w64 yasm wget
```

## Study Material

* [How to cross compile from linux](http://projectsymphony.blogspot.cz/2012/09/how-to-cross-compile-from-linux-to.html)
