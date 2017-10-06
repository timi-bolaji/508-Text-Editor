@echo off
SET PATH=%PATH%;c:\masm32\bin

if exist Smartpad.obj del Smartpad.obj
if exist Smartpad.res del Smartpad.res

if exist texteditor.obj del texteditor.obj
if exist texteditor.res del texteditor.res

ml /c /coff /Cp texteditor.asm
ml /c /coff /Cp Smartpad.asm

rc texteditor.rc
rc Smartpad.rc

link /SUBSYSTEM:WINDOWS /LIBPATH:c\masm32\lib Smartpad.obj Smartpad.res
link /SUBSYSTEM:WINDOWS /LIBPATH:c\masm32\lib texteditor.obj texteditor.res

del texteditor.obj
del Smartpad.obj

del texteditor.res
del Smartpad.res

dir texteditor.*
dir Smartpad.*

pause
