/*
	File:		PackagePart.h

	Abstract:	Wrapper for package part that maintains its data and info.

	Written by:	Newton Research Group, 2015.
*/

#import <Cocoa/Cocoa.h>
#import "NewtonKit.h"
#import "NTK/PackageParts.h"
#import "NTK/ObjHeader.h"

/*------------------------------------------------------------------------------
	Legacy Refs for a 64-bit world.
	See also Newton/ObjectSystem.cc which does this for Refs createwd by NTK.
------------------------------------------------------------------------------*/

typedef int32_t Ref32;

#define OBJHEADER32 \
	uint32_t size  : 24; \
	uint32_t flags :  8; \
	union { \
		struct { \
			uint32_t	locks :  8; \
			uint32_t	slots : 24; \
		} count; \
		int32_t stuff; \
		Ref32 destRef; \
	}gc;

struct ObjHeader32
{
	OBJHEADER32
}__attribute__((packed));

struct ArrayObject32
{
	OBJHEADER32
	Ref32		objClass;
	Ref32		slot[];
}__attribute__((packed));

struct SymbolObject32
{
	OBJHEADER32
	Ref32		objClass;
	ULong		hash;
	char		name[];
}__attribute__((packed));

struct StringObject32
{
	OBJHEADER32
	Ref32		objClass;
	UniChar	str[];
}__attribute__((packed));

#define BYTE_SWAP_SIZE(n) (((n << 16) & 0x00FF0000) | (n & 0x0000FF00) | ((n >> 16) & 0x000000FF))
#if defined(hasByteSwapping)
#define CANONICAL_SIZE BYTE_SWAP_SIZE
#else
#define CANONICAL_SIZE(n) (n)
#endif

#define k4ByteAlignmentFlag 0x00000001

/* -----------------------------------------------------------------------------
	N T X P a c k a g e P a r t
----------------------------------------------------------------------------- */
@interface NTXPackagePart : NSObject
{
	PartEntry _dirEntry;
	RefStruct _partData;
	int _alignment;
	ArrayObject32 * partRoot;
	const char * infoStr;
}
@property(readonly) PartEntry * entry;
@property(readonly) const char * info;
@property(readonly) NSUInteger infoLen;
@property(readonly) const void * data;
@property(readonly) NSUInteger dataLen;
@property(readonly) const void * relocationData;
@property(readonly) NSUInteger relocationDataLen;

- (id)initWith:(RefArg)content type:(const char *)type alignment:(int)inAlignment;
- (id)initWithRawData:(const void *)content size:(int)contentSize type:(const char *)type;
- (void)updateInfoOffset:(ULong *)ioInfoOffset dataOffset:(ULong *)ioDataOffset;
- (void)buildPartData:(NSUInteger)inBaseOffset;
@end

