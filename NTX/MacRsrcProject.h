/*
	File:		MacRsrcProject.h

	Abstract:	We import Mac NTK project files (but we don’t save that format).
					An NTXRsrcProject reads resources and builds a frame Ref of the type we require.

	Written by:	Newton Research Group, 2014.
*/

#import "MacRsrcTypes.h"
#import "NewtonKit.h"


/* -----------------------------------------------------------------------------
	N T X R s r c F i l e
----------------------------------------------------------------------------- */

@interface NTXRsrcFile : NSObject
{
	FILE * fref;
	int rsrcLen;
	char * rsrcImage;
	char * rsrcData;
	RsrcMap * rsrcMap;
	RsrcList * rsrcTypeList;
}
@property(copy) NSURL * url;
@property(readonly) int read4Bytes;
@property(readonly) int read2Bytes;
@property(readonly) int readByte;

- (void)read:(NSUInteger)inCount into:(char *)inBuffer;
- (void *)readResource:(OSType)inType number:(uint16_t)inNumber;

- (id)initWithURL:(NSURL *)inURL;
@end

/* -----------------------------------------------------------------------------
	N T X R s r c P r o j e c t
----------------------------------------------------------------------------- */

@interface NTXRsrcProject : NTXRsrcFile
@property(readonly) Ref projectRef;
@end
