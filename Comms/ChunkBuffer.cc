/*
	File:		ChunkBuffer.cc

	Contains:	Implementation of chunk buffers. Buffers… of chunks.

	Written by:	Newton Research Group, 2005.
*/

#include "Chunks.h"
#include <strings.h>


/*------------------------------------------------------------------------------
	C C h u n k
------------------------------------------------------------------------------*/

CChunk::CChunk()
{ init(); }

CChunk::~CChunk()
{ }

/*------------------------------------------------------------------------------
	Initialize. Reset input and output pointers to start of data buffer.
	Args:		--
	Return:	--
------------------------------------------------------------------------------*/

void
CChunk::init(void)
{
	inPtr = outPtr = data;
}


/*------------------------------------------------------------------------------
	Return the number of bytes of data in the buffer.
	Args:		--
	Return:	the number of bytes
------------------------------------------------------------------------------*/

unsigned int
CChunk::amtFilled(void)
{
	return inPtr - outPtr;
}


/*------------------------------------------------------------------------------
	Return the number of bytes available in the buffer.
	Args:		--
	Return:	the number of bytes
------------------------------------------------------------------------------*/

unsigned int
CChunk::amtLeft(void)
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

void
CChunk::write(const void * inBuf, unsigned int inSize)
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

BOOL
CChunk::read(void * outBuf, unsigned int inSize)
{
	memcpy(outBuf, outPtr, inSize);
	outPtr += inSize;

	return (outPtr >= inPtr);
}

#pragma mark -

/*------------------------------------------------------------------------------
	C C h u n k B u f f e r
------------------------------------------------------------------------------*/

/*------------------------------------------------------------------------------
	Initialize. There are no chunks initially.
	Args:		--
	Return:	self
------------------------------------------------------------------------------*/

CChunkBuffer::CChunkBuffer()
{
	numOfChunks = 0;
	chunks = nil;
}


/*------------------------------------------------------------------------------
	Deallocate. Deallocate any chunks.
	Args:		--
	Return:	--
------------------------------------------------------------------------------*/

CChunkBuffer::~CChunkBuffer()
{
	flush();
}


/*------------------------------------------------------------------------------
	Return the total number of bytes available.
	Args:		--
	Return:	the number of bytes
------------------------------------------------------------------------------*/

unsigned int
CChunkBuffer::size(void)
{
	unsigned int i, total = 0;

	for (i = 0; i < numOfChunks; i++)
		total += chunks[i]->amtFilled();

	return total;
}


/*------------------------------------------------------------------------------
	Return a pointer to the chunk into which we are currently writing.
	Grow the chunks if there is no space available.
	Args:		--
	Return:	a pointer to the chunk
------------------------------------------------------------------------------*/

CChunk *
CChunkBuffer::getNextChunk(void)
{
	if (numOfChunks == 0 || chunks[numOfChunks-1]->amtLeft() == 0)
	{
		CChunk ** enlargedChunkPtrs = (CChunk **) realloc(chunks, (numOfChunks+1) * sizeof(CChunk*));
		if (enlargedChunkPtrs == nil)
			return nil;
		chunks = enlargedChunkPtrs;
		chunks[numOfChunks++] = new CChunk;
	}
	return chunks[numOfChunks-1];
}


/*------------------------------------------------------------------------------
	Read data from the buffer.
	ASSUME the caller will not read more data than is available.
	Args:		outBuf		data destination
				inSize		number of bytes to read
	Return:	the number of bytes actually read
------------------------------------------------------------------------------*/

unsigned int
CChunkBuffer::read(void * outBuf, unsigned int inSize)
{
	CChunk * chunk;
	unsigned int amtRead, amtRequested, amtAvailable;

	ASSERT(inSize <= size());

	for (amtRead = 0; amtRead < inSize && size() > 0; amtRead += amtRequested)
	{
		// start reading from the first chunk
		chunk = chunks[0];
		amtRequested = inSize - amtRead;
		amtAvailable = chunk->amtFilled();
		if (amtRequested > amtAvailable)
			amtRequested = amtAvailable;

		if (chunk->read(outBuf, amtRequested))
		{
			// chunk is now empty
			if (numOfChunks == 1)
				// always leave one chunk but re-initialize it
				chunk->init();
			else
			{
				// lose the first chunk
				delete chunk;
				numOfChunks--;
				memcpy(&chunks[0], &chunks[1], numOfChunks * sizeof(CChunk*));
			}
		}
		outBuf = (char *) outBuf + amtRequested;
	}
	return amtRead;
}


/*------------------------------------------------------------------------------
	Write data to the buffer.
	Args:		inBuf			data source
				inSize		number of bytes to write
	Return:	the number of bytes actually written
------------------------------------------------------------------------------*/

unsigned int
CChunkBuffer::write(const void * inBuf, unsigned int inSize)
{
	CChunk * chunk;
	unsigned int chunkSize, chunkLeft;
	unsigned int amtWritten;

	for (amtWritten = 0; amtWritten < inSize; amtWritten += chunkSize)
	{
		if ((chunk = getNextChunk()) == nil)
			break;
		chunkSize = inSize - amtWritten;
		chunkLeft = chunk->amtLeft();
		if (chunkSize > chunkLeft)
			chunkSize = chunkLeft;
		chunk->write(inBuf, chunkSize);
		inBuf = (const char *) inBuf + chunkSize;
	}
	return amtWritten;
}


/*------------------------------------------------------------------------------
	Release all the data.
	Args:		--
	Return:	--
------------------------------------------------------------------------------*/

void
CChunkBuffer::flush(void)
{
	if (chunks)
	{
		for (int i = 0; i < numOfChunks; i++)
			delete chunks[i];
		free(chunks);
	}
	chunks = nil;
	numOfChunks = 0;
}

