;
;   Example for Inter Process Communication
;
;   Compile with FASM for Menuet
;

use32

               org    0x0

               db     'MENUET01'              ; 8 byte id
               dd     0x01                    ; header version
               dd     START                   ; start of code
               dd     I_END                   ; size of image
               dd     0x100000                ; memory for app
               dd     0x7fff0                 ; esp
               dd     0x0 , 0x0               ; I_Param , I_Icon


START:                          ; start of execution


    mov  eax,60                 ; IPC
    mov  ebx,1                  ; define receive area
    mov  ecx,received_messages  ; pointer to start
    mov  edx,1000               ; size of area
    int  0x40

    mov  eax,40                 ; WANTED EVENTS
    mov  ebx,01000111b          ; IPC 7 + defaults
    int  0x40

    mov  [received_messages+8],dword 0*256+0
    mov  [received_messages+12],dword 0

    call draw_window            ; at first, draw the window

still:

    mov  eax,23                 ; wait here for event
    mov  ebx,50
    int  0x40

    cmp  eax,1                  ; redraw request ?
    je   red
    cmp  eax,2                  ; key in buffer ?
    je   key
    cmp  eax,3                  ; button in buffer ?
    je   button

    cmp  eax,7                  ; IPC ?
    jne  no_ipc
    call display_ipc_messages
    jmp  still
  no_ipc:

    jmp  still

  red:                          ; redraw
    call draw_window
    jmp  still

  key:                          ; key
    mov  eax,2                  ; just read it and ignore
    int  0x40
    jmp  still

  button:                       ; button
    mov  eax,17                 ; get id
    int  0x40

    cmp  ah,1                   ; button id=1 ?
    jne  noclose
    mov  eax,-1                 ; close this program
    int  0x40
  noclose:

    cmp  ah,2
    jne  no_read
    call read_string

    movzx eax,byte [message]
    sub   eax,48
    imul  eax,10
    movzx ebx,byte [message+1]
    add   eax,ebx
    sub   eax,48
    imul  eax,10
    movzx ebx,byte [message+2]
    add   eax,ebx
    sub   eax,48
    imul  eax,10
    movzx ebx,byte [message+3]
    add   eax,ebx
    sub   eax,48

    mov   [PID],eax

    mov  eax,60                 ; IPC
    mov  ebx,2                  ; send message
    mov  ecx,[PID]
    mov  edx,message+4
    mov  esi,20;[message_size]
    int  0x40

    jmp  still
  no_read:


    cmp  ah,3
    jne  no_messages_pop        ; pop the first out
    call ipc_message_pop
    jmp  still
  no_messages_pop:

    jmp  still


ipc_message_pop:

    pusha

    cmp  [received_messages+4],dword 8
    je   already_empty

    mov  [received_messages],byte 1  ; lock the area

    push dword [received_messages+4]

    mov  ecx,[received_messages+12]

    sub  [received_messages+4],ecx
    sub  [received_messages+4],dword 8

    mov  edi,received_messages+8
    mov  esi,edi
    add  esi,ecx
    add  esi,8

    pop  ecx

    cld
    rep  movsb

    call display_ipc_messages

    mov  [received_messages],byte 0  ; free the area

  already_empty:

    popa
    ret



 display_ipc_messages:

    pusha

    mov  eax,13
    mov  ebx,25*65536+245
    mov  ecx,105*65536+90
    mov  edx,0xdddddd
    int  0x40

    cmp  [received_messages+4],dword 8  ; empty list
    je   ipma1

    mov  ebx,25*65536+105           ; draw info text with function 4
    mov  ecx,0x224466
    mov  edx,received_messages+8
    mov  esi,40
    mov  [counter],0
  newline2:
    pusha
    mov  ecx,[edx]
    and  ecx,0xfff
    mov  edx,ebx
    mov  eax,47
    mov  ebx,4*65536
    mov  esi,0xff0000
    int  0x40
    popa
    pusha
    mov  esi,20
    add  edx,8
    add  ebx,30*65536
    mov  eax,4
    int  0x40
    popa

    add  ebx,10
    mov  edi,[edx+4]
    add  edi,8
    and  edi,0xfff
    add  edx,edi

    mov  edi,[received_messages+4]
    add  edi,received_messages
    cmp  edx,edi
    jge  ipma1

    inc  [counter]
    cmp  [counter],8
    jbe  newline2

   ipma1:

    popa
    ret


counter   dd  0x0


;   *********************************************
;   *******  WINDOW DEFINITIONS AND DRAW ********
;   *********************************************


draw_window:

    mov  eax,12                    ; function 12:tell os about windowdraw
    mov  ebx,1                     ; 1, start of draw
    int  0x40

                                   ; DRAW WINDOW
    mov  eax,0                     ; function 0 : define and draw window
    mov  ebx,100*65536+290         ; [x start] *65536 + [x size]
    mov  ecx,100*65536+220         ; [y start] *65536 + [y size]
    mov  edx,0x03ffffff            ; color of work area RRGGBB,8->color gl
    mov  esi,0x808899ff            ; color of grab bar  RRGGBB,8->color gl
    mov  edi,0x008899ff            ; color of frames    RRGGBB
    int  0x40

                                   ; WINDOW LABEL
    mov  eax,4                     ; function 4 : write text to window
    mov  ebx,8*65536+8             ; [x start] *65536 + [y start]
    mov  ecx,0x00ddeeff            ; color of text RRGGBB
    mov  edx,labelt                ; pointer to text beginning
    mov  esi,labellen-labelt       ; text length
    int  0x40

    mov  eax,9
    mov  ebx,process_info
    mov  ecx,-1
    int  0x40

    mov  eax,47
    mov  ebx,4*65536
    mov  ecx,[process_info+30]
    mov  edx,180*65536+35
    mov  esi,0x000000
    int  0x40

    mov  eax,8                     ; MESSAGE
    mov  ebx,25*65536+87
    mov  ecx,50*65536+16
    mov  edx,2
    mov  esi,0x5588dd
    int  0x40

     mov  eax,8                     ; POP
     mov  ebx,216*65536+53
    mov  ecx,80*65536+16
    mov  edx,3
    mov  esi,0x5588dd
    int  0x40

    mov  ebx,25*65536+35           ; draw info text with function 4
    mov  ecx,0x224466
    mov  edx,text
    mov  esi,40
  newline:
    mov  eax,4
    int  0x40
    add  ebx,10
    add  edx,40
    cmp  [edx],byte 'x'
    jne  newline

    call display_ipc_messages

    mov  eax,12                    ; function 12:tell os about windowdraw
    mov  ebx,2                     ; 2, end of draw
    int  0x40

    ret




read_string:

    pusha

    mov  [addr],dword message
    mov  [ya],55
    mov  [xa],120

    mov  ecx,20
    mov  edi,[addr]
    mov  al,' '
    cld
    rep  stosb

    call print_text

    mov  edi,[addr]

  f11:
    mov  eax,10
    int  0x40
    cmp  eax,2
    jz   fbu

  exit_readkey:

    popa
    ret

  fbu:
    mov  eax,2
    int  0x40  ; get key
    shr  eax,8

    cmp  eax,13
    je   exit_readkey

    cmp  eax,8
    jnz  nobs
    cmp  edi,[addr]
    jz   f11
    sub  edi,1
    mov  [edi],byte ' '
    call print_text
    jmp  f11
  nobs:

    cmp  eax,31
    jbe  f11
    cmp  eax,95
    jb   keyok
    sub  eax,32
  keyok:
    mov  [edi],al

    call print_text

    add  edi,1
    mov  esi,[addr]
    add  esi,20
    cmp  esi,edi
    jnz  f11

    popa
    ret



print_text:

    mov  eax,13
    mov  ebx,[xa]
    shl  ebx,16
    add  ebx,25*6
    mov  ecx,[ya]
    shl  ecx,16
    mov  cx,8
    mov  edx,0xffffff
    int  0x40

    mov  eax,4
    mov  ebx,[xa]
    shl  ebx,16
    add  ebx,[ya]
    mov  ecx,0x000000
    mov  edx,[addr]
    mov  esi,25
    int  0x40

    ret






; DATA AREA

ya   dd  0x0
xa   dd  0x0
addr dd  0x0

text:
    db 'PROCESS ID FOR THIS APP :               '
    db '                                        '
    db '  PID:MESSAGE   0130 EXAMPLE MESSAGE    '
    db '                                        '
    db '                                        '
    db 'RECEIVED:                          POP  '
    db 'x <- END MARKER, DONT DELETE            '


labelt:
       db   'IPC - START ATLEAST TWO IPC EXAMPLES'
labellen:

process_info:  times 256 dd 0


message:   times 70  db  0
PID:                 dd  0x0
message_size:        dd  20

received_messages:

      db  0      ; lock byte
      db  0,0,0  ; reserved
      dd  8      ; pointer to free msg position from received_messages

; Sender PID
; Msg length
; Msg data


I_END:


