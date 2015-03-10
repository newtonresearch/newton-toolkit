/*
	File:		CircleBuf.h

	Contains:	Circle buffer interface.

	Written by:	Newton Research Group, 2009.
*/

#if !defined(__CIRCLEBUF_H)
#define __CIRCLEBUF_H 1

#include "Chunks.h"

// from "TraceEvents.h"
typedef enum { eNormalBuffer, eLockedBuffer, eWiredBuffer }  EBufferResidence;

struct MarkerInfo
{
	ULong	x00;
	ULong	x04;
};

/*------------------------------------------------------------------------------
	C C i r c l e B u f
	A circular FIFO buffer for communications services.
------------------------------------------------------------------------------*/

class CCircleBuf
{
public:
					CCircleBuf();
					~CCircleBuf();

	NewtonErr	allocate(size_t inSize);
	NewtonErr	allocate(size_t inSize, int inArg2, EBufferResidence inResidence, UChar inArg4);
	void			deallocate(void);

	void			reset(void);
	void			resetStart(void);

	size_t		bufferCount(void);
	size_t		bufferSpace(void);
	NewtonErr	bufferSpace(size_t inSpaceReqd);

	size_t		markerCount(void);
	size_t		markerSpace(void);

	NewtonErr	copyIn(CChunkBuffer * inBuf, size_t * ioSize);
	NewtonErr	copyIn(UByte * inBuf, ULong * ioSize, BOOL inArg3 = NO, ULong inArg4 = 0);

	NewtonErr	copyOut(CChunkBuffer * outBuf, ULong * ioSize, ULong * outArg3 = NULL);
	NewtonErr	copyOut(UByte * outBuf, ULong * ioSize, ULong * outArg3 = NULL);

	void			updateStart(ULong inDelta);
	void			updateEnd(ULong inDelta);

	NewtonErr	putEOM(ULong);
	NewtonErr	putNextEOM(ULong);
	NewtonErr	putEOMMark(ULong, ULong);
	ULong			getEOMMark(ULong *);
	ULong			peekNextEOMIndex(void);
	ULong			peekNextEOMIndex(ULong *);
	NewtonErr	bufferCountToNextMarker(ULong * outCount);
	NewtonErr	flushToNextMarker(ULong *);

	NewtonErr	getBytes(CCircleBuf * inBuf);
	NewtonErr	getNextByte(UByte * outByte);
	NewtonErr	getNextByte(UByte * outByte, ULong *);
	NewtonErr	peekNextByte(UByte * outByte);
	NewtonErr	peekNextByte(UByte * outByte, ULong *);
	NewtonErr	peekFirstLong(ULong * outLong);

	NewtonErr	putFirstPossible(UByte inByte);
	NewtonErr	putNextPossible(UByte inByte);
	NewtonErr	putNextStart(void);
	NewtonErr	putNextCommit(void);
	NewtonErr	putNextByte(UByte);
	NewtonErr	putNextByte(UByte, ULong);
	void			flushBytes(void);

private:
	void			getAlignLong(void);
	void			putAlignLong(void);

	size_t			fBufLen;				// +00
	UByte *			fBuf;					// +04
	ULong				fGetIndex;			// +08
	ULong				fPutIndex;			// +0C
	ULong				f10;
	EBufferResidence	fBufferResidence;	// +14
	UChar				f15;					// +15	flags:  0x02 => lock this in the heap  0x04 => wire it
	ULong				fNumOfMarkers;		// +18
	MarkerInfo *	fMarkers;			// +1C
	ULong				fGetMarkerIndex;	// +20
	ULong				fPutMarkerIndex;	// +24
};


#endif	/* __CIRCLEBUF_H */
