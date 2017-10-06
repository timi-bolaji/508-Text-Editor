.386 
.model flat,stdcall 
option casemap:none 
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

.const 
MIDR_MAINMENU 	equ 201 
MIDR_CHILDMENU	equ 202 
MIDM_EXIT 		equ 50001 
MIDM_TILEHORZ	equ 50002 
MIDM_TILEVERT	equ 50003
MIDM_CASCADE	equ 50004 
MIDM_NEW 		equ 50005 
MIDM_CLOSE	    equ 50006

; constants important for the richedit windows

MAINMENU                   equ 801
IDM_OPEN                   equ 40001
IDM_SAVE                   equ 40002
IDM_CLOSE                  equ 40003
IDM_SAVEAS                 equ 40004
IDM_EXIT                   equ 40005
IDM_COPY                   equ 40006
IDM_CUT                    equ 40007
IDM_PASTE                  equ 40008
IDM_DELETE                 equ 40009
IDM_SELECTALL              equ 40010
IDM_OPTION 			       equ 40011
IDM_UNDO			       equ 40012
IDM_REDO	               equ 40013

RichEditID 			equ 300
;=================================================================
.data 
ClassName 	db "MDIASMClass",0 
MDIClientName	db "MDICLIENT",0 
MDIChildClassName	db "TextEdit",0 
MDIChildTitle	db "Text Editor",0 
AppName		db "Smartpad - Multi-window text editor",0 
ClosePromptMessage	db "Are you sure you want to close this window?",0

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

;================================================================

.data? 
CommandLine dd ?
hInstance 	dd ?
hIcon       dd ?
hRichEditDLL   dd ?
hwndRichEdit    dd ?
hMainMenu 	dd ? 
hwndClient 	dd ? 
hChildMenu 	dd ? 
mdicreate		MDICREATESTRUCT <> 
hwndFrame 	dd ?

FileName db 256 dup(?)
AlternateFileName db 256 dup(?)
CustomColors dd 16 dup(?)

.code 
start: 
	invoke GetModuleHandle, NULL    
	mov hInstance,eax

    invoke GetCommandLine
	mov CommandLine, eax 

    invoke LoadLibrary,addr RichEditDLL
	.if eax!=0
	    mov hRichEditDLL,eax
		invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
		invoke FreeLibrary,hRichEditDLL
	.else
		invoke MessageBox,0,addr NoRichEdit,addr AppName,MB_OK or MB_ICONERROR
    .endif

	invoke ExitProcess,eax 

WinMain proc hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD    
	LOCAL wc:WNDCLASSEX 
	LOCAL msg:MSG 
	;=============================================    
	; Register the frame window class 
	;=============================================    
	mov wc.cbSize,SIZEOF WNDCLASSEX 
	mov wc.style, CS_HREDRAW or CS_VREDRAW 
	mov wc.lpfnWndProc,OFFSET WndProc 
	mov wc.cbClsExtra,NULL 
	mov wc.cbWndExtra,NULL 
	push hInstance
	pop wc.hInstance 
	mov wc.hbrBackground,COLOR_APPWORKSPACE 
	mov wc.lpszMenuName,MIDR_MAINMENU
	mov wc.lpszClassName,OFFSET ClassName
	invoke LoadIcon,NULL,IDI_APPLICATION 
	mov wc.hIcon,eax 
	mov wc.hIconSm,eax 
	invoke LoadCursor,NULL,IDC_ARROW 
	mov wc.hCursor,eax    
	invoke RegisterClassEx, addr wc 

	;================================================    
	; Register the MDI child window class 
	;================================================
	mov   wc.lpfnWndProc, offset ChildProc
	mov   wc.hbrBackground,COLOR_WINDOW+1
	mov   wc.lpszClassName,offset MDIChildClassName
	invoke RegisterClassEx,addr wc 

	invoke CreateWindowEx,NULL,ADDR ClassName,ADDR AppName,\ 
			WS_OVERLAPPEDWINDOW or WS_CLIPCHILDREN,CW_USEDEFAULT,\    
			CW_USEDEFAULT,CW_USEDEFAULT,CW_USEDEFAULT,NULL,0,\ 
			hInst,NULL 
	mov hwndFrame,eax    
	invoke LoadMenu,hInstance, MIDR_CHILDMENU 
	mov hChildMenu,eax 
	invoke ShowWindow,hwndFrame,SW_SHOWNORMAL 
	invoke UpdateWindow, hwndFrame 
	.while TRUE 
		invoke GetMessage,ADDR msg,NULL,0,0 
		.break .if (!eax) 
		invoke TranslateMDISysAccel,hwndClient,addr msg 
		.if !eax 
			invoke TranslateMessage, ADDR msg 
			invoke DispatchMessage, ADDR msg 
		.endif 
	.endw 
	invoke DestroyMenu, hChildMenu 
	mov eax,msg.wParam 
	ret 
WinMain endp 

WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM 
	LOCAL ClientStruct:CLIENTCREATESTRUCT    
	.if uMsg==WM_CREATE 
		invoke GetMenu,hWnd 
		mov hMainMenu,eax 
		invoke GetSubMenu,hMainMenu,2    
		mov ClientStruct.hWindowMenu,eax 
		mov ClientStruct.idFirstChild,900 
		INVOKE CreateWindowEx,NULL,ADDR MDIClientName,NULL,\ 
				WS_CHILD or WS_VISIBLE or WS_CLIPCHILDREN,CW_USEDEFAULT,\
				CW_USEDEFAULT,CW_USEDEFAULT,CW_USEDEFAULT,hWnd,NULL,\ 
				hInstance,addr ClientStruct    
		mov hwndClient,eax
		;======================================= 
		; Initialize the MDICREATESTRUCT 
		;======================================= 
		mov mdicreate.szClass,offset MDIChildClassName 
		mov mdicreate.szTitle,offset MDIChildTitle
		push hInstance    
		pop mdicreate.hOwner 
		mov mdicreate.x,CW_USEDEFAULT 
		mov mdicreate.y,CW_USEDEFAULT    
		mov mdicreate.lx,CW_USEDEFAULT 
		mov mdicreate.ly,CW_USEDEFAULT 
	.elseif uMsg==WM_COMMAND    
		.if lParam==0 
			mov eax,wParam 
			.if ax==MIDM_EXIT 
				invoke SendMessage,hWnd,WM_CLOSE,0,0    
			.elseif ax==MIDM_TILEHORZ 
				invoke SendMessage,hwndClient,WM_MDITILE,MDITILE_HORIZONTAL,0 
			.elseif ax==MIDM_TILEVERT 
				invoke SendMessage,hwndClient,WM_MDITILE,MDITILE_VERTICAL,0    
			.elseif ax==MIDM_CASCADE 
				invoke SendMessage,hwndClient,WM_MDICASCADE,MDITILE_SKIPDISABLED,0	   
			.elseif ax==MIDM_NEW 
				invoke SendMessage,hwndClient,WM_MDICREATE,0,addr mdicreate   
			.elseif ax==MIDM_CLOSE 
				invoke SendMessage,hwndClient,WM_MDIGETACTIVE,0,0
				invoke SendMessage,eax,WM_CLOSE,0,0
            ; Child menu options
			.else
                invoke SendMessage,hwndClient,WM_MDIGETACTIVE,0,0
                invoke SendMessage,eax,WM_COMMAND,wParam,0 
				invoke DefFrameProc,hWnd,hwndClient,uMsg,wParam,lParam	   
				ret
			.endif 
		.endif 
	.elseif uMsg==WM_DESTROY 
		invoke PostQuitMessage,NULL 
	.else 
		invoke DefFrameProc,hWnd,hwndClient,uMsg,wParam,lParam 
		ret 
	.endif 
	xor eax,eax 
	ret 
WndProc endp

;===========================================================================================
;Other procs relevant to the richedit business

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
		invoke MessageBox,hWnd,addr IsSave,addr MDIChildTitle,MB_YESNOCANCEL
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

;===========================================================================================

ChildProc proc hChild:DWORD,uMsg:DWORD,wParam:DWORD,lParam:DWORD

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

	.if uMsg==WM_MDIACTIVATE    
		mov eax,lParam 
		.if eax==hChild 
			invoke GetSubMenu,hChildMenu,2 
			mov edx,eax 
			invoke SendMessage,hwndClient,WM_MDISETMENU,hChildMenu,edx 
		.else 
			invoke GetSubMenu,hMainMenu,2    
			mov edx,eax 
			invoke SendMessage,hwndClient,WM_MDISETMENU,hMainMenu,edx 
		.endif 
		invoke DrawMenuBar,hwndFrame

    .elseif uMsg==WM_CREATE
		invoke CreateWindowEx,WS_EX_CLIENTEDGE,addr RichEditClass,0,WS_CHILD or WS_VISIBLE or ES_MULTILINE or WS_VSCROLL or WS_HSCROLL or ES_NOHIDESEL,\
				CW_USEDEFAULT,CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,hChild,RichEditID,hInstance,0
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
				push hChild
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
						invoke MessageBox,hChild,addr OpenFileFail,addr MDIChildTitle,MB_OK or MB_ICONERROR
					.endif
				.endif
			.elseif ax==IDM_CLOSE
				invoke CheckModifyState,hChild
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
					invoke MessageBox,hChild,addr OpenFileFail,addr MDIChildTitle,MB_OK or MB_ICONERROR
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
				push hChild
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
				invoke SendMessage,hChild,WM_CLOSE,0,0
			.else
				invoke DefMDIChildProc,hChild,uMsg,wParam,lParam
			.endif
		.endif
	
	.elseif uMsg==WM_SIZE
		mov eax,lParam
		mov edx,eax
		and eax,0FFFFh
		shr edx,16
		invoke MoveWindow,hwndRichEdit,0,0,eax,edx,TRUE

    .elseif uMsg==WM_CLOSE   
		invoke MessageBox,hChild,addr ClosePromptMessage,addr AppName,MB_YESNO 
		.if eax==IDYES 
			;invoke DestroyWindow,hChild   
			invoke SendMessage,hwndClient,WM_MDIDESTROY,hChild,0 
		.endif 
	.else 
		invoke DefMDIChildProc,hChild,uMsg,wParam,lParam    
		ret
    .endif

	xor eax,eax 
	ret 
ChildProc endp 

end start 