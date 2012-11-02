#include <stdio.h>
#include <stdarg.h>
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x500
#include <windows.h>
#include "ipclib.h"
#include "mogwai.h"

perthread_t *ctx;
shm_buf_t *mbox;

enum {
    MSG_FAR_JMP,
    MSG_UNK_INSN,
};

enum {
    NtContinue = 0x40,
};

int __fastcall handle_msg(perthread_t *ctx, int msg)
{
    /* WARNING:
     * Running on switched stack in here, so no system calls, no exception
     * handling, no printf(), no libc, nothing fancy, just raw C code!
     */

    int retval = 0;

    /*__asm int 3;*/

    switch (msg)
    {
        shm_msg_t m;

        case MSG_FAR_JMP:
        {
            DWORD resume_eip;

            m.cnt = 2;
            m.arg[1] = ctx->eax;

            switch (ctx->eax)
            {
                case NtContinue:
                {
                    CONTEXT *excc = *(CONTEXT **) ctx->edx;
                    resume_eip = excc->Eip;
                    excc->Eip = (DWORD) &ctx->epilog;

                    m.cnt++;
                    m.arg[2] = resume_eip;
                    break;
                }
                default:
                    resume_eip = *(DWORD *) ctx->esp;
                    *(DWORD *) ctx->esp = (DWORD) &ctx->epilog;
                    break;
            }
            ctx->nxt = (void *) resume_eip;

            shm_post(mbox, &m);

            break;
        }
        case MSG_UNK_INSN:
        {
            m.cnt = 3;
            m.arg[1] = (unsigned) ctx->eip;
            m.arg[2] = ctx->tmp;

            shm_post(mbox, &m);

            break;
        }
    }
    return retval;
}

LONG seh(DWORD exccode)
{
    /*__asm int 3;*/

    printf("In SEH filter\n");

    return EXCEPTION_EXECUTE_HANDLER;
}

void f(void)
{
    int zero, dummy;
    FILE *hnd;

    __try {
        _asm mov zero, 0;
        dummy = 1 / zero;
    }
    __except(seh(GetExceptionCode()))
    {
        printf("In SEH handler\n");
    }

    printf("World\n");

    hnd = fopen("foo.bar", "wb");

    if (hnd)
    {
        fwrite("\x00", 1, 1, hnd);
        fclose(hnd);
    }
    else
        printf("can't create \"foo.bar\"\n");

    printf("Ticks: %d\n", ctx->ticks);
#if 0
    _asm int 3
#endif
}

void typical(void)
{
    GetProcAddress(LoadLibrary("gdi32"), "arc");
    MessageBox(0, "hello", "world", MB_OK);
#if 0
    _asm int 3
#endif
}

void dummy(void) {}

LONG CALLBACK VectoredHandler(PEXCEPTION_POINTERS ExceptionInfo)
{
    DWORD Eip = ExceptionInfo->ContextRecord->Eip;

    if ((DWORD) &ctx->insn == Eip)
    {
        printf("Redirecting %x/%x -> %x\n",
                ExceptionInfo->ContextRecord->Eip,
                ExceptionInfo->ExceptionRecord->ExceptionAddress,
                ctx->eip);

        ExceptionInfo->ContextRecord->Eip = (DWORD) ctx->eip;
        ExceptionInfo->ExceptionRecord->ExceptionAddress = ctx->eip;

        ctx->eip = dummy;
        run(ctx);
    }

    return EXCEPTION_CONTINUE_SEARCH;
}

static int signal = 0;

DWORD WINAPI MsgSink(LPVOID dummy)
{
    unsigned i, n;
    shm_msg_t m;

    for (;!signal;)
    {
        while (shm_recv(mbox, &m))
        {
            for (i = 1; i < m.cnt; ++i)
                printf("%8x ", m.arg[i]);
            printf("\n");
        }

        if (n = mbox->lost)
        {
            mbox->lost = 0; /* race condition not very important */
            printf("%d lost messages\n", n);
        }

        Sleep(0);
    }
    return 0;
}

void main(void)
{
    int zero, dummy;
    DWORD mbox_sz = 0x10000 + 100;

    BYTE *pg = (BYTE *) VirtualAlloc(0, 0x1000, MEM_COMMIT,
            PAGE_EXECUTE_READWRITE);

    ctx = (perthread_t *)(pg + 0x1000 - sizeof(perthread_t));

    mbox = shm_init(VirtualAlloc(0, mbox_sz, MEM_COMMIT, PAGE_READWRITE),
            mbox_sz);

    (void) CreateThread(0, 0, MsgSink, 0, 0, 0);

    printf("Hello...\n");

  /*_asm int 3;*/

    (void) AddVectoredExceptionHandler(1, VectoredHandler);
/*
    _asm mov zero, 0;
    dummy = 1 / zero;
*/
#if 0
    _asm int 3
#endif
    ctx->eip = f;
    ctx->ccb = handle_msg;
    run(ctx);

    typical();
#if 1
    resume_native_exec();
#endif
    Sleep(100);

    signal = 1;

    printf("Done\n");
    printf("Ticks: %d\n", ctx->ticks);
}

