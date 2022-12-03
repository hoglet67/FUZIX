/*

  Blitter JIM Ramdisk driver

  Derived from:

  CoCoSDC driver
  (c)2015 Brett M. Gordon GPL2

 * init / mounting stuff really needs to set/update blkdev structure for size
 * need to get rawmode=1 and 2 working.

*/

#include <kernel.h>
#include <kdata.h>
#include <blkdev.h>
#include <mbr.h>
/* not to be confused with devsd.h ..!! [NAC HACK 2016Apr26] */
#include <dev_jimram.h>
#include <printf.h>


/* multicomp09 hw registers */

#define BLITTER_DEV					0xD1
#define	fred_JIM_PAGE_HI		*((volatile uint8_t *)0xFCFD)
#define	fred_JIM_PAGE_LO		*((volatile uint8_t *)0xFCFE)
#define	fred_JIM_DEVNO			*((volatile uint8_t *)0xFCFF)


/* a "simple" internal function pointer to which transfer
   routine to use.
*/
typedef void (*sd_transfer_function_t)( void *addr);


/* blkdev method: flush drive */
int dev_jimram_flush( void )
{
	return 0;
}


/* blkdev method: transfer sectors */
uint8_t dev_jimram_transfer_sector(void)
{
	uint8_t *ptr;                  /* points to 32 bit lba in blk op */
	sd_transfer_function_t fptr;   /* holds which xfer routine we want */


	/* select blitter device */

	fred_JIM_DEVNO = BLITTER_DEV;

	if (fred_JIM_DEVNO ^ BLITTER_DEV) {
		panic("No Blitter DEV");
	}

 	ptr=((uint8_t *)(&blk_op.lba));
 	fred_JIM_PAGE_LO = ptr[3];	//LSB
 	fred_JIM_PAGE_HI = (ptr[2] + 0x10) & 0x7F;

	/* do the low-level data transfer (512 bytes) */
	fptr( blk_op.addr );

	/* No mechanism for failing so assume success! */
	return 1;
}

__attribute__((section(".discard")))
/* Returns true if hardware seems to exist */
bool dev_jimram_exist()
{
	return 1;
}

__attribute__((section(".discard")))
/* Call this to initialize SD/blkdev interface */
void dev_jimram_init()
{
	blkdev_t *blk;

	kputs("JIMRAM: ");
	if( dev_jimram_exist() ){
		/* there is only 1 drive. Register it. */
		blk=blkdev_alloc();
		blk->driver_data = 0 ;
		blk->transfer = dev_jimram_transfer_sector;
		blk->flush = dev_jimram_flush;
		blk->drive_lba_count=400;									//TODO:DB: this is just what I set in filesystem build?!
		blkdev_scan(blk, 0);

		kputs("ok.\n");
	}
	else kprintf("Not Found.\n");
}

