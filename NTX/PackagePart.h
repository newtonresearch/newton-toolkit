/*
	File:		PackagePart.h

	Abstract:	Wrapper for package part that maintains its data and info.

	Written by:	Newton Research Group, 2015.
*/

#import <Cocoa/Cocoa.h>
#import "NewtonKit.h"
#import "NTK/PackageParts.h"
#import "NTK/ObjHeader.h"
#import "NTK/Ref32.h"

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
- (void)buildPartData:(NSUInteger)inBaseOffset;
@end

