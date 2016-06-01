#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
//#define HW_BASE 0xfc000000
//#define HW_SPAN 0x04000000
//#define ALT_LWFPGASLVS_OFST     0xff200000

#define FIGNUM		400
#define BUS_WITH	16

#define HW_BASE 0xc0000000
#define HW_SPAN 0x40000000
#define HW_MASK HW_SPAN - 1

#define PIXELS_OFFSET	1
#define WEIGHTS1_OFFSET	(PIXELS_OFFSET + 98/2)
#define RESULTS1_OFFSET	(WEIGHTS1_OFFSET + (784*200*4/8)/2)
#define LAYER1_OFFSET	(RESULTS1_OFFSET + 200)
#define WEIGHTS2_OFFSET	(LAYER1_OFFSET + 26/2)
#define RESULTS2_OFFSET	(WEIGHTS2_OFFSET + (200*200*4/8)/2)
#define B1L1_OFFSET	(RESULTS2_OFFSET + 200)
#define B1L2_OFFSET	(B1L1_OFFSET + 200)
#define W1L1_OFFSET	(B1L2_OFFSET + 200)
#define W1L2_OFFSET	(W1L1_OFFSET + 200 * 784)
#define SOFTMAX_OFFSET	(W1L2_OFFSET + 200 * 200)
#define DATA_OFFSET	(SOFTMAX_OFFSET + 10 * 200)
#define LABELS_OFFSET	(DATA_OFFSET + FIGNUM * 784)
#define HIDDEN1_OFFSET	(LABELS_OFFSET + 10000)
#define HIDDEN2_OFFSET	(HIDDEN1_OFFSET + 200)
#define OUT_OFFSET	(HIDDEN2_OFFSET + 200)


clock_t exclude;
clock_t timetmp, time1, time2;

void* sdram;
void writeZero()
{
	int j;
	for (j = 0; j < 200; j++) {
		//printf("%d,", results[i][j]);
		((short*)sdram)[RESULTS1_OFFSET + j] = 1;
	}
}

//void writeResult(short **results, int i)
//{
//	int j;
//	for (j = 0; j < 200; j++) {
//		//printf("%d,", results[i][j]);
//		((short*)sdram)[RESULTS1_OFFSET + j] = results[i][j];
//	}
//	//puts("");
//}


void mult1(int fignum, int dim2)
{
	int i, j, k;
	float sum = 0;

	//float *ret = &((float*)sdram)[RESULTS1_OFFSET];

	unsigned short buf = 0;
	int count = 0;
	int poscount = 0;
	int tmp;
	//puts("mult1 start");

	
	timetmp = (float)clock();
	int pixelCount = 0;
	for (i = 0; i < dim2; i++) {
		count++;
		poscount++;
		buf <<= 1;
		buf += round(((float*)sdram)[DATA_OFFSET+fignum*784+i]);
		if (poscount == 28) {
			poscount = 0;
		}

		if (count == BUS_WITH) {
			count = 0;
			((unsigned short*)sdram)[PIXELS_OFFSET + pixelCount++] = buf;
			buf = 0;
		}
	}
	//puts("mult1 end");

	((unsigned short*)sdram)[0] = 0xFFFE;

	exclude += (float)clock() - timetmp;
	//while (0xFFFF != (((short*)sdram)[0] & 0xFFFF)) {
	while (0xFFFF != ((unsigned short*)sdram)[0]) {
		for (i = 0; i < 2000; i++) {
			tmp += 1;	
		}
	}

	//printf("FPGA return\n");

	timetmp = (float)clock();
	// short2float1
	for (i = 0; i < 200; i++) {
		((float*)sdram)[HIDDEN1_OFFSET+i] = (float)((short*)sdram)[RESULTS1_OFFSET+i];
	}
	exclude += (float)clock() - timetmp;
}

void newmult2(int dim2)
{
	int i, j, k;
	float sum = 0;

	unsigned short buf = 0;
	int count = 0;
	int tmp;
	//puts("mult2 start");

	timetmp = (float)clock();
	int pixelCount = 0;
	for (i = 0; i < dim2; i++) {
		count++;
		buf <<= 1;
		buf += round(((float*)sdram)[HIDDEN1_OFFSET+i]);

		if (count == BUS_WITH) {
			count = 0;
			((unsigned short*)sdram)[LAYER1_OFFSET + pixelCount++] = buf;
			//printf("%04x\n", buf);
			buf = 0;
		}
	}
	buf <<= 8;
	((unsigned short*)sdram)[LAYER1_OFFSET + pixelCount] = buf;
	

	// Start signal
	((unsigned short*)sdram)[0] = 0xFFFD;
	exclude += (float)clock() - timetmp;

	//while (0xFFFF != (((short*)sdram)[0] & 0xFFFF)) {
	while (0xFFFF != ((unsigned short*)sdram)[0]) {
		for (i = 0; i < 2000; i++) {
			tmp += 1;	
		}
	}

	//printf("FPGA return\n");

	// short2float
	timetmp = (float)clock();
	for (i = 0; i < 200; i++) {
		((float*)sdram)[HIDDEN2_OFFSET+i] = (float)((short*)sdram)[RESULTS2_OFFSET+i];
	}
	exclude += (float)clock() - timetmp;
}

//void mult2(int offset1, int offset2, int dim1, int dim2, int dim3)
//{
//	int i, j, k;
//	float sum = 0;
//
//	float *ret = &((float*)sdram)[HIDDEN2_OFFSET];
////	float **ret = (float**)malloc(dim1 * sizeof(float*));
////	for (i = 0; i < dim1; i++) {
////		ret[i] = (float*)malloc(dim3 * sizeof(float));
////	}
//	
//	for (i = 0; i < dim1; i++) {
//		for (j = 0; j < dim3; j++) {
//			for (k = 0; k < dim2; k++) {
//				sum += ((float*)sdram)[offset1 + i*dim2+k] * ((float*)sdram)[offset2 + k*dim3+j];
//				//printf("a = %.4lf, b = %.4lf\n", A[i][k] , x[k][j]);
//			}
//			ret[i*dim3 + j] = sum;
//			sum = 0;
//		}
//	}
//}

void mult3(int offset1, int offset2, int dim1, int dim2)
{
	int i, j, k;
	float sum = 0;

	float *ret = &((float*)sdram)[OUT_OFFSET];
//	float **ret = (float**)malloc(dim1 * sizeof(float*));
//	for (i = 0; i < dim1; i++) {
//		ret[i] = (float*)malloc(dim3 * sizeof(float));
//	}
	
	for (i = 0; i < dim1; i++) {
			for (k = 0; k < dim2; k++) {
				//sum += A[i][k] * x[k][j];
				sum += ((float*)sdram)[offset1 + i*dim2+k] * ((float*)sdram)[offset2 + k];
				//printf("a = %.4lf, b = %.4lf\n", A[i][k] , x[k][j]);
			}
			ret[i] = sum;
			sum = 0;
	}
}

void add(int offset1, int offset2, int dim1)
{
	int i, j;
	for (i = 0; i < dim1; i++) {
		((float*)sdram)[offset1+i] += ((float*)sdram)[offset2+i];
	}
}

void sigmoid(int offset, int dim1)
{
	int i, j;
	for (i = 0; i < dim1; i++) {
		((float*)sdram)[offset+i] = 1.0/(1.0 + exp(-((float*)sdram)[offset+i]));
	} 
}

int main(void)
{
	FILE *finalB1L1 = fopen("finalB1L1.txt", "r");
	FILE *finalB1L2 = fopen("finalB1L2.txt", "r");
	FILE *finalW1L1 = fopen("finalW1L1.txt", "r");
	FILE *finalW1L2 = fopen("finalW1L2.txt", "r");
	FILE *finalSoftmaxTheta = fopen("finalSoftmaxTheta.txt", "r");
	//FILE *testData = fopen("testData.txt", "r");
	FILE *testData;
	//FILE *testLabels = fopen("testLabels.txt", "r");
	FILE *testLabels = fopen("sample/labels.txt", "r");
	//FILE *testresult = fopen("result.txt", "r");

	int Labels[10000];

	char line[8000];
	char *ptr;
	int i;
	int j;


	void *VA;
	int fd;


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
	sdram = VA + ((unsigned long)(HW_BASE + 0x00) & (unsigned long)(HW_MASK));
	printf("sdram = 0x%X\n", (unsigned int)sdram);





	puts("parsing start");
	time1 = (float) clock();
	i = 0;
	while (fgets(line, 8000, finalB1L1) != NULL) {
		line[strlen(line)-1] = '\0';
		((float*)sdram)[B1L1_OFFSET+i] = atof(line);
		i++;
	}


	i = 0;
	while (fgets(line, 8000, finalB1L2) != NULL) {
		line[strlen(line)-1] = '\0';
		((float*)sdram)[B1L2_OFFSET+i] = atof(line);
		i++;
	}

	i = 0;
	while (fgets(line, 8000, testLabels) != NULL) {
		line[strlen(line)-1] = '\0';
		Labels[i] = atoi(line);
		i++;
	}


	unsigned short buf = 0;
	int count = 0;
	int writeCount = 0;
	short weight;

	while (fgets(line, 8000, finalW1L1) != NULL) {
		line[strlen(line)-1] = '\0';
		ptr = strtok(line, ",");

		while (ptr != NULL) {
			count++;
			weight = (short)(round(atof(ptr)));
			if (weight > 7) {
				weight = 7;
			} else if (weight < -8) {
				weight = -8;
			}
			buf <<= 4;
			buf = buf | (weight & 0xF);

			if (count == BUS_WITH/4) {
				count = 0;
				((short*)sdram)[WEIGHTS1_OFFSET + writeCount++] = buf;
				buf = 0;
			}
			ptr = strtok(NULL, ",");
		}
	}


	buf = 0;
	count = 0;
	writeCount = 0;

	while (fgets(line, 8000, finalW1L2) != NULL) {
		line[strlen(line)-1] = '\0';
		ptr = strtok(line, ",");

		while (ptr != NULL) {
			count++;
			weight = (short)(round(atof(ptr)));
			if (weight > 7) {
				weight = 7;
			} else if (weight < -8) {
				weight = -8;
			}
			buf <<= 4;
			buf = buf | (weight & 0xF);

			if (count == BUS_WITH/4) {
				count = 0;
				((short*)sdram)[WEIGHTS2_OFFSET + writeCount++] = buf;
				buf = 0;
			}
			ptr = strtok(NULL, ",");
		}
	}


	//rewind(finalW1L2);
	//i = 0;
	//j = 0;
	//while (fgets(line, 8000, finalW1L2) != NULL) {
	//	line[strlen(line)-1] = '\0';
	//	ptr = strtok(line, ",");

	//	while (ptr != NULL) {
	//		((float*)sdram)[W1L2_OFFSET+i*200+j] = atof(ptr);
	//		j++;
	//		ptr = strtok(NULL, ",");
	//	}
	//	j = 0;
	//	i++;
	//}


	i = 0;
	j = 0;
	while (fgets(line, 8000, finalSoftmaxTheta) != NULL) {
		line[strlen(line)-1] = '\0';
		ptr = strtok(line, ",");

		while (ptr != NULL) {
			((float*)sdram)[SOFTMAX_OFFSET+i*200+j] = atof(ptr);
			j++;
			ptr = strtok(NULL, ",");
		}
		j = 0;
		i++;
	}

	
	char filename[20];
	i = 0;
	j = 0;

	for (i = 0; i < FIGNUM; i++) {
		sprintf(filename, "sample/%d.txt", i+1);
		//printf("%s\n", filename);
		testData = fopen(filename, "r");
		if (testData == NULL) {
			printf("\nERROR: Cannot open %s\n", filename);
			exit(1);
		}

		while (fgets(line, 8000, testData) != NULL) {
			line[strlen(line)-1] = '\0';
			((float*)sdram)[DATA_OFFSET+i*784+j] = round(atof(line));
			j++;
		}

		j = 0;
		//fclose(testData);
	}

	//i = 0;
	//j = 0;
	//while (fgets(line, 8000, testData) != NULL) {
	//	line[strlen(line)-1] = '\0';
	//	ptr = strtok(line, ",");

	//	while (ptr != NULL) {
	//		((float*)sdram)[DATA_OFFSET+i*784+j] = round(atof(ptr));
	//		j++;
	//		ptr = strtok(NULL, ",");
	//	}
	//	j = 0;
	//	i++;
	//}

	fprintf(stderr, "parsing end: %.2f seconds\n",(float) (clock() - time1) / CLOCKS_PER_SEC);






	float max = 0;
	int maxidx = 0;
	int fignum = 0;
	count = 0;

	time1 = (float) clock();
	for (fignum = 0; fignum < FIGNUM; fignum++) {
		//writeZero();
		mult1(fignum, 784);
		//writeResult(results, fignum);
		add(HIDDEN1_OFFSET, B1L1_OFFSET, 200);
		sigmoid(HIDDEN1_OFFSET, 200);

		//mult2(W1L2_OFFSET, HIDDEN1_OFFSET, 200, 200, 1);
		newmult2(200);
		add(HIDDEN2_OFFSET, B1L2_OFFSET, 200);
		sigmoid(HIDDEN2_OFFSET, 200);

		mult3(SOFTMAX_OFFSET, HIDDEN2_OFFSET, 10, 200);
		sigmoid(OUT_OFFSET, 10);
		
		for (i = 0; i< 10; i++ ) {
			//printf("%.3f\t", final[i][0]);
			if (((float*)sdram)[OUT_OFFSET+i] > max) {
				max = ((float*)sdram)[OUT_OFFSET+i];
				maxidx = i + 1;
			}
		}
		printf("max_index = %d; expected %d\n", maxidx, Labels[fignum]);

		if (Labels[fignum] == maxidx) {
			count++;
		}
		
		max = 0;
		maxidx = 0;
	}
	time2 = (float)clock();

	fprintf(stderr, "\nCalculation: %.2f seconds(total), %.1f ms per image\n",(float) (time2 - time1 - exclude) / CLOCKS_PER_SEC, (float) (time2 - time1 - exclude) * 1000 / CLOCKS_PER_SEC / fignum);
	fprintf(stderr, "exclude: %.2f seconds(total)\n",(float) (exclude) / CLOCKS_PER_SEC);
	printf("sample size = %d, accuracy = %f\n", fignum, count / (float)fignum);
	return 0;
}
