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
- (void)open;
- (void)close;
- (NewtonErr)read:(char *)inBuf length:(NSUInteger)inLength;			// blocking
- (NewtonErr)send:(char *)inBuf length:(NSUInteger)inLength;			// blocking; but will never block in practice
// NTXStreamProtocol
- (void)addData:(NSData *)inData;
@end


/* -----------------------------------------------------------------------------
	N T X N u b F e e d b a c k
	Protocol for reporting received objects.
----------------------------------------------------------------------------- */
@protocol NTXNubFeedback
@property(nonatomic,readonly) NSProgress * progress;
@property(nonatomic,assign,getter=isConnected) BOOL connected;
- (void)receivedText:(NSString *)inText;
- (void)receivedObject:(RefArg)inObject;
- (void)receivedScreenshot:(RefArg)inData;
@end

/* -----------------------------------------------------------------------------
	N T X T o o l k i t P r o t o c o l C o n t r o l l e r
----------------------------------------------------------------------------- */

@interface NTXToolkitProtocolController : NSObject
// state
@property(assign,readonly) BOOL isTethered;		// we are tethered between receiving kTConnect -- kTTerminate from Newton
@property(assign) NSUInteger breakLoopDepth;

// control of the only channel available
+ (BOOL)isAvailable;
+ (NTXToolkitProtocolController *)bind:(id<NTXNubFeedback>)inDelegate;
+ (void)unbind:(id<NTXNubFeedback>)inDelegate;

// Commands
- (void)evaluate:(NSString *)inScript;
- (void)installPackage:(NSURL *)inPackage;
- (void)takeScreenshot;
- (void)disconnect;

@end


// There is one global NTXToolkitProtocolController
extern NTXToolkitProtocolController * gNTXNub;
