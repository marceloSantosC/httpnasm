%ifndef FILE_V2_ASM
%define FILE_V2_ASM

%include "print_v2.asm"
%include "memory_v2.asm"


struc sockaddr
    .family: resb 2
    .port: resb 2
    .address: resb 12
    alignb 8           
endstruc

section .data
    string db '/home/marcelo17082000/test/index.html HTTP/1.1 Host: localhost:8080 Connection: ABCASDADA ? ADSADSAD', 0
    string_len equ $ - string
    
section .bss
    string_cp resb 512

section .text
    global file_size_stat
    extern PRINT_ERRNO, malloc, free, copy_until
    
not:
    mov rbp, rsp; for correct debugging
    mov rdi, string_cp
    mov rsi, string
    mov rdx, '?'
    mov rcx, ' '
    call copy_until
    
    mov rdx, rax
    mov rdi, 1
    mov rsi, string_cp
    mov rax, 1
    syscall
    
    mov rdi, string_cp
    call file_size_stat
    xor rcx, rcx
    ret

; RDI = FILE PATH
; RETURNS FILE SIZE IN RAX OR NEGATIVE VALUE IF ERROR (-2 IF NOT FOUND) 
file_size_stat:
    %define SYSCALL_STAT 4
    %define STAT_STRUCT_SIZE_FIELD 48
    %define STAT_STRUCT_SIZE 144
    
    push rdi
    mov rdi, STAT_STRUCT_SIZE
    call malloc
    
    pop rdi
    mov rsi, rax
    push rsi
    mov rax, SYSCALL_STAT                           
    syscall    
                
    test rax, rax
    js .file_size_stat_error
    
    pop rsi
    mov rax, [rsi + STAT_STRUCT_SIZE_FIELD]
    push rax
    
    mov rdi, rsi
    mov rsi, STAT_STRUCT_SIZE
    call free 
    
    pop rax
    ret
.file_size_stat_error:
    pop rdi
    push rax
    mov rsi, STAT_STRUCT_SIZE
    call free 
    
    pop rax
    PRINT_ERRNO "STAT SYSCALL RETURNED ERRNO"
    ret 
%endif