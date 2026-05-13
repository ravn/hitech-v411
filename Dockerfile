# HI-TECH C V4.11 (Z80 Cross Compiler for MS-DOS) wrapped in DOSBox.
#
# Build:  docker build -t hitech-v411 .
# Use:    docker run --rm -v "$PWD:/work" hitech-v411 zc hello.c
#         docker run --rm -v "$PWD:/work" hitech-v411 zc -A0,0x8000,0x1000 hello.c
#
# Output files (.com / .bin / .obj / .as / .map / .sym) land in $PWD.

FROM ubuntu:24.04

# DOSBox classic is enough for text-mode DOS tools; no graphics needed.
# SDL_VIDEODRIVER=dummy keeps it headless. coreutils for the wrapper.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        dosbox \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# V4.11 distribution layout, normalised into a single tree under
# /opt/hitech that mirrors the install.exe output:
#   /opt/hitech/        (binaries + headers)
#   /opt/hitech/zlibc.lib
#   /opt/hitech/zlibf.lib
# Inside DOSBox this becomes C:\HITECH\ — matching the V4.11 default
# DEFPATH in ZC.C so HITECH env var doesn't strictly need to be set.
COPY diskA/HITECH/ /opt/hitech/
COPY diskB/HITECH/ /opt/hitech/
# ZC.EXE (the driver) lives in diskA root, not diskA/HITECH/.
COPY diskA/ZC.EXE /opt/hitech/

# DOSBox config: no autoexec.bat (we drive everything via -c flags),
# mute machine output, headless SDL.
ENV SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy

# Wrapper: `zc args...` (or `cgen`/`p1`/`zas`/`link`/`objtohex`/`optim`/
# `libr`/`cref`/`cpp`) becomes a DOSBox invocation with /work mounted as D:.
COPY hitech-wrap /usr/local/bin/hitech-wrap
RUN chmod +x /usr/local/bin/hitech-wrap \
    && for tool in zc cpp p1 cgen optim zas link objtohex libr cref dehuff; do \
        ln -s hitech-wrap /usr/local/bin/$tool; \
       done

WORKDIR /work

CMD ["zc"]
