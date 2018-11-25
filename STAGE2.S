.code32
.globl _start

jmp _start

_start:

    cli
    xor %eax, %eax
    #mov %eax, %ss
    mov $0x7F00, %esp

    xor %eax, %eax
    mov %eax, %ds
    mov %eax, %es
    mov %eax, %fs
    mov %eax, %gs
    sti
    //jmp write_e
    movb $'E', (0xB8000)
    movb $0x57, (0xB8001)
    #int $0x19
    cli
    hlt

.code32
write_e:
    
