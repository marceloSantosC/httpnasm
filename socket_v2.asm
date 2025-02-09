%include "print_v2.asm"
%include "file_v2.asm"
%include "constants.asm"

struc sockaddr
    .family: resb 2
    .port: resb 2
    .address: resb 12
    alignb 8           
endstruc

section .data
    SOCKET_PORT equ 0x901F 

section .bss
    address: resb sockaddr_size   
    socket_fd resb 8
    request_fd resb 8
    request_method resb 8
    request_path resb 256
    request_path_len resb 1
    request_buffer resb REQUEST_BUFFER_SIZE
        
section .text
    global main
    extern PRINTLN, PRINT_ERRNO, file_size_stat
    
main:
    mov rbp, rsp; for correct debugging
    mov rdi, SOCKET_PORT
    call open_socket
    
    mov [socket_fd], rax

    
.accept_loop:
    %define ACCEPTS_ALL_ADDRESSES 0
    %define SYSCALL_ACCEPT 43 
    mov rdi, [socket_fd]
    mov rax, SYSCALL_ACCEPT
    mov rsi, ACCEPTS_ALL_ADDRESSES
    xor rdx, rdx
    syscall
    
    test rax, rax
    js .accept_error
.read_request:
    %define REQUEST_BUFFER_SIZE 2048
    %define SYSCALL_READ 0

    mov [request_fd], rax
    mov rdi, [request_fd]
    mov rax, SYSCALL_READ      
    mov rsi, request_buffer
    mov rdx, REQUEST_BUFFER_SIZE
    syscall
        
    test rax, rax
    js .proccess_error
   
    
    ; TODO: ADICIONAR UM LIMITE A COPY_UNTIL, SE ELE CHEGAR A ESSE LIMITE A EXECUÇÃO RETORNA UM ERRO (LIMITE = RAX(BYTES NA REQUEST))
    ; ISSO EVITARÁ QUE UMA REQUEST MAL FORMADA CAUSE COMPORTAMENTO INESPERADO
    mov rdi, request_method 
    mov rsi, request_buffer
    mov rdx, ' '
    xor rcx, rcx
    call copy_until
    
    mov rdi, request_path 
    mov rsi, request_buffer
    inc rax
    add rsi, rax
    mov rdx, '?'
    mov rcx, ' '
    call copy_until
    
    mov [request_path_len], rax
.write_response:
    mov rdi, request_path
    call file_size_stat

    %define SYSCALL_WRITE 1
    test rax, rax ; error = file not found or acessible
    js .write_404_response

    
.write_200_response:
    push rax ; File length (int)
    push rax ; (for future use)
    
    mov rdi, [request_fd]
    mov rsi, OK_STATUS_LINE
    mov rdx, OK_STATUS_LINE_len
    mov rax, SYSCALL_WRITE
    syscall
    
    mov rdi, [request_fd]
    mov rsi, CONTENT_LENGTH_HEADER
    mov rdx, CONTENT_LENGTH_HEADER_len
    mov rax, SYSCALL_WRITE
    syscall

    pop rdi ; File length (int)
    call itoa 
    push rax ; File length string ptr
    
    mov rdi, [request_fd]
    mov rsi, rax
    add rsi, 8 ; string start (4b for len, 4b for size)
    movzx rdx, word [rax] ; string len (1st 4 bytes)
    mov rax, SYSCALL_WRITE
    syscall

    pop rdi ; File length string ptr
    mov rsi, 32
    call free
    
    mov rdi, [request_fd]
    mov rsi, CONTENT_SEPARATOR
    mov rdx, CONTENT_SEPARATOR_len
    mov rax, SYSCALL_WRITE
    syscall
    
    mov rdi, [request_fd]
    mov rsi, CONTENT_SEPARATOR
    mov rdx, CONTENT_SEPARATOR_len
    mov rax, SYSCALL_WRITE
    syscall
    
.write_file_content:
    %define FILE_BUFFER_SIZE 2048
    %define SYSCALL_SYSOPEN 2
    %define SYSOPEN_O_RDONLY 0
    %define SYSCALL_SEND_FILE 40
    %define SYSCALL_SYSCLOSE 3
    
    mov rax, SYSCALL_SYSOPEN
    mov rdi, request_path
    mov rsi, SYSOPEN_O_RDONLY
    xor rdx, rdx
    syscall
    
    test rax, rax
    js .proccess_error
    
    mov rdi, [request_fd]
    mov rsi, rax
    xor rdx, rdx
    pop r10 ; File length (int)
    push rax ; Open file fd
    mov rax, SYSCALL_SEND_FILE
    syscall
    
    test rax, rax
    js .proccess_error
    
    pop rdi
    mov rax, SYSCALL_SYSCLOSE
    syscall
    
    
    jmp .accept_loop
    
.write_404_response:
    mov rdi, [request_fd]
    mov rsi, NOT_FOUND_STATUS_LINE
    mov rdx, NOT_FOUND_STATUS_LINE_len
    mov rax, SYSCALL_WRITE
    syscall
    
    mov rdi, [request_fd]
    mov rsi, SERVER_HEADER
    mov rdx, SERVER_HEADER_len
    mov rax, SYSCALL_WRITE
    syscall
    
    mov rdi, [request_fd]
    mov rsi, CONNECTION_HEADER
    mov rdx, CONNECTION_HEADER_len
    mov rax, SYSCALL_WRITE
    syscall
    
    mov rdi, [request_fd]
    mov rsi, ZERO_CONTENT_LENGTH_HEADER
    mov rdx, ZERO_CONTENT_LENGTH_HEADER_len
    mov rax, SYSCALL_WRITE
    syscall
    
    mov rdi, [request_fd]
    mov rsi, CONTENT_SEPARATOR
    mov rdx, CONTENT_SEPARATOR_len
    mov rax, SYSCALL_WRITE
    syscall
    
    mov rdi, [request_fd]
    mov rax, 3
    syscall
    jmp .accept_loop
    
    jmp .shutdown_request_fd

.shutdown_request_fd:
    %define SYSCALL_SHUTDOWN 52
    %define SHUT_WR 1
    mov rax, SYSCALL_SHUTDOWN
    mov rdi, [request_fd]
    mov rsi, SHUT_WR
    
    test rax, rax
    js .proccess_error
    jmp .accept_loop
    
.accept_error:
    %define ECONNABORTED 103
    cmp rax, ECONNABORTED
    je .accept_loop
    
    PRINT_ERRNO "FAILED TO ACCEPT CONNECTION"
    mov rdi, [socket_fd]
    call close_fd
    ret
.proccess_error:
    mov rdi, [request_fd]
    call close_fd
    PRINT_ERRNO "FAILED TO PROCESS REQUEST"
    jmp .accept_loop
    
   

; RDI = PORT IN HEX
; Returns FD in RAX
open_socket:
    %define AF_INET 2
    %define SOCK_STREAM 1
    %define DEFAULT_PROTOCOL 0
    %define INADDR_ANY 0 
    %define MAX_PENDING_CONNECTIONS 5
    
    %define SYSCALL_SOCKET 41  
    %define SYSCALL_BIND 49
    %define SYSCALL_LISTEN 50

    
    push rdi ; PORT

    mov rax, SYSCALL_SOCKET          
    mov rdi, AF_INET           
    mov rsi, SOCK_STREAM
    mov rdx, DEFAULT_PROTOCOL                  
    syscall
    
    test rax, rax
    js .socket_err
    
    pop rdi ; PORT
    push rax ; FD

    mov word [address + sockaddr.family], AF_INET
    mov [address + sockaddr.port], rdi
    mov dword [address +  sockaddr.address], INADDR_ANY  

    pop rdi
    push rdi
    mov rax, SYSCALL_BIND
    mov rsi, address
    mov rdx, sockaddr_size
    syscall
       
    test rax, rax
    js .bind_err
    
    pop rdi ; FD
    push rdi
    mov rax, SYSCALL_LISTEN
    mov rsi, MAX_PENDING_CONNECTIONS
    syscall
    
    test rax, rax
    js .listen_err 
        
    PRINTLN "LISTENING FOR CONNECTIONS ON PORT 8080"
    pop rax
    ret

.socket_err:
    PRINT_ERRNO "FAILED TO CREATE SOCKET"
    ret
.bind_err:
    PRINT_ERRNO "FAILED TO BIND SOCKET"
    ret
.listen_err:
    PRINT_ERRNO "FAILED TO LISTEN TO PORT"
    ret
    
; RDI = FD
close_fd:
    %define SYSCALL_CLOSE 3
    mov rax, SYSCALL_CLOSE
    syscall
    
    test rax, rax
    js .close_err
    ret
.close_err:
    PRINT_ERRNO "FAILED TO CLOSE FD"
    ret
    
; RDI = Request FD
; RSI = Content
; RDX = Length
write: 
    mov rax, 1 ; WRITE     
    syscall
    
    test rax, rax
    js .write_err
    ret
.write_err:
    PRINT_ERRNO "FAILED TO WRITE"
    ret