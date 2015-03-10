/*
	File:		Transport.m

	Contains:	NCTransport communications transport interface.
					Currently there are three transports, TCP, MNP serial and bluetooth,
					which are subclasses of NCTransport.

	Written by:	Newton Research Group, 2005-2011.
*/

#import "Transport.h"


/*------------------------------------------------------------------------------
	N C T r a n s p o r t
------------------------------------------------------------------------------*/

@implementation NCTransport

/*------------------------------------------------------------------------------
	Initialize.
------------------------------------------------------------------------------*/

- (id) init
{
	if (self = [super init])
	{
		fd = -1;
	}
	return self;
}


/*------------------------------------------------------------------------------
	Accessor.
------------------------------------------------------------------------------*/

- (int) fileDescriptor
{
	return fd;
}


@end
