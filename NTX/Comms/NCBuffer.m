/*
	File:		NCBuffer.m

	Contains:	A simple buffer implementation.

	Written by:	Newton Research Group, 2012.
*/

#import "NCBuffer.h"

/* -----------------------------------------------------------------------------
	N C B u f f e r
	count => limit of data written to buffer
	index => limit of data read from buffer
----------------------------------------------------------------------------- */

@implementation NCBuffer

- (id) init
{
	if (self = [super init])
	{
		bufPtr = buf;
	}
	return self;
}
@end


@implementation NCBufferAccess

- (id) init
{
	if (self = [super init])
	{
		[self clear];
	}
	return self;
}


- (void) setData: (unsigned char *) inData length: (NSUInteger) inLength
{
	bufPtr = inData;
	count = inLength;
	[self reset];
}


- (void) clear
{ [self reset]; count = 0; }


- (void) reset
{ index = 0; }


- (void) mark
{ lastCount = count; }


- (void) refill
{ [self reset]; count = lastCount; }


- (unsigned char *) ptr
{ return bufPtr + index; }


@synthesize count;


- (unsigned int) freeSpace
{ return kPageBufSize - count; }


- (unsigned int) usedSpace
{ return count - index; }


- (int) nextChar
{ if (index < count) return bufPtr[index++]; else {[self clear]; return -1;} }


- (void) setNextChar: (int) inCh
{ if (count < kPageBufSize) bufPtr[count++] = inCh; }


// return amount actually filled
- (unsigned int) fill: (unsigned int) inAmount
{
	unsigned int actualAmount = inAmount;
	if (actualAmount > self.freeSpace)
		actualAmount = self.freeSpace;
	count += actualAmount;
	return actualAmount;
}


- (unsigned int) fill: (unsigned int) inAmount from: (const void *) inBuf
{
	unsigned int actualAmount = inAmount;
	if (actualAmount > self.freeSpace)
		actualAmount = self.freeSpace;
	memcpy(self.ptr, inBuf, actualAmount);
	[self fill:actualAmount];
	return actualAmount;
}


- (void) drain: (unsigned int) inAmount
{
	unsigned int actualAmount = inAmount;
	if (actualAmount > self.usedSpace)
	{
		actualAmount = self.usedSpace;
	}
	index += actualAmount;
	if (index == count)
		[self clear];
}


- (unsigned int) drain: (unsigned int) inAmount into: (void *) inBuf
{
	unsigned int actualAmount = inAmount;
	if (actualAmount > self.usedSpace)
		actualAmount = self.usedSpace;
	memcpy(inBuf, self.ptr, actualAmount);
	[self drain:actualAmount];
	return actualAmount;
}


- (NSString *) description
{
	char dbuf[1024];
	int i, len = sprintf(dbuf, "NCBuffer index:%u, count:%u", index,count);
	if (count > index)
	{
		len += sprintf(dbuf+len, ", data:");
		char * s = dbuf+len;
		unsigned char * p = self.ptr;
		for (i = index; i < count; i++, p++, s+=3)
		{
			sprintf(s, " %02X", *p);
		}
		*s = 0;
	}
	return [NSString stringWithUTF8String:dbuf];
}


@end

