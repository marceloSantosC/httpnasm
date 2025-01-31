%ifndef MEMORY_V2_ASM
%define MEMORY_V2_ASM
section .data
    align_values dd 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 0
    align_values_len equ $ - align_values

section .text
    global malloc, free, memgrow, memshrink
    
    
; RDI = Quantity to allocate in bytes
; Returns memory address in RAX    
malloc:
    %define SYSCALL_MMAP 9
    %define PROT_READ_WRITE 3
    %define MAP_PRIVATE 2
    %define MAP_ANONYMOUS 32 
    %define PAGE_SIZE 4095
    
    and rdi, PAGE_SIZE 
    test rdi, rdi
    jz .alloc
    xor rcx, rcx
.align:     
    movzx r10, word [align_values + rcx * 2] 
   
    add rcx, 2

    cmp r10, rdi
    jl .align
    mov rdi, r10
                  
.alloc:    
    push rdi
    mov rax, SYSCALL_MMAP
    mov rsi, rdi
    xor rdi, rdi
    mov rdx, PROT_READ_WRITE
    xor r8, r8
    xor r9, r9
    mov r10, MAP_PRIVATE | MAP_ANONYMOUS
    syscall   
    
    test rax, rax
    js .malloc_error
    pop rdx
    ret               
.malloc_error:
    mov rdx, 0
    ret
    
free:
    ; RDI = Memory address
    ; RSI = Quantity to deallocate in bytes
    ; Returns result in RAX
    %define SYSCALL_MUNMAP 11
    mov rax, SYSCALL_MUNMAP
    syscall   
    
    test rax, rax
    js .free_error
        
    ret
.free_error:
    ret

; RDI = Old Address
; RSI = Old size
; RDX = Size increased by (in bytes)
; Returns new memory address in RAX
memgrow:
    %define MREMAP_MAYMOVE 1
    %define SYSCALL_MREMAP 25
    mov rax, SYSCALL_MREMAP    
    add rdx, rsi                             
    mov r10, MREMAP_MAYMOVE                     
    syscall
    ret
    
; RDI = Old Address
; RSI = Old size
; RDX = Size reduced by (in bytes)
; Returns new memory address in RAX

memshrink:
    %define SYSCALL_MREMAP 25
    mov rax, SYSCALL_MREMAP                     

    push rsi
    sub rsi, rdx
    mov rdx, rsi
    pop rsi
    xor r10, r10  
    syscall
    
    test rax, rax
    ret
    
%endif