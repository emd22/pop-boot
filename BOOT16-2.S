.code16

.text
.globl _start

_start:
    # this is to preserve any information below in the binary
    jmp boot

failureMsg:        .asciz "Sector read failed"
enterNumber:       .asciz "Enter a partition(1-4)"
no_ext_msg:        .asciz "E:NoExt"
no_32b_msg:        .asciz "E:No32"
bootDrive:         .byte 0

DAP:
        .byte 0x10
        .byte 0
DAPSec: .word 1
DAPLoc: .long 0x7E00
DAPLbaLo: .int 1
DAPLbaHi: .int 0

.align 8
gdtr:
    .word 0
    .long 0

gdt_base:
    .quad 0
    .word 0xFFFF
    .word 0
    .byte 0
    .byte 0x9A
    .byte 0xCF
    .byte 0
    .word 0xFFFF
    .word 0
    .word 0
    .byte 0
    .byte 0x92
    .byte 0xCF
    .byte 0
gdt_end:

printc:
    mov $0x0E, %ah # use bios teletype
    int $0x10      # call bios interrupt to print character
    ret

prints:
    lodsb        # load one char from si into al
    orb %al, %al # check if al == 0
    jz end       # if so, return to previous label
    call printc
    jmp prints   # jmp until end of string
    end:
        ret

print:
    call prints
printnl:
    mov $13, %al
    call printc
    mov $10, %al
    call printc
    ret

/*printi:
    pushal
    xor %cx, %cx
    loop1:
        xor %dx, %dx
        mov $10, %bx
        div %bx

        push %dx
        inc %cx
        cmp $0, %ax
        jne loop1
    loop2:
        pop %ax
        add $'0', %al
        call printc
        loop loop2
        popal
        call printnl
        ret
*/
no_extensions:
    mov $no_ext_msg, %si
    call print
    cli
    hlt

read_sectors:
    read_start:
        mov $0x0005, %di
    sector_read:
        xor %ax, %ax

        mov $0x42, %ah
        mov (bootDrive), %dl
        movw $DAP, %si

        int $0x13
        jnc success
        
        xor %ax, %ax
        int $0x13
        dec %di
        jnz sector_read

        mov $failureMsg, %si
        call print
        cli
        hlt
    success:
        ret

boot:
    # adjust segment registers(code is located at 0000:7C00)
    cli # clear interrupt flags
    mov $0x07C0, %ax
    # setup registers
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    mov $0x0000, %ax
    mov %ax, %ss
    mov $0xFFFF, %sp
    sti # restore interrupts

    movb %dl, (bootDrive) # save boot drive loaded from bios

    mov $0x41, %ah
    mov $0x55AA, %bx
    int $0x13
    jc no_extensions
    cmp $0xAA55, %bx
    jnz no_extensions
    call read_sectors

    xor %ax, %ax

    # get partition entry location
get_p_num:
    mov $enterNumber, %si
    call print
    xor %ax, %ax
    int $0x16
    # make boundaries so p index cannot be less than 1 or greater than 4
    cmp $'1', %al
    jl get_p_num
    cmp $'4', %al
    jg get_p_num
    
    # clear upper 8 bits of ax so we can use ax instead of al
    xor %ah, %ah

    # subtract '1' from value, so '1' would = 0, '2' = 1, etc for
    # partition index.

    sub $'1', %al

    mov %ax, %bx
    imul $16, %bx
    add $446, %bx
    mov %bx, %ax
    
    # check if first character in partition entry is bootable (0x80)
    movb (%bx), %al
    cmpb $0x80, %al
    jne clear_screen
    jmp continue

clear_screen:
    pusha
    mov $0x0700, %ax
    mov $0x07, %bh
    mov $0x0000, %cx
    mov $0x184F, %dx
    int $0x10

    xor %bh, %bh
    xor %dx, %dx
    mov $0x02, %ah
    int $0x10
    popa
    jmp  get_p_num

continue:
    movw 8(%bx), %bx
    movw %bx, (DAPLbaLo)
    movw (DAPLbaLo), %ax
    #call printi

    movw $0x7F00, (DAPLoc) # load sector containing vbr to addr 0x7F00
    call read_sectors

    /*mov $0x2403, %ax
    int $0x15
    jb no_32b
    cmp $0, %ah
    jnz no_32b

    mov $0x2402, %ax
    int $0x15
    jb no_32b
    cmp $0, %ah
    jnz no_32b

    cmp $1, %al
    jz a20_activated

    mov $0x2401, %ax
    int $0x15
    jb no_32b
    cmp $0, %ah
    jnz no_32b*/

    #a20_activated:

    cli

    in $0x92, %al
    or $2, %al
    out %al, $0x92

    xor %eax, %eax
    mov %ds, %ax
    shl $4, %eax
    add $gdt_base, %eax
    mov %eax, gdtr+2
    mov $gdt_end, %eax
    sub $gdt_base, %eax

    mov %ax, gdtr
    lgdtw gdtr

    cli
    mov %cr0, %eax
    or $1, %eax
    mov %eax, %cr0

   # mov $0x10, %ax
    #mov %ax, %ds
    #mov %ax, %es
    #mov %ax, %fs
    #mov %ax, %gs
    #mov %ax, %ss


    # jump to loaded vbr

    #ljmp $0x08, $0x7F00

    #ljmp $0x08, $0x7F00

    #mov $failureMsg, %si
    #call print
    #mov $10, %eax
    ljmp $0x08, $0x7F00

    cli
    hlt

    # in case the jump returns for some odd reason,
    # we will catch it with the ol' cli hlt.
    jmp fail_loop

    no_32b:
        mov $no_32b_msg, %si
        call print
    fail_loop:
    cli
    hlt

.code32
final:
    /*mov $0x10, %eax
    mov %eax, %ds
    mov %eax, %es
    mov %eax, %fs
    mov %eax, %gs
    mov %eax, %ss
    mov $0xFFFF, %esp*/

    #ljmp $0x08, $0x7F00
    cli
    hlt

# fill rest of the sector with zeroes
. = _start + 510
# add mbr signature(0x55 0xAA) at end of sector
.word 0xAA55
