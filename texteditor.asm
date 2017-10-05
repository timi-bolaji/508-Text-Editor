.386
.model  flat,stdcall
option casemap:none

;neccessary include files + libs for now
include     \masm32\include\windows.inc
include     \masm32\include\masm32.inc
include     \masm32\include\kernel32.inc
include     \masm32\include\user32.inc
includelib  \masm32\lib\kernel32.lib
includelib  \masm32\lib\user32.lib

WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD

.data
ClassName db "TextEdit",0
WindowName db "Text Editor",0

.data?
CommandLine   dd ?
hWnd          dd ?
hInstance     dd ?
hIcon         dd ?
CtrlFlag      dd ?

.code

start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax

    invoke GetCommandLine
    mov CommandLine, eax 

    invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
    invoke ExitProcess,eax

;==============WinMain===============================
WinMain proc hInst :DWORD, hPrevInst :DWORD, CmdLine :DWORD, CmdShow :DWORD
    ;Local vars
    LOCAL wc  :WNDCLASSEX
    LOCAL msg :MSG

    ;Fill wc
    ;invoke LoadIcon,hInst,500     ; icon ID
    ;mov hIcon, eax

    mov wc.cbSize,         sizeof WNDCLASSEX
    mov wc.style,          CS_BYTEALIGNWINDOW
    mov wc.lpfnWndProc,    offset WndProc
    mov wc.cbClsExtra,     NULL
    mov wc.cbWndExtra,     NULL
    push                   hInst
    pop                    wc.hInstance
    mov wc.hbrBackground,  NULL
    mov wc.lpszMenuName,   NULL
    mov wc.lpszClassName,  offset ClassName
    invoke LoadIcon,NULL,IDI_APPLICATION 
    mov   wc.hIcon,eax 
    mov   wc.hIconSm,eax 
    invoke LoadCursor,NULL,IDC_ARROW
    mov wc.hCursor,        eax

    ;Register wc
    invoke RegisterClassEx, ADDR wc

    ;Create window
    invoke CreateWindowEx,WS_EX_LEFT or WS_EX_ACCEPTFILES,
                            ADDR ClassName,
                            ADDR WindowName,
                            WS_OVERLAPPEDWINDOW,
                            0,0,500,500,
                            NULL,NULL,
                            hInst,NULL
    mov hWnd, eax
    
    ;Show & update
    invoke ShowWindow,hWnd,SW_SHOWNORMAL
    invoke UpdateWindow,hWnd

    ;message loop
    MessageLoop:
        invoke GetMessage,ADDR msg,NULL,0,0
        cmp eax, 0
        je ExitMsgLoop

        .if msg.message == WM_KEYDOWN
            .if msg.wParam == VK_ESCAPE
                invoke SendMessage,hWnd,WM_SYSCOMMAND,SC_CLOSE,NULL
            .elseif msg.wParam == VK_CONTROL
                nop ;mov MessageLoop, 1                   ; flag set
            .endif
        .endif

        .if msg.message == WM_KEYUP
            .if msg.wParam == VK_CONTROL
                mov CtrlFlag, 0                   ; flag clear
            .elseif msg.wParam == 54h           ; Ctrl + T
            .if CtrlFlag == 1
                invoke SendMessage,hWnd,WM_COMMAND,1105,0
            .endif
            .elseif msg.wParam == 4Eh           ; Ctrl + N
                .if CtrlFlag == 1
                invoke SendMessage,hWnd,WM_COMMAND,1000,0
            .endif
            .elseif msg.wParam == 57h           ; Ctrl + W
                .if CtrlFlag == 1
                invoke SendMessage,hWnd,WM_COMMAND,1001,0
                jmp MessageLoop
            .endif
            .elseif msg.wParam == 4Fh           ; Ctrl + O
                .if CtrlFlag == 1
                invoke SendMessage,hWnd,WM_COMMAND,1002,0
            .endif
            .elseif msg.wParam == 53h           ; Ctrl + S
                .if CtrlFlag == 1
                invoke SendMessage,hWnd,WM_COMMAND,1003,0
            .endif
            .elseif msg.wParam == 42h           ; Ctrl + B
                .if CtrlFlag == 1
                invoke SendMessage,hWnd,WM_COMMAND,1004,0
            .endif
        .endif
      .endif
    ; ------------------------------------------------
    invoke TranslateMessage, ADDR msg
    invoke DispatchMessage,  ADDR msg
    jmp MessageLoop

    ExitMsgLoop:
        xor   eax, eax 
        ret 
WinMain endp
;------------------------------------------------------

;==============Windows Procedure=====================
WndProc proc hWin :DWORD, uMsg :DWORD, wParam :DWORD, lParam :DWORD
    ;Local vars
    LOCAL hDC :DWORD

    ;process commands here

    .if uMsg == WM_DESTROY
        invoke PostQuitMessage,NULL
        ret
    .endif

    invoke DefWindowProc,hWin,uMsg,wParam,lParam

    ret
WndProc endp
;====================================================

end start