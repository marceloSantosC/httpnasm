%include "print_v2.asm"
%include "http_v2.asm"

struc sockaddr
    .family: resb 2
    .port: resb 2
    .address: resb 12
    alignb 8           
endstruc

section .data
    SOCKET_PORT equ 0x901F 
    REQUEST_BUFFER_SIZE equ 2048

section .bss
    socket_fd resq 1
    address: resb sockaddr_size   
    request_buffer resb REQUEST_BUFFER_SIZE
        
section .text
    global main
    extern PRINTLN, PRINT_ERRNO, answer_request
main:
    mov rbp, rsp; for correct debugging
    call create_socket
    %define ACCEPTS_ALL_ADDRESSES 0
    %define SYSCALL_ACCEPT 43 
accept_loop:
    mov rax, SYSCALL_ACCEPT
    mov rdi, [socket_fd]
    mov rsi, ACCEPTS_ALL_ADDRESSES
    xor rdx, rdx
    syscall
    
    test rax, rax
    js .accept_error
    
    push rax
    mov rdi, rax
    call read_request
    
    PRINTLN "RECEIVED NEW CONNECTION"

    pop rdi
    call answer_request
    
    jmp accept_loop
.accept_error:
    PRINT_ERRNO "FAILED TO ACCEPT CONNECTION"
    jmp accept_loop
    
read_request:
    %define SYSCALL_READ 0
    mov rax, SYSCALL_READ
    mov rdi, rdi          
    mov rsi, request_buffer
    mov rdx, REQUEST_BUFFER_SIZE
    syscall
    
    mov rdx, rax
    mov rsi, request_buffer
    mov rax, 1
    mov rdi, 1
    syscall

    test rax, rax
    js .read_error
    ret

.read_error:
    PRINT_ERRNO "READ ERROR"
    ret

create_socket:
    %define AF_INET 2
    %define SOCK_STREAM 1
    %define DEFAULT_PROTOCOL 0
    %define SYSCALL_SOCKET 41  
    %define INADDR_ANY 0 

    mov rax, SYSCALL_SOCKET          
    mov rdi, AF_INET           
    mov rsi, SOCK_STREAM
    mov rdx, DEFAULT_PROTOCOL                  
    syscall
    
    test rax, rax
    js .socket_err
    
    mov [socket_fd], rax
    
    mov word [address + sockaddr.family], AF_INET
    mov word [address + sockaddr.port], SOCKET_PORT
    mov dword [address +  sockaddr.address], INADDR_ANY  
    
    jmp bind
.socket_err:
    PRINT_ERRNO "FAILED TO CREATE SOCKET"
    call exit 
    
bind:
    %define SOCKET_PORT 0x901F  
    %define INADDR_ANY 0    
    %define SYSCALL_BIND 49
    
    mov rax, SYSCALL_BIND
    mov rdi, [socket_fd]
    mov rsi, address
    mov rdx, sockaddr_size
    syscall
    
    test rax, rax
    jns listen
.bind_err:
    PRINT_ERRNO "FAILED TO BIND SOCKET"
    call exit
    
listen:
    %define SYSCALL_LISTEN 50
    %define MAX_PENDING_CONNECTIONS 5
    mov rax, SYSCALL_LISTEN
    mov rdi, [socket_fd]
    mov rsi, MAX_PENDING_CONNECTIONS
    syscall
    
    PRINTLN "LISTENING FOR CONNECTIONS ON PORT 8080"
    
    test rax, rax
    js .listen_err
    ret

.listen_err:
    PRINT_ERRNO "FAILED TO LISTEN TO PORT"
    call exit
   
   
exit:
    mov rdi, rax
    mov rax, 60
    syscall
    