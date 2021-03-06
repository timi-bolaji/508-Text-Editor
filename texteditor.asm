.386
.model flat,stdcall
option casemap:none

;neccessary include files + libs for now
include     \masm32\include\windows.inc
include     \masm32\include\masm32.inc
include     \masm32\include\kernel32.inc
include     \masm32\include\user32.inc
include     \masm32\include\comdlg32.inc
include     \masm32\include\gdi32.inc
include     \masm32\include\comctl32.inc
includelib  \masm32\lib\kernel32.lib
includelib  \masm32\lib\user32.lib
includelib  \masm32\lib\comdlg32.lib
includelib  \masm32\lib\gdi32.lib
includelib  \masm32\lib\comctl32.lib 

WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
FillBuffer     PROTO :DWORD,:DWORD,:BYTE
Paint_Proc     PROTO :DWORD,:DWORD
EditControl    PROTO :DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD
hEditProc      PROTO :DWORD,:DWORD,:DWORD,:DWORD
Do_Status PROTO :DWORD

.const
MAINMENU                   equ 101
IDM_OPEN                       equ  40001
IDM_SAVE                       equ 40002
IDM_CLOSE                      equ 40003
IDM_SAVEAS                     equ 40004
IDM_EXIT                       equ 40005
IDM_COPY                       equ  40006
IDM_CUT                        equ  40007
IDM_PASTE                      equ 40008
IDM_DELETE                     equ 40009
IDM_SELECTALL                  equ 40010
IDM_OPTION 			       equ 40011
IDM_UNDO			       equ 40012
IDM_REDO	                   equ 40013


RichEditID 			equ 300

.data
ClassName db "TextEdit",0
WindowName db "Text Editor",0
IsSave db "Save the file before closing?",0
hStatus       dd 0
RichEditDLL db "riched20.dll",0
RichEditClass db "RichEdit20A",0
NoRichEdit db "Cannot find riched20.dll",0
FileFilterString 		db "Text file (*.txt)",0,"*.txt",0
				db "All Files (*.*)",0,"*.*",0,0
OpenFileFail db "Cannot open the file",0
FileOpened dd FALSE
BackgroundColor dd 0FFFFFFh		; default to white
TextColor dd 0		            ; default to black

.data?
CommandLine   dd ?
hInstance     dd ?
hIcon         dd ?
hRichEdit       dd ?
hwndRichEdit dd ?
FileName db 256 dup(?)
AlternateFileName db 256 dup(?)
CustomColors dd 16 dup(?)
lpfnhEditProc dd ?
CtrlFlag      dd ?
hMnu          dd ?

.code
start:
	invoke GetModuleHandle, NULL
	mov hInstance, eax

	invoke GetCommandLine
	mov CommandLine, eax 

	invoke LoadLibrary,addr RichEditDLL
		.if eax!=0
	mov hRichEdit,eax
		invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
		invoke FreeLibrary,hRichEdit
	.else
		invoke MessageBox,0,addr NoRichEdit,addr WindowName,MB_OK or MB_ICONERROR
	.endif
	invoke ExitProcess,eax
	
WinMain proc hInst:DWORD,hPrevInst:DWORD,CmdLine:DWORD,CmdShow:DWORD
      ;Local vars
	LOCAL wc:WNDCLASSEX
	LOCAL msg:MSG
	LOCAL hwnd:DWORD

	;Fill wc
	;invoke LoadIcon,hInst,500     ; icon ID
	;mov hIcon, eax
      
	mov   wc.cbSize,SIZEOF WNDCLASSEX
	mov   wc.style, CS_HREDRAW or CS_VREDRAW
	mov   wc.lpfnWndProc, OFFSET WndProc
	mov   wc.cbClsExtra,NULL
	mov   wc.cbWndExtra,NULL
	push  hInst
	pop   wc.hInstance
	mov   wc.hbrBackground,COLOR_WINDOW+1
	mov   wc.lpszMenuName,MAINMENU
	mov   wc.lpszClassName,OFFSET ClassName
	invoke LoadIcon,NULL,IDI_APPLICATION
	mov   wc.hIcon,eax
	mov   wc.hIconSm,eax
	invoke LoadCursor,NULL,IDC_ARROW
	mov   wc.hCursor,eax

	;Register wc
	invoke RegisterClassEx, addr wc

	;Create window
	invoke CreateWindowEx,WS_EX_LEFT or WS_EX_ACCEPTFILES,
						ADDR ClassName,
						ADDR WindowName,
						WS_OVERLAPPEDWINDOW,
						0,0,500,500,
						NULL,NULL,
						hInst,NULL
	mov   hwnd,eax
	invoke ShowWindow, hwnd,SW_SHOWNORMAL
	invoke UpdateWindow, hwnd
	
    MessageLoop:
		invoke GetMessage,ADDR msg,NULL,0,0
		cmp eax, 0
		je ExitMsgLoop

    invoke TranslateMessage, ADDR msg
    invoke DispatchMessage,  ADDR msg
    jmp MessageLoop
    ExitMsgLoop:
        xor   eax, eax 
        ret
		
WinMain endp
;-------------------------------------------------------

StreamInProc proc hFile:DWORD,pBuffer:DWORD, NumBytes:DWORD, pBytesRead:DWORD
	invoke ReadFile,hFile,pBuffer,NumBytes,pBytesRead,0
	xor eax,1
	ret
StreamInProc endp

StreamOutProc proc hFile:DWORD,pBuffer:DWORD, NumBytes:DWORD, pBytesWritten:DWORD
	invoke WriteFile,hFile,pBuffer,NumBytes,pBytesWritten,0
	xor eax,1
	ret
StreamOutProc endp

CheckModifyState proc hWnd:DWORD
	invoke SendMessage,hwndRichEdit,EM_GETMODIFY,0,0
	.if eax!=0
		invoke MessageBox,hWnd,addr IsSave,addr WindowName,MB_YESNOCANCEL
		.if eax==IDYES
			invoke SendMessage,hWnd,WM_COMMAND,IDM_SAVE,0
		.elseif eax==IDCANCEL
			mov eax,FALSE
			ret
		.endif
	.endif
	mov eax,TRUE
	ret
CheckModifyState endp

SetColor proc
	LOCAL cfm:CHARFORMAT
	invoke SendMessage,hwndRichEdit,EM_SETBKGNDCOLOR,0,BackgroundColor
	invoke RtlZeroMemory,addr cfm,sizeof cfm
	mov cfm.cbSize,sizeof cfm
	mov cfm.dwMask,CFM_COLOR
	push TextColor
	pop cfm.crTextColor
	invoke SendMessage,hwndRichEdit,EM_SETCHARFORMAT,SCF_ALL,addr cfm
	ret
SetColor endp


;---------------------------------

;================ Status Proc =======================
Do_Status proc hParent:DWORD

    LOCAL sbParts[4] :DWORD

    invoke CreateStatusWindow,WS_CHILD or WS_VISIBLE or \
                              SBS_SIZEGRIP,NULL, hParent, 200
    mov hStatus, eax
      
    mov [sbParts +  0],   125    ; pixels from left
    mov [sbParts +  4],   250    ; pixels from left
    mov [sbParts +  8],   375    ; pixels from left
    mov [sbParts + 12],    -1    ; last part

    invoke SendMessage,hStatus,SB_SETPARTS,4,ADDR sbParts

    ret

Do_Status endp
;------------------------------------------------------


;==============Windows Procedure=====================
WndProc proc hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
        ;Local vars
        LOCAL var    :DWORD
        LOCAL hDC :DWORD
        LOCAL rect    :RECT
        LOCAL ps     :PAINTSTRUCT
        LOCAL chrg:CHARRANGE
        LOCAL ofn:OPENFILENAME
        LOCAL buffer1[128]:BYTE
        LOCAL FileBuffer[260]:BYTE
        LOCAL editstream:EDITSTREAM
        LOCAL hFile:DWORD
	
        ;process commands here
        .if uMsg==WM_CREATE
		invoke CreateWindowEx,WS_EX_CLIENTEDGE,addr RichEditClass,0,WS_CHILD or WS_VISIBLE or ES_MULTILINE or WS_VSCROLL or WS_HSCROLL or ES_NOHIDESEL,\
				CW_USEDEFAULT,CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,hWnd,RichEditID,hInstance,0
		mov hwndRichEdit,eax

		invoke SendMessage,hwndRichEdit,EM_LIMITTEXT,-1,0
		
		invoke SetColor
		invoke SendMessage,hwndRichEdit,EM_SETMODIFY,FALSE,0
		invoke SendMessage,hwndRichEdit,EM_EMPTYUNDOBUFFER,0,0
	.elseif uMsg==WM_INITMENUPOPUP
		mov eax,lParam
		.if ax==0		; file menu			
			.if FileOpened==TRUE	; a file is already opened
				invoke EnableMenuItem,wParam,IDM_OPEN,MF_GRAYED
				invoke EnableMenuItem,wParam,IDM_CLOSE,MF_ENABLED
				invoke EnableMenuItem,wParam,IDM_SAVE,MF_ENABLED
				invoke EnableMenuItem,wParam,IDM_SAVEAS,MF_ENABLED
			.else
				invoke EnableMenuItem,wParam,IDM_OPEN,MF_ENABLED
				invoke EnableMenuItem,wParam,IDM_CLOSE,MF_GRAYED
				invoke EnableMenuItem,wParam,IDM_SAVE,MF_GRAYED
				invoke EnableMenuItem,wParam,IDM_SAVEAS,MF_GRAYED
			.endif
		.elseif ax==1	; edit menu
		
			invoke SendMessage,hwndRichEdit,EM_CANPASTE,CF_TEXT,0
			.if eax==0		; no text in the clipboard
				invoke EnableMenuItem,wParam,IDM_PASTE,MF_GRAYED
			.else
				invoke EnableMenuItem,wParam,IDM_PASTE,MF_ENABLED
			.endif

			invoke SendMessage,hwndRichEdit,EM_CANUNDO,0,0
			.if eax==0
				invoke EnableMenuItem,wParam,IDM_UNDO,MF_GRAYED
			.else
				invoke EnableMenuItem,wParam,IDM_UNDO,MF_ENABLED
			.endif

			invoke SendMessage,hwndRichEdit,EM_CANREDO,0,0
			.if eax==0
				invoke EnableMenuItem,wParam,IDM_REDO,MF_GRAYED
			.else
				invoke EnableMenuItem,wParam,IDM_REDO,MF_ENABLED
			.endif

			invoke SendMessage,hwndRichEdit,EM_EXGETSEL,0,addr chrg
			mov eax,chrg.cpMin
			.if eax==chrg.cpMax		; no current selection
				invoke EnableMenuItem,wParam,IDM_COPY,MF_GRAYED
				invoke EnableMenuItem,wParam,IDM_CUT,MF_GRAYED
				invoke EnableMenuItem,wParam,IDM_DELETE,MF_GRAYED
			.else
				invoke EnableMenuItem,wParam,IDM_COPY,MF_ENABLED
				invoke EnableMenuItem,wParam,IDM_CUT,MF_ENABLED
				invoke EnableMenuItem,wParam,IDM_DELETE,MF_ENABLED
			.endif
		.endif
	.elseif uMsg==WM_COMMAND
		.if lParam==0		; menu commands
			mov eax,wParam
			.if ax==IDM_OPEN
				invoke RtlZeroMemory,addr ofn,sizeof ofn
				mov ofn.lStructSize,sizeof ofn
				push hWnd
				pop ofn.hwndOwner
				push hInstance
				pop ofn.hInstance
				mov ofn.lpstrFilter,offset FileFilterString
				mov ofn.lpstrFile,offset FileName
				mov byte ptr [FileName],0
				mov ofn.nMaxFile,sizeof FileName
				mov ofn.Flags,OFN_FILEMUSTEXIST or OFN_HIDEREADONLY or OFN_PATHMUSTEXIST
				invoke GetOpenFileName,addr ofn
				.if eax!=0
					invoke CreateFile,addr FileName,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
					.if eax!=INVALID_HANDLE_VALUE
						mov hFile,eax
						
						mov editstream.dwCookie,eax
						mov editstream.pfnCallback,offset StreamInProc
						invoke SendMessage,hwndRichEdit,EM_STREAMIN,SF_TEXT,addr editstream

						invoke SendMessage,hwndRichEdit,EM_SETMODIFY,FALSE,0
						invoke CloseHandle,hFile
						mov FileOpened,TRUE
					.else
						invoke MessageBox,hWnd,addr OpenFileFail,addr WindowName,MB_OK or MB_ICONERROR
					.endif
				.endif
			.elseif ax==IDM_CLOSE
				invoke CheckModifyState,hWnd
				.if eax==TRUE
					invoke SetWindowText,hwndRichEdit,0
					mov FileOpened,FALSE
				.endif
			.elseif ax==IDM_SAVE
				invoke CreateFile,addr FileName,GENERIC_WRITE,FILE_SHARE_READ,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0
				.if eax!=INVALID_HANDLE_VALUE
@@:				
					mov hFile,eax
						
					mov editstream.dwCookie,eax
					mov editstream.pfnCallback,offset StreamOutProc
					invoke SendMessage,hwndRichEdit,EM_STREAMOUT,SF_TEXT,addr editstream

					invoke SendMessage,hwndRichEdit,EM_SETMODIFY,FALSE,0
					invoke CloseHandle,hFile
				.else
					invoke MessageBox,hWnd,addr OpenFileFail,addr WindowName,MB_OK or MB_ICONERROR
				.endif
			.elseif ax==IDM_COPY
				invoke SendMessage,hwndRichEdit,WM_COPY,0,0
			.elseif ax==IDM_CUT
				invoke SendMessage,hwndRichEdit,WM_CUT,0,0
			.elseif ax==IDM_PASTE
				invoke SendMessage,hwndRichEdit,WM_PASTE,0,0
			.elseif ax==IDM_DELETE
				invoke SendMessage,hwndRichEdit,EM_REPLACESEL,TRUE,0
			.elseif ax==IDM_SELECTALL
				mov chrg.cpMin,0
				mov chrg.cpMax,-1
				invoke SendMessage,hwndRichEdit,EM_EXSETSEL,0,addr chrg
			.elseif ax==IDM_UNDO
				invoke SendMessage,hwndRichEdit,EM_UNDO,0,0
			.elseif ax==IDM_REDO
				invoke SendMessage,hwndRichEdit,EM_REDO,0,0
			
			.elseif ax==IDM_SAVEAS
				invoke RtlZeroMemory,addr ofn,sizeof ofn
				mov ofn.lStructSize,sizeof ofn
				push hWnd
				pop ofn.hwndOwner
				push hInstance
				pop ofn.hInstance
				mov ofn.lpstrFilter,offset FileFilterString
				mov ofn.lpstrFile,offset AlternateFileName
				mov byte ptr [AlternateFileName],0
				mov ofn.nMaxFile,sizeof AlternateFileName
				mov ofn.Flags,OFN_FILEMUSTEXIST or OFN_HIDEREADONLY or OFN_PATHMUSTEXIST
				invoke GetSaveFileName,addr ofn
				.if eax!=0
					invoke CreateFile,addr AlternateFileName,GENERIC_WRITE,FILE_SHARE_READ,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0
					.if eax!=INVALID_HANDLE_VALUE
						jmp @B
					.endif
				.endif
			.elseif ax==IDM_EXIT
				invoke SendMessage,hWnd,WM_CLOSE,0,0
			.endif
		.endif
	.elseif uMsg==WM_CLOSE
		invoke CheckModifyState,hWnd
		.if eax==TRUE
			invoke DestroyWindow,hWnd
		.endif
	.elseif uMsg==WM_SIZE
		mov eax,lParam
		mov edx,eax
		and eax,0FFFFh
		shr edx,16
		invoke MoveWindow,hwndRichEdit,0,0,eax,edx,TRUE		
	.elseif uMsg==WM_DESTROY
		invoke PostQuitMessage,NULL
	.else
		invoke DefWindowProc,hWnd,uMsg,wParam,lParam		
		ret
	.endif
	xor eax,eax
	ret
WndProc endp
end start