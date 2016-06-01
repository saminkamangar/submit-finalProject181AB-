#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int calc(unsigned char bitmap[1000][], int T[3][3], int y, int x)
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
	char line[4000];
	char *ptr;
	int x = 0, y = 0;
	unsigned char bitmap[1000][1000];
	int outbuf[1000][1000];
	int Tx[3][3] = {{-1, 0, 1}, {-2, 0, 2}, {-1, 0, 1}};
	int Ty[3][3] = {{-1, -2, -1}, {0, 0, 0}, {1, 2, 1}};
	
	while (NULL != fgets(line, 4000, img)) {
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

	int i, j;
	int xVal, yVal, val;
	for (j = 1; j < y-1; j++) {
		for (i = 1; i < x-1; i++) {
			xVal = calc(bitmap, Tx, j, i);
			yVal = calc(bitmap, Ty, j, i);
			val = abs(xVal) + abs(yVal);
			outbuf[j][i] = val > 255 ? 255 : val;
		}
	}

	for (j = 1; j < y-1; j++) {
		printf("%d", outbuf[j][1]);
		for (i = 2; i < x-1; i++) {
			printf(",%d", outbuf[j][i]);
		}
		printf("\n");
	}
	
	return 0;
}
