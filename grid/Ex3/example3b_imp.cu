#include <stdio.h>
#include <stdlib.h>
// these are just for timing measurments
#include <time.h>
// Code that reads values from a 2D grid and for each node in the grid finds the minumum
// value among all values stored in cells sharing that node, and stores the minumum
// value in that node.

// To compile it with nvcc execute: nvcc -O2 -o grid3 grid3.cu
// Modified by Bob Crovella NVIDIA Corp. 12/2011 to demonstrate CUDA

//define the window size (square window) and the data set size
#define WSIZE 16
#define DATAHSIZE 20000
#define DATAWSIZE 14000
#define CHECK_VAL 1
#define MIN(X,Y) ((X<Y)?X:Y)
#define BLKWSIZE 32
#define BLKHSIZE 32

#define cudaCheckErrors(msg) \
    do { \
        cudaError_t __err = cudaGetLastError(); \
        if (__err != cudaSuccess) { \
            fprintf(stderr, "Fatal error: %s (%s at %s:%d)\n", \
                msg, cudaGetErrorString(__err), \
                __FILE__, __LINE__); \
            fprintf(stderr, "*** FAILED - ABORTING\n"); \
            exit(1); \
        } \
    } while (0)

typedef int oArray[DATAHSIZE];
typedef int iArray[DATAHSIZE+WSIZE];

__global__ void cmp_win(oArray *output, const iArray *input)
{
    __shared__ int smem[(BLKHSIZE + (WSIZE-1))][(BLKWSIZE + (WSIZE-1))];
    int tempout, i, j;
    int idx = blockIdx.x*blockDim.x + threadIdx.x;
    int idy = blockIdx.y*blockDim.y + threadIdx.y;
    if ((idx < DATAHSIZE+WSIZE) && (idy < DATAWSIZE+WSIZE))
      smem[threadIdx.y][threadIdx.x]=input[idy][idx];
    if ((idx < DATAHSIZE+WSIZE) && (idy < DATAWSIZE) && (threadIdx.y > BLKWSIZE - WSIZE))
      smem[threadIdx.y + (WSIZE-1)][threadIdx.x] = input[idy+(WSIZE-1)][idx];
    if ((idx < DATAHSIZE) && (idy < DATAWSIZE+WSIZE) && (threadIdx.x > BLKHSIZE - WSIZE))
      smem[threadIdx.y][threadIdx.x + (WSIZE-1)] = input[idy][idx+(WSIZE-1)];
    if ((idx < DATAHSIZE) && (idy < DATAWSIZE) && (threadIdx.x > BLKHSIZE - WSIZE) && (threadIdx.y > BLKWSIZE - WSIZE))
      smem[threadIdx.y + (WSIZE-1)][threadIdx.x + (WSIZE-1)] = input[idy+(WSIZE-1)][idx+(WSIZE-1)];
    __syncthreads();
    if ((idx < DATAHSIZE) && (idy < DATAWSIZE)){
      tempout = output[idy][idx];
      for (i=0; i<WSIZE; i++)
        for (j=0; j<WSIZE; j++)
          if (smem[threadIdx.y + i][threadIdx.x + j] < tempout)
            tempout = smem[threadIdx.y + i][threadIdx.x + j];
      output[idy][idx] = tempout;
      }
}

int main(int argc, char *argv[])
{
    int i, j;
    const dim3 blockSize(BLKHSIZE, BLKWSIZE, 1);
    const dim3 gridSize(((DATAHSIZE+BLKHSIZE-1)/BLKHSIZE), ((DATAWSIZE+BLKWSIZE-1)/BLKWSIZE), 1);
// these are just for timing
    clock_t t0, t1, t2;
    double t1sum=0.0;
    double t2sum=0.0;
// overall data set sizes
    const int nr = DATAHSIZE;
    const int nc = DATAWSIZE;
// window dimensions
    const int wr = WSIZE;
    const int wc = WSIZE;
// pointers for data set storage via malloc
    iArray *h_in, *d_in;
    oArray *h_out, *d_out;
// start timing
    t0 = clock();
// allocate storage for data set
    if ((h_in = (iArray *)malloc(((nr+wr)*(nc+wc))*sizeof(int))) == 0) {printf("malloc Fail \n"); exit(1);}
    if ((h_out = (oArray *)malloc((nr*nc)*sizeof(int))) == 0) {printf("malloc Fail \n"); exit(1); }
// synthesize data
    printf("Begin init\n");
    memset(h_in, 0x7F, (nr+wr)*(nc+wc)*sizeof(int));
    memset(h_out, 0x7F, (nr*nc)*sizeof(int));
    for (i=0; i<nc+wc; i+=wc)
      for (j=0; j< nr+wr; j+=wr)
        h_in[i][j] = CHECK_VAL;
    t1 = clock();
    t1sum = ((double)(t1-t0))/CLOCKS_PER_SEC;
    printf("Init took %f seconds.  Begin compute\n", t1sum);
// allocate GPU device buffers
    cudaMalloc((void **) &d_in, (((nr+wr)*(nc+wc))*sizeof(int)));
    cudaCheckErrors("Failed to allocate device buffer");
    cudaMalloc((void **) &d_out, ((nr*nc)*sizeof(int)));
    cudaCheckErrors("Failed to allocate device buffer2");
// copy data to GPU
    cudaMemcpy(d_out, h_out, ((nr*nc)*sizeof(int)), cudaMemcpyHostToDevice);
    cudaCheckErrors("CUDA memcpy failure");
    cudaMemcpy(d_in, h_in, (((nr+wr)*(nc+wc))*sizeof(int)), cudaMemcpyHostToDevice);
    cudaCheckErrors("CUDA memcpy2 failure");

    cmp_win<<<gridSize,blockSize>>>(d_out, d_in);
    cudaCheckErrors("Kernel launch failure");
// copy output data back to host

    cudaMemcpy(h_out, d_out, ((nr*nc)*sizeof(int)), cudaMemcpyDeviceToHost);
    cudaCheckErrors("CUDA memcpy3 failure");
    t2 = clock();
    t2sum = ((double)(t2-t1))/CLOCKS_PER_SEC;
    printf ("Done. Compute took %f seconds\n", t2sum);
    for (i=0; i < nc; i++)
      for (j=0; j < nr; j++)
        if (h_out[i][j] != CHECK_VAL) {printf("mismatch at %d,%d, was: %d should be: %d\n", i,j,h_out[i][j], CHECK_VAL); return 1;}
    printf("Results pass\n");

    return 0;
}
