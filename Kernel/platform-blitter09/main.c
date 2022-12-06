#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>


struct blkbuf *bufpool_end = bufpool + NBUFS;

void plt_discard(void)
{
	extern uint8_t discard_size;
	bufptr bp = bufpool_end;

	kprintf("%d buffers reclaimed from discard\n", discard_size);
	
	bufpool_end += discard_size;

	memset( bp, 0, discard_size * sizeof(struct blkbuf) );

	for( bp = bufpool + NBUFS; bp < bufpool_end; ++bp ){
		bp->bf_dev = NO_DEVICE;
		bp->bf_busy = BF_FREE;
	}
}


void plt_idle(void)
{
}

void do_beep(void)
{
}

void plt_copyright(void)
{
	kprintf("Bitter+SBC09 platform Copyright (c) 2022 Dominic Beesley\n");
}


/*
 Map handling: We have flexible paging. Each map table consists
 of a set of pages with the last page repeated to fill any holes.
 */

void pagemap_init(void)
{
    int i;
    // Add 
    for (i = 0x90; i < 0xC0; i+=2)
        pagemap_add(i);
    /* add common page last so init gets it */
    pagemap_add(0x8E);
}

void map_init(void)
{
}


uint8_t plt_param(char *p)
{
	return 0;
}
