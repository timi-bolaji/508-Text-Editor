@echo off
SET PATH=%PATH%;c:\masm32\bin

ml /c /coff /Cp texteditor.asm
rc texteditor.rc
link /SUBSYSTEM:WINDOWS /LIBPATH:c\masm32\lib texteditor.obj texteditor.res

pause
