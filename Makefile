
all: test.exe target.exe susp.exe ctrl.dll conn.exe

conn.exe: conn.obj ipclib.obj ipclib.h ctrl.h
	link /nologo /out:$@ conn.obj ipclib.obj

ctrl.dll: ctrl.obj mogwai.obj ipclib.obj ipclib.h mogwai.h ctrl.h
	link /nologo /dll /out:$@ ctrl.obj mogwai.obj ipclib.obj

test.exe: test.obj mogwai.obj ipclib.obj ipclib.h mogwai.h
	link /nologo /out:$@ test.obj mogwai.obj ipclib.obj user32.lib

target.exe: target.obj
	link /nologo /out:$@ $** user32.lib

susp.exe: susp.obj
	link /nologo /out:$@ $**

.c.obj:
	cl /c /GS- $<

.asm.obj:
	ml /c $<

