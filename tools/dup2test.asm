[BITS 16]
[ORG 0x100]
        ; create ERR.LOG
        mov ah, 0x3C
        xor cx, cx
        mov dx, errf
        int 0x21
        jc q
        mov bx, ax
        ; dup2: handle 2 -> bx
        mov cx, 2
        mov ah, 0x46
        int 0x21
        ; close original
        mov ah, 0x3E
        int 0x21
        ; NOW write to stderr (handle 2) — should land in ERR.LOG
        mov ah, 0x40
        mov bx, 2
        mov cx, m_len
        mov dx, msg
        int 0x21
q:      mov ah, 0x4C
        mov al, 0
        int 0x21
errf:   db "ERR.LOG", 0
msg:    db "DUP2 OK", 0x0D, 0x0A
m_len equ $ - msg
