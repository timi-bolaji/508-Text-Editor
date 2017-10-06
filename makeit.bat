@echo off
SET PATH=%PATH%;c:\masm32\bin

ml /c /coff /Cp texteditor.asm
ml /c /coff /Cp Smartpad.asm

rc texteditor.rc
rc MDI.rc

link /SUBSYSTEM:WINDOWS /LIBPATH:c\masm32\lib Smartpad.obj MDI.res
link /SUBSYSTEM:WINDOWS /LIBPATH:c\masm32\lib texteditor.obj texteditor.res

pause
