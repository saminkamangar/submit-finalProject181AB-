#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
//#define HW_BASE 0xfc000000
//#define HW_SPAN 0x04000000
//#define ALT_LWFPGASLVS_OFST     0xff200000

#define HW_BASE 0xc0000000
#define HW_SPAN 0x40000000
#define HW_MASK HW_SPAN - 1
//#define ALT_LWFPGASLVS_OFST     0xc0000000

//#define OFFSET 262144//131072
#define OFFSET (x*(y))

int calc(unsigned char **bitmap, int T[3][3], int y, int x)
{
	int i, j;
	int ret = 0;

	for (j = -1; j <= 1 ; j++) {
		for (i = -1; i <= 1 ; i++) {
			ret += bitmap[y+i][x+j] * T[j+1][i+1];
		}
	}
	return ret;
}

int main(int argc, const char *argv[])
{

	FILE *img = fopen(argv[1], "r");
	char line[15000];
	char *ptr;
	int x = 0, y = 0;
	unsigned char *bitmap[3000];
	unsigned char *outbuf[3000];
	unsigned char *outbuf2[3000];
	int Tx[3][3] = {{-1, 0, 1}, {-2, 0, 2}, {-1, 0, 1}};
	int Ty[3][3] = {{-1, -2, -1}, {0, 0, 0}, {1, 2, 1}};
	int i, j;

	void *VA;
	void* sdram;
	int fd;

	clock_t time;

	time = (float) clock();
	if ((fd = open("/dev/mem", (O_RDWR|O_SYNC))) == -1) {
		perror("ERROR: could not open \"/dev/mem\"\n");
		return 1;
	}

	VA = mmap(NULL, HW_SPAN, (PROT_READ|PROT_WRITE), MAP_SHARED, fd, HW_BASE);
	if (VA == MAP_FAILED) {
		perror("ERROR: mmap() failed ... \n");
		close(fd);
		return 1;
	}
	fprintf(stderr, "\nmmap(): %.2f seconds\n",(float) (clock() - time) / CLOCKS_PER_SEC);





	time = (long)clock();
	sdram = VA + ((unsigned long)(HW_BASE + 0x00) & (unsigned long)(HW_MASK));
	for (i = 0; i < 3000; i++) {
		bitmap[i] = (unsigned char *)malloc(3000 * sizeof(unsigned char));
		outbuf[i] = (unsigned char *)malloc(3000 * sizeof(unsigned char));
		outbuf2[i] = (unsigned char *)malloc(3000 * sizeof(unsigned char));
	}
	fprintf(stderr, "Memory Allocation: %.2f seconds\n",(float) (clock() - time) / CLOCKS_PER_SEC);





		
	time = (long)clock();
	while (NULL != fgets(line, sizeof(line), img)) {
		// Init
		line[strlen(line)-1] = '\0';
		x = 0;

		// Read the first value
		ptr = strtok(line, ",");
		bitmap[y][x] = atoi(ptr);
		x++;

		// Read remaining
		while (NULL != (ptr = strtok(NULL, ","))) {
			bitmap[y][x] = atoi(ptr);
			x++;
		}

		y++;
	}
	fprintf(stderr, "Disk Read: %.2f seconds\n",(float) (clock() - time) / CLOCKS_PER_SEC);






	time = (float) clock();
	int xVal, yVal, val;
	for (j = 1; j < y-1; j++) {
		for (i = 1; i < x-1; i++) {
			xVal = calc(bitmap, Tx, j, i);
			yVal = calc(bitmap, Ty, j, i);
			val = abs(xVal) + abs(yVal);
			outbuf[j][i] = val > 255 ? 255 : val;
		}
	}
	fprintf(stderr, "Image Processing: %.2f seconds\n",(float) (clock() - time) / CLOCKS_PER_SEC);

	x -= 2;
	y -= 2;






	//time = (long)clock();
	//// Initialize the SDRAM
	//((unsigned char *)sdram)[1] = 0;
	//((unsigned char *)sdram)[0] = 0;	
	//for (j = 0; j < y; j++) {
	//	for (i = 0; i < x; i++) {
	//		//((unsigned char *)sdram)[j*x + i] = 100;
	//		//((unsigned char *)sdram)[j*x + i + OFFSET] = 123;
	//		((unsigned char *)sdram)[2 + j*x + i] = 100;
	//		((unsigned char *)sdram)[2 + j*x + i + OFFSET] = 123;
	//	}
	//}
	//fprintf(stderr, "SDRAM Init: %.2f seconds\n",(float) (clock() - time) / CLOCKS_PER_SEC);








	time = (long)clock();
	// Write to SDRAM
	for (j = 0; j < y; j++) {
		for (i = 0; i < x; i++) {
			//((unsigned char *)sdram)[j*x + i] = outbuf[j+1][i+1];
			//((unsigned char *)sdram)[2 + j*x + i] = outbuf[j+1][i+1];
			((unsigned char *)sdram)[2 + j*x + i] = bitmap[j+1][i+1];
		}
	}
	fprintf(stderr, "SDRAM Write: %.2f seconds\n",(float) (clock() - time) / CLOCKS_PER_SEC);






	// Send start signal

	time = (long)clock();

	((unsigned char *)sdram)[1] = 0xFF;
	((unsigned char *)sdram)[0] = 0xFE;
	//usleep(100000);


	long t, temp;
	while (((unsigned char*)sdram)[0] != 0xFF)
	{
		temp = 1;
		for (t = 0; t < 100; t++)
			temp = temp * 3;
		//usleep(10000);
		//fprintf(stderr, "[0]: %d\n", (int)((unsigned char *)sdram)[0]);
		//fprintf(stderr, "[1]: %d\n", (int)((unsigned char *)sdram)[1]);
	}


	fprintf(stderr, "Delay: %.2f seconds\n",(float) (clock() - time) / CLOCKS_PER_SEC);







	time = (long)clock();
	// Read from SDRAM to a new array: outbuf2
	for (j = 0; j < y; j++) {
		for (i = 0; i < x; i++) {
			outbuf2[j][i] = ((unsigned char*)sdram)[8 + OFFSET + j*x + i];
		}
	}
	fprintf(stderr, "SDRAM Read: %.2f seconds\n",(float) (clock() - time) / CLOCKS_PER_SEC);










	time = (long)clock();
	for (j = 1; j < y-1; j++) {
		printf("%d", outbuf2[j][1]);
		for (i = 2; i < x-1; i++) {
			printf(",%d", outbuf2[j][i]);
		}
		printf("\n");
	}
	fprintf(stderr, "printf(): %.2f seconds\n",(float) (clock() - time) / CLOCKS_PER_SEC);
	return 0;
}
