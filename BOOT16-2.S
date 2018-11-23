.code16

.text
.globl _start

_start:
    # this is to preserve any information below in the binary
    jmp boot

failureMsg:        .asciz "Sector read failed"
enterNumber:       .asciz "Enter a partition(1-4)"
no_ext_msg:        .asciz "E:NoExt"
bootDrive:         .byte 0

DAP:
        .byte 0x10
        .byte 0
DAPSec: .word 1
DAPLoc: .long 0x7E00
DAPLbaLo: .int 1
DAPLbaHi: .int 0

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
        #xor %ds, %ds
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

    # jump to loaded vbr
    ljmp $0x00, $0x7F00

    # in case the jump returns for some odd reason,
    # we will catch it with the ol' cli hlt.

    cli
    hlt
    # fill rest of the sector with zeroes
    . = _start + 510
    # add mbr signature(0x55 0xAA) at end of sector
    .word 0xAA55
