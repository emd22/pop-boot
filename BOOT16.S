.code16

.text
.globl _start
.org   0x0000

_start:
    jmp boot

bpbOEM:               .ascii "POPBOOT "
bpbBytesPerSector:    .word 512
bpbSectorsPerCluster: .byte 1
bpbReservedSectors:   .word 1
bpbNumberOfFATS:      .byte 2
bpbRootEntries:       .word 224
bpbTotalSectors:      .word 2880
bpbMedia:             .byte 0xF8
bpbSectorsPerFAT:     .word 9
bpbSectorsPerTrack:   .word 18
bpbHeadsPerCylinder:  .word 2
bpbHiddenSectors:     .long 0
bpbTotalSectorsBig:   .long 0
bsDriveNumber:        .byte 0
bsUnused:             .byte 0
bsExtBootSignature:   .byte 0x29
bsSerialNumber:       .long 0xA0A1A2A3
bsVolumeLabel:        .ascii "POPBOOT STG"
bsFileSystem:         .ascii "FAT12   "

dataSector:           .word 0x0000
absoluteSector:       .byte 0x00
absoluteHead:         .byte 0x00
absoluteTrack:        .byte 0x00
currentCluster:       .word 0x0000
stage2Name:           .ascii "KRNLDR  SYS"

bootDrive:            .byte  0x00
bootMsg:              .asciz "Retrieving stage 2..."
failureMsg:           .asciz "ERROR: load failed."
successMsg:           .asciz "Success!"
debugMsg:             .asciz "DBG"

print:
    lodsb           # load byte from string into al
    orb %al, %al    # check if al == 0
    jz print_end    # if so, return
    movb $0xe, %ah  # get next character 
    int $0x10       # call interrupt 0x10
    jmp print       # jmp again until end of string
    
print_end:
    ret

debughlt:
    mov $debugMsg, %si
    call print
    cli 
    hlt

lba_to_chs:
    push %dx
    xor %dx, %dx
    divw (bpbSectorsPerTrack)
    inc %dl
    movb %dl, (absoluteSector)

    xor %dx, %dx
    movw $0x02, (bpbHeadsPerCylinder)
    divw (bpbHeadsPerCylinder)
    movb %dl, (absoluteHead)
    movb %al, (absoluteTrack)
    pop %dx
    ret

chs_to_lba:
    sub $0x0002, %ax
    xor %cx, %cx
    movb (bpbSectorsPerCluster), %cl
    mul %cx
    addw (dataSector), %ax
    ret

# in:
#   ch: cylinder index
#   dh: head index
#   cl: sector index
#   dl: disk index
# out:
#   bx: buffer pointer
read_sectors:
    .Lmain:
        mov $0x0005, %di
    .Lsector_loop:
        push %ax
        push %bx
        push %cx
        #mov failureMsg, %si
        #call print
        call lba_to_chs
        mov $0x02, %ah # read sectors command
        mov $0x01, %al # sectors to read
        movb (absoluteTrack), %ch
        movb (absoluteSector), %cl
        movb (absoluteHead), %dh
        movb (bootDrive), %dl
        int $0x13
        jnc .Lsuccess
        xor %ax, %ax # bios reset disk
        int $0x13
        dec %di
        pop %cx
        pop %bx
        pop %ax
        jnz .Lsector_loop
        mov $failureMsg, %si
        call print
        cli 
        hlt
    .Lsuccess:
        pop %cx
        pop %bx
        pop %ax
        
        addw (bpbBytesPerSector), %bx
        inc %ax
        #loop .Lmain
        ret

load_root_dir:
    # compute size of root directory
    xor %cx, %cx
    xor %dx, %dx
    mov $0x0020, %ax
    mulw (bpbRootEntries)
    divw (bpbBytesPerSector)
    xchg %cx, %ax # store in register cx

    # compute location of root directory
    movb (bpbNumberOfFATS), %al
    mulw (bpbSectorsPerFAT)
    addw (bpbReservedSectors), %ax
    movw %ax, (dataSector)
    addw %cx, (dataSector)

    # read root directory into memory
    mov $0x0200, %bx
    call read_sectors

    # find stage 2
    movw (bpbRootEntries), %cx
    mov $0x0200, %di
    
.Lloop:
    push %cx
    mov $0x000B, %cx
    mov stage2Name, %si
    push %di
rep cmpsb
    pop %di
    je load_fat
    pop %cx
    add $0x0020, %di
    loop .Lloop
    jmp failure

load_fat:
    movw 0x001A(%di), %dx
    mov %dx, (currentCluster)

    xor %ax, %ax
    mov (bpbNumberOfFATS), %al
    mulw (bpbSectorsPerFAT)
    mov %ax, %cx

    movw (bpbReservedSectors), %ax

    mov $0x0200, %bx
    call read_sectors

    mov $0x0050, %ax
    mov %ax, %es
    mov $0x0000, %bx
    push %bx

load_image:
    movw (currentCluster), %ax
    pop %bx
    call chs_to_lba
    xor %cx, %cx
    movb (bpbSectorsPerCluster), %cl
    call read_sectors
    push %bx

    movw (currentCluster), %ax
    mov %ax, %cx
    mov %ax, %dx
    shr $0x0001, %dx
    add %dx, %cx
    mov $0x0200, %bx
    add %cx, %bx
    movw (%bx), %dx
    test $0x0001, %ax
    jnz .Lodd_cluster

.Leven_cluster:
    and $0b0000111111111111, %dx
    jmp .Ldone

.Lodd_cluster:
    shr $0x0004, %dx

.Ldone:
    movw $successMsg, %si
    call print
    movw %dx, (currentCluster)
    cmp $0x0FF0, %dx
    jb load_image

done:
    mov $successMsg, %si
    call print
    pushw $0x0050
    pushw $0x0000
    retf

failure:
    mov $failureMsg, %si
    call print
    # call interrupt with command 0 to halt until keypress.
    mov $0x00, %ah
    int $0x16
    # restart computer
    int $0x19

boot:
    #xor %ax, %ax
    #mov %ax, %ds
    #mov %ax, %es
    #mov %ax, %fs
    #mov %ax, %gs

    #cld

    #mov $0x7C00, %sp

    cli
    mov $0x07C0, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    mov $0x0000, %ax
    mov %ax, %ss
    mov $0xFFFF, %sp
    sti

    mov $bootMsg, %si
    call print

    jmp load_root_dir

    cli
    hlt
    . = _start + 510
    .byte 0x55
    .byte 0xAA