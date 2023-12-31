/*
Computing a movie of zooming into a fractal

Original C++ code by Martin Burtscher, Texas State University

Reference: E. Ayguade et al., 
           "Peachy Parallel Assignments (EduHPC 2018)".
           2018 IEEE/ACM Workshop on Education for High-Performance Computing (EduHPC), pp. 78-85,
           doi: 10.1109/EduHPC.2018.00012

Copyright (c) 2018, Texas State University. All rights reserved.

Redistribution and usage in source and binary form, with or without
modification, is only permitted for educational use.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Author: Martin Burtscher
*/

#include <stdlib.h>
#include <stdio.h>
#include <cuda_runtime.h>
#include <sys/stat.h>
#include <sys/types.h>
#include "timer.h"
#include "fractal.h"

static const double Delta = 0.001;
static const double xMid =  0.23701;
static const double yMid =  0.521;

__global__ void computeFractal(int width, int height, double x0, double y0, double dx, double dy, unsigned char *pic, int frame) {
    // printf("calling compute fractal\n");
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    if (col < width && row < height) {
        double cx = x0 + col * dx;
        double cy = y0 + row * dy;
        
        double x = cx;
        double y = cy;
        int depth = 256;
        double x2, y2;

        while (depth > 0 && (x * x + y * y) < 5.0) {
            x2 = x * x;
            y2 = y * y;
            y = 2 * x * y + cy;
            x = x2 - y2 + cx;
            depth--;
        }

        pic[frame * height * width + row * width + col] = (unsigned char)depth;
    }
}


int main(int argc, char *argv[]) {
    double start, end;

    printf("Fractal v1.6 [serial]\n");

    /* read command line arguments */
    if (argc != 4) {fprintf(stderr, "usage: %s height width num_frames\n", argv[0]); exit(-1);}
    int width = atoi(argv[1]);
    if (width < 10) {fprintf(stderr, "error: width must be at least 10\n"); exit(-1);}
    int height = atoi(argv[2]);
    if (height < 10) {fprintf(stderr, "error: height must be at least 10\n"); exit(-1);}
    int num_frames = atoi(argv[3]);
    if (num_frames < 1) {fprintf(stderr, "error: num_frames must be at least 1\n"); exit(-1);}
    printf("Computing %d frames of %d by %d fractal\n", num_frames, width, height);

    /* allocate image array */
    unsigned char *pic = (unsigned char *)malloc(num_frames * height * width * sizeof(unsigned char));

    unsigned char *cuda_pic;
    cudaMalloc(&cuda_pic, num_frames * height * width * sizeof(unsigned char));

    // Define block and grid sizes
    dim3 threadsPerBlock(16, 16);
    dim3 numBlocks((width + threadsPerBlock.x - 1) / threadsPerBlock.x, 
                   (height + threadsPerBlock.y - 1) / threadsPerBlock.y);


    GET_TIME(start);

    // Main loop to compute frames
    for (int frame = 0; frame < num_frames; frame++) {
        double delta = Delta * pow(0.98, frame);
        double x0 = xMid - delta * (double)width / height;
        double y0 = yMid - delta;
        double dx = 2.0 * delta * (double)width / height / width;
        double dy = 2.0 * delta / height;

        computeFractal<<<numBlocks, threadsPerBlock>>>(width, height, x0, y0, dx, dy, cuda_pic, frame);
        // Synchronize after each kernel call
        cudaDeviceSynchronize();

        // Check for errors immediately after kernel call
        cudaError_t err = cudaGetLastError();
        if (err != cudaSuccess) {
            fprintf(stderr, "CUDA Error: %s\n", cudaGetErrorString(err));
        }
    }


    GET_TIME(end);
    printf("CUDA compute time: %.4f s\n", end - start);

    cudaMemcpy(pic, cuda_pic, num_frames * height * width * sizeof(unsigned char), cudaMemcpyDeviceToHost);

    if ((width <= 4096) && (num_frames <= 120)) {
        
        // Create sub-directory to store frames in
        #ifdef _WIN32
        _mkdir("frames");
        #else
        mkdir("frames",0777);
        #endif

	printf("saving frames\n");
        for (int frame = 0; frame < num_frames; frame++) {
            char name[32];
            sprintf(name, "frames/fractal%d.bmp", frame + 1000);
            writeBMP(width, height, &pic[frame * height * width], name);
        }
    }

    free(pic);
    cudaFree(cuda_pic);
    
    
    return 0;
} /* main */
