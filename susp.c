#include <stdio.h>
#include <stdlib.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

int main(int argc, char *argv[])
{
    BOOL bInheritHandles;
    LPTSTR lpCmdLine, lpCurDir;
    LPSECURITY_ATTRIBUTES lpProcessSecAttr, lpThreadSecAttr;
    DWORD dwCreationFlags;
    LPVOID lpEnv;
    STARTUPINFO StartupInfo = {0};
    PROCESS_INFORMATION ProcessInfo = {0};

    if (argc < 2)
    {
        printf("Usage: susp <.exe> [cmd line]\n");
        exit(0);
    }

    StartupInfo.cb = sizeof(StartupInfo);

    if (CreateProcess(argv[1],
                      lpCmdLine = argc > 2 ? argv[2] : 0,
                      lpProcessSecAttr = 0,
                      lpThreadSecAttr = 0,
                      bInheritHandles = FALSE,
                      dwCreationFlags = CREATE_SUSPENDED,
                      lpEnv = 0,
                      lpCurDir = 0,
                      &StartupInfo,
                      &ProcessInfo))
    {
        printf("Successfully created suspended process %d / thread %d\n",
                ProcessInfo.dwProcessId, ProcessInfo.dwThreadId);
        CloseHandle(ProcessInfo.hThread);
        CloseHandle(ProcessInfo.hProcess);
        CloseHandle(StartupInfo.hStdInput);
        CloseHandle(StartupInfo.hStdOutput);
        CloseHandle(StartupInfo.hStdError);
    }
    else
    {
        printf("Could not create process\n");
    }
    return 0;
}

