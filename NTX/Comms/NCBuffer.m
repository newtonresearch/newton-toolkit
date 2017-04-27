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

@interface NCBufferAccess ()
{
	unsigned int	index;
	unsigned int	lastCount;
}
@property(assign) unsigned char * basePtr;
@end

#define kPageBufSize 1024

@interface NCBuffer ()
{
	unsigned char buf[kPageBufSize];
}
@end


@implementation NCBuffer

- (id)init {
	if (self = [super init]) {
		self.basePtr = buf;
	}
	return self;
}
@end


/* -----------------------------------------------------------------------------
	N C B u f f e r A c c e s s
	Access to the buffer.
----------------------------------------------------------------------------- */

@implementation NCBufferAccess

- (id)init {
	if (self = [super init]) {
		[self clear];
	}
	return self;
}


- (void)setData:(unsigned char *)inData length:(NSUInteger)inLength {
	self.basePtr = inData;
	self.count = inLength;
	[self reset];
}


- (void)clear {
	[self reset];
	self.count = 0;
}


- (void)reset {
	index = 0;
}


- (void)mark {
	lastCount = self.count;
}


- (void)refill {
	[self reset];
	self.count = lastCount;
}


- (unsigned char *)ptr {
	return self.basePtr + index;
}


- (unsigned int) freeSpace {
	return kPageBufSize - self.count;
}


- (unsigned int) usedSpace {
	return self.count - index;
}


- (int) nextChar {
	if (index < self.count) {
		return self.basePtr[index++];
	} else {
		[self clear];
		return -1;
	}
}


- (void)setNextChar:(int)inCh {
	if (self.count < kPageBufSize) {
		self.basePtr[self.count++] = inCh;
	}
}


// return amount actually filled
- (unsigned int)fill:(unsigned int)inAmount {
	unsigned int actualAmount = inAmount;
	if (actualAmount > self.freeSpace) {
		actualAmount = self.freeSpace;
	}
	self.count += actualAmount;
	return actualAmount;
}


- (unsigned int)fill:(unsigned int)inAmount from:(const void *)inBuf {
	unsigned int actualAmount = inAmount;
	if (actualAmount > self.freeSpace) {
		actualAmount = self.freeSpace;
	}
	memcpy(self.ptr, inBuf, actualAmount);
	[self fill:actualAmount];
	return actualAmount;
}


- (void)drain:(unsigned int)inAmount {
	unsigned int actualAmount = inAmount;
	if (actualAmount > self.usedSpace) {
		actualAmount = self.usedSpace;
	}
	index += actualAmount;
	if (index == self.count) {
		[self clear];
	}
}


- (unsigned int)drain:(unsigned int)inAmount into:(void *)inBuf {
	unsigned int actualAmount = inAmount;
	if (actualAmount > self.usedSpace) {
		actualAmount = self.usedSpace;
	}
	memcpy(inBuf, self.ptr, actualAmount);
	[self drain:actualAmount];
	return actualAmount;
}


- (NSString *)description {
	char dbuf[1024];
	int i, len = sprintf(dbuf, "NCBuffer index:%u, count:%u", index,self.count);
	if (self.count > index) {
		len += sprintf(dbuf+len, ", data:");
		char * s = dbuf+len;
		unsigned char * p = self.ptr;
		for (i = index; i < self.count; i++, p++, s+=3) {
			sprintf(s, " %02X", *p);
		}
		*s = 0;
	}
	return [NSString stringWithUTF8String:dbuf];
}


@end

