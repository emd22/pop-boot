.code16
.globl _start

jmp _start

enterNumber:       .asciz "Enter a partition(1-4)"
failureMsg:        .asciz "Sector read failed"
no_32b_msg:        .asciz "E:No32"
no_ext_msg:        .asciz "E:NoExt"
bootDrive:         .byte 0

DAP:
           .byte 0x10
           .byte 0
DAPSecCnt: .word 1
DAPLoc:    .long 0x8000
DAPLbaLo:  .int 1
DAPLbaHi:  .int 0

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
    pusha
    mov $13, %al
    call printc
    mov $10, %al
    call printc
    popa
    ret

printi:
    pusha
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
        popa
        call printnl
        ret

no_extensions:
    mov $no_ext_msg, %si
    call print
    cli
    hlt

bios_clear_screen:
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
    ret

read_sectors:
    pusha
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
        popa
        cli
        hlt
    success:
        popa
        ret

_start:
    cli # clear interrupt flags
    mov $0x07E0, %ax
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

    movw $0, (DAPLbaLo)
    movl $0x8000, (DAPLoc)
    movw $1, (DAPSecCnt)
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

    xor %bx, %bx
    mov %ax, %bx
    #mov $446, %bx
    imul $16, %bx
    add $0x3be, %bx
    #add %ax, %bx

    # check if first character in partition entry is bootable (0x80)
    movb (%bx), %al
    cmpb $0x80, %al
    jne clear_screen
    jmp continue

clear_screen:
    call printi
    #call bios_clear_screen
    jmp  get_p_num

continue:
    movw 8(%bx), %ax
    cmp $0, %ax
    jne isnz_lo
    jmp isz_lo
    isnz_lo:
        dec %ax
    isz_lo:
    movw %ax, (DAPLbaLo)

    movw 10(%bx), %ax
    cmp $0, %ax
    jne isnz_hi
    jmp isz_hi
    isnz_hi:
        dec %ax
    isz_hi:
    movw %ax, (DAPLbaHi)

    movw $0x8F00, (DAPLoc)
    call read_sectors

activate_a20:
    # check if a20 is supported
    mov $0x2403, %ax
    int $0x15
    jb a20_error
    cmp $0, %ah
    jnz a20_error

    # check status
    mov $0x2402, %ax
    int $0x15
    jb a20_error
    cmp $0, %ah
    jnz a20_error

    # is a20 activated? if so, jump to end
    cmp $1, %al
    jz a20_activated

    # finally, activate the a20 line.
    mov $0x2401, %ax
    int $0x15
    jb a20_error
    cmp $0, %ah
    jnz a20_error

a20_activated:
    call bios_clear_screen
    # clear screen before entering protected mode
    # so it's nice and clean for the OS

setup_gdt:
    cli
    xor %eax, %eax
    mov %ds, %ax
    shl $4, %eax
    add $gdt_base, %eax
    mov %eax, gdtr+2
    mov $gdt_end, %eax
    sub $gdt_base, %eax

    mov %ax, gdtr
    lgdtw gdtr

enter_pmode:
    # finally, enter protected mode
    mov %cr0, %eax
    or $1, %eax
    mov %eax, %cr0

    sti

    # clear all the junk in the registers
    xor %eax, %eax
    mov %eax, %ds
    mov %eax, %es
    mov %eax, %fs
    mov %eax, %gs

    # jump stage 2
    ljmp $0x08, $0x8F00
    cli
    hlt

    # in case the jump returns for some odd reason,
    # we will catch it with the ol' cli hlt.
    jmp failure

    a20_error:
        mov $no_32b_msg, %si
        call print
    failure:
    cli
    hlt
