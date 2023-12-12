/* File:     timer.h
 *
 * Purpose:  Define a macro that returns the number of seconds that 
 *           have elapsed since some point in the past.  The timer
 *           should return times with microsecond accuracy.
 *
 * Note:     The argument passed to the GET_TIME macro should be
 *           a double, *not* a pointer to a double.
 *
 * Example:  
 *    #include "timer.h"
 *    . . .
 *    double start, finish, elapsed;
 *    . . .
 *    GET_TIME(start);
 *    . . .
 *    Code to be timed
 *    . . .
 *    GET_TIME(finish);
 *    elapsed = finish - start;
 *    printf("The code to be timed took %e seconds\n", elapsed);
 *
 * IPP:  Section 3.6.1 (p. 129)
 */
#ifndef _TIMER_H_
#define _TIMER_H_

#ifdef _WIN32
#include <windows.h>
#else
#include <sys/time.h>
#endif

#ifdef _WIN32
static double frequency;

static void init_frequency() {
    LARGE_INTEGER li;
    QueryPerformanceFrequency(&li);
    frequency = (double)li.QuadPart;
}

#define GET_TIME(now) { \
    LARGE_INTEGER li; \
    if (frequency == 0) init_frequency(); \
    QueryPerformanceCounter(&li); \
    now = (double)li.QuadPart / frequency; \
}
#else
#define GET_TIME(now) { \
    struct timeval t; \
    gettimeofday(&t, NULL); \
    now = t.tv_sec + t.tv_usec / 1000000.0; \
}
#endif

#endif
