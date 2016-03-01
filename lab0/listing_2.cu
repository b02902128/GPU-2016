#include <stdio.h>
#include <ctype.h>
#include <cstdio>
#include <cstdlib>
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "SyncedMemory.h"

#define CHECK {\
	auto e = cudaDeviceSynchronize();\
	if (e != cudaSuccess) {\
		printf("At " __FILE__ ":%d, %s\n", __LINE__, cudaGetErrorString(e));\
		abort();\
		}\
}

__global__ void PairSwap(char *input_gpu, int fsize) {
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	char temp;
	if (idx % 2 == 0)
		if (idx < fsize && input_gpu[idx] != '\0') {
			if ((input_gpu[idx] >= 65 && input_gpu[idx] <= 90) ||
				(input_gpu[idx] >= 97 && input_gpu[idx] <= 122))
				if ((input_gpu[idx + 1] >= 65 && input_gpu[idx + 1] <= 90) ||
					(input_gpu[idx + 1] >= 97 && input_gpu[idx + 1] <= 122)){
					temp = input_gpu[idx + 1];
					input_gpu[idx + 1] = input_gpu[idx];
					input_gpu[idx] = temp;
				}
		}
}

int main(int argc, char **argv) {
	// init, and check
	/*if (argc != 2) {
		printf("Usage %s <input text file>\n", argv[0]);
		abort();
	}*/
	//FILE *fp = fopen(argc[1], "r");
	FILE *fp = fopen("test.txt", "r");
	if (fp == NULL) {
		printf("Cannot open %s", argv[1]);
		abort();
	}
	// get file size
	fseek(fp, 0, SEEK_END);
	size_t fsize = ftell(fp);
	fseek(fp, 0, SEEK_SET);
	// read files
	MemoryBuffer<char> text(fsize + 1);
	auto text_smem = text.CreateSync(fsize);
	CHECK;
	fread(text_smem.get_cpu_wo(), 1, fsize, fp);               
	text_smem.get_cpu_wo()[fsize] = '\0';
	fclose(fp);

	// TODO: do your transform here
	char *input_gpu = text_smem.get_gpu_rw();
	// An example: transform the first 64 characters to '!'
	// Don't transform over the tail
	// And don't transform the line breaks
	int blocksize = 8;
	int nblock = (fsize / blocksize) + (fsize % blocksize == 0 ? 0 : 1);
	//pair swap
	PairSwap << < nblock, blocksize >> >(input_gpu, fsize);
	puts(text_smem.get_cpu_ro());

	return 0;
}