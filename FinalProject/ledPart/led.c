#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>
//#define HW_BASE 0xfc000000
#define HW_BASE 0xff200000
//#define HW_SPAN 0x04000000
#define HW_SPAN 0x00200000
#define HW_MASK HW_SPAN-1
#define ALT_LWFPGASLVS_OFST	0xff200000

int main(void)
{
	void *VA, *led;
	int fd;

	fd = open("/dev/mem", (O_RDWR|O_SYNC));
	VA = mmap(NULL, HW_SPAN, (PROT_READ|PROT_WRITE), MAP_SHARED, fd, HW_BASE);
	led = VA + ((unsigned long)(ALT_LWFPGASLVS_OFST + 0x90) & (unsigned long)(HW_MASK));


	unsigned int offset = 0; // sum of stable bits
	int i;	// i is the latest stable bit (on the left hand side)
	int j;	// j is the moving bit 

	while(1) { // infinite loop
		for (i = 9; i >= 0 ; i--){
			for (j = 0; j <= i; j++){
				*(unsigned long*)led = offset + (1<<j); // move
				usleep(500000);	// 0.5 s
			}
			// when moving bit reaches the end on the left,
			// we have a new offset which needs to be updated
			offset += (1<<i);
		}
		// reset
		offset = 0;
	}
	return 0;
}
