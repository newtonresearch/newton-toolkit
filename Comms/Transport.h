/*
	File:		Transport.h

	Contains:	NCTransport communications transport interface.
					Currently there are three transports, TCP, MNP serial and bluetooth,
					which are subclasses of NCTransport.

	Written by:	Newton Research Group, 2005-2011.
*/

#import <Foundation/Foundation.h>

#import "Comms.h"
#import "ChunkBuffer.h"
#import "NCBuffer.h"


/*------------------------------------------------------------------------------
	N C T r a n s p o r t
	Base class.
	Subclass
		TCPIPTransport
		MNPSerialTransport
		BluetoothTransport
------------------------------------------------------------------------------*/

@interface NCTransport : NSObject
{
	// every transport must be based on a file descriptor
	// since the GCD dispatch source requires it
	int		fd;
	int		platformErr;
}

+ (BOOL)		isAvailable;

@property(readonly)	int fileDescriptor;

- (NCError)	listen;
- (NCError)	accept;
- (NCError) processPage: (NCBuffer *) inFrameBuf into: (NCChunkBuffer *) inGetQueue;
- (BOOL) willSend: (NCChunkBuffer *) inPutQueue;
- (unsigned int) getPageToSend: (unsigned char *) inBuf length: (unsigned int) inLength;
- (NCError)	close;

@end
