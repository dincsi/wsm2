/*
Author: Chris Gage
*/
#include <stdio.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>

int main ( void )
{
unsigned long tmp, a1, a2, b1, b2, c1, c2, d1, d2;
char cny[3];
char infile[100];
char outfile[100];
FILE* pfin;
FILE* pfout;

scanf ( " %99[^\n]", infile );
scanf ( " %99[^\n]", outfile );

pfin = fopen( infile, "r" );
if (pfin == NULL)
{
printf( "Error Opening %s\n", infile );
return 1;
}

pfout = fopen( outfile, "w" );
if (pfout == NULL)
{
printf( "Error Opening %s\n", outfile );
return 2;
}

for (;;)
{
fscanf( pfin, " %lu,%lu,%s", &d1, &d2, cny );
if (feof( pfin )) break;

tmp=256*256*256;

a1=d1/tmp;
d1=d1-(a1*tmp);

a2=d2/tmp;
d2=d2-(a2*tmp);

tmp=256*256;

b1=d1/tmp;
d1=d1-(b1*tmp);

b2=d2/tmp;
d2=d2-(b2*tmp);

tmp=256;

c1=d1/tmp;
d1=d1-(c1*tmp);

c2=d2/tmp;
d2=d2-(c2*tmp);

fprintf( pfout, "%s: %lu.%lu.%lu.%lu %lu.%lu.%lu.%lu\n", cny, a1, b1, c1, d1, a2, b2, c2,
d2);
}

fclose( pfin );
fclose( pfout );
return 0;
}

