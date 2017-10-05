@echo off
SET PATH=%PATH%;c:\masm32\bin

ml /c /coff /Cp texteditor.asm
link /SUBSYSTEM:WINDOWS /LIBPATH:c\masm32\lib texteditor.obj

pause
