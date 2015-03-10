/*
	File:		ToolkitProtocolController.h

	Abstract:	Toolkit Protocol controller interface.
					The controller knows about the toolkit protocol.
					It translates requests for Newton data to toolkit command events
					that it passs to the active session.

	Written by:	Newton Research, 2012.
*/

#import <Cocoa/Cocoa.h>
#import "Endpoint.h"
#import "NewtonKit.h"


/* -----------------------------------------------------------------------------
	N T X S t r e a m
	Byte-stream interface to the connection.
	Comms thread adds received bytes to a buffer.
	ToolkitProtocol thread reads (blocking) buffer to build events.
	ToolkitProtocol thread sends by passing buffer directly to comms thread.
----------------------------------------------------------------------------- */

@interface NTXStream : NSObject <NTXStreamProtocol>
{
	dispatch_semaphore_t readDataReady;
	dispatch_queue_t accessQueue;
	NSMutableData * inputStreamBuf;
	NCEndpointController * ep;
}
//- (NewtonErr) addBytes: (void *) inData length: (NSUInteger) inLength;	// serialize access to buffer
- (NewtonErr) read: (char *) inBuf length: (NSUInteger) inLength;			// blocking
- (NewtonErr) send: (char *) inBuf length: (NSUInteger) inLength;			// blocking; but will never block in practice

@end


/* -----------------------------------------------------------------------------
	N T X T o o l k i t P r o t o c o l C o n t r o l l e r
----------------------------------------------------------------------------- */

@interface NTXToolkitProtocolController : NSObject
{
//	event queue
	NTXStream * ioStream;

	NewtonErr toolkitError;
	RefStruct toolkitObject;
	NSString * toolkitMessage;

	NewtonErr exceptionError;
	RefStruct exceptionObject;
	NSString * exceptionMessage;

//	package installation
	unsigned int totalAmount, amountDone;
}
// state
@property(assign)   BOOL isTethered;
@property(assign)   NSUInteger breakLoopDepth;


// Initialization
- (id) init;

// Commands
- (void) evaluate: (NSString *) inScript;
- (void) installPackage: (NSData *) inPackage;

@end
