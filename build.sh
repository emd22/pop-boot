as BOOT16-2.S -o build/BOOT16.o
as STAGE2.S   -o build/STAGE2.o
as TESTKRN.S   -o build/TESTKRN.o
ld -Tlinker.ld --oformat=binary build/BOOT16.o -o build/BOOT16.bin
ld -Tlinker.ld --oformat=binary build/STAGE2.o -o build/STAGE2.bin
ld -Tlinker.ld --oformat=binary build/TESTKRN.o -o build/TESTKRN.bin
./outtofs.sh
#qemu-system-i386 -drive format=raw,file=build/fs.img
qemu-system-i386 -hda build/fs.img