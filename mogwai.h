#pragma once

typedef int __fastcall C_callback(struct _perthread *ctx, int msg);

typedef struct _perthread {
    void *eip;
    void *nxt;
    unsigned eax;
    unsigned ecx;
    unsigned edx;
    unsigned esp;
    unsigned esi;
    unsigned edi;
    unsigned flags;
    unsigned tmp;
    unsigned ticks;
    C_callback *ccb;
    char epilog[6 + 6];
    void *back;
    unsigned ebx;
    char prologue[3], insn[15+2];
} perthread_t;

extern
void
__declspec(noreturn)
__fastcall
pop_run(perthread_t *ctx);

extern
void
__fastcall
run(perthread_t *ctx);

__forceinline
void
resume_native_exec(void)
{
    __asm _emit 0xf3
    __asm _emit 0xf2
    __asm _emit 0xf0
    __asm _emit 0x66
    __asm _emit 0xff
    __asm _emit 0x7a
}

