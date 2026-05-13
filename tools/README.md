# `tools/` — diagnostic utilities for V4.11 forensics

## `runcap.asm` — stderr capture for DOS programs in DOSBox

V4.11's `cgen.exe` truncates `rom.c` from `rc700-gensmedet/autoload-in-c/`
silently — it emits 6104 bytes of asm output and exits without writing
anything to stderr or returning a non-zero exit code. DOSBox 0.74's
shell doesn't separate stdout/stderr redirects (the `2>` syntax is
accepted but routed to the last redirect), so it's hard to see what
*if anything* a misbehaving DOS program is writing to handle 2.

`runcap.com` is a 283-byte DOS .COM that uses INT 21h/46h (DUP2) to
redirect stderr to a file at the DOS API level, **before** EXEC'ing
the target program. After the child exits, `ERR.LOG` contains
exactly what the child wrote to handle 2.

It's currently hard-coded for `C:\CGEN.EXE  ROM.T2  OUT.T1` — for
other targets, edit `cgen_path` and `cmdline` and re-assemble.

```sh
# Build (host-side NASM):
nasm -f bin runcap.asm -o RUNCAP.COM

# Use (inside DOSBox; cwd must contain ROM.T2):
RUNCAP.COM
# Result: OUT.T1 (cgen's stdout), ERR.LOG (cgen's stderr).
```

### Why this exists

Built as part of investigating cgen.exe's silent-truncation behaviour
on `rom.c`. We expected the V3.09 cgen source's `fatalErr("No room")`
path to fire, writing "cgen: No room" to stderr; runcap confirmed
that V4.11's cgen writes *nothing* to stderr on the truncation
trigger, ruling out the documented allocMem-failure path and pointing
at a different (undocumented) early-exit path in V4.11's binary.

### Why DOSBox classic can't do this natively

- DOSBox 0.74 shell parses `>` but maps `2>` to "use the last
  redirect as the stdout target". Stderr is never separated.
- DOSBox-x's shell (tested) collapses `1>` and `2>` to the last
  redirect too.
- DOS-program-side INT 21h/40h writes to handle 2 are not captured
  by any DOSBox redirect mechanism in headless (SDL dummy) mode —
  they go to the virtual VGA console which is then discarded.
- DOS-side INT 21h/46h (DUP2) **does** work: aliasing handle 2 to
  an open disk file lands writes in the file, exactly as on real DOS.

So `runcap.com` is the smallest reliable mechanism for capturing
DOS-program stderr in DOSBox without modifying the emulator.

## `dup2test.asm` — sanity-check for the DUP2 mechanism

A 60-byte NASM program that does just the DUP2 + writes "DUP2 OK" to
handle 2 itself. If you suspect stderr capture isn't working, build
this first and confirm `ERR.LOG` contains "DUP2 OK\r\n". If that
fails, the underlying DOSBox / handle wiring is broken; if it
succeeds, the target program isn't writing to handle 2 (which was
the finding for V4.11 cgen).

```sh
nasm -f bin dup2test.asm -o DUP2TEST.COM
# inside DOSBox:
DUP2TEST.COM
# Result: ERR.LOG with "DUP2 OK\r\n" (9 bytes).
```
