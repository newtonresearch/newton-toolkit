/*
	File:		Chunks.h

	Contains:	Interface to buffered chunks of data.

	Written by:	Newton Research Group, 2005.
*/

// USE MAC MEMORY FUNCTIONS
#define __NEWTONMEMORY_H 1

#include "Newton.h"


#define kChunkSize 1024

/*------------------------------------------------------------------------------
	C C h u n k
------------------------------------------------------------------------------*/

class CChunk
{
public:
						CChunk();
						~CChunk();

	void				init(void);
	unsigned int	amtFilled(void);
	unsigned int	amtLeft(void);
	BOOL				read(void * outBuf, unsigned int inSize);
	void				write(const void * inBuf, unsigned int inSize);

private:
	char	 	data[kChunkSize];
	char *	inPtr;
	char *	outPtr;
};


/*------------------------------------------------------------------------------
	C C h u n k B u f f e r
------------------------------------------------------------------------------*/

class CChunkBuffer
{
public:
						CChunkBuffer();
						~CChunkBuffer();

	unsigned int	size(void);
	CChunk *			getNextChunk(void);
	unsigned int	read(void * outBuf, unsigned int inSize);
	unsigned int	write(const void * inBuf, unsigned int inSize);
	void				flush(void);

private:
	unsigned int	numOfChunks;
	CChunk **		chunks;
};

