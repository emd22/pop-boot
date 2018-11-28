#qemu-img create -f raw -o size=12M build/fs.img
#dd if=/dev/zero of=build/fs.img bs=1024 count=720
#sudo mkdosfs -F 12 build/fs.img 10240
dd bs=512 if=build/BOOT16.bin of=build/fs.img seek=0 count=1 conv=notrunc
dd bs=512 if=build/STAGE2.bin of=build/fs.img seek=1 count=2 conv=notrunc
dd bs=512 if=build/TESTKRN.bin of=build/fs.img seek=4 count=2 conv=notrunc
(
echo n
echo p
echo 1
echo 4
echo 9
echo a
echo w
) | fdisk build/fs.img &>fdisk.log
#mcopy -i ./build/fs.img ./build/KRNLDR.SYS ::/KRNLDR.SYS