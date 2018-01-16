DEV=/dev/sdb
DEV1=$DEV"1"
DEV2=$DEV"2"

dd bs=1M count=20 if=/dev/zero of=$DEV

echo "[Create Partition ...]"
cat <<EOF | fdisk $DEV
o
n
p
1
40960
+50M
n
p
2
143360
+100M
t
1
c
t
2
83
w
EOF

echo "[Update Image ...]"
dd conv=notrunc bs=1k seek=8 if=bootfile/boot0.bin of=$DEV
dd conv=notrunc bs=1k seek=19096 if=bootfile/u-boot-with-dtb.bin of=$DEV

echo "cat sdx1.fat32.img > $DEV1"
cat sdx1.fat32.img > $DEV1

echo "cat sdx2.ext4.img > $DEV2"
cat sdx2.ext4.img > $DEV2

sync
echo "[Finish]"



