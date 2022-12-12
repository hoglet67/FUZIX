/*
 *	SPI interface for a BBC Micro user port (non-turbo) MMC card
 *      
 *      User Port     SD Card
 *       (Master)     (Slave)
 *      =========     =======
 *        CB1/PB1 ==> S_CLK  (Clock)
 *            CB2 <== S_MISO (Dout)
 *            PB0 ==> S_MOSI (Din)
 *             0V ==> S_SEL  (Select)
 *      
 */

#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <timer.h>
#include <stdbool.h>
#include <blkdev.h>
#include "config.h"

//***********************************************************************
//* User VIA                                                            *
//***********************************************************************
#define sheila_USRVIA_orb			((volatile uint8_t *)0xFE60)
#define sheila_USRVIA_ora			((volatile uint8_t *)0xFE61)
#define sheila_USRVIA_ddrb			((volatile uint8_t *)0xFE62)
#define sheila_USRVIA_ddra			((volatile uint8_t *)0xFE63)
#define sheila_USRVIA_t1cl			((volatile uint8_t *)0xFE64)
#define sheila_USRVIA_t1ch			((volatile uint8_t *)0xFE65)
#define sheila_USRVIA_t1ll			((volatile uint8_t *)0xFE66)
#define sheila_USRVIA_t1lh			((volatile uint8_t *)0xFE67)
#define sheila_USRVIA_t2cl			((volatile uint8_t *)0xFE68)
#define sheila_USRVIA_t2ch			((volatile uint8_t *)0xFE69)
#define sheila_USRVIA_sr			((volatile uint8_t *)0xFE6A)
#define sheila_USRVIA_acr			((volatile uint8_t *)0xFE6B)
#define sheila_USRVIA_pcr			((volatile uint8_t *)0xFE6C)
#define sheila_USRVIA_ifr			((volatile uint8_t *)0xFE6D)
#define sheila_USRVIA_ier			((volatile uint8_t *)0xFE6E)
#define sheila_USRVIA_ora_nh			((volatile uint8_t *)0xFE6F)



void sd_spi_raise_cs(void)
{
	// always asserted!
}

void sd_spi_lower_cs(void)
{
	// always asserted!
}

static uint8_t xmit_recv(uint8_t b)
{
	uint8_t i;
	uint8_t bb;

//	irqflags_t irq = di();

	for (i = 0; i < 8; i++) {
		bb = (b & 0x80)?1:0;
		*sheila_USRVIA_orb = bb;
		*sheila_USRVIA_orb = 0x02 | bb;
		b = b << 1;
	}

	bb = *sheila_USRVIA_sr;

	*sheila_USRVIA_orb = 0;

//	irqrestore(irq);
	return bb;
}

void sd_spi_transmit_byte(uint8_t b)
{
	xmit_recv(b);
}

uint8_t sd_spi_receive_byte(void)
{
	return xmit_recv(0xff);
}


bool sd_spi_receive_sector(void)
{
	uint8_t* addr = blk_op.addr;
	uint8_t* endaddr = addr + 512;

	while (addr != endaddr)
		*addr++ = xmit_recv(0xff);
	return 0;
}

bool sd_spi_transmit_sector(void)
{
	uint8_t* addr = blk_op.addr;
	uint8_t* endaddr = addr + 512;

	while (addr != endaddr)
		xmit_recv(*addr++);
	return 0;
}

__attribute__((section(".discard")))
void sd_spi_clock(bool go_fast)
{
	// do nothing!
}


__attribute__((section(".discard")))
void sd_rawinit(void)
{
	//PORB bit 0,1 outputs
	*sheila_USRVIA_orb = 0x03;
	*sheila_USRVIA_ddrb = 0x03;

	// shift mode 0, no latching etc
	*sheila_USRVIA_acr = 0x00;

	//disable shift cb2, cb1 interrupts
	*sheila_USRVIA_ier = 0x1C;
}

