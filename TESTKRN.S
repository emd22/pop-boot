.code32
.globl _start

jmp _start

_start:
    cli # clear interrupt flags
    mov $0x08F0, %ax
    # setup registers
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    mov $0x0000, %ax
    mov %ax, %ss
    mov $0xFFFF, %sp
    sti # restore interrupts

    jmp write_e
    
    write_e:
        movb $'E', (0xB8000)
        movb $0x57, (0xB8001)
    cli
    hlt
