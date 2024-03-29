SIZE_OF_80387_REGISTERS   equ 80

STATUS_WAIT_0             equ 00000000h
STATUS_ABANDONED_WAIT_0   equ 00000080h
STATUS_USER_APC           equ 000000C0h
STATUS_TIMEOUT            equ 00000102h
STATUS_PENDING            equ 00000103h
STATUS_DATATYPE_MISALIGNMENT              equ 80000002h
STATUS_BREAKPOINT         equ 80000003h
STATUS_SINGLE_STEP        equ 80000004h
STATUS_ACCESS_VIOLATION   equ 0C0000005h
STATUS_IN_PAGE_ERROR      equ 0C0000006h
STATUS_NO_MEMORY          equ 0C0000017h
STATUS_ILLEGAL_INSTRUCTION                equ 0C000001Dh
STATUS_NONCONTINUABLE_EXCEPTION           equ 0C0000025h
STATUS_INVALID_DISPOSITION                equ 0C0000026h
STATUS_ARRAY_BOUNDS_EXCEEDED              equ 0C000008Ch
STATUS_FLOAT_DENORMAL_OPERAND             equ 0C000008Dh
STATUS_FLOAT_DIVIDE_BY_ZERO               equ 0C000008Eh
STATUS_FLOAT_INEXACT_RESULT               equ 0C000008Fh
STATUS_FLOAT_INVALID_OPERATION            equ 0C0000090h
STATUS_FLOAT_OVERFLOW     equ 0C0000091h
STATUS_FLOAT_STACK_CHECK  equ 0C0000092h
STATUS_FLOAT_UNDERFLOW    equ 0C0000093h
STATUS_INTEGER_DIVIDE_BY_ZERO             equ 0C0000094h
STATUS_INTEGER_OVERFLOW   equ 0C0000095h
STATUS_PRIVILEGED_INSTRUCTION             equ 0C0000096h
STATUS_STACK_OVERFLOW     equ 0C00000FDh
STATUS_CONTROL_C_EXIT     equ 0C000013Ah

EXCEPTION_EXECUTE_HANDLER            equ 1
EXCEPTION_CONTINUE_SEARCH            equ 0
EXCEPTION_CONTINUE_EXECUTION         equ -1

EXCEPTION_CONTINUABLE     equ 0
EXCEPTION_NONCONTINUABLE  equ 1h
EXCEPTION_ACCESS_VIOLATION                equ STATUS_ACCESS_VIOLATION
EXCEPTION_DATATYPE_MISALIGNMENT           equ STATUS_DATATYPE_MISALIGNMENT
EXCEPTION_BREAKPOINT      equ STATUS_BREAKPOINT
EXCEPTION_SINGLE_STEP     equ STATUS_SINGLE_STEP
EXCEPTION_ARRAY_BOUNDS_EXCEEDED           equ STATUS_ARRAY_BOUNDS_EXCEEDED
EXCEPTION_FLT_DENORMAL_OPERAND            equ STATUS_FLOAT_DENORMAL_OPERAND
EXCEPTION_FLT_DIVIDE_BY_ZERO              equ STATUS_FLOAT_DIVIDE_BY_ZERO
EXCEPTION_FLT_INEXACT_RESULT              equ STATUS_FLOAT_INEXACT_RESULT
EXCEPTION_FLT_INVALID_OPERATION           equ STATUS_FLOAT_INVALID_OPERATION
EXCEPTION_FLT_OVERFLOW    equ STATUS_FLOAT_OVERFLOW
EXCEPTION_FLT_STACK_CHECK equ STATUS_FLOAT_STACK_CHECK
EXCEPTION_FLT_UNDERFLOW   equ STATUS_FLOAT_UNDERFLOW
EXCEPTION_INT_DIVIDE_BY_ZERO              equ STATUS_INTEGER_DIVIDE_BY_ZERO
EXCEPTION_INT_OVERFLOW    equ STATUS_INTEGER_OVERFLOW
EXCEPTION_ILLEGAL_INSTRUCTION     equ  STATUS_ILLEGAL_INSTRUCTION
EXCEPTION_PRIV_INSTRUCTION                equ STATUS_PRIVILEGED_INSTRUCTION
EXCEPTION_IN_PAGE_ERROR   equ STATUS_IN_PAGE_ERROR
CONTEXT_i386              equ 00010000h
CONTEXT_i486              equ 00010000h
CONTEXT_CONTROL           equ CONTEXT_i386 OR 00000001h
CONTEXT_INTEGER           equ CONTEXT_i386 OR 00000002h
CONTEXT_SEGMENTS          equ CONTEXT_i386 OR 00000004h
CONTEXT_FLOATING_POINT    equ CONTEXT_i386 OR 00000008h
CONTEXT_DEBUG_REGISTERS   equ CONTEXT_i386 OR 00000010h
CONTEXT_FULL              equ CONTEXT_CONTROL OR CONTEXT_INTEGER OR CONTEXT_SEGMENTS
EXCEPTION_MAXIMUM_PARAMETERS         equ 15
MAXIMUM_SUPPORTED_EXTENSION          equ 512

EXCEPTION_RECORD STRUCT
  ExceptionCode         DWORD      ?
  ExceptionFlags        DWORD      ?
  pExceptionRecord      DWORD      ?
  ExceptionAddress      DWORD      ?
  NumberParameters      DWORD      ?
  ExceptionInformation  DWORD EXCEPTION_MAXIMUM_PARAMETERS dup(?)
EXCEPTION_RECORD ENDS

FLOATING_SAVE_AREA STRUCT
  ControlWord   DWORD      ?
  StatusWord    DWORD      ?
  TagWord       DWORD      ?
  ErrorOffset   DWORD      ?
  ErrorSelector DWORD      ?
  DataOffset    DWORD      ?
  DataSelector  DWORD      ?
  RegisterArea  BYTE  SIZE_OF_80387_REGISTERS dup(?)
  Cr0NpxState   DWORD      ?
FLOATING_SAVE_AREA ENDS

CONTEXT STRUCT
  ContextFlags  DWORD      ?
  iDr0          DWORD      ?
  iDr1          DWORD      ?
  iDr2          DWORD      ?
  iDr3          DWORD      ?
  iDr6          DWORD      ?
  iDr7          DWORD      ?
  FloatSave     FLOATING_SAVE_AREA <>
  regGs         DWORD      ?
  regFs         DWORD      ?
  regEs         DWORD      ?
  regDs         DWORD      ?
  regEdi        DWORD      ?
  regEsi        DWORD      ?
  regEbx        DWORD      ?
  regEdx        DWORD      ?
  regEcx        DWORD      ?
  regEax        DWORD      ?
  regEbp        DWORD      ?
  regEip        DWORD      ?
  regCs         DWORD      ?
  regFlag       DWORD      ?
  regEsp        DWORD      ?
  regSs         DWORD      ?
  ExtendedRegisters db MAXIMUM_SUPPORTED_EXTENSION dup(?)
CONTEXT ENDS

EXCEPTION_POINTERS STRUCT
  pExceptionRecord  DWORD      ?
  ContextRecord     DWORD      ?
EXCEPTION_POINTERS ENDS

