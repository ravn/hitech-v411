#!/bin/sh
# Thorough test matrix for V4.11 image vs our needs (rcbios-in-c / cpnos-rom /
# autoload-in-c style code).  Each test prints PASS/FAIL plus key evidence.

set -eu
IMG=${IMG:-hitech-v411:test}
ZC="docker run --rm -v $(pwd):/work $IMG zc"

pass() { printf '\033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '\033[31mFAIL\033[0m %s — %s\n' "$1" "$2"; }
note() { printf '       %s\n' "$1"; }

rm -f *.COM *.com *.BIN *.bin *.OBJ *.obj *.AS *.as *.LOG *.log *.HEX *.hex *.MAP *.map *.SYM *.sym 2>/dev/null

# ============================================================
# 1. CP/M target — baseline (we already know this works)
# ============================================================
cat > t01.c <<'EOF'
#include <stdio.h>
int main(void) { printf("hi %d\n", 42); return 0; }
EOF
if $ZC -CPM t01.c >/dev/null 2>&1 && [ -s T01.COM ]; then
    pass "01 CP/M baseline compile"
    note "T01.COM size = $(wc -c < T01.COM)"
else
    fail "01 CP/M baseline compile" "no .COM produced"
fi

# ============================================================
# 2. ROM mode — -A code,ram,size produces a .bin at a non-CP/M ORG
# ============================================================
cat > t02.c <<'EOF'
unsigned char rambuf[16];
const unsigned char romtab[4] = {0x11,0x22,0x33,0x44};
void main(void) {
    unsigned char i;
    for (i=0; i<4; i++) rambuf[i] = romtab[i];
    for (;;);
}
EOF
# -A code_adr,ram_adr,ram_size in HEX (sscanf %x).
# code at 0x0000 (ROM base), ram at 0x8000, ram size 0x1000.
if $ZC -A0,8000,1000 -Ot02.bin t02.c >/dev/null 2>&1 && [ -s T02.BIN ]; then
    pass "02 ROM mode -A0,8000,1000 produces .bin"
    note "T02.BIN size = $(wc -c < T02.BIN) bytes"
    note "T02.BIN first 8 bytes = $(od -A n -t x1 -N 8 T02.BIN | tr -s ' ')"
else
    fail "02 ROM mode -A" "no .bin produced or empty"
    ls T02.* 2>/dev/null | sed 's/^/       leftover: /'
fi

# ============================================================
# 3. Calling convention — does V4.11 pass args in registers or on stack?
# ============================================================
cat > t03.c <<'EOF'
unsigned char x;
unsigned char add(unsigned char a, unsigned char b) { return a + b; }
unsigned add16(unsigned a, unsigned b) { return a + b; }
void store(unsigned char v) { x = v; }
EOF
if $ZC -S -CPM t03.c >/dev/null 2>&1 && [ -s T03.AS ]; then
    pass "03 codegen via -S produces .as"
    note "T03.AS head:"
    head -40 T03.AS | sed 's/^/         /'
else
    fail "03 codegen -S" "no .as produced"
fi

# ============================================================
# 4. interrupt qualifier on Z80
# ============================================================
cat > t04.c <<'EOF'
interrupt void isr(void) { *(unsigned char *)0xF800 = 0x21; }
EOF
rm -f T04.* 2>/dev/null
if $ZC -S -CPM t04.c > t04-build.log 2>&1; then
    if [ -s T04.AS ]; then
        pass "04 interrupt qualifier accepted on Z80"
        note "T04.AS body (look for di/ei/reti):"
        grep -E '\b(di|ei|reti|ret)\b' T04.AS | head -5 | sed 's/^/         /'
    else
        fail "04 interrupt qualifier" "compile succeeded but no .as"
    fi
else
    fail "04 interrupt qualifier" "compile failed"
    head -5 t04-build.log | sed 's/^/       /'
fi

# ============================================================
# 5. port qualifier on Z80
# ============================================================
cat > t05.c <<'EOF'
port unsigned char p10;
void f(void) { p10 = 0x42; }
unsigned char g(void) { return p10; }
EOF
rm -f T05.* 2>/dev/null
if $ZC -S -CPM t05.c > t05-build.log 2>&1; then
    if [ -s T05.AS ]; then
        pass "05 port qualifier accepted on Z80"
        note "T05.AS body (look for in/out):"
        grep -E '\b(in|out)\b' T05.AS | head -5 | sed 's/^/         /'
    else
        fail "05 port qualifier" "compile succeeded but no .as"
    fi
else
    fail "05 port qualifier" "compile failed"
    head -5 t05-build.log | sed 's/^/       /'
fi

# ============================================================
# 6. C dialect — inline keyword, for-loop decl, _Bool, // comments
# ============================================================
cat > t06inline.c <<'EOF'
static inline int dbl(int x) { return x * 2; }
int main(void) { return dbl(21); }
EOF
rm -f T06INLINE.* 2>/dev/null
if $ZC -CPM t06inline.c >/dev/null 2>&1 && [ -s T06INLIN.COM -o -s T06INLINE.COM ]; then
    pass "06a inline keyword accepted"
else
    fail "06a inline keyword" "rejected"
fi

cat > t06for.c <<'EOF'
int main(void) { int s=0; for (int i=0; i<3; i++) s += i; return s; }
EOF
rm -f T06FOR.* 2>/dev/null
if $ZC -CPM t06for.c >/dev/null 2>&1 && [ -s T06FOR.COM ]; then
    pass "06b for-loop decl (C99) accepted"
else
    fail "06b for-loop decl" "rejected (expected — V4.11 is C89)"
fi

cat > t06slash.c <<'EOF'
// single-line comment style
int main(void) { return 0; }
EOF
rm -f T06SLASH.* 2>/dev/null
if $ZC -CPM t06slash.c >/dev/null 2>&1 && [ -s T06SLAS.COM -o -s T06SLASH.COM ]; then
    pass "06c // comments accepted"
else
    fail "06c // comments" "rejected"
fi

# ============================================================
# 7. Codegen quality — compare V4.11 vs V3.09 on the same source
# ============================================================
cat > t07.c <<'EOF'
#include <stdio.h>
int main(void) {
    int x = 0; int i;
    for (i = 0; i < 10; i++) x += i;
    printf("sum=%d\n", x);
    return 0;
}
EOF
rm -f T07.* 2>/dev/null
if $ZC -CPM -O t07.c >/dev/null 2>&1 && [ -s T07.COM ]; then
    v411_O=$(wc -c < T07.COM)
    rm -f T07.COM 2>/dev/null
    $ZC -CPM t07.c >/dev/null 2>&1
    v411_noO=$(wc -c < T07.COM)
    # Compare against V3.09 ghcr.io/ravn/hitech (zc.c outputs hello.com here too)
    docker run --rm -v $(pwd):/work ghcr.io/ravn/hitech:latest zc -O t07.c >/dev/null 2>&1
    v309_O=$(wc -c < t07.com)
    rm -f t07.com 2>/dev/null
    docker run --rm -v $(pwd):/work ghcr.io/ravn/hitech:latest zc t07.c >/dev/null 2>&1
    v309_noO=$(wc -c < t07.com)
    pass "07 codegen size comparison"
    note "V3.09       : $v309_noO bytes"
    note "V3.09 -O    : $v309_O bytes"
    note "V4.11       : $v411_noO bytes"
    note "V4.11 -O    : $v411_O bytes"
    note "V4.11 vs V3.09 saves $(( v309_O - v411_O )) bytes (with -O)"
else
    fail "07 codegen comparison" "V4.11 compile failed"
fi

# ============================================================
# 8. Inline asm syntax (#asm / asm())
# ============================================================
cat > t08.c <<'EOF'
unsigned char x;
void f(void) {
#asm
    ld a, 0x42
    ld (_x), a
#endasm
}
EOF
rm -f T08.* 2>/dev/null
if $ZC -S -CPM t08.c >/dev/null 2>&1 && [ -s T08.AS ]; then
    if grep -qE 'ld\s+a,\s*0x42|ld\s+a,\s*\.low\.66' T08.AS; then
        pass "08 #asm/#endasm inline asm syntax"
    else
        fail "08 inline asm" "asm body not in .as"
        head -30 T08.AS | sed 's/^/       /'
    fi
else
    fail "08 inline asm" "compile failed"
fi
