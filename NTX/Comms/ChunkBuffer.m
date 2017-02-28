/*
	File:		ChunkBuffer.m

	Contains:	Implementation of chunk buffers. Buffers… of chunks.

	Written by:	Newton Research Group, 2005.
*/

#import "ChunkBuffer.h"


/*------------------------------------------------------------------------------
	N C C h u n k
------------------------------------------------------------------------------*/

@implementation NCChunk

/*------------------------------------------------------------------------------
	Initialize. Reset input and output pointers to start of data buffer.
	Args:		--
	Return:	self
------------------------------------------------------------------------------*/

- (id) init
{
	if (self = [super init])
	{
		inPtr = outPtr = data;
	}
	return self;
}


/*------------------------------------------------------------------------------
	Return the number of bytes of data in the buffer.
	Args:		--
	Return:	the number of bytes
------------------------------------------------------------------------------*/

- (unsigned int) amtFilled
{
	return inPtr - outPtr;
}


/*------------------------------------------------------------------------------
	Return the number of bytes available in the buffer.
	Args:		--
	Return:	the number of bytes
------------------------------------------------------------------------------*/

- (unsigned int) amtLeft
{
	return kChunkSize - (inPtr - data);
}


/*------------------------------------------------------------------------------
	Write data into the buffer.
	ASSUME the caller will not write out of bounds.
	Args:		inBuf			data source
				inSize		number of bytes to write
	Return:	--
------------------------------------------------------------------------------*/

- (void) write: (const void *) inBuf length: (unsigned int) inSize
{
	memcpy(inPtr, inBuf, inSize);
	inPtr += inSize;
}


/*------------------------------------------------------------------------------
	Read data from the buffer.
	ASSUME the caller will not read out of bounds.
	Args:		outBuf		data destination
				inSize		number of bytes to read
	Return:	YES => the buffer is now empty
------------------------------------------------------------------------------*/

- (BOOL) read: (void *) outBuf length: (unsigned int) inSize
{
	memcpy(outBuf, outPtr, inSize);
	outPtr += inSize;

	return (outPtr >= inPtr);
}

@end


/*------------------------------------------------------------------------------
	N C C h u n k B u f f e r
------------------------------------------------------------------------------*/

@implementation NCChunkBuffer

/*------------------------------------------------------------------------------
	Initialize. There are no chunks initially.
	Args:		--
	Return:	self
------------------------------------------------------------------------------*/

- (id) init
{
	if (self = [super init])
	{
		accessQueue = dispatch_queue_create("com.newton.connection.fifo", NULL);
		numOfChunks = 0;
		chunks = nil;
	}
	return self;
}


/*------------------------------------------------------------------------------
	Deallocate. Deallocate any chunks.
	Args:		--
	Return:	--
------------------------------------------------------------------------------*/

- (void) dealloc
{
	[self flush];
	dispatch_release(accessQueue), accessQueue = nil;
	[super dealloc];
}


/*------------------------------------------------------------------------------
	Return the total number of bytes available.
	Args:		--
	Return:	the number of bytes
------------------------------------------------------------------------------*/

- (unsigned int) size
{
	unsigned int i, total = 0;

	for (i = 0; i < numOfChunks; i++)
		total += chunks[i].amtFilled;

	return total;
}


/*------------------------------------------------------------------------------
	Return the empty state.
	Args:		--
	Return:	YES => no bytes available
------------------------------------------------------------------------------*/

- (BOOL)	isEmpty
{
	return self.size == 0;
}


/*------------------------------------------------------------------------------
	Return a pointer to the chunk into which we are currently writing.
	Grow the chunks if there is no space available.
	Args:		--
	Return:	a pointer to the chunk
------------------------------------------------------------------------------*/

- (NCChunk *) getNextChunk
{
	if (numOfChunks == 0 || chunks[numOfChunks-1].amtLeft == 0)
	{
		NCChunk ** enlargedChunkPtrs = (NCChunk **) realloc(chunks, (numOfChunks+1) * sizeof(NCChunk*));
		if (enlargedChunkPtrs == nil)
			return nil;
		chunks = enlargedChunkPtrs;
		chunks[numOfChunks++] = [[NCChunk alloc] init];
	}
	return chunks[numOfChunks-1];
}


/*------------------------------------------------------------------------------
	Read data from the buffer.
	Args:		outBuf		data destination
				inSize		number of bytes to read
	Return:	the number of bytes actually read
------------------------------------------------------------------------------*/

- (int) nextChar
{
	unsigned char ch;
	return ([self read: &ch length: 1] == 1) ? ch : -1;
}


- (unsigned int) read: (void *) outBuf length: (unsigned int) inSize
{
	__block unsigned int amtRead;
	dispatch_sync(accessQueue,
	^{
		NCChunk * chunk;
		unsigned int amtRequested, amtAvailable;
		char * buf = (char *)outBuf;

		for (amtRead = 0; amtRead < inSize && [self size] > 0; amtRead += amtRequested)
		{
			// start reading from the first chunk
			chunk = chunks[0];
			amtRequested = inSize - amtRead;
			amtAvailable = chunk.amtFilled;
			if (amtRequested > amtAvailable)
				amtRequested = amtAvailable;

			if ([chunk read: buf length: amtRequested])
			{
				// chunk is now empty
				if (numOfChunks == 1)
					// always leave one chunk but re-initialize it
					[chunk init];
				else
				{
					// lose the first chunk
					[chunk release];
					numOfChunks--;
					memcpy(&chunks[0], &chunks[1], numOfChunks * sizeof(NCChunk*));
				}
			}
			buf += amtRequested;
		}
	});
	return amtRead;
}


/*------------------------------------------------------------------------------
	Write data to the buffer.
	Args:		inBuf			data source
				inSize		number of bytes to write
	Return:	the number of bytes actually written
------------------------------------------------------------------------------*/

- (unsigned int) write: (const void *) inBuf length: (unsigned int) inSize
{
	__block unsigned int amtWritten;
	dispatch_sync(accessQueue,
	^{
		NCChunk * chunk;
		unsigned int chunkSize, chunkLeft;
		const char * buf = (const char *)inBuf;

		for (amtWritten = 0; amtWritten < inSize; amtWritten += chunkSize)
		{
			if ((chunk = [self getNextChunk]) == nil)
				break;
			chunkSize = inSize - amtWritten;
			chunkLeft = chunk.amtLeft;
			if (chunkSize > chunkLeft)
				chunkSize = chunkLeft;
			[chunk write: buf length: chunkSize];
			buf += chunkSize;
		}
	});
	return amtWritten;
}


/*------------------------------------------------------------------------------
	Release all the data.
	Args:		--
	Return:	--
------------------------------------------------------------------------------*/

- (void) flush
{
	unsigned int i;

	for (i = 0; i < numOfChunks; i++)
		[chunks[i] release];
	free(chunks);
	chunks = nil;
	numOfChunks = 0;
}

@end
