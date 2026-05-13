# HI-TECH-Z80-C-Cross-Compiler (ravn/hitech-v411 fork)

This is the HI-TECH Z80 C Cross Compiler (MS-DOS) v4.11

## ravn fork additions

Content-identical to
[agn453/HI-TECH-Z80-C-Cross-Compiler](https://github.com/agn453/HI-TECH-Z80-C-Cross-Compiler)
on the V4.11 distribution itself; this fork adds a Docker wrapper plus
diagnostic tools:

- **`Dockerfile`** — wraps the V4.11 DOS toolchain in DOSBox so it runs
  on any Linux/macOS host without a host DOS install. `docker build -t
  hitech-v411 .` produces an image. Bind-mount your source dir as
  `/work`, and any of `zc cpp p1 cgen optim zas link objtohex libr cref
  dehuff` becomes a host-callable command via `docker run … hitech-v411
  zc -CPM hello.c`.
- **`hitech-wrap`** — the per-tool entrypoint that runs the requested
  V4.11 tool under DOSBox with `/work` mounted as `D:\` and the V4.11
  install at `C:\`.
- **`tests/run-all-tests.sh`** — verifies key V4.11 capabilities on
  the image: CP/M baseline compile, ROM mode `-A0,8000,1000`, codegen
  `.as` listing, `interrupt` qualifier, `port` qualifier, dialect
  surface (`inline`, for-decl, `//`), V4.11-vs-V3.09 size comparison,
  inline-asm syntax.
- **`tools/`** — DOS-side diagnostic utilities (NASM source). Currently
  `runcap.asm` (stderr capture for DOS programs in DOSBox via INT
  21h/46h DUP2) and `dup2test.asm` (sanity-check). See
  [tools/README.md](tools/README.md) for the story.

## Upstream README continues:

This is the HI-TECH Z80 C Cross Compiler (MS-DOS) v4.11

On the Facebook Zilog Z80 DIY group, Chris A Hills requested
and was granted permission from Microchip Technology Inc. to
release this software for cross-compiling CP/M Z80 programs
under MS-DOS.

The external download link for this software is

http://www.safetycritical.info/pub/Microchip_Hitech_C_Z80.zip

and it is also available from GitHub from
[here](https://raw.githubusercontent.com/agn453/HI-TECH-Z80-C-Cross-Compiler/master/Microchip_Hitech_C_Z80.zip).

Please read and keep a copy of the licence agreement in the
LICENSE file with all copies of these files.

This version runs under x86 MS-DOS (or equivalent).  If you're wanting
a version that runs on a Z80 under CP/M - please use the updated and
enhanced version derived from HI-TECH C Compiler for Z80 v3.09 from

https://github.com/agn453/HI-TECH-Z80-C

### Source files extracted

I've extracted the library source files from the Huffman encoded .HUF archives
into the *cpm*, *float*, *gen*, *romstdio* and *stdio* folders.

Documentation is in the *manuals* folder.

To install to MS-DOS, copy the files from the *diskA* and *diskB* folders
(and all their subfolders - preserving the directory heirarchy) into 
a empty directory on the MS-DOS hard disk and run the install program.

```
rem  Assumes files are located in C:\KITS\HITECHC
cd c:\
mkdir ins
xcopy /s c:\kits\hitechc\diska\*.* \ins
xcopy /s c:\kits\hitechc\diskb\*.* \ins
rem Mount the folder as drive I:
subst i: \ins
i:
install
```

When prompted, specify 'i' as the drive letter containing the distribution,
and choose the default path of C:\HITECH to install the files.

When done, remember to review changes to the AUTOEXEC.BAT file and 
remove the drive substitution before re-booting.

```
cd c:\
subst i: /d
```

--
Tony Nicholson 10-May-2021
