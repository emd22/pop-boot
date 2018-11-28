.code16

.text
.globl _start

_start:
    # this is to preserve any information below in the binary
    jmp boot

sector_fail_msg: .asciz "Stage 1: Error: CHS Sector read failed."
ljmp_returned:   .asciz "Stage 1: Error: Jump to stage 2 returned!"

absoluteTrack:     .byte 0
absoluteSector:    .byte 1
absoluteHead:      .byte 0
sectorCount:       .byte 1
bootDrive:         .byte 0x80

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

read_sectors_chs:
    .Lread_start:
        mov $0x0005, %di
    .Lsector_read:
        xor %ax, %ax
        mov %ax, %es
        mov $0x02, %ah
        mov (sectorCount), %al
        
        mov (bootDrive), %dl

        mov (absoluteTrack), %ch
        mov (absoluteSector), %cl
        mov (absoluteHead), %dh

        int $0x13
        jnc .Lsuccess
        
        xor %ax, %ax
        int $0x13
        dec %di
        jnz .Lsector_read

        mov $sector_fail_msg, %si
        call print
        cli
        hlt
    .Lsuccess:
        ret

boot:
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

    movb %dl, (bootDrive)

    movb $0x00, (absoluteTrack)
    movb $0x02, (absoluteSector)
    movb $0x00, (absoluteHead)
    movb $0x02, (sectorCount)
    mov $0x7E00, %bx
    call read_sectors_chs
    
    ljmp $0x00, $0x7E00

    mov $ljmp_returned, %si
    call print
    
    cli
    hlt

# fill rest of the sector with zeroes
. = _start + 510
# add mbr signature(0x55 0xAA) at end of sector
.word 0xAA55
