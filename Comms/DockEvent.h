/*
	File:		DockEvent.h

	Contains:	Newton Dock event interface.
					Commands are exchanged as events (described in Newton/Events.h)
						class	= 'newt' (is it ever anything else?)
						id		= 'ntp '

	Written by:	Newton Research Group, 2011.
*/

#import <dispatch/dispatch.h>

#import "NSMutableArray-Extensions.h"
#import "NTKProtocol.h"
//#import "ChunkBuffer.h"
#import "NewtonKit.h"
#import "Endpoint.h"


/* --- Event send progress callback --- */

typedef void (^NCProgressCallback)(unsigned int totalAmount, unsigned int amountDone);

/* -----------------------------------------------------------------------------
	N C D o c k E v e n t
----------------------------------------------------------------------------- */

#define kEventBufSize	240

@interface NCDockEvent : NSObject
{
	DockEventHeader header;
	unsigned char	buf[kEventBufSize+4];
	unsigned int	bufLength;
	unsigned int	dataLength;
	unsigned int	alignedLength;
	void *			data;
	NSURL *			file;
}

+ (NCDockEvent *) makeEvent: (EventType) inCmd;
+ (NCDockEvent *) makeEvent: (EventType) inCmd value: (int) inValue;
+ (NCDockEvent *) makeEvent: (EventType) inCmd ref: (RefArg) inValue;
+ (NCDockEvent *) makeEvent: (EventType) inCmd file: (NSURL *) inURL;
+ (NCDockEvent *) makeEvent: (EventType) inCmd length: (unsigned int) inLength data: (const void *) inData length: (unsigned int) inDataLength;

- (id) initEvent: (EventType) inCmd;
- (NCError) build: (NCBuffer *) inData;
- (void) addIndeterminateData: (unsigned char) inData;

- (NewtonErr) send: (NCEndpoint *) ep;
- (NewtonErr) send: (NCEndpoint *) ep callback: (NCProgressCallback) inCallback frequency: (unsigned int) inFrequency;

@property (readonly)	NSString *	command;
@property (readonly)	EventType	tag;
@property (assign)	unsigned int	length;
@property (assign)	unsigned int	dataLength;
@property (assign)	void *	data;
@property (assign)	int		value;
@property				Ref		ref;
@property (readonly)	Ref		ref1;
@property (readonly)	Ref		ref2;
@property (copy)		NSURL *	file;

@end


/* -----------------------------------------------------------------------------
	N C D o c k E v e n t Q u e u e
----------------------------------------------------------------------------- */

@interface NCDockEventQueue : NSObject
{
	NCEndpointController * ep;

	NCDockEvent * eventUnderConstruction;
	NSMutableArray * eventQueue;
	dispatch_semaphore_t eventReady;
	dispatch_queue_t accessQueue;
}
@property(readonly) BOOL isEventReady;

- (void) readEvent: (NCBuffer *) inData;
- (void) addEvent: (NCDockEvent *) inCmd;
- (NCDockEvent *) getNextEvent;
- (void) flush;
- (void) suppressEndpointTimeout: (BOOL) inDoSuppress;

- (NewtonErr) sendEvent: (EventType) inCmd;
- (NewtonErr) sendEvent: (EventType) inCmd value: (int) inValue;
- (NewtonErr) sendEvent: (EventType) inCmd ref: (RefArg) inRef;
- (NewtonErr) sendEvent: (EventType) inCmd length: (unsigned int) inLength data: (const void *) inData length: (unsigned int) inDataLength;
- (NewtonErr) sendEvent: (EventType) inCmd data: (const void *) inData length: (unsigned int) inLength callback: (NCProgressCallback) inCallback frequency: (unsigned int) inFrequency;
- (NewtonErr) sendEvent: (EventType) inCmd file: (NSURL *) inURL callback: (NCProgressCallback) inCallback frequency: (unsigned int) inFrequency;
@end


extern NCDockEventQueue * gDockEventQueue;

