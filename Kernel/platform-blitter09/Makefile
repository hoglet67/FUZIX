
CSRCS += devices.c main.c libc.c dev_jimram.c

CDSRCS += ../dev/devsd_discard.c

DSRCS = ../dev/blkdev.c ../dev/mbr.c ../dev/devsd.c devsdspi.c

ASRCS = blitsbc09.s crt0.s devsdspi_sec.s
ASRCS += tricks.s commonmem.s usermem_sbc09.s dev_jimram_int.s videoll.s

COBJS = $(CSRCS:.c=$(BINEXT))
AOBJS = $(ASRCS:.s=$(BINEXT))
DOBJS = $(DSRCS:.c=$(BINEXT))
CDOBJS = $(CDSRCS:.c=$(BINEXT))
OBJS  = $(COBJS) $(AOBJS) $(DOBJS) $(CDOBJS)

# to save intermediate files (eg, assembler) add -save-temps=cwd
# and do the same thing in cpu-6809/rules.mk
CROSS_CCOPTS += -I../dev/

../dev/drivewire/drivewire.o: ASOPTS += --defsym BLITSBC09=1

JUNK = $(CSRCS:.c=.o) $(ASRCS:.s=.o) $(DSRCS:.c=.o)

all:	$(OBJS)

$(COBJS): %$(BINEXT): %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -o $@ -c $<

#$(CDOBJS): %$(BINEXT): %.c
#	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -o $@ -c $<

$(CDOBJS): %$(BINEXT): %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -o $@ -c $<


$(DOBJS): %$(BINEXT): %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -o $@ -c $<

$(AOBJS): %$(BINEXT): %.s kernel.def platform.def ../kernel09.def
	$(CROSS_AS) $(ASOPTS) $< -o $*.o


clean:
	rm -f $(OBJS) $(JUNK)  core *~
	#not sure why devtty needs to be compiled separately but it does (-o0?)
	rm -f devtty.o
	rm -f ../fuzix.bin ../fuzix.decb ../fuzix.srec ../fuzix.map ../fuzix.ma2 ../fuzix.decb.bin

image:
	$(CROSS_CC) $(CROSS_CCOPTS) -O0 -c -o ../bank16k.o ../bank16k.c
	$(CROSS_CC) $(CROSS_CCOPTS) -O0 -c -o devtty.o devtty.c
	$(CROSS_CC) $(CROSS_CC_VIDEO) $(CROSS_CCOPTS) -O0 -c -o ../usermem.o ../usermem.c
	$(CROSS_LD) -o ../fuzix.srec -Map=../fuzix.map --script=fuzix.link --oformat=srec \
	crt0.o commonmem.o \
	blitsbc09.o ../start.o ../version.o ../lowlevel-6809.o \
	tricks.o main.o ../timer.o ../kdata.o devices.o \
	dev_jimram.o dev_jimram_int.o \
	devsdspi_sec.o \
	$(DOBJS) \
	$(CDOBJS) \
	../devio.o ../filesys.o ../process.o ../inode.o ../syscall_fs.o \
	../syscall_proc.o ../syscall_other.o ../mm.o ../bank16k.o ../swap.o \
	../tty.o ../devsys.o ../usermem.o ../syscall_fs2.o \
	../syscall_exec.o ../syscall_exec16.o ../syscall_fs3.o \
	../usermem_std-6809.o devtty.o libc.o ../vt.o usermem_sbc09.o \
	videoll.o ../blk512.o

	srec_cat -Output ../fuzix.bin -Binary  ../fuzix.srec

	$(CROSS_LD) -o ../fuzix.decb -Map=../fuzix.ma2 --script=fuzix.link --oformat=decb \
	crt0.o commonmem.o \
	blitsbc09.o ../start.o ../version.o ../lowlevel-6809.o \
	tricks.o main.o ../timer.o ../kdata.o devices.o \
	dev_jimram.o dev_jimram_int.o \
	devsdspi_sec.o \
	$(DOBJS) \
	$(CDOBJS) \
	../devio.o ../filesys.o ../process.o ../inode.o ../syscall_fs.o \
	../syscall_proc.o ../syscall_other.o ../mm.o ../bank16k.o ../swap.o \
	../tty.o ../devsys.o ../usermem.o ../syscall_fs2.o \
	../syscall_exec.o ../syscall_exec16.o ../syscall_fs3.o \
	../usermem_std-6809.o devtty.o libc.o ../vt.o usermem_sbc09.o \
	videoll.o ../blk512.o

	./decb2bin.pl --base=0 -v ../fuzix.decb ../fuzix.decb.bin

boot.bin: boot/boot.s
	lwasm -lboot.list --format=raw -oboot.bin boot/boot.s
