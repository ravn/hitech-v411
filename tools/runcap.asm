[BITS 16]
[ORG 0x100]
start:
        mov     [ss_save], ss
        mov     [sp_save], sp

        ; --- SETBLOCK: shrink parent memory so child can load ---
        mov     ah, 0x4A
        mov     bx, 0x200       ; 0x200 paragraphs = 8 KB (room for runcap itself)
        int     0x21
        jc      fail

        ; --- create ERR.LOG ---
        mov     ah, 0x3C
        xor     cx, cx
        mov     dx, errlog
        int     0x21
        jc      fail
        mov     [our_handle], ax

        ; --- DUP2 handle 2 -> our file ---
        mov     bx, ax
        mov     cx, 2
        mov     ah, 0x46
        int     0x21
        jc      fail

        ; --- close our original handle ---
        mov     bx, [our_handle]
        mov     ah, 0x3E
        int     0x21

        ; --- EXEC parameter block ---
        mov     ax, cs
        mov     [pb_cmd_seg], ax
        mov     [pb_fcb1_seg], ax
        mov     [pb_fcb2_seg], ax
        mov     word [pb_env], 0
        mov     word [pb_cmd_off], cmdline
        mov     word [pb_fcb1_off], fcb_dummy
        mov     word [pb_fcb2_off], fcb_dummy

        ; --- EXEC C:\CGEN.EXE ---
        mov     dx, cgen_path
        mov     bx, parm_block
        mov     ax, 0x4B00
        int     0x21
        jc      exec_fail

        ; restore SS:SP
        cli
        mov     ss, [ss_save]
        mov     sp, [sp_save]
        sti
        mov     ah, 0x4C
        mov     al, 0
        int     0x21

fail:
        ; Write "FAIL:<errcode>\n" to handle 2 (still original stdout
        ; if we got here before DUP2)
        mov     ah, 0x4C
        mov     al, 1
        int     0x21

exec_fail:
        ; AX has DOS error code from failed EXEC.
        ; Write to ERR.LOG (handle 2, already dup'd)
        cli
        mov     ss, [ss_save]
        mov     sp, [sp_save]
        sti
        ; Save errcode
        mov     [errcode], ax
        ; Write "EXEC ERR " then 4 hex digits
        mov     ah, 0x40
        mov     bx, 2
        mov     cx, exec_msg_len
        mov     dx, exec_msg
        int     0x21
        ; Convert errcode to hex
        mov     ax, [errcode]
        mov     di, hexbuf
        mov     cx, 4
hex_loop:
        rol     ax, 4
        push    ax
        and     al, 0x0F
        cmp     al, 10
        jb      .digit
        add     al, 'A' - 10 - '0'
.digit: add     al, '0'
        mov     [di], al
        inc     di
        pop     ax
        loop    hex_loop
        mov     ah, 0x40
        mov     bx, 2
        mov     cx, 6           ; 4 hex digits + CR + LF
        mov     dx, hexbuf
        int     0x21
        mov     ah, 0x4C
        mov     al, 2
        int     0x21

errlog:        db "ERR.LOG", 0
cgen_path:     db "C:\CGEN.EXE", 0

exec_msg:      db "EXEC ERR "
exec_msg_len   equ $ - exec_msg

cmdline:       db cmd_end - cmd_args
cmd_args:      db " ROM.T2 OUT.T1"
cmd_end:       db 0x0D

fcb_dummy:     times 16 db 0

parm_block:
pb_env:        dw 0
pb_cmd_off:    dw 0
pb_cmd_seg:    dw 0
pb_fcb1_off:   dw 0
pb_fcb1_seg:   dw 0
pb_fcb2_off:   dw 0
pb_fcb2_seg:   dw 0

our_handle:    dw 0
ss_save:       dw 0
sp_save:       dw 0
errcode:       dw 0
hexbuf:        times 4 db 0
               db 0x0D, 0x0A
