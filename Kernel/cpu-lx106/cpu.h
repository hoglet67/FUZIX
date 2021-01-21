#include <string.h>

/* The LX106 requires aligned accesses. (Annoying, it doesn't trap if you get
 * this wrong. It just reads to or writes from the wrong place.) */

#define ALIGNUP(v)   alignup(v, 4)
#define ALIGNDOWN(v) aligndown(v, 4)

#define uputp  uputl			/* Copy user pointer type */
#define ugetp  ugetl			/* between user and kernel */
#define uputi  uputl			/* Copy user int type */
#define ugeti(x) ugetl(x, NULL) /* between user and kernel */

/* Allow a minimum of 512 bytes gap between stack and top of allocations */
#define brk_limit() (udata.u_syscall_sp - 512)

extern void* memcpy(void*, const void*, size_t);
extern void* memset(void*, int, size_t);
extern size_t strlen(const char *);
extern uint16_t swab(uint16_t);

/* LX106 doesn't benefit from making a few key variables in
   non-reentrant functions static */
#define staticfast auto

/* FIXME: should be 64bits - need to add helpers and struct variants */
typedef struct {
   uint32_t low;
   uint32_t high;
} time_t;

typedef union {            /* this structure is endian dependent */
    clock_t  full;         /* 32-bit count of ticks since boot */
    struct {
      uint16_t low;
      uint16_t high;         /* 16-bit count of ticks since boot */
    } h;
} ticks_t;

#define used(x)

#define cpu_to_le16(x)	(x)
#define le16_to_cpu(x)	(x)
#define cpu_to_le32(x)  (x)
#define le32_to_cpu(x)  (x)

/* jmp over the Fuzix header. Will need updating if the header size changes */
#define EMAGIC   0x08
#define EMAGIC_2 0x3c

#define no_cache_udata()

#define CPUTYPE	CPUTYPE_LX106

/* Memory helpers: Max of 32767 blocks (16MB) as written */
extern void copy_blocks(void *, void *, unsigned int);
extern void swap_blocks(void *, void *, unsigned int);


