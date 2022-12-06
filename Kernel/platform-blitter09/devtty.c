#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <stdbool.h>
#include <devtty.h>
#include <device.h>
#include <tty.h>

static uint8_t tbuf1[TTYSIZ];   /* virtual serial port 0: console */


#define sheila_ACIA_CTL		((uint8_t *)0xFE08)
#define ACIA_RDRF		((uint8_t)0x01)
#define ACIA_TDRE		((uint8_t)0x02)

#define sheila_ACIA_DATA	((uint8_t *)0xFE09)
#define sheila_SERIAL_ULA	((uint8_t *)0xFE10)

#define sheila_SYSVIA_ifr	((uint8_t *)0xFE4D)



struct s_queue ttyinq[NUM_DEV_TTY + 1] = {
	/* ttyinq[0] is never used */
	{NULL, NULL, NULL, 0, 0, 0},
	/* Virtual UART/Real UART Consoles */
	{tbuf1, tbuf1, tbuf1, TTYSIZ, 0, TTYSIZ / 2},
};

tcflag_t termios_mask[NUM_DEV_TTY + 1] = {
	0,
	/* Virtual UART */
	_CSYS,
};


/* A wrapper for tty_close that closes the DW port properly */
int my_tty_close(uint_fast8_t minor)
{
	return (tty_close(minor));
}


/* Output for the system console (kprintf etc) */
void kputchar(uint_fast8_t c)
{
	uint8_t minor = minor(TTYDEV);

	while ((*sheila_ACIA_CTL & ACIA_TDRE) != ACIA_TDRE) {
		/* UART is busy */
	}

	/* convert from CR to CRLF */
	if (c == '\n') {
		tty_putc(minor, '\r');
		while ((*sheila_ACIA_CTL & ACIA_TDRE) != ACIA_TDRE) {
			/* UART is busy */
		}
	}

	tty_putc(minor, c);
}

ttyready_t tty_writeready(uint_fast8_t minor)
{
        if (minor != 1) {
		return TTY_READY_NOW;
        }
	return (*sheila_ACIA_CTL & ACIA_TDRE) ? TTY_READY_NOW : TTY_READY_SOON; /* TX DATA empty */
}

void tty_putc(uint_fast8_t minor, uint_fast8_t c)
{
	if ((minor > 0) && (minor < 3)) {
		*sheila_ACIA_DATA = c; /* UART Data */
	}
}

void tty_sleeping(uint_fast8_t minor)
{
	used(minor);
}


void tty_setup(uint_fast8_t minor, uint_fast8_t flags)
{

}


int tty_carrier(uint_fast8_t minor)
{
	return 1;
}

void tty_interrupt(void)
{

}

void tty_data_consumed(uint_fast8_t minor)
{
}


void plt_interrupt(void)
{
	uint8_t c;

	//DB:TODO: this is crappy polled i/o TODO: interrupts

	if (*sheila_ACIA_CTL & ACIA_RDRF)
	{ 
		c = *sheila_ACIA_DATA;
		tty_inproc(1, c); 
	}

	c = *sheila_SYSVIA_ifr;
	if (c & 0x80) {
		*sheila_SYSVIA_ifr = c & 0x7F;
		timer_interrupt();   /* tell the OS it happened */
	}

}


/* Initial Setup stuff down here. */

__attribute__((section(".discard")))
void devtty_init()
{

}
