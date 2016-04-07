/*
	File:		ToolkitProtocolController.h

	Abstract:	Toolkit Protocol controller interface.
					The controller knows about the toolkit protocol.
					It translates requests for Newton data to toolkit command events
					that it passs to the active session.
					Responses are passed up to the UI via the NTXNubProtocol.

	Written by:	Newton Research, 2012.
*/

#import <Cocoa/Cocoa.h>
#import "Endpoint.h"
#import "NewtonKit.h"


/* -----------------------------------------------------------------------------
	N T X S t r e a m
	Byte-stream interface to the connection.
	Comms thread adds received bytes to a buffer.
	ToolkitProtocol thread (blocking) reads buffer to build events.
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
	Keys for notifications sent by the communications layer.
----------------------------------------------------------------------------- */
extern NSString * const kNubConnectionDidChangeNotification;
extern NSString * const kNubOwnerDidChangeNotification;

/* -----------------------------------------------------------------------------
	N T X N u b F e e d b a c k
	Protocol for reporting received objects.
----------------------------------------------------------------------------- */
@protocol NTXNubFeedback
@property(readonly) NSProgress * progress;
- (void)receivedText:(NSString *)inText;
- (void)receivedObject:(RefArg)inObject;
- (void)receivedScreenshot:(RefArg)inData;
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

// feedback to UI
	id<NTXNubFeedback> delegate;
}
// state
@property(assign,readonly)   BOOL isTethered;
@property(assign)   NSUInteger breakLoopDepth;


// Initialization
- (id)init;
- (void)requestOwnership:(id<NTXNubFeedback>)inProposedOwner;

// Commands
- (void)evaluate:(NSString *)inScript;
- (void)installPackage:(NSURL *)inPackage;
- (void)takeScreenshot;
- (void)disconnect;

@end
