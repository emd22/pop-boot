.code16
.globl _start

jmp _start

outMsg: .asciz "HELLO, WORLD!"

print:
    lodsb        # load one char from si into al
    orb %al, %al # check if al == 0
    jz .Lend     # if so, return to previous label
    movb $0x0E, %ah
    int $0x10    # call bios interrupt to print character
    jmp print    # jmp until end of string
    .Lend:
        ret

_start:
    cli
    # set stack to code location(stage2 loaded at 0000:7E00)
    mov $0x07F0, %ax
    # setup registers
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    mov $0x0000, %ax
    mov %ax, %ss
    mov $0xF000, %sp
    sti
    mov $outMsg, %si
    call print

    cli
    hlt
