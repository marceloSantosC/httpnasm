
%include "print_v2.asm"
%include "memory_v2.asm"

section .data
    ; ASCII Codes
    CR equ 13
    LF equ 10
    SPACE equ 32
    ZERO equ 48
    DOUBLE_QUOTES equ 34
    
    HTTP_VERSION db "HTTP/1.0" 
    
    ; Headers
    SERVER_HEADER db "Server: HTTPNASM/1.0", CR, LF
    SERVER_HEADER_len equ $ - SERVER_HEADER
    
    CONNECTION_HEADER db "Connection: close", CR, LF
    CONNECTION_HEADER_len equ $ - CONNECTION_HEADER
    
    CONTENT_TYPE_HEADER db "Content-Type: text/html", CR, LF
    CONTENT_TYPE_HEADER_len equ $ - CONTENT_TYPE_HEADER
    
    CONTENT_LENGTH_HEADER db "Content-Length: "
    CONTENT_LENGTH_HEADER_len equ $ - CONTENT_LENGTH_HEADER
    file_size dq 0
    
    ; Status Line
    OK_STATUS_LINE db "HTTP/1.0 200 OK", CR, LF
    OK_STATUS_LINE_len equ $ - OK_STATUS_LINE
    NOT_FOUND_STATUS_LINE db "HTTP/1.0 404 Not Found", CR, LF
    NOT_FOUND_STATUS_LINE_len equ $ - NOT_FOUND_STATUS_LINE
    
    ; Content Separator
    CONTENT_SEPARATOR db CR, LF
    CONTENT_SEPARATOR_len equ $ - CONTENT_SEPARATOR
    
    file_path db "/home/marcelo17082000/test/index1.html", 0
section .bss
    fd_pointer resq 1

section .text
    global answer_request
    extern PRINTLN, PRINT_ERRNO, print, itoa, malloc


; RDI = FD PTR
; RSI = REQUEST URL PTR
; RDX = REQUEST CONTENT PTR
answer_request:
    mov [fd_pointer], rdi
    call write_status_line
    call write_default_headers
    call write_response_content
    ret
    
    
write_response_content:
    mov rdi, file_path
    call file_size_stat
    mov rdi, rax
    push rdi
    call write_content_legth
    
    mov rdi, CONTENT_SEPARATOR
    mov rsi, CONTENT_SEPARATOR_len
    call write
    
    %define FILE_BUFFER_SIZE 2048
    %define SYSCALL_SYSOPEN 2
    %define SYSOPEN_O_RDONLY 0
    %define SYSCALL_SEND_FILE 40
    %define SYSCALL_SYSCLOSE 3
    
    mov rax, SYSCALL_SYSOPEN
    lea rdi, [file_path]
    mov rsi, SYSOPEN_O_RDONLY
    xor rdx, rdx
    syscall
    test rax, rax
    js .write_response_error
    

    mov rdi, [fd_pointer]
    mov rsi, rax
    xor rdx, rdx
    pop r10
    push rax
    mov rax, SYSCALL_SEND_FILE
    syscall
    test rax, rax
    js .write_response_error
    
    pop rdi
    mov rax, SYSCALL_SYSCLOSE
    syscall
    test rax, rax
    js .write_response_error
    ret
.write_response_error:
    PRINT_ERRNO "FAILED TO WRITE RESPONSE"
    mov rax, -100
    ret
    
; RDI = Content Legth value
write_content_legth:
    push rdi
    mov rdi, CONTENT_LENGTH_HEADER
    mov rsi, CONTENT_LENGTH_HEADER_len
    call write

    pop rdi    
    call itoa
     
    push rax
    mov rdi, rax
    call write_str 
    
    pop rdi
    mov rsi, 32
    call free
    
    mov rdi, CONTENT_SEPARATOR
    mov rsi, CONTENT_SEPARATOR_len
    call write
    ret

 
; RDI = file path 
; Returns file size in rax  
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
    PRINT_ERRNO "file_size_stat returned error with errno "
    ret 

    
write_default_headers:
    mov rdi, SERVER_HEADER
    mov rsi, SERVER_HEADER_len
    call write
    
    mov rdi, CONNECTION_HEADER
    mov rsi, CONNECTION_HEADER_len
    call write
    
    mov rdi, CONTENT_TYPE_HEADER
    mov rsi, CONTENT_TYPE_HEADER_len
    call write
    
    
    ret

write_status_line:
    mov rdi, OK_STATUS_LINE
    mov rsi, OK_STATUS_LINE_len
    call write
    ret
    
; RDI = Content
; RSI = Length
write: 
    mov rax, 1
    mov rdx, rsi
    mov rsi, rdi              
    mov rdi, [fd_pointer]          
    syscall
    ret

; RDI = String pointer
write_str:
    movzx rdx, word [rdi]
    add rdi, 8
    mov rsi, rdi
    mov rdi, [fd_pointer]
    mov rax, 1
    syscall
    ret
    