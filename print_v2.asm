%ifndef PRINT_V2_ASM
%define PRINT_V2_ASM

%include "memory_v2.asm"

section .data
    SYSCALL_WRITE equ 1
    STDOUT equ 1
    ITOA_STR_SIZE equ 32

section .text
    global itoa, print, PRINTLN, PRINT_ERRNO, main
    extern malloc, free
    
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
    push rbp
    mov rbp, rsp

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
    pop rbp
    ret 
    
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
        
        mov rax, SYSCALL_WRITE          
        mov rdi, STDOUT          
        mov rsi, %%str      
        mov rdx, %%len      
        syscall
        
        mov rdi, rax
        call itoa
        
        movzx rdx, word [rax]
        mov byte [rax + rdx + 1], 10
        
        push rax
        
        mov rdi, rax
        call print
        
        pop rdi
        mov rsi, ITOA_STR_SIZE
        call free
        
        pop rdx             
        pop rsi
        pop rdi
        pop rax
%endmacro 

%endif