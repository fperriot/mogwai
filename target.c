#include <windows.h>
#include <stdio.h>

LONG seh(DWORD exccode)
{
    /*__asm int 3;*/

    MessageBox(0, "In SEH filter", "target", MB_OK);

    return EXCEPTION_EXECUTE_HANDLER;
}

void f(void)
{
    int zero, dummy;

    __try {
        _asm mov zero, 0;
        dummy = 1 / zero;
    }
    __except(seh(GetExceptionCode()))
    {
        MessageBox(0, "In SEH handler", "target", MB_OK);
    }
}

void main(void)
{
    f();
    MessageBox(0, "running", "target", MB_OK);
}

