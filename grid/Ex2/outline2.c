#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// Code that reads values from a 2D grid and for each input point in the grid finds the minumum 
// value among all values stored in a window around that element, and stores the minumum 
// value in that output point.
//cell = input, node = output
// To compile it with GCC: g++ grid.cpp -lm
// WSIZE determines size of window which affects amount of work
#define WSIZE 16  
#define DATAHSIZE 20000
#define DATAWSIZE 14000
#define CHECK_VAL 1
#define MIN(X,Y) ((X<Y)?X:Y)
int main()
{
    int i, j, sr, sc, tempout;
    const int nr = DATAHSIZE; 
    const int nc = DATAWSIZE;
    const int wr = WSIZE;
    const int wc = WSIZE;
    typedef int oArray[DATAWSIZE];
    typedef int iArray[DATAWSIZE+WSIZE];
    oArray * output;
    iArray * input;
    if ((input = (iArray *)malloc(((nr+wr)*(nc+wc))*sizeof(int))) == 0) {printf("malloc fail\n"); exit(1);}
    if ((output = (oArray *)malloc((nr*nc)*sizeof(int))) == 0) {printf("malloc fail\n"); exit(1); }
    printf("Begin init\n");
    memset(input, 0x7F, (nr+wr)*(nc+wc)*sizeof(int));
    memset(output, 0x7F, (nr*nc)*sizeof(int));
    for (i=0; i < nr+wr; i+=wr)
      for (j=0; j < nc+wc; j+=wc)
        input[i][j] = CHECK_VAL;
    printf("Begin compute\n");
//INSERT ACCELERATOR DIRECTIVE HERE
    for(i=0; i<nr; i++)
        for(j=0; j<nc; j++){
          tempout = output[i][j];
          for (sr=0; sr<wr; sr++)
            for (sc=0; sc<wc; sc++)
            // node(i,j) = min( node(i,j), cell(i,j) );
              if (tempout > input[i+sr][j+sc]) tempout = input[i+sr][j+sc];
          output[i][j] = tempout;}
    printf("Finished Compute\n");
    for(i=0; i<nr; i++)
        for(j=0; j<nc; j++)
            if (output[i][j] != CHECK_VAL) {printf("mismatch at %d,%d, was: %d should be: %d\n", i,j,output[i][j], CHECK_VAL); return 1;}
    printf("Results pass\n");
    return 0;
}

