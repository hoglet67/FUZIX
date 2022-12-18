#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <stdbool.h>
#include <devtty.h>
#include <device.h>
#include <tty.h>

#define UART_BASE    0xFE00

#define UART_SRA     ((volatile uint8_t *)(UART_BASE + 0x01))
#define UART_THRA    ((volatile uint8_t *)(UART_BASE + 0x03))
#define UART_RHRA    ((volatile uint8_t *)(UART_BASE + 0x03))
#define UART_ISR     ((volatile uint8_t *)(UART_BASE + 0x05))
#define UART_STOPCT  ((volatile uint8_t *)(UART_BASE + 0x0f))

#define UART_RXRDY   0x01
#define UART_TXRDY   0x04

static uint8_t tbuf1[TTYSIZ];   /* virtual serial port 0: console */


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

	while ((*UART_SRA & UART_TXRDY) != UART_TXRDY) {
		/* UART is busy */
	}

	/* convert from CR to CRLF */
	if (c == '\n') {
		tty_putc(minor, '\r');
		while ((*UART_SRA & UART_TXRDY) != UART_TXRDY) {
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
	return (*UART_SRA & UART_TXRDY) ? TTY_READY_NOW : TTY_READY_SOON; /* TX DATA empty */
}

void tty_putc(uint_fast8_t minor, uint_fast8_t c)
{
	if ((minor > 0) && (minor < 3)) {
		*UART_THRA = c; /* UART Data */
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

	if (*UART_SRA & UART_RXRDY)
	{
		c = *UART_RHRA;
		tty_inproc(1, c);
	}

	c = *UART_ISR;
	if (c & 0x08) {
		c = *UART_STOPCT;
		timer_interrupt();   /* tell the OS it happened */
	}

}


/* Initial Setup stuff down here. */

__attribute__((section(".discard")))
void devtty_init()
{

}
