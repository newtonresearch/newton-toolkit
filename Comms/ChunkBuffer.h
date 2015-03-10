/*
	File:		ChunkBuffer.h

	Contains:	Interface to buffered chunks of data.

	Written by:	Newton Research Group, 2011.
*/

#import <Foundation/Foundation.h>

#define kChunkSize 1024

/*------------------------------------------------------------------------------
	N C C h u n k
------------------------------------------------------------------------------*/

@interface NCChunk : NSObject
{
	char	 	data[kChunkSize];
	char *	inPtr;
	char *	outPtr;
}

@property(readonly)	unsigned int	amtFilled;
@property(readonly)	unsigned int	amtLeft;

- (BOOL)				read: (void *) outBuf length: (unsigned int) inSize;
- (void)				write: (const void *) inBuf length: (unsigned int) inSize;

@end


/*------------------------------------------------------------------------------
	N C C h u n k B u f f e r
------------------------------------------------------------------------------*/

@interface NCChunkBuffer : NSObject
{
	dispatch_queue_t accessQueue;
	unsigned int	numOfChunks;
	NCChunk **		chunks;
}

@property(readonly)	unsigned int	size;
@property(readonly)	BOOL	isEmpty;
@property(readonly)	int	nextChar;

- (NCChunk *)		getNextChunk;
- (unsigned int)	read: (void *) outBuf length: (unsigned int) inSize;
- (unsigned int)	write: (const void *) inBuf length: (unsigned int) inSize;
- (void)				flush;

@end

