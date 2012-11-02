#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT _WIN32_WINNT_WINXP
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include "ctrl.h"
#include "ipclib.h"

HANDLE process_connect(int pid)
{
    HANDLE hProc;
    BOOL bInheritHandle;

    hProc = OpenProcess(PROCESS_ALL_ACCESS,
                        bInheritHandle = FALSE,
                        pid);
    return hProc;
}

HANDLE open_thread(int tid)
{
    BOOL bInheritHnd;

    HANDLE hThrd = OpenThread(THREAD_ALL_ACCESS,
                              bInheritHnd = FALSE,
                              tid);
    return hThrd;
}

struct Shm { HANDLE hMapping; LPVOID lpView; };

BOOL open_shm(int pid, struct Shm *shm)
{
    HANDLE hMapping;
    BOOL bInheritHnd;
    LPCTSTR lpName;
    LPVOID lpView;
    DWORD dwOfsHi, dwOfsLo, dwNumBytesToMap;

    (void) pid; /* for now, a single process-independent mapping */

    hMapping = OpenFileMapping(FILE_MAP_ALL_ACCESS,
                               bInheritHnd = FALSE,
                               lpName = SHM_NAME);
    if (! hMapping)
        return FALSE;

    lpView = MapViewOfFile(hMapping,
                           FILE_MAP_ALL_ACCESS,
                           dwOfsHi = 0,
                           dwOfsLo = 0,
                           dwNumBytesToMap = 0);
    if (! lpView)
    {
        CloseHandle(hMapping);
        return FALSE;
    }

    shm->hMapping = hMapping;
    shm->lpView = lpView;

    return TRUE;
}

static int signal = 0;

DWORD WINAPI MsgSink(LPVOID lpv)
{
    unsigned i, n;
    shm_buf_t *mbox = (shm_buf_t *) lpv;
    shm_msg_t m;

    while (! signal)
    {
        while (shm_recv(mbox, &m))
        {
            printf("%-10d ", m.arg[1]);
            for (i = 2; i < m.cnt; ++i)
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

void listen(shm_buf_t *mbox)
{
    LPSECURITY_ATTRIBUTES lpSecAttrs;
    DWORD dwStackSize, dwCreationFlags, dwTid;

    (void) CreateThread(lpSecAttrs = 0,
                        dwStackSize = 0,
                        MsgSink,
                        mbox,
                        dwCreationFlags = 0,
                        &dwTid);
}

int main(int argc, char *argv[])
{
    int pid, tid;
    HANDLE hProc = 0;
    HANDLE hThrd = 0;
    struct Shm shm = {0};
    shm_buf_t *mbox;
    shm_msg_t msg;
    DWORD replacement_RtlUserThreadStart;
    DWORD addr_RtlUserThreadStart;
    CONTEXT ctx;

    if (argc < 3)
    {
        printf("Usage: conn <pid> <tid>\n");
        exit(0);
    }

    pid = atoi(argv[1]);
    tid = atoi(argv[2]);

    if (hProc = process_connect(pid))
    {
        printf("Successfully connected to process %d\n", pid);
    }
    else
    {
        printf("Can't connect to process %d\n", pid);
        goto end;
    }

    if (hThrd = open_thread(tid))
    {
        printf("Successfully opened thread %d\n", tid);
    }
    else
    {
        printf("Can't open thread %d\n", tid);
        goto end;
    }

    if (open_shm(pid, &shm))
    {
        printf("Successfully opened shared memory\n");
    }
    else
    {
        printf("Can't open shared memory\n");
        goto end;
    }

    mbox = (shm_buf_t *) shm.lpView;


    ctx.ContextFlags = CONTEXT_ALL;

    if (GetThreadContext(hThrd, &ctx))
    {
        printf("Thread current Eip = %08x\n", ctx.Eip);
        printf("Thread current Eax = %08x\n", ctx.Eax);
        printf("Thread current Ebx = %08x\n", ctx.Ebx);
    }
    else
    {
        printf("Can't get thread context\n");
        goto end;
    }

    if (shm_recv(mbox, &msg))
    {
        replacement_RtlUserThreadStart = msg.arg[1];
        addr_RtlUserThreadStart = msg.arg[2];
        printf("Recvd new main thread entry-point: %08x\n", msg.arg[1]);
        printf("Recvd RtlUserThreadStart address : %08x\n", msg.arg[2]);
        printf("Recvd injected .dll base address : %08x\n", msg.arg[3]);
    }
    else
    {
        printf("Didn't recv new main thread entry-point\n");
        goto end;
    }

    if (ctx.Eip == addr_RtlUserThreadStart)
    {
        ctx.Eip = replacement_RtlUserThreadStart;
        ctx.ContextFlags = CONTEXT_CONTROL;

        if (SetThreadContext(hThrd, &ctx))
        {
            printf("Hijacked thread entry-point\n");
        }
        else
        {
            printf("Can't change thread entry-point\n");
            goto end;
        }

        printf("Listening for messages\n");

        listen(mbox);

        printf("Resuming remote thread\n");

        ResumeThread(hThrd);

        printf("Waiting on target process\n");

        if (WAIT_OBJECT_0 == WaitForSingleObject(hProc, INFINITE))
        {
            printf("Process has finished\n");
        }
    }
    else
    {
        printf("Unexpected thread start address\n");
    }

end:
    if (shm.lpView)
        UnmapViewOfFile(shm.lpView);

    if (shm.hMapping)
        CloseHandle(shm.hMapping);

    if (hThrd)
        CloseHandle(hThrd);

    if (hProc)
        CloseHandle(hProc);
}

