%ifndef PRINT_V2_ASM
%define PRINT_V2_ASM

%include "memory_v2.asm"

%macro PRINT_REG 1
    push rax
    push rdi
    push rsi
    push rdx

    mov rdi, %1
    call itoa
        
    push rax
        
    mov rdi, rax
    call print
    
    PRINTLN ""
        
    pop rdi
    mov rsi, ITOA_STR_SIZE
    call free
   

    pop rdx
    pop rsi
    pop rdi
    pop rax
%endmacro
    
%macro PRINTLN 1
    section .data
        %%str: db %1, 10  
        %%len equ $ - %%str 
    
    section .text
        push rax            
        push rdi
        push rsi
        push rdx
        
        mov rax, 1          
        mov rdi, 1          
        mov rsi, %%str      
        mov rdx, %%len      
        syscall
        
        pop rdx             
        pop rsi
        pop rdi
        pop rax
%endmacro

%macro PRINT_ERRNO 1
    section .data
        %%str: db %1, 32
        %%len equ $ - %%str 
    section .text
        push rax            
        push rdi
        push rsi
        push rdx
        push rax
        
        mov rax, SYSCALL_WRITE          
        mov rdi, STDOUT          
        mov rsi, %%str      
        mov rdx, %%len      
        syscall
        
        pop rax
        PRINT_REG rax
        
        pop rdx             
        pop rsi
        pop rdi
        pop rax
%endmacro 


section .data
    SYSCALL_WRITE equ 1
    STDOUT equ 1
    ITOA_STR_SIZE equ 32

section .text
    global itoa, print, PRINTLN, PRINT_ERRNO, PRINT_REG, copy_until, main
    extern malloc, free
   

    
; Will copy the bytes from RDI to RSI until the char code in RDX or null terminator is found
; RDI = Target memory address start
; RSI = Source string address start
; RDX = Char code 1
; RCX = Char code 2 or Zero
; Returns number of bytes writen in rax
copy_until:
    xor r10, r10
    cld

.next_char:
    lodsb
    cmp al, dl
    je .end_copy
    
    cmp al, cl
    je .end_copy
    
    cmp al, 0
    je .end_copy
    
    stosb
    inc r10
    
    jmp .next_char
.end_copy:
    mov rax, r10
    mov [rdi + rcx + 1], byte 0 
    ret
    
    
    
str_copy:    
    xor rcx, rcx
.loop:
    test rax, rax               
    jz .done
    movzx rax, byte [rdi + rcx]   
    mov [rsi + rcx], rax
    inc rcx
    jmp .loop
.done:
    mov rax, rcx              
    ret

print:
    mov rax, SYSCALL_WRITE
    mov rsi, rdi
    add rsi, 8 
    movzx rdx, word [rdi]
    mov rdi, STDOUT
    syscall
    ret
    
; RDI = INT to Convert
; Returns new null terminated string address in RAX    
itoa:
    push rdi
    mov rdi, ITOA_STR_SIZE
    call malloc
    test rax, rax
    js .return
   
    mov r11, rax
    
    pop rdi
    mov r10, 10
    mov rax, rdi
    xor rcx, rcx
.check_negative:
    test rax, rax
    jns .convert_digit
    neg rax
    mov r12, -1
.convert_digit:
    xor rdx, rdx
    div r10
    add rdx,  '0'
    push rdx
    inc rcx
    test rax, rax
    jnz .convert_digit
    
    mov rax, r11
    mov byte [r11 + 4], 32 ; size
    test r12, r12
    js .calc_negative_number_len


    mov [r11], rcx ; len

    add r11, 8
    jmp .write_string

.calc_negative_number_len:
    mov r12, rcx
    inc r12
    mov [r11], r12 
    add r11, 8
    mov byte [r11], '-'
    inc r11
.write_string:
    pop rdx
    mov [r11], rdx
    inc r11
    dec rcx
    test rcx, rcx
    jnz .write_string
    mov byte [r11], 0  
.return:
    ret 
    
%endif