.586
.model small
.code

;include seh.inc

org 0

perthread struct
    _eip    dd ?
    _nxt    dd ?
    union
    _eax    dd ?
    _ax     dw ?
    struct
    _al     db ?
    _ah     db ?
    ends
    ends
    union
    _ecx    dd ?
    _cx     dw ?
    struct
    _cl     db ?
    _ch     db ?
    ends
    ends
    union
    _edx    dd ?
    _dx     dw ?
    struct
    _dl     db ?
    _dh     db ?
    ends
    ends
    union
    _esp    dd ?
    _sp     dw ?
    ends
    union
    _esi    dd ?
    _si     dw ?
    ends
    union
    _edi    dd ?
    _di     dw ?
    ends
    _flags  dd ?
    _tmp    dd ?
    _ticks  dd ?
    _ccb    dd ?
    _epilog db 6 dup (?)
    _jback  db 6 dup (?)
    _back   dd ?
    union
    _ebx    dd ?
    _bx     dw ?
    struct
    _bl     db ?
    _bh     db ?
    ends
    ends
    _prolog db 3 dup (?)
    _insn   db 15 dup (?)
    _jup    db 2 dup (?)
perthread ends

MSG_FAR_JMP  EQU 0
MSG_UNK_INSN EQU 1

public @pop_run@4
public @run@4

@pop_run@4:
    lea     esp, [esp + 4]              ; discard return addr.
@run@4:
    ; __fastcall passes first args in ecx, edx

    assume ecx:ptr perthread

    mov     [ecx]._eax, eax
    mov     [ecx]._ebx, ebx
    mov     [ecx]._esi, esi
    mov     [ecx]._edi, edi
    mov     ebx, ecx

    assume ecx:nothing
    assume ebx:ptr perthread

    ; initial dynamic code setup
    mov     dword ptr [ebx]._prolog, 00fc5b87h ; xchg ebx, [ebx - 4]
                                               ; ebx - 4 -> _ebx
   ;mov     dword ptr [ebx]._nops, 90909090h
   ;mov     dword ptr [ebx + 4]._nops, 90909090h
   ;mov     dword ptr [ebx + 8]._nops, 90909090h
   ;mov     word ptr [ebx + 12]._nops, 9090h

    mov     word ptr [ebx]._epilog, 1d87h ; xchg ebx, [perthread._ebx]
    lea     eax, [ebx]._ebx
    mov     dword ptr [ebx + 2]._epilog, eax

    mov     word ptr [ebx]._jback, 25ffh ; jmp [perthread._back]
    lea     eax, [ebx]._back
    mov     dword ptr [ebx + 2]._jback, eax
    mov     dword ptr [eax], back

    mov     esi, [ebx]._eip
    jmp     insnloop

back:

    ; the usual follow-up after executing an insn copy
    ; or upon reentering user-mode from kernel

    lea     ebx, [ebx - perthread._prolog] ; ebx set in epilogue
    mov     [ebx]._eax, eax
    mov     [ebx]._ecx, ecx
    mov     [ebx]._esi, esi
    mov     [ebx]._edi, edi
    mov     esi, [ebx]._nxt             ; next virtual eip
    mov     [ebx]._eip, esi
    jmp     insnloop

; upon entering insnloop, the state of registers is as follows:
; eax: scratch (used e.g. to store opcode bytes)
; ebx: ptr to perthread context struct
; ecx: cl = prefix count; ch = 0/1 depending on 67 prefix
; edx: same as target
; esi: virtual eip
; edi: opcode dispatch table / scratch
; ebp: same as target
; esp: same as target
; flags: same as target

up6:
    lea     esi, [esi + 1]
up5:
    lea     esi, [esi + 2]
up3:
    lea     esi, [esi + 1]
up2:
    lea     esi, [esi + 1]
up1:
    lea     esi, [esi + 1]

store_eip:
    mov     [ebx]._eip, esi

insnloop:
    mov     eax, [ebx]._ticks
    lea     eax, [eax + 1]
    mov     [ebx]._ticks, eax

    mov     ecx, 0
    mov     edi, one_byte_opc32
    movzx   eax, byte ptr [esi]
    jmp     dword ptr [edi + eax * 4]

;------------------------------------------------------------------------------

stack_switch macro
    mov     [ebx]._esp, esp
    mov     esp, ebx
endm

rstor_stack macro
    mov     ebx, esp
    mov     esp, [ebx]._esp
endm

;------------------------------------------------------------------------------

save_flags macro
    xchg    eax, esp
    lea     esp, [ebx + 4]._flags
    pushfd
    pop     esp
    xchg    eax, esp
endm

rstor_flags macro
    xchg    eax, esp
    lea     esp, [ebx]._flags
    popfd
    xchg    eax, esp
endm

laxf macro
    lahf
    setno   al                          ; al = !ovf
endm

saxf macro
    dec     al                          ; ovf = !al
    sahf
endm

;------------------------------------------------------------------------------

push_eax:
    push    [ebx]._eax
    jmp     up1

push_ebx:
    push    [ebx]._ebx
    jmp     up1

push_ecx:
    push    [ebx]._ecx
    jmp     up1

push_edx:
    push    edx
    jmp     up1

push_esi:
    push    [ebx]._esi
    jmp     up1

push_edi:
    push    [ebx]._edi
    jmp     up1

push_esp:
    push    esp
    jmp     up1

push_ebp:
    push    ebp
    jmp     up1

pop_eax:
    pop     [ebx]._eax
    jmp     up1

pop_ebx:
    pop     [ebx]._ebx
    jmp     up1

pop_ecx:
    pop     [ebx]._ecx
    jmp     up1

pop_edx:
    pop     edx
    jmp     up1

pop_esi:
    pop     [ebx]._esi
    jmp     up1

pop_edi:
    pop     [ebx]._edi
    jmp     up1

pop_esp:
    pop     esp
    jmp     up1

pop_ebp:
    pop     ebp
    jmp     up1

;------------------------------------------------------------------------------

_pushad:
    mov     eax, esp
    push    [ebx]._eax
    push    [ebx]._ecx
    push    edx
    push    [ebx]._ebx
    push    eax
    push    ebp
    push    [ebx]._esi
    push    [ebx]._edi
    jmp     up1

_popad:
    pop     [ebx]._edi
    pop     [ebx]._esi
    pop     ebp
    pop     eax
    pop     [ebx]._ebx
    pop     edx
    pop     [ebx]._ecx
    pop     [ebx]._eax
    jmp     up1

;------------------------------------------------------------------------------

push_ib:
    movsx   eax, byte ptr [esi + 1]
    push    eax
    jmp     up2

push_id:
    push    dword ptr [esi + 1]
    jmp     up5

;------------------------------------------------------------------------------

inc_eax:
    inc     [ebx]._eax
    jmp     up1

inc_ebx:
    inc     [ebx]._ebx
    jmp     up1

inc_ecx:
    inc     [ebx]._ecx
    jmp     up1

inc_edx:
    inc     edx
    jmp     up1

inc_esi:
    inc     [ebx]._esi
    jmp     up1

inc_edi:
    inc     [ebx]._edi
    jmp     up1

inc_esp:
    inc     esp
    jmp     up1

inc_ebp:
    inc     ebp
    jmp     up1

dec_eax:
    dec     [ebx]._eax
    jmp     up1

dec_ebx:
    dec     [ebx]._ebx
    jmp     up1

dec_ecx:
    dec     [ebx]._ecx
    jmp     up1

dec_edx:
    dec     edx
    jmp     up1

dec_esi:
    dec     [ebx]._esi
    jmp     up1

dec_edi:
    dec     [ebx]._edi
    jmp     up1

dec_esp:
    dec     esp
    jmp     up1

dec_ebp:
    dec     ebp
    jmp     up1

;------------------------------------------------------------------------------

inc_ax:
    inc     [ebx]._ax
    jmp     up1

inc_bx:
    inc     [ebx]._bx
    jmp     up1

inc_cx:
    inc     [ebx]._cx
    jmp     up1

inc_dx:
    inc     dx
    jmp     up1

inc_si:
    inc     [ebx]._si
    jmp     up1

inc_di:
    inc     [ebx]._di
    jmp     up1

inc_sp:
    inc     sp
    jmp     up1

inc_bp:
    inc     bp
    jmp     up1

dec_ax:
    dec     [ebx]._ax
    jmp     up1

dec_bx:
    dec     [ebx]._bx
    jmp     up1

dec_cx:
    dec     [ebx]._cx
    jmp     up1

dec_dx:
    dec     dx
    jmp     up1

dec_si:
    dec     [ebx]._si
    jmp     up1

dec_di:
    dec     [ebx]._di
    jmp     up1

dec_sp:
    dec     sp
    jmp     up1

dec_bp:
    dec     bp
    jmp     up1

;------------------------------------------------------------------------------

orm:
    mov     edi, 1
    mov     eax, 1

calc_sz:

    ; al = ilen not counting prfxs or eff. addr.
    ; eax & ffffff00 = 0
    ; cl = # of prfxs
    ; ch = 0/1 depending on 67 prefix
    ; ecx & ffff0000 = 0
    ; edi = offset of reg/rm relative to first opc byte

    mov     [ebx]._edx, edx             ; free edx
    xchg    eax, edx                    ; edx = 000000<ilen>

    movzx   eax, byte ptr [esi + edi]   ; load reg/rm
    xchg    dh, cl                      ; dh = prfx cnt; cl = 0
                                        ; ecx = 0/256 depending on 67 prfx
    movzx   eax, byte ptr [regrm_sz + ecx + eax] ; sz or 0 if sib

    lea     eax, [eax + 1]              ; inc by 1 because loop dec's by 1
    xchg    eax, ecx
    loop    @F

    movzx   ecx, byte ptr [esi + edi + 1] ; load sib
    movzx   ecx, byte ptr [sib_sz + ecx]
@@:
    movzx   edi, dh                     ; edi = prfx cnt
    mov     dh, 0
    lea     ecx, [ecx + edx]            ; ecx = ilen + eff.addr. sz
    lea     edx, [ebx]._nxt

exec_insn_copy:

    ; ecx = # of bytes to copy
    ; edx = & of next virtual eip
    ; edi = offset in insn buffer

    lea     edi, [ebx + edi]._insn

copy_to_edi:

    ; ecx = # of bytes to copy
    ; edx = & of next virtual eip
    ; edi = destination

   ;rep     movsb                       ; can't use, direction unknown!

@@:
    mov     al, [esi]
    mov     [edi], al
    lea     esi, [esi + 1]
    lea     edi, [edi + 1]
    loop    @B


insn_copied:

    ; edx = & of next virtual eip
    ; edi = destination of jmp to epilogue

    mov     [edx], esi                  ; [_nxt] = next virtual eip

    ; follow up insn copy with a jmp to epilogue

    mov     byte ptr [edi], 0ebh
    not     edi
    lea     ecx, [ebx + perthread._epilog + edi - 1]
    not     edi
    mov     [edi + 1], cl

    mov     edx, [ebx]._edx


exec: ; edx same as target

    mov     eax, [ebx]._eax             ; restore scratch regs (except ebx)
    mov     ecx, [ebx]._ecx
    mov     esi, [ebx]._esi
    mov     edi, [ebx]._edi
    lea     ebx, [ebx]._prolog
    jmp     ebx

;------------------------------------------------------------------------------

jo_jb:
    jo      @F
    jmp     up2

jno_jb:
    jno     @F
    jmp     up2

jb_jb:
    jb      @F
    jmp     up2

jnb_jb:
    jnb     @F
    jmp     up2

jz_jb:
    jz      @F
    jmp     up2

jnz_jb:
    jnz     @F
    jmp     up2

jbe_jb:
    jbe     @F
    jmp     up2

ja_jb:
    ja      @F
    jmp     up2

js_jb:
    js      @F
    jmp     up2

jns_jb:
    jns     @F
    jmp     up2

jpe_jb:
    jpe     @F
    jmp     up2

jpo_jb:
    jpo     @F
    jmp     up2

jl_jb:
    jl      @F
    jmp     up2

jnl_jb:
    jnl     @F
    jmp     up2

jle_jb:
    jle     @F
    jmp     up2

jg_jb:
    jle     up2
@@:
    movsx   eax, byte ptr [esi + 1]
    lea     esi, [esi + eax + 2]
    jmp     store_eip

;------------------------------------------------------------------------------

jo_jz:
    jo      @F
    jmp     up6

jno_jz:
    jno     @F
    jmp     up6

jb_jz:
    jb      @F
    jmp     up6

jnb_jz:
    jnb     @F
    jmp     up6

jz_jz:
    jz      @F
    jmp     up6

jnz_jz:
    jnz     @F
    jmp     up6

jbe_jz:
    jbe     @F
    jmp     up6

ja_jz:
    ja      @F
    jmp     up6

js_jz:
    js      @F
    jmp     up6

jns_jz:
    jns     @F
    jmp     up6

jpe_jz:
    jpe     @F
    jmp     up6

jpo_jz:
    jpo     @F
    jmp     up6

jl_jz:
    jl      @F
    jmp     up6

jnl_jz:
    jnl     @F
    jmp     up6

jle_jz:
    jle     @F
    jmp     up6

jg_jz:
    jle     up6
@@:
    mov     eax, [esi + 2]
    lea     esi, [esi + eax + 6]
    jmp     store_eip

;------------------------------------------------------------------------------

call_jd:
    mov     eax, [esi + 1]
    lea     esi, [esi + 5]
    push    esi
    lea     esi, [esi + eax]
    jmp     store_eip

jmp_jd:
    mov     eax, [esi + 1]
    lea     esi, [esi + eax + 5]
    jmp     store_eip

jmp_jb:
    movsx   eax, byte ptr [esi + 1]
    lea     esi, [esi + eax + 2]
    jmp     store_eip

_loop:
    mov     ecx, [ebx]._ecx
    loop    @F
    mov     [ebx]._ecx, ecx
    jmp     up2
@@:
    mov     [ebx]._ecx, ecx
    movsx   eax, byte ptr [esi + 1]
    lea     esi, [esi + eax + 2]
    jmp     store_eip

;------------------------------------------------------------------------------

call_ed:
    mov     [ebx]._edx, edx
    mov     [ebx]._back, do_call

decod_ea:
    movzx   eax, byte ptr [esi + 1]     ; load reg/rm
    movzx   edx, cl                     ; edx = prfx cnt
    mov     cl, 0                       ; ecx = 0/256 depending on 67
    movzx   ecx, byte ptr [regrm_sz + ecx + eax]
    lea     ecx, [ecx + 1]
    loop    @F
    movzx   ecx, byte ptr [esi + 2]     ; load sib
    movzx   ecx, byte ptr [sib_sz + ecx]
@@:

    lea     edi, [ebx + edx + 2]._insn
    mov     byte ptr [edi - 2], 8bh     ; mov gd, ed
    movzx   eax, byte ptr [esi + 1]
    mov     al, byte ptr [zap_mid3 + eax]
    mov     [edi - 1], al               ; mov eax, ed

    lea     esi, [esi + 2]              ; skip ffxx
    lea     edx, [ebx]._nxt             ; &next virtual eip
    lea     ecx, [ecx - 1]              ; copy tail eff. addr. bytes
    jecxz   @F
    jmp     copy_to_edi
@@:
    jmp     insn_copied

do_call:
    lea     ebx, [ebx - perthread._prolog]
    mov     [ebx]._back, back
    push    [ebx]._nxt
    mov     esi, eax
    jmp     store_eip

;------------------------------------------------------------------------------

jmp_ed:
    mov     [ebx]._edx, edx
    mov     [ebx]._back, do_jmp
    jmp     decod_ea

do_jmp:
    lea     ebx, [ebx - perthread._prolog]
    mov     [ebx]._back, back
    mov     esi, eax
    jmp     store_eip

;------------------------------------------------------------------------------

_leave:
    mov     esp, ebp
    pop     ebp
    jmp     up1

_ret:
    pop     esi
    jmp     store_eip

ret_iw:
    movzx   eax, word ptr [esi + 1]
    pop     esi
    lea     esp, [esp + eax]
    jmp     store_eip

;------------------------------------------------------------------------------

mov_ov:
    movzx   edi, cl
    movzx   ecx, ch
    loop    @F
    mov     cl, 3
    jmp     copy_n
@@:
    mov     ecx, 5
    jmp     copy_n

;------------------------------------------------------------------------------

_f6:
    lea     edi, [edi + (f6_grp32 - one_byte_opc32)]
    jmp     grp_dispatch

_f7:
    lea     edi, [edi + (f7_grp32 - one_byte_opc32)]
    jmp     grp_dispatch

_ff:
   ;lea     ecx, [ecx + ff_grp32 - one_byte_opc32]  ; masm bug?
    lea     edi, [edi + (ff_grp32 - one_byte_opc32)]
   ;jmp     grp_dispatch

   ; WARNING fall-through

grp_dispatch:
    movzx   eax, byte ptr [esi + 1]     ; load reg/rm
    lea     eax, [eax * 4]              ; shl eax, 2
    mov     ah, 0                       ; chop off mod bits
    lea     eax, [eax * 8]              ; shl eax, 3
    movzx   eax, ah                     ; keep just opc bits

    jmp     dword ptr [edi + eax * 4]

_66_ff38:
    mov     edi, ecx
    movzx   ecx, word ptr [esi]
    lea     ecx, [ecx - 7affh]          ; ff 'z'
    jecxz   @F
    mov     ecx, edi
    jmp     orm
@@:
    mov     ecx, dword ptr [ebx]._insn
    lea     ecx, [ecx - 66f0f2f3h]      ; f3 f2 f0 66 ff 'z'
    jecxz   @F
    mov     ecx, edi
    jmp     orm
@@:
    ; resume native execution

    mov     word ptr [ebx]._insn, 25ffh ; jmp [$+6]
    lea     eax, [ebx + 6]._insn
    mov     dword ptr [ebx + 2]._insn, eax
    lea     esi, [esi + 2]              ; skip ff 'z'
    mov     dword ptr [ebx + 6]._insn, esi
    jmp     exec

;------------------------------------------------------------------------------

ormi:
    mov     edi, 1
    mov     eax, 2
    jmp     calc_sz

oormi:
    mov     edi, 2
    mov     eax, 3
    jmp     calc_sz

ormii:
    mov     edi, 1
    mov     eax, 3
    jmp     calc_sz

ormiiii:
    mov     edi, 1
    mov     eax, 5
    jmp     calc_sz

;------------------------------------------------------------------------------

copy5:
    movzx   edi, cl
    mov     ecx, 5
copy_n:
    mov     [ebx]._edx, edx
    lea     edx, [ebx]._nxt             ; & of next virtual eip
    jmp     exec_insn_copy

;------------------------------------------------------------------------------

copy1:
    movzx   edi, cl
    mov     ecx, 1
    jmp     copy_n

copy2:
    movzx   edi, cl
    mov     ecx, 2
    jmp     copy_n

copy3:
    movzx   edi, cl
    mov     ecx, 3
    jmp     copy_n

copy4:
    movzx   edi, cl
    mov     ecx, 4
    jmp     copy_n

;------------------------------------------------------------------------------

add_al_ib:
    mov     al, [esi + 1]
    add     [ebx]._al, al
    jmp     up2

adc_al_ib:
    mov     al, [esi + 1]
    adc     [ebx]._al, al
    jmp     up2

and_al_ib:
    mov     al, [esi + 1]
    and     [ebx]._al, al
    jmp     up2

xor_al_ib:
    mov     al, [esi + 1]
    xor     [ebx]._al, al
    jmp     up2

or_al_ib:
    mov     al, [esi + 1]
    or      [ebx]._al, al
    jmp     up2

sbb_al_ib:
    mov     al, [esi + 1]
    sbb     [ebx]._al, al
    jmp     up2

sub_al_ib:
    mov     al, [esi + 1]
    sub     [ebx]._al, al
    jmp     up2

cmp_al_ib:
    mov     al, [esi + 1]
    cmp     [ebx]._al, al
    jmp     up2

;------------------------------------------------------------------------------

add_ax_iw:
    mov     ax, [esi + 1]
    add     [ebx]._ax, ax
    jmp     up3

adc_ax_iw:
    mov     ax, [esi + 1]
    adc     [ebx]._ax, ax
    jmp     up3

and_ax_iw:
    mov     ax, [esi + 1]
    and     [ebx]._ax, ax
    jmp     up3

xor_ax_iw:
    mov     ax, [esi + 1]
    xor     [ebx]._ax, ax
    jmp     up3

or_ax_iw:
    mov     ax, [esi + 1]
    or      [ebx]._ax, ax
    jmp     up3

sbb_ax_iw:
    mov     ax, [esi + 1]
    sbb     [ebx]._ax, ax
    jmp     up3

sub_ax_iw:
    mov     ax, [esi + 1]
    sub     [ebx]._ax, ax
    jmp     up3

cmp_ax_iw:
    mov     ax, [esi + 1]
    cmp     [ebx]._ax, ax
    jmp     up3

;------------------------------------------------------------------------------

add_eax_id:
    mov     eax, [esi + 1]
    add     [ebx]._eax, eax
    jmp     up5

adc_eax_id:
    mov     eax, [esi + 1]
    adc     [ebx]._eax, eax
    jmp     up5

and_eax_id:
    mov     eax, [esi + 1]
    and     [ebx]._eax, eax
    jmp     up5

xor_eax_id:
    mov     eax, [esi + 1]
    xor     [ebx]._eax, eax
    jmp     up5

or_eax_id:
    mov     eax, [esi + 1]
    or      [ebx]._eax, eax
    jmp     up5

sbb_eax_id:
    mov     eax, [esi + 1]
    sbb     [ebx]._eax, eax
    jmp     up5

sub_eax_id:
    mov     eax, [esi + 1]
    sub     [ebx]._eax, eax
    jmp     up5

cmp_eax_id:
    mov     eax, [esi + 1]
    cmp     [ebx]._eax, eax
    jmp     up5

;------------------------------------------------------------------------------

mov_al_ib:
    mov     al, [esi + 1]
    mov     [ebx]._al, al
    jmp     up2

mov_bl_ib:
    mov     al, [esi + 1]
    mov     [ebx]._bl, al
    jmp     up2

mov_cl_ib:
    mov     al, [esi + 1]
    mov     [ebx]._cl, al
    jmp     up2

mov_dl_ib:
    mov     dl, [esi + 1]
    jmp     up2

mov_ah_ib:
    mov     al, [esi + 1]
    mov     [ebx]._ah, al
    jmp     up2

mov_bh_ib:
    mov     al, [esi + 1]
    mov     [ebx]._bh, al
    jmp     up2

mov_ch_ib:
    mov     al, [esi + 1]
    mov     [ebx]._ch, al
    jmp     up2

mov_dh_ib:
    mov     dh, [esi + 1]
    jmp     up2

;------------------------------------------------------------------------------

mov_ax_iw:
    mov     ax, [esi + 1]
    mov     [ebx]._ax, ax
    jmp     up3

mov_bx_iw:
    mov     ax, [esi + 1]
    mov     [ebx]._bx, ax
    jmp     up3

mov_cx_iw:
    mov     ax, [esi + 1]
    mov     [ebx]._cx, ax
    jmp     up3

mov_dx_iw:
    mov     dx, [esi + 1]
    jmp     up3

mov_sp_iw:
    mov     sp, [esi + 1]
    jmp     up3

mov_bp_iw:
    mov     bp, [esi + 1]
    jmp     up3

mov_si_iw:
    mov     ax, [esi + 1]
    mov     [ebx]._si, ax
    jmp     up3

mov_di_iw:
    mov     ax, [esi + 1]
    mov     [ebx]._di, ax
    jmp     up3

;------------------------------------------------------------------------------

mov_eax_id:
    mov     eax, [esi + 1]
    mov     [ebx]._eax, eax
    jmp     up5

mov_ebx_id:
    mov     eax, [esi + 1]
    mov     [ebx]._ebx, eax
    jmp     up5

mov_ecx_id:
    mov     eax, [esi + 1]
    mov     [ebx]._ecx, eax
    jmp     up5

mov_edx_id:
    mov     edx, [esi + 1]
    jmp     up5

mov_esp_id:
    mov     esp, [esi + 1]
    jmp     up5

mov_ebp_id:
    mov     ebp, [esi + 1]
    jmp     up5

mov_esi_id:
    mov     eax, [esi + 1]
    mov     [ebx]._esi, eax
    jmp     up5

mov_edi_id:
    mov     eax, [esi + 1]
    mov     [ebx]._edi, eax
    jmp     up5

;------------------------------------------------------------------------------

test_al_ib:
    mov     al, [esi + 1]
    test    [ebx]._al, al
    jmp     up2

test_ax_iw:
    mov     ax, [esi + 1]
    test    [ebx]._ax, ax
    jmp     up3

test_eax_id:
    mov     eax, [esi + 1]
    test    [ebx]._eax, eax
    jmp     up5

;------------------------------------------------------------------------------

_0f:
    movzx   eax, byte ptr [esi + 1]
    jmp     dword ptr [edi + 256 * 4 + eax * 4]

;------------------------------------------------------------------------------

oorm:
    mov     edi, 2  ; offset of reg/rm relative to first opc byte
    mov     eax, 2
    jmp     calc_sz

;------------------------------------------------------------------------------

_clc:
    clc
    jmp     up1

_stc:
    stc
    jmp     up1

_cmc:
    cmc
    jmp     up1

_cli:
    cli
    jmp     up1

_sti:
    sti
    jmp     up1

_cld:
    cld
    jmp     up1

_std:
    std
    jmp     up1

_hlt:
    hlt
    jmp     up1

;------------------------------------------------------------------------------

xchg_eax_ebx:
    mov     eax, [ebx]._eax
    xchg    eax, [ebx]._ebx
    mov     [ebx]._eax, eax
    jmp     up1

xchg_eax_ecx:
    mov     eax, [ebx]._eax
    xchg    eax, [ebx]._ecx
    mov     [ebx]._eax, eax
    jmp     up1

xchg_eax_edx:
    xchg    edx, [ebx]._eax
    jmp     up1

xchg_eax_esp:
    xchg    esp, [ebx]._eax
    jmp     up1

xchg_eax_ebp:
    xchg    ebp, [ebx]._eax
    jmp     up1

xchg_eax_esi:
    mov     eax, [ebx]._eax
    xchg    eax, [ebx]._esi
    mov     [ebx]._eax, eax
    jmp     up1

xchg_eax_edi:
    mov     eax, [ebx]._eax
    xchg    eax, [ebx]._edi
    mov     [ebx]._eax, eax
    jmp     up1

;------------------------------------------------------------------------------

_cwde:
    movsx   eax, [ebx]._ax
    mov     [ebx]._eax, eax
    jmp     up1

_cdq:
    mov     eax, [ebx]._eax
    cdq
    jmp     up1

;------------------------------------------------------------------------------

_pushfd:
    pushfd
    jmp     up1

_popfd:                                 ; TODO check trap flag
    popfd
    jmp     up1

;------------------------------------------------------------------------------

_66:
    movzx   edi, cl
    mov     [ebx + edi]._insn, al
    lea     ecx, [ecx + 1]
    lea     esi, [esi + 1]
    mov     edi, one_byte_opc16
    movzx   eax, byte ptr [esi]
    jmp     dword ptr [edi + eax * 4]

;------------------------------------------------------------------------------

_67:
    mov     ch, 1

prfx:
    mov     ah, ch
    movzx   ecx, cl
    mov     [ebx + ecx]._insn, al
    mov     ch, ah
    lea     ecx, [ecx + 1]
    lea     esi, [esi + 1]
    movzx   eax, byte ptr [esi]
    jmp     dword ptr [edi + eax * 4]

;------------------------------------------------------------------------------

far_jmp:
   ;int 3

    stack_switch
    pushf
    pusha

    mov     ecx, ebx
    mov     edx, MSG_FAR_JMP
    call    [ebx]._ccb

    popa
    popf
    rstor_stack

    mov     [ebx]._edx, edx
    lea     edx, [ebx]._tmp             ; discard next virtual eip
    movzx   edi, cl
    mov     ecx, 7
    jmp     exec_insn_copy

;------------------------------------------------------------------------------


bswap_eax:
    mov     eax, [ebx]._eax
    bswap   eax
    mov     [ebx]._eax, eax
    jmp     up2

bswap_ebx:
    mov     eax, [ebx]._ebx
    bswap   eax
    mov     [ebx]._ebx, eax
    jmp     up2

bswap_ecx:
    mov     eax, [ebx]._ecx
    bswap   eax
    mov     [ebx]._ecx, eax
    jmp     up2

bswap_edx:
    bswap   edx
    jmp     up2

bswap_esp:
    bswap   esp
    jmp     up2

bswap_ebp:
    bswap   ebp
    jmp     up2

bswap_esi:
    mov     eax, [ebx]._esi
    bswap   eax
    mov     [ebx]._esi, eax
    jmp     up2

bswap_edi:
    mov     eax, [ebx]._edi
    bswap   eax
    mov     [ebx]._edi, eax
    jmp     up2

;------------------------------------------------------------------------------

_rdtsc:
   ;mov     eax, [ebx]._ticks
   ;mov     [ebx]._eax, eax
    mov     [ebx]._eax, 1234
    mov     [ebx]._edx, 5678
    jmp     up2
   ;jmp     copy2

;------------------------------------------------------------------------------

SIB EQU 0

regrm_sz:

    ; 32-bit reg/rm

    db 1, 1, 1, 1, SIB, 5, 1, 1
    db 1, 1, 1, 1, SIB, 5, 1, 1
    db 1, 1, 1, 1, SIB, 5, 1, 1
    db 1, 1, 1, 1, SIB, 5, 1, 1
    db 1, 1, 1, 1, SIB, 5, 1, 1
    db 1, 1, 1, 1, SIB, 5, 1, 1
    db 1, 1, 1, 1, SIB, 5, 1, 1
    db 1, 1, 1, 1, SIB, 5, 1, 1

    db 2, 2, 2, 2, 3, 2, 2, 2
    db 2, 2, 2, 2, 3, 2, 2, 2
    db 2, 2, 2, 2, 3, 2, 2, 2
    db 2, 2, 2, 2, 3, 2, 2, 2
    db 2, 2, 2, 2, 3, 2, 2, 2
    db 2, 2, 2, 2, 3, 2, 2, 2
    db 2, 2, 2, 2, 3, 2, 2, 2
    db 2, 2, 2, 2, 3, 2, 2, 2

    db 5, 5, 5, 5, 6, 5, 5, 5
    db 5, 5, 5, 5, 6, 5, 5, 5
    db 5, 5, 5, 5, 6, 5, 5, 5
    db 5, 5, 5, 5, 6, 5, 5, 5
    db 5, 5, 5, 5, 6, 5, 5, 5
    db 5, 5, 5, 5, 6, 5, 5, 5
    db 5, 5, 5, 5, 6, 5, 5, 5
    db 5, 5, 5, 5, 6, 5, 5, 5

    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1

    ; 16-bit reg/rm

    db 1, 1, 1, 1, 1, 1, 2, 1
    db 1, 1, 1, 1, 1, 1, 2, 1
    db 1, 1, 1, 1, 1, 1, 2, 1
    db 1, 1, 1, 1, 1, 1, 2, 1
    db 1, 1, 1, 1, 1, 1, 2, 1
    db 1, 1, 1, 1, 1, 1, 2, 1
    db 1, 1, 1, 1, 1, 1, 2, 1
    db 1, 1, 1, 1, 1, 1, 2, 1

    db 2, 2, 2, 2, 2, 2, 2, 2
    db 2, 2, 2, 2, 2, 2, 2, 2
    db 2, 2, 2, 2, 2, 2, 2, 2
    db 2, 2, 2, 2, 2, 2, 2, 2
    db 2, 2, 2, 2, 2, 2, 2, 2
    db 2, 2, 2, 2, 2, 2, 2, 2
    db 2, 2, 2, 2, 2, 2, 2, 2
    db 2, 2, 2, 2, 2, 2, 2, 2

    db 3, 3, 3, 3, 3, 3, 3, 3
    db 3, 3, 3, 3, 3, 3, 3, 3
    db 3, 3, 3, 3, 3, 3, 3, 3
    db 3, 3, 3, 3, 3, 3, 3, 3
    db 3, 3, 3, 3, 3, 3, 3, 3
    db 3, 3, 3, 3, 3, 3, 3, 3
    db 3, 3, 3, 3, 3, 3, 3, 3
    db 3, 3, 3, 3, 3, 3, 3, 3

    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1
    db 1, 1, 1, 1, 1, 1, 1, 1

sib_sz:
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2

    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2

    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2

    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2
    db 2, 2, 2, 2, 2, 6, 2, 2

one_byte_opc32:
    dd orm  ; 00
    dd orm  ; 01
    dd orm  ; 02
    dd orm  ; 03
    dd add_al_ib  ; 04
    dd add_eax_id  ; 05
    dd unk  ; 06
    dd unk  ; 07
    dd orm  ; 08
    dd orm  ; 09
    dd orm  ; 0a
    dd orm  ; 0b
    dd or_al_ib  ; 0c
    dd or_eax_id  ; 0d
    dd unk  ; 0e
    dd _0f  ; 0f
    dd orm  ; 10
    dd orm  ; 11
    dd orm  ; 12
    dd orm  ; 13
    dd adc_al_ib  ; 14
    dd adc_eax_id  ; 15
    dd unk  ; 16
    dd unk  ; 17
    dd orm  ; 18
    dd orm  ; 19
    dd orm  ; 1a
    dd orm  ; 1b
    dd sbb_al_ib  ; 1c
    dd sbb_eax_id  ; 1d
    dd unk  ; 1e
    dd unk  ; 1f
    dd orm  ; 20
    dd orm  ; 21
    dd orm  ; 22
    dd orm  ; 23
    dd and_al_ib  ; 24
    dd and_eax_id  ; 25
    dd prfx  ; 26
    dd unk  ; 27
    dd orm  ; 28
    dd orm  ; 29
    dd orm  ; 2a
    dd orm  ; 2b
    dd sub_al_ib  ; 2c
    dd sub_eax_id  ; 2d
    dd prfx  ; 2e
    dd unk  ; 2f
    dd orm  ; 30
    dd orm  ; 31
    dd orm  ; 32
    dd orm  ; 33
    dd xor_al_ib  ; 34
    dd xor_eax_id  ; 35
    dd prfx  ; 36
    dd unk  ; 37
    dd orm  ; 38
    dd orm  ; 39
    dd orm  ; 3a
    dd orm  ; 3b
    dd cmp_al_ib  ; 3c
    dd cmp_eax_id  ; 3d
    dd prfx  ; 3e
    dd unk  ; 3f
    dd inc_eax  ; 40
    dd inc_ecx  ; 41
    dd inc_edx  ; 42
    dd inc_ebx  ; 43
    dd inc_esp  ; 44
    dd inc_ebp  ; 45
    dd inc_esi  ; 46
    dd inc_edi  ; 47
    dd dec_eax  ; 48
    dd dec_ecx  ; 49
    dd dec_edx  ; 4a
    dd dec_ebx  ; 4b
    dd dec_esp  ; 4c
    dd dec_ebp  ; 4d
    dd dec_esi  ; 4e
    dd dec_edi  ; 4f
    dd push_eax  ; 50
    dd push_ecx  ; 51
    dd push_edx  ; 52
    dd push_ebx  ; 53
    dd push_esp  ; 54
    dd push_ebp  ; 55
    dd push_esi  ; 56
    dd push_edi  ; 57
    dd pop_eax  ; 58
    dd pop_ecx  ; 59
    dd pop_edx  ; 5a
    dd pop_ebx  ; 5b
    dd pop_esp  ; 5c
    dd pop_ebp  ; 5d
    dd pop_esi  ; 5e
    dd pop_edi  ; 5f
    dd _pushad  ; 60
    dd _popad  ; 61
    dd unk  ; 62
    dd unk  ; 63
    dd prfx  ; 64
    dd prfx  ; 65
    dd _66  ; 66
    dd _67  ; 67
    dd push_id  ; 68
    dd ormiiii  ; 69
    dd push_ib  ; 6a
    dd ormi  ; 6b
    dd unk  ; 6c
    dd unk  ; 6d
    dd unk  ; 6e
    dd unk  ; 6f
    dd jo_jb   ; 70
    dd jno_jb  ; 71
    dd jb_jb   ; 72
    dd jnb_jb  ; 73
    dd jz_jb   ; 74
    dd jnz_jb  ; 75
    dd jbe_jb  ; 76
    dd ja_jb   ; 77
    dd js_jb   ; 78
    dd jns_jb  ; 79
    dd jpe_jb  ; 7a
    dd jpo_jb  ; 7b
    dd jl_jb   ; 7c
    dd jnl_jb  ; 7d
    dd jle_jb  ; 7e
    dd jg_jb   ; 7f
    dd ormi    ; 80
    dd ormiiii ; 81
    dd ormi    ; 82
    dd ormi    ; 83
    dd orm  ; 84
    dd orm  ; 85
    dd orm  ; 86
    dd orm  ; 87
    dd orm  ; 88
    dd orm  ; 89
    dd orm  ; 8a
    dd orm  ; 8b
    dd orm  ; 8c
    dd orm  ; 8d
    dd orm  ; 8e
    dd orm  ; 8f
    dd up1  ; 90
    dd xchg_eax_ecx  ; 91
    dd xchg_eax_edx  ; 92
    dd xchg_eax_ebx  ; 93
    dd xchg_eax_esp  ; 94
    dd xchg_eax_ebp  ; 95
    dd xchg_eax_esi  ; 96
    dd xchg_eax_edi  ; 97
    dd _cwde  ; 98
    dd _cdq   ; 99
    dd unk  ; 9a
    dd copy1  ; 9b
    dd _pushfd  ; 9c
    dd _popfd  ; 9d
    dd unk  ; 9e
    dd unk  ; 9f
    dd mov_ov  ; a0
    dd mov_ov  ; a1
    dd mov_ov  ; a2
    dd mov_ov  ; a3
    dd copy1  ; a4
    dd copy1  ; a5
    dd copy1  ; a6
    dd copy1  ; a7
    dd test_al_ib  ; a8
    dd test_eax_id  ; a9
    dd copy1  ; aa
    dd copy1  ; ab
    dd copy1  ; ac
    dd copy1  ; ad
    dd copy1  ; ae
    dd copy1  ; af
    dd mov_al_ib  ; b0
    dd mov_cl_ib  ; b1
    dd mov_dl_ib  ; b2
    dd mov_bl_ib  ; b3
    dd mov_ah_ib  ; b4
    dd mov_ch_ib  ; b5
    dd mov_dh_ib  ; b6
    dd mov_bh_ib  ; b7
    dd mov_eax_id ; b8
    dd mov_ecx_id ; b9
    dd mov_edx_id ; ba
    dd mov_ebx_id ; bb
    dd mov_esp_id ; bc
    dd mov_ebp_id ; bd
    dd mov_esi_id ; be
    dd mov_edi_id ; bf
    dd ormi  ; c0
    dd ormi  ; c1
    dd ret_iw ; c2
    dd _ret   ; c3
    dd unk  ; c4
    dd unk  ; c5
    dd ormi  ; c6
    dd ormiiii  ; c7
    dd copy4  ; c8 enter
    dd _leave ; c9
    dd unk  ; ca
    dd unk  ; cb
    dd copy1  ; cc
    dd unk  ; cd
    dd unk  ; ce
    dd unk  ; cf
    dd orm  ; d0
    dd orm  ; d1
    dd orm  ; d2
    dd orm  ; d3
    dd unk  ; d4
    dd unk  ; d5
    dd unk  ; d6
    dd unk  ; d7
    dd orm  ; d8
    dd orm  ; d9
    dd orm  ; da
    dd orm  ; db
    dd orm  ; dc
    dd orm  ; dd
    dd orm  ; de
    dd orm  ; df
    dd unk  ; e0
    dd unk  ; e1
    dd _loop  ; e2
    dd unk  ; e3
    dd unk  ; e4
    dd unk  ; e5
    dd unk  ; e6
    dd unk  ; e7
    dd call_jd  ; e8
    dd jmp_jd   ; e9
    dd far_jmp  ; ea
    dd jmp_jb  ; eb
    dd unk  ; ec
    dd unk  ; ed
    dd unk  ; ee
    dd unk  ; ef
    dd prfx  ; f0
    dd unk  ; f1
    dd prfx  ; f2
    dd prfx  ; f3
    dd _hlt  ; f4
    dd _cmc  ; f5
    dd _f6  ; f6
    dd _f7  ; f7
    dd _clc  ; f8
    dd _stc  ; f9
    dd _cli  ; fa
    dd _sti  ; fb
    dd _cld  ; fc
    dd _std  ; fd
    dd orm  ; fe
    dd _ff  ; ff

    dd oorm  ; 0f 00
    dd oorm  ; 0f 01
    dd unk  ; 0f 02
    dd oorm  ; 0f 03
    dd oorm  ; 0f 04
    dd unk  ; 0f 05
    dd unk  ; 0f 06
    dd unk  ; 0f 07
    dd unk  ; 0f 08
    dd unk  ; 0f 09
    dd unk  ; 0f 0a
    dd unk  ; 0f 0b
    dd unk  ; 0f 0c
    dd unk  ; 0f 0d
    dd unk  ; 0f 0e
    dd unk  ; 0f 0f
    dd unk  ; 0f 10
    dd unk  ; 0f 11
    dd unk  ; 0f 12
    dd unk  ; 0f 13
    dd unk  ; 0f 14
    dd unk  ; 0f 15
    dd unk  ; 0f 16
    dd unk  ; 0f 17
    dd unk  ; 0f 18
    dd unk  ; 0f 19
    dd unk  ; 0f 1a
    dd unk  ; 0f 1b
    dd unk  ; 0f 1c
    dd unk  ; 0f 1d
    dd unk  ; 0f 1e
    dd unk  ; 0f 1f
    dd unk  ; 0f 20
    dd unk  ; 0f 21
    dd unk  ; 0f 22
    dd unk  ; 0f 23
    dd unk  ; 0f 24
    dd unk  ; 0f 25
    dd unk  ; 0f 26
    dd unk  ; 0f 27
    dd unk  ; 0f 28
    dd unk  ; 0f 29
    dd unk  ; 0f 2a
    dd unk  ; 0f 2b
    dd unk  ; 0f 2c
    dd unk  ; 0f 2d
    dd unk  ; 0f 2e
    dd unk  ; 0f 2f
    dd unk  ; 0f 30
    dd _rdtsc  ; 0f 31
    dd unk  ; 0f 32
    dd unk  ; 0f 33
    dd unk  ; 0f 34
    dd unk  ; 0f 35
    dd unk  ; 0f 36
    dd unk  ; 0f 37
    dd unk  ; 0f 38
    dd unk  ; 0f 39
    dd unk  ; 0f 3a
    dd unk  ; 0f 3b
    dd unk  ; 0f 3c
    dd unk  ; 0f 3d
    dd unk  ; 0f 3e
    dd unk  ; 0f 3f
    dd unk  ; 0f 40
    dd unk  ; 0f 41
    dd unk  ; 0f 42
    dd unk  ; 0f 43
    dd unk  ; 0f 44
    dd unk  ; 0f 45
    dd unk  ; 0f 46
    dd unk  ; 0f 47
    dd unk  ; 0f 48
    dd unk  ; 0f 49
    dd unk  ; 0f 4a
    dd unk  ; 0f 4b
    dd unk  ; 0f 4c
    dd unk  ; 0f 4d
    dd unk  ; 0f 4e
    dd unk  ; 0f 4f
    dd unk  ; 0f 50
    dd unk  ; 0f 51
    dd unk  ; 0f 52
    dd unk  ; 0f 53
    dd unk  ; 0f 54
    dd unk  ; 0f 55
    dd unk  ; 0f 56
    dd unk  ; 0f 57
    dd unk  ; 0f 58
    dd unk  ; 0f 59
    dd unk  ; 0f 5a
    dd unk  ; 0f 5b
    dd unk  ; 0f 5c
    dd unk  ; 0f 5d
    dd unk  ; 0f 5e
    dd unk  ; 0f 5f
    dd unk  ; 0f 60
    dd unk  ; 0f 61
    dd unk  ; 0f 62
    dd unk  ; 0f 63
    dd unk  ; 0f 64
    dd unk  ; 0f 65
    dd unk  ; 0f 66
    dd unk  ; 0f 67
    dd unk  ; 0f 68
    dd unk  ; 0f 69
    dd unk  ; 0f 6a
    dd unk  ; 0f 6b
    dd unk  ; 0f 6c
    dd unk  ; 0f 6d
    dd oorm  ; 0f 6e
    dd oorm  ; 0f 6f
    dd unk  ; 0f 70
    dd unk  ; 0f 71
    dd unk  ; 0f 72
    dd unk  ; 0f 73
    dd oorm  ; 0f 74
    dd oorm  ; 0f 75
    dd oorm  ; 0f 76
    dd copy2  ; 0f 77
    dd unk  ; 0f 78
    dd unk  ; 0f 79
    dd unk  ; 0f 7a
    dd unk  ; 0f 7b
    dd unk  ; 0f 7c
    dd unk  ; 0f 7d
    dd oorm  ; 0f 7e
    dd oorm  ; 0f 7f
    dd jo_jz   ; 0f 80
    dd jno_jz  ; 0f 81
    dd jb_jz   ; 0f 82
    dd jnb_jz  ; 0f 83
    dd jz_jz   ; 0f 84
    dd jnz_jz  ; 0f 85
    dd jbe_jz  ; 0f 86
    dd ja_jz   ; 0f 87
    dd js_jz   ; 0f 88
    dd jns_jz  ; 0f 89
    dd jpe_jz  ; 0f 8a
    dd jpo_jz  ; 0f 8b
    dd jl_jz   ; 0f 8c
    dd jnl_jz  ; 0f 8d
    dd jle_jz  ; 0f 8e
    dd jg_jz   ; 0f 8f
    dd oorm  ; 0f 90 setcc
    dd oorm  ; 0f 91
    dd oorm  ; 0f 92
    dd oorm  ; 0f 93
    dd oorm  ; 0f 94
    dd oorm  ; 0f 95
    dd oorm  ; 0f 96
    dd oorm  ; 0f 97
    dd oorm  ; 0f 98
    dd oorm  ; 0f 99
    dd oorm  ; 0f 9a
    dd oorm  ; 0f 9b
    dd oorm  ; 0f 9c
    dd oorm  ; 0f 9d
    dd oorm  ; 0f 9e
    dd oorm  ; 0f 9f
    dd copy2  ; 0f a0
    dd copy2  ; 0f a1
    dd copy2  ; 0f a2
    dd oorm  ; 0f a3
    dd oormi  ; 0f a4
    dd oorm  ; 0f a5
    dd unk  ; 0f a6
    dd unk  ; 0f a7
    dd unk  ; 0f a8
    dd unk  ; 0f a9
    dd unk  ; 0f aa
    dd oorm  ; 0f ab
    dd oormi  ; 0f ac
    dd oorm  ; 0f ad
    dd unk  ; 0f ae
    dd oorm  ; 0f af
    dd oorm  ; 0f b0
    dd oorm  ; 0f b1
    dd oorm  ; 0f b2
    dd oorm  ; 0f b3
    dd oorm  ; 0f b4
    dd oorm  ; 0f b5
    dd oorm  ; 0f b6
    dd oorm  ; 0f b7
    dd unk  ; 0f b8
    dd unk  ; 0f b9
    dd oormi  ; 0f ba
    dd unk  ; 0f bb
    dd oorm  ; 0f bc
    dd oorm  ; 0f bd
    dd oorm  ; 0f be
    dd oorm  ; 0f bf
    dd oorm  ; 0f c0
    dd oorm  ; 0f c1
    dd unk  ; 0f c2
    dd unk  ; 0f c3
    dd unk  ; 0f c4
    dd unk  ; 0f c5
    dd unk  ; 0f c6
    dd oorm ; 0f c7
    dd bswap_eax  ; 0f c8
    dd bswap_ecx  ; 0f c9
    dd bswap_edx  ; 0f ca
    dd bswap_ebx  ; 0f cb
    dd bswap_esp  ; 0f cc
    dd bswap_ebp  ; 0f cd
    dd bswap_esi  ; 0f ce
    dd bswap_edi  ; 0f cf
    dd unk  ; 0f d0
    dd unk  ; 0f d1
    dd unk  ; 0f d2
    dd unk  ; 0f d3
    dd unk  ; 0f d4
    dd unk  ; 0f d5
    dd unk  ; 0f d6
    dd unk  ; 0f d7
    dd unk  ; 0f d8
    dd unk  ; 0f d9
    dd unk  ; 0f da
    dd unk  ; 0f db
    dd unk  ; 0f dc
    dd unk  ; 0f dd
    dd unk  ; 0f de
    dd unk  ; 0f df
    dd unk  ; 0f e0
    dd unk  ; 0f e1
    dd unk  ; 0f e2
    dd unk  ; 0f e3
    dd unk  ; 0f e4
    dd unk  ; 0f e5
    dd unk  ; 0f e6
    dd unk  ; 0f e7
    dd oorm  ; 0f e8
    dd oorm  ; 0f e9
    dd oorm  ; 0f ea
    dd oorm  ; 0f eb
    dd oorm  ; 0f ec
    dd oorm  ; 0f ed
    dd oorm  ; 0f ee
    dd oorm  ; 0f ef
    dd unk  ; 0f f0
    dd unk  ; 0f f1
    dd unk  ; 0f f2
    dd unk  ; 0f f3
    dd unk  ; 0f f4
    dd unk  ; 0f f5
    dd unk  ; 0f f6
    dd unk  ; 0f f7
    dd oorm  ; 0f f8
    dd oorm  ; 0f f9
    dd oorm  ; 0f fa
    dd oorm  ; 0f fb
    dd oorm  ; 0f fc
    dd oorm  ; 0f fd
    dd oorm  ; 0f fe
    dd oorm  ; 0f ff

f6_grp32:
    dd ormi
    dd orm
    dd orm
    dd orm
    dd orm
    dd orm
    dd orm
    dd orm

f7_grp32:
    dd ormiiii
    dd ormiiii
    dd orm
    dd orm
    dd orm
    dd orm
    dd orm
    dd orm

ff_grp32:
    dd orm
    dd orm
    dd call_ed
    dd unk
    dd jmp_ed
    dd unk
    dd orm
    dd orm

one_byte_opc16:
    dd orm  ; (66) 00
    dd orm  ; (66) 01
    dd orm  ; (66) 02
    dd orm  ; (66) 03
    dd add_al_ib  ; (66) 04
    dd add_ax_iw  ; (66) 05
    dd unk  ; (66) 06
    dd unk  ; (66) 07
    dd orm  ; (66) 08
    dd orm  ; (66) 09
    dd orm  ; (66) 0a
    dd orm  ; (66) 0b
    dd or_al_ib  ; (66) 0c
    dd or_ax_iw  ; (66) 0d
    dd unk  ; (66) 0e
    dd _0f  ; (66) 0f
    dd orm  ; (66) 10
    dd orm  ; (66) 11
    dd orm  ; (66) 12
    dd orm  ; (66) 13
    dd adc_al_ib  ; (66) 14
    dd adc_ax_iw  ; (66) 15
    dd unk  ; (66) 16
    dd unk  ; (66) 17
    dd orm  ; (66) 18
    dd orm  ; (66) 19
    dd orm  ; (66) 1a
    dd orm  ; (66) 1b
    dd sbb_al_ib  ; (66) 1c
    dd sbb_ax_iw  ; (66) 1d
    dd unk  ; (66) 1e
    dd unk  ; (66) 1f
    dd orm  ; (66) 20
    dd orm  ; (66) 21
    dd orm  ; (66) 22
    dd orm  ; (66) 23
    dd and_al_ib  ; (66) 24
    dd and_ax_iw  ; (66) 25
    dd unk  ; (66) 26
    dd unk  ; (66) 27
    dd orm  ; (66) 28
    dd orm  ; (66) 29
    dd orm  ; (66) 2a
    dd orm  ; (66) 2b
    dd sub_al_ib  ; (66) 2c
    dd sub_ax_iw  ; (66) 2d
    dd unk  ; (66) 2e
    dd unk  ; (66) 2f
    dd orm  ; (66) 30
    dd orm  ; (66) 31
    dd orm  ; (66) 32
    dd orm  ; (66) 33
    dd xor_al_ib  ; (66) 34
    dd xor_ax_iw  ; (66) 35
    dd unk  ; (66) 36
    dd unk  ; (66) 37
    dd orm  ; (66) 38
    dd orm  ; (66) 39
    dd orm  ; (66) 3a
    dd orm  ; (66) 3b
    dd cmp_al_ib  ; (66) 3c
    dd cmp_ax_iw  ; (66) 3d
    dd unk  ; (66) 3e
    dd unk  ; (66) 3f
    dd inc_ax  ; (66) 40
    dd inc_cx  ; (66) 41
    dd inc_dx  ; (66) 42
    dd inc_bx  ; (66) 43
    dd inc_sp  ; (66) 44
    dd inc_bp  ; (66) 45
    dd inc_si  ; (66) 46
    dd inc_di  ; (66) 47
    dd dec_ax  ; (66) 48
    dd dec_cx  ; (66) 49
    dd dec_dx  ; (66) 4a
    dd dec_bx  ; (66) 4b
    dd dec_sp  ; (66) 4c
    dd dec_bp  ; (66) 4d
    dd dec_si  ; (66) 4e
    dd dec_di  ; (66) 4f
    dd unk  ; (66) 50
    dd unk  ; (66) 51
    dd unk  ; (66) 52
    dd unk  ; (66) 53
    dd unk  ; (66) 54
    dd unk  ; (66) 55
    dd unk  ; (66) 56
    dd unk  ; (66) 57
    dd unk  ; (66) 58
    dd unk  ; (66) 59
    dd unk  ; (66) 5a
    dd unk  ; (66) 5b
    dd unk  ; (66) 5c
    dd unk  ; (66) 5d
    dd unk  ; (66) 5e
    dd unk  ; (66) 5f
    dd unk  ; (66) 60
    dd unk  ; (66) 61
    dd unk  ; (66) 62
    dd unk  ; (66) 63
    dd prfx  ; (66) 64
    dd unk  ; (66) 65
    dd _66  ; (66) 66
    dd unk  ; (66) 67
    dd unk  ; (66) 68
    dd ormii  ; (66) 69
    dd push_ib  ; (66) 6a
    dd ormi  ; (66) 6b
    dd unk  ; (66) 6c
    dd unk  ; (66) 6d
    dd unk  ; (66) 6e
    dd unk  ; (66) 6f
    dd jo_jb   ; (66) 70
    dd jno_jb  ; (66) 71
    dd jb_jb   ; (66) 72
    dd jnb_jb  ; (66) 73
    dd jz_jb   ; (66) 74
    dd jnz_jb  ; (66) 75
    dd jbe_jb  ; (66) 76
    dd ja_jb   ; (66) 77
    dd js_jb   ; (66) 78
    dd jns_jb  ; (66) 79
    dd jpe_jb  ; (66) 7a
    dd jpo_jb  ; (66) 7b
    dd jl_jb   ; (66) 7c
    dd jnl_jb  ; (66) 7d
    dd jle_jb  ; (66) 7e
    dd jg_jb   ; (66) 7f
    dd ormi    ; (66) 80
    dd ormii   ; (66) 81
    dd ormi    ; (66) 82
    dd ormi    ; (66) 83
    dd orm  ; (66) 84
    dd orm  ; (66) 85
    dd orm  ; (66) 86
    dd orm  ; (66) 87
    dd orm  ; (66) 88
    dd orm  ; (66) 89
    dd orm  ; (66) 8a
    dd orm  ; (66) 8b
    dd orm  ; (66) 8c
    dd orm  ; (66) 8d
    dd orm  ; (66) 8e
    dd orm  ; (66) 8f
    dd up1  ; (66) 90
    dd copy1  ; (66) 91
    dd copy1  ; (66) 92
    dd copy1  ; (66) 93
    dd copy1  ; (66) 94
    dd copy1  ; (66) 95
    dd copy1  ; (66) 96
    dd copy1  ; (66) 97
    dd _cwde  ; (66) 98
    dd _cdq   ; (66) 99
    dd unk  ; (66) 9a
    dd unk  ; (66) 9b
    dd unk  ; (66) 9c
    dd unk  ; (66) 9d
    dd unk  ; (66) 9e
    dd unk  ; (66) 9f
    dd copy5  ; (66) a0
    dd copy5  ; (66) a1
    dd copy5  ; (66) a2
    dd copy5  ; (66) a3
    dd copy1  ; (66) a4
    dd copy1  ; (66) a5
    dd copy1  ; (66) a6
    dd copy1  ; (66) a7
    dd test_al_ib  ; (66) a8
    dd test_ax_iw  ; (66) a9
    dd copy1  ; (66) aa
    dd copy1  ; (66) ab
    dd copy1  ; (66) ac
    dd copy1  ; (66) ad
    dd copy1  ; (66) ae
    dd copy1  ; (66) af
    dd mov_al_ib  ; (66) b0
    dd mov_cl_ib  ; (66) b1
    dd mov_dl_ib  ; (66) b2
    dd mov_bl_ib  ; (66) b3
    dd mov_ah_ib  ; (66) b4
    dd mov_ch_ib  ; (66) b5
    dd mov_dh_ib  ; (66) b6
    dd mov_bh_ib  ; (66) b7
    dd mov_ax_iw  ; (66) b8
    dd mov_cx_iw  ; (66) b9
    dd mov_dx_iw  ; (66) ba
    dd mov_bx_iw  ; (66) bb
    dd mov_sp_iw  ; (66) bc
    dd mov_bp_iw  ; (66) bd
    dd mov_si_iw  ; (66) be
    dd mov_di_iw  ; (66) bf
    dd ormi  ; (66) c0
    dd ormi  ; (66) c1
    dd ret_iw ; (66) c2
    dd _ret   ; (66) c3
    dd unk  ; (66) c4
    dd unk  ; (66) c5
    dd ormi  ; (66) c6
    dd ormii  ; (66) c7
    dd copy4  ; (66) c8 enter
    dd _leave ; (66) c9
    dd unk  ; (66) ca
    dd unk  ; (66) cb
    dd unk  ; (66) cc
    dd unk  ; (66) cd
    dd unk  ; (66) ce
    dd unk  ; (66) cf
    dd orm  ; (66) d0
    dd orm  ; (66) d1
    dd orm  ; (66) d2
    dd orm  ; (66) d3
    dd unk  ; (66) d4
    dd unk  ; (66) d5
    dd unk  ; (66) d6
    dd unk  ; (66) d7
    dd unk  ; (66) d8
    dd unk  ; (66) d9
    dd unk  ; (66) da
    dd unk  ; (66) db
    dd unk  ; (66) dc
    dd unk  ; (66) dd
    dd unk  ; (66) de
    dd unk  ; (66) df
    dd unk  ; (66) e0
    dd unk  ; (66) e1
    dd unk  ; (66) e2
    dd unk  ; (66) e3
    dd unk  ; (66) e4
    dd unk  ; (66) e5
    dd unk  ; (66) e6
    dd unk  ; (66) e7
    dd unk  ; (66) e8
    dd unk  ; (66) e9
    dd unk  ; (66) ea
    dd jmp_jb  ; (66) eb
    dd unk  ; (66) ec
    dd unk  ; (66) ed
    dd unk  ; (66) ee
    dd unk  ; (66) ef
    dd prfx  ; (66) f0
    dd unk  ; (66) f1
    dd prfx  ; (66) f2
    dd prfx  ; (66) f3
    dd unk  ; (66) f4
    dd unk  ; (66) f5
    dd _f6  ; (66) f6
    dd _f7  ; (66) f7
    dd _clc  ; (66) f8
    dd _stc  ; (66) f9
    dd _cli  ; (66) fa
    dd _sti  ; (66) fb
    dd _cld  ; (66) fc
    dd _std  ; (66) fd
    dd orm  ; (66) fe
    dd _ff  ; (66) ff

    dd oorm  ; (66) 0f 00
    dd oorm  ; (66) 0f 01
    dd unk  ; (66) 0f 02
    dd oorm  ; (66) 0f 03
    dd oorm  ; (66) 0f 04
    dd unk  ; (66) 0f 05
    dd unk  ; (66) 0f 06
    dd unk  ; (66) 0f 07
    dd unk  ; (66) 0f 08
    dd unk  ; (66) 0f 09
    dd unk  ; (66) 0f 0a
    dd unk  ; (66) 0f 0b
    dd unk  ; (66) 0f 0c
    dd unk  ; (66) 0f 0d
    dd unk  ; (66) 0f 0e
    dd unk  ; (66) 0f 0f
    dd unk  ; (66) 0f 10
    dd unk  ; (66) 0f 11
    dd unk  ; (66) 0f 12
    dd unk  ; (66) 0f 13
    dd unk  ; (66) 0f 14
    dd unk  ; (66) 0f 15
    dd unk  ; (66) 0f 16
    dd unk  ; (66) 0f 17
    dd unk  ; (66) 0f 18
    dd unk  ; (66) 0f 19
    dd unk  ; (66) 0f 1a
    dd unk  ; (66) 0f 1b
    dd unk  ; (66) 0f 1c
    dd unk  ; (66) 0f 1d
    dd unk  ; (66) 0f 1e
    dd unk  ; (66) 0f 1f
    dd unk  ; (66) 0f 20
    dd unk  ; (66) 0f 21
    dd unk  ; (66) 0f 22
    dd unk  ; (66) 0f 23
    dd unk  ; (66) 0f 24
    dd unk  ; (66) 0f 25
    dd unk  ; (66) 0f 26
    dd unk  ; (66) 0f 27
    dd unk  ; (66) 0f 28
    dd unk  ; (66) 0f 29
    dd unk  ; (66) 0f 2a
    dd unk  ; (66) 0f 2b
    dd unk  ; (66) 0f 2c
    dd unk  ; (66) 0f 2d
    dd unk  ; (66) 0f 2e
    dd unk  ; (66) 0f 2f
    dd unk  ; (66) 0f 30
    dd unk  ; (66) 0f 31
    dd unk  ; (66) 0f 32
    dd unk  ; (66) 0f 33
    dd unk  ; (66) 0f 34
    dd unk  ; (66) 0f 35
    dd unk  ; (66) 0f 36
    dd unk  ; (66) 0f 37
    dd unk  ; (66) 0f 38
    dd unk  ; (66) 0f 39
    dd unk  ; (66) 0f 3a
    dd unk  ; (66) 0f 3b
    dd unk  ; (66) 0f 3c
    dd unk  ; (66) 0f 3d
    dd unk  ; (66) 0f 3e
    dd unk  ; (66) 0f 3f
    dd unk  ; (66) 0f 40
    dd unk  ; (66) 0f 41
    dd unk  ; (66) 0f 42
    dd unk  ; (66) 0f 43
    dd unk  ; (66) 0f 44
    dd unk  ; (66) 0f 45
    dd unk  ; (66) 0f 46
    dd unk  ; (66) 0f 47
    dd unk  ; (66) 0f 48
    dd unk  ; (66) 0f 49
    dd unk  ; (66) 0f 4a
    dd unk  ; (66) 0f 4b
    dd unk  ; (66) 0f 4c
    dd unk  ; (66) 0f 4d
    dd unk  ; (66) 0f 4e
    dd unk  ; (66) 0f 4f
    dd unk  ; (66) 0f 50
    dd unk  ; (66) 0f 51
    dd unk  ; (66) 0f 52
    dd unk  ; (66) 0f 53
    dd unk  ; (66) 0f 54
    dd unk  ; (66) 0f 55
    dd unk  ; (66) 0f 56
    dd unk  ; (66) 0f 57
    dd unk  ; (66) 0f 58
    dd unk  ; (66) 0f 59
    dd unk  ; (66) 0f 5a
    dd unk  ; (66) 0f 5b
    dd unk  ; (66) 0f 5c
    dd unk  ; (66) 0f 5d
    dd unk  ; (66) 0f 5e
    dd unk  ; (66) 0f 5f
    dd unk  ; (66) 0f 60
    dd unk  ; (66) 0f 61
    dd unk  ; (66) 0f 62
    dd unk  ; (66) 0f 63
    dd unk  ; (66) 0f 64
    dd unk  ; (66) 0f 65
    dd unk  ; (66) 0f 66
    dd unk  ; (66) 0f 67
    dd oorm  ; (66) 0f 68
    dd oorm  ; (66) 0f 69
    dd oorm  ; (66) 0f 6a
    dd oorm  ; (66) 0f 6b
    dd oorm  ; (66) 0f 6c
    dd oorm  ; (66) 0f 6d
    dd oorm  ; (66) 0f 6e
    dd oorm  ; (66) 0f 6f
    dd unk  ; (66) 0f 70
    dd unk  ; (66) 0f 71
    dd unk  ; (66) 0f 72
    dd unk  ; (66) 0f 73
    dd unk  ; (66) 0f 74
    dd unk  ; (66) 0f 75
    dd unk  ; (66) 0f 76
    dd unk  ; (66) 0f 77
    dd unk  ; (66) 0f 78
    dd unk  ; (66) 0f 79
    dd unk  ; (66) 0f 7a
    dd unk  ; (66) 0f 7b
    dd oorm  ; (66) 0f 7c
    dd oorm  ; (66) 0f 7d
    dd oorm  ; (66) 0f 7e
    dd oorm  ; (66) 0f 7f
    dd unk  ; (66) 0f 80
    dd unk  ; (66) 0f 81
    dd unk  ; (66) 0f 82
    dd unk  ; (66) 0f 83
    dd unk  ; (66) 0f 84
    dd unk  ; (66) 0f 85
    dd unk  ; (66) 0f 86
    dd unk  ; (66) 0f 87
    dd unk  ; (66) 0f 88
    dd unk  ; (66) 0f 89
    dd unk  ; (66) 0f 8a
    dd unk  ; (66) 0f 8b
    dd unk  ; (66) 0f 8c
    dd unk  ; (66) 0f 8d
    dd unk  ; (66) 0f 8e
    dd unk  ; (66) 0f 8f
    dd oorm  ; (66) 0f 90 setcc
    dd oorm  ; (66) 0f 91
    dd oorm  ; (66) 0f 92
    dd oorm  ; (66) 0f 93
    dd oorm  ; (66) 0f 94
    dd oorm  ; (66) 0f 95
    dd oorm  ; (66) 0f 96
    dd oorm  ; (66) 0f 97
    dd oorm  ; (66) 0f 98
    dd oorm  ; (66) 0f 99
    dd oorm  ; (66) 0f 9a
    dd oorm  ; (66) 0f 9b
    dd oorm  ; (66) 0f 9c
    dd oorm  ; (66) 0f 9d
    dd oorm  ; (66) 0f 9e
    dd oorm  ; (66) 0f 9f
    dd unk  ; (66) 0f a0
    dd unk  ; (66) 0f a1
    dd unk  ; (66) 0f a2
    dd unk  ; (66) 0f a3
    dd unk  ; (66) 0f a4
    dd unk  ; (66) 0f a5
    dd unk  ; (66) 0f a6
    dd unk  ; (66) 0f a7
    dd unk  ; (66) 0f a8
    dd unk  ; (66) 0f a9
    dd unk  ; (66) 0f aa
    dd oorm  ; (66) 0f ab
    dd oorm  ; (66) 0f ac
    dd oorm  ; (66) 0f ad
    dd unk  ; (66) 0f ae
    dd oorm  ; (66) 0f af
    dd oorm  ; (66) 0f b0
    dd oorm  ; (66) 0f b1
    dd oorm  ; (66) 0f b2
    dd oorm  ; (66) 0f b3
    dd oorm  ; (66) 0f b4
    dd oorm  ; (66) 0f b5
    dd oorm  ; (66) 0f b6
    dd oorm  ; (66) 0f b7
    dd unk  ; (66) 0f b8
    dd unk  ; (66) 0f b9
    dd oormi  ; (66) 0f ba
    dd unk  ; (66) 0f bb
    dd oorm  ; (66) 0f bc
    dd oorm  ; (66) 0f bd
    dd oorm  ; (66) 0f be
    dd oorm  ; (66) 0f bf
    dd oorm  ; (66) 0f c0
    dd oorm  ; (66) 0f c1
    dd unk  ; (66) 0f c2
    dd unk  ; (66) 0f c3
    dd unk  ; (66) 0f c4
    dd unk  ; (66) 0f c5
    dd unk  ; (66) 0f c6
    dd oorm ; (66) 0f c7
    dd unk  ; (66) 0f c8
    dd unk  ; (66) 0f c9
    dd unk  ; (66) 0f ca
    dd unk  ; (66) 0f cb
    dd unk  ; (66) 0f cc
    dd unk  ; (66) 0f cd
    dd unk  ; (66) 0f ce
    dd unk  ; (66) 0f cf
    dd unk  ; (66) 0f d0
    dd unk  ; (66) 0f d1
    dd unk  ; (66) 0f d2
    dd unk  ; (66) 0f d3
    dd unk  ; (66) 0f d4
    dd unk  ; (66) 0f d5
    dd unk  ; (66) 0f d6
    dd unk  ; (66) 0f d7
    dd unk  ; (66) 0f d8
    dd unk  ; (66) 0f d9
    dd unk  ; (66) 0f da
    dd unk  ; (66) 0f db
    dd unk  ; (66) 0f dc
    dd unk  ; (66) 0f dd
    dd unk  ; (66) 0f de
    dd unk  ; (66) 0f df
    dd unk  ; (66) 0f e0
    dd unk  ; (66) 0f e1
    dd unk  ; (66) 0f e2
    dd unk  ; (66) 0f e3
    dd unk  ; (66) 0f e4
    dd unk  ; (66) 0f e5
    dd unk  ; (66) 0f e6
    dd unk  ; (66) 0f e7
    dd oorm  ; (66) 0f e8
    dd oorm  ; (66) 0f e9
    dd oorm  ; (66) 0f ea
    dd oorm  ; (66) 0f eb
    dd oorm  ; (66) 0f ec
    dd oorm  ; (66) 0f ed
    dd oorm  ; (66) 0f ee
    dd oorm  ; (66) 0f ef
    dd unk  ; (66) 0f f0
    dd unk  ; (66) 0f f1
    dd unk  ; (66) 0f f2
    dd unk  ; (66) 0f f3
    dd unk  ; (66) 0f f4
    dd unk  ; (66) 0f f5
    dd unk  ; (66) 0f f6
    dd unk  ; (66) 0f f7
    dd oorm  ; (66) 0f f8
    dd oorm  ; (66) 0f f9
    dd oorm  ; (66) 0f fa
    dd oorm  ; (66) 0f fb
    dd oorm  ; (66) 0f fc
    dd oorm  ; (66) 0f fd
    dd oorm  ; (66) 0f fe
    dd oorm  ; (66) 0f ff

f6_grp16:
    dd ormi
    dd orm
    dd orm
    dd orm
    dd orm
    dd orm
    dd orm
    dd orm

f7_grp16:
    dd ormii
    dd ormii
    dd orm
    dd orm
    dd orm
    dd orm
    dd orm
    dd orm

ff_grp16:
    dd orm
    dd orm
    dd unk
    dd unk
    dd unk
    dd unk
    dd orm
    dd _66_ff38


zap_mid3:
    db 0, 1, 2, 3, 4, 5, 6, 7
    db 0, 1, 2, 3, 4, 5, 6, 7
    db 0, 1, 2, 3, 4, 5, 6, 7
    db 0, 1, 2, 3, 4, 5, 6, 7
    db 0, 1, 2, 3, 4, 5, 6, 7
    db 0, 1, 2, 3, 4, 5, 6, 7
    db 0, 1, 2, 3, 4, 5, 6, 7
    db 0, 1, 2, 3, 4, 5, 6, 7
    db 0, 1, 2, 3, 4, 5, 6, 7

    db 40h, 41h, 42h, 43h, 44h, 45h, 46h, 47h
    db 40h, 41h, 42h, 43h, 44h, 45h, 46h, 47h
    db 40h, 41h, 42h, 43h, 44h, 45h, 46h, 47h
    db 40h, 41h, 42h, 43h, 44h, 45h, 46h, 47h
    db 40h, 41h, 42h, 43h, 44h, 45h, 46h, 47h
    db 40h, 41h, 42h, 43h, 44h, 45h, 46h, 47h
    db 40h, 41h, 42h, 43h, 44h, 45h, 46h, 47h
    db 40h, 41h, 42h, 43h, 44h, 45h, 46h, 47h

    db 80h, 81h, 82h, 83h, 84h, 85h, 86h, 87h
    db 80h, 81h, 82h, 83h, 84h, 85h, 86h, 87h
    db 80h, 81h, 82h, 83h, 84h, 85h, 86h, 87h
    db 80h, 81h, 82h, 83h, 84h, 85h, 86h, 87h
    db 80h, 81h, 82h, 83h, 84h, 85h, 86h, 87h
    db 80h, 81h, 82h, 83h, 84h, 85h, 86h, 87h
    db 80h, 81h, 82h, 83h, 84h, 85h, 86h, 87h
    db 80h, 81h, 82h, 83h, 84h, 85h, 86h, 87h

    db 0c0h, 0c1h, 0c2h, 0c3h, 0c4h, 0c5h, 0c6h, 0c7h
    db 0c0h, 0c1h, 0c2h, 0c3h, 0c4h, 0c5h, 0c6h, 0c7h
    db 0c0h, 0c1h, 0c2h, 0c3h, 0c4h, 0c5h, 0c6h, 0c7h
    db 0c0h, 0c1h, 0c2h, 0c3h, 0c4h, 0c5h, 0c6h, 0c7h
    db 0c0h, 0c1h, 0c2h, 0c3h, 0c4h, 0c5h, 0c6h, 0c7h
    db 0c0h, 0c1h, 0c2h, 0c3h, 0c4h, 0c5h, 0c6h, 0c7h
    db 0c0h, 0c1h, 0c2h, 0c3h, 0c4h, 0c5h, 0c6h, 0c7h
    db 0c0h, 0c1h, 0c2h, 0c3h, 0c4h, 0c5h, 0c6h, 0c7h

unk:
    stack_switch
    pushf
    pusha

    mov     ecx, ebx
    mov     edx, MSG_UNK_INSN
    mov     eax, [ebx]._eip
    mov     eax, [eax]
    mov     [ebx]._tmp, eax
    call    [ebx]._ccb

    popa
    popf
    rstor_stack
@@:
    jmp     @B

brkpt:
    int 3
    db 'F'

;public @codelen
;@codelen dd @codelen

end

