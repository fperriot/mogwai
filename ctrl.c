#include <windows.h>
#include "ctrl.h"
#include "ipclib.h"
#include "mogwai.h"

HINSTANCE hDllInst;
DWORD shm_sz = 0x10000 + 100;
HANDLE hMapping;
LPVOID lpView;
DWORD tls_slot;
FARPROC RtlUserThreadStart;

shm_buf_t *mbox;

enum {
    MSG_FAR_JMP,
    MSG_UNK_INSN,
};

enum {
    NtContinue = 0x40,
};

int __fastcall xlat_msg(perthread_t *ctx, int msg)
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

            switch (ctx->eax)
            {
                case NtContinue:
                {
                    CONTEXT *excc = *(CONTEXT **) ctx->edx;
                    resume_eip = excc->Eip;
                    excc->Eip = (DWORD) &ctx->epilog;

                    break;
                }
                default:
                    resume_eip = *(DWORD *) ctx->esp;
                    *(DWORD *) ctx->esp = (DWORD) &ctx->epilog;
                    break;
            }
            ctx->nxt = (void *) resume_eip;

            m.cnt = 4;
            m.arg[1] = ctx->ticks;
            m.arg[2] = ctx->eax;
            m.arg[3] = resume_eip;

            shm_post(mbox, &m);

            break;
        }
        case MSG_UNK_INSN:
        {
            m.cnt = 4;
            m.arg[2] = (unsigned) ctx->eip;
            m.arg[3] = ctx->tmp;

            shm_post(mbox, &m);

            break;
        }
    }
    return retval;
}

void enter_emu(void) {}

void
replacement_RtlUserThreadStart(void)
{
    DWORD zax, zbx, zcx, zdx, zsi, zdi;
    BYTE *pg;
    perthread_t *ctx;
    shm_msg_t m;

    __asm {
        mov     zax, eax
        mov     zbx, ebx
        mov     zcx, ecx
        mov     zdx, edx
        mov     zsi, esi
        mov     zdi, edi
    }

    m.cnt = 3;
    m.arg[1] = 0;
    m.arg[2] = 0;
    shm_post(mbox, &m);

    pg = (BYTE *) VirtualAlloc(0, 0x1000, MEM_COMMIT, PAGE_EXECUTE_READWRITE);

    if (! pg) for (;;) Sleep(1000);

    ctx = (perthread_t *) (pg + 0x1000 - sizeof(perthread_t));

    m.arg[2] = 1;
    shm_post(mbox, &m);

    if (! TlsSetValue(tls_slot, ctx)) for (;;) Sleep(1000);

    m.arg[2] = 2;
    shm_post(mbox, &m);
#if 0
    _asm int 3;
#endif
    ctx->ccb = xlat_msg;
    ctx->eip = enter_emu;
    ctx->edx = zdx;
    ctx->ecx = zcx;

    __asm {
        mov     eax, zax
        mov     ebx, zbx
        mov     esi, zsi
        mov     edi, zdi
    }

    run(ctx);

    __asm {
        jmp     [RtlUserThreadStart]
    }
}

static
void post_init_info(void)
{
    shm_msg_t msg;

    msg.cnt = 4;
    msg.arg[1] = (unsigned) &replacement_RtlUserThreadStart;
    msg.arg[2] = (unsigned) RtlUserThreadStart;
    msg.arg[3] = (unsigned) hDllInst;

    shm_post(mbox, &msg);
}

LONG CALLBACK VectoredHandler(PEXCEPTION_POINTERS ExceptionInfo)
{
    perthread_t *ctx = TlsGetValue(tls_slot);
    DWORD Eip = ExceptionInfo->ContextRecord->Eip;
    shm_msg_t msg;

    if ((DWORD) &ctx->insn == Eip)
    {
        msg.cnt = 4;
        msg.arg[1] = ctx->ticks;
        msg.arg[2] = ExceptionInfo->ExceptionRecord->ExceptionCode;
        msg.arg[3] = (unsigned) ctx->eip;

        shm_post(mbox, &msg);

        ExceptionInfo->ContextRecord->Eip = (DWORD) ctx->eip;
        ExceptionInfo->ExceptionRecord->ExceptionAddress = ctx->eip;

        ctx->eip = enter_emu;
        run(ctx);
    }

    return EXCEPTION_CONTINUE_SEARCH;
}

static
BOOL init(void)
{
    HANDLE hFile;
    LPSECURITY_ATTRIBUTES lpSecAttr;
    DWORD dwMaxSzHi, dwMaxSzLo;
    DWORD dwFileOfsHi, dwFileOfsLo;
    LPCSTR lpName;
    SIZE_T dwNumBytesToMap;
    HMODULE ntdll;
    ULONG FirstHandler;

    hMapping = CreateFileMapping(hFile = 0,
                                 lpSecAttr = 0,
                                 PAGE_READWRITE,
                                 dwMaxSzHi = 0,
                                 dwMaxSzLo = shm_sz,
                                 lpName = SHM_NAME);
    if (! hMapping)
        return FALSE;

    lpView = MapViewOfFile(hMapping,
                           FILE_MAP_ALL_ACCESS,
                           dwFileOfsHi = 0,
                           dwFileOfsLo = 0,
                           dwNumBytesToMap = 0);
    if (! lpView)
        return FALSE;

    mbox = shm_init(lpView, shm_sz);

    if (! mbox)
        return FALSE;

    tls_slot = TlsAlloc();

    if (TLS_OUT_OF_INDEXES == tls_slot)
        return FALSE;

    if ((ntdll = GetModuleHandle("ntdll")) &&
        (RtlUserThreadStart = GetProcAddress(ntdll, "RtlUserThreadStart")))
        ;
    else
        return FALSE;

    if (AddVectoredExceptionHandler(FirstHandler = 1, VectoredHandler))
        ;
    else
        return FALSE;

    post_init_info();

    return TRUE;
}

static
void deinit(void)
{
    __try { resume_native_exec(); } __except(EXCEPTION_EXECUTE_HANDLER) {}

    if (lpView)
        (void) UnmapViewOfFile(lpView);

    if (hMapping)
        (void) CloseHandle(hMapping);

    TlsFree(tls_slot);

    RemoveVectoredExceptionHandler(VectoredHandler);
}

static
void attach(void)
{
}

static
void detach(void)
{
    LPVOID pg;

    __try { resume_native_exec(); } __except(EXCEPTION_EXECUTE_HANDLER) {}

    pg = (LPVOID) ((DWORD) TlsGetValue(tls_slot) & ~0xffful);

    if (pg)
        VirtualFree(pg, 0, MEM_RELEASE);
}

BOOL WINAPI DllMain(HINSTANCE hinst, DWORD dwReason, LPVOID lpvReserved)
{
    hDllInst = hinst;

    switch (dwReason)
    {
        case DLL_PROCESS_ATTACH:
            return init();

        case DLL_PROCESS_DETACH:
            deinit();
            break;

        case DLL_THREAD_ATTACH:
            attach();
            break;

        case DLL_THREAD_DETACH:
            detach();
            break;
    }
}

