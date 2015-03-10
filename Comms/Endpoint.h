/*
	File:		Endpoint.h

	Contains:	Communications endpoint and controller interfaces.

	Written by:	Newton Research Group, 2011.
*/

#import <dispatch/dispatch.h>
#include <sys/select.h>

#import <Foundation/Foundation.h>

#import "Comms.h"
#import "NCBuffer.h"

#define kDebugOn 0

#ifdef __cplusplus
extern "C" {
#endif
int	REPprintf(const char * inFormat, ...);
#ifdef __cplusplus
}
#endif
// from "Newton/NewtonDebug.h"

#define XTRY							do
#define XENDTRY  						while(0)

#define XDOFAIL(expr)				if (expr) do
#define XENDFAIL						while(0)

#define XFAIL(expr)					{ if ((expr) != 0) { break; } }
#define XFAILIF(expr, action)		{ if ((expr) != 0) { { action } break; } }
#define XFAILNOT(expr, action)	{ if ((expr) == 0) { { action } break; } }


/* -----------------------------------------------------------------------------
	Disconnection notification.
----------------------------------------------------------------------------- */

#define kNewtonDisconnected	@"NCDisconnected"


/* -----------------------------------------------------------------------------
	Values that can be passed to setTimeout as timeout values.
----------------------------------------------------------------------------- */

#define kDefaultTimeoutInSecs		 30


@protocol NTXStreamProtocol
- (int) addData: (NSData *) inData;
@end


/* -----------------------------------------------------------------------------
	N C E n d p o i n t
	Base class.
	Subclass
		TCPIPEndpoint
		MNPSerialEndpoint
		BluetoothEndpoint
----------------------------------------------------------------------------- */
#define kRxBufLength 1024

@interface NCEndpoint : NSObject
{
// every endpoint must be based on a file descriptor
// since the GCD dispatch source requires it
	int _fd;
	int timeoutSecs;					// timeout in seconds
//	dispatch_source_t readSrc;		// GCD dispatch source for reading data from fd
	unsigned char rxPageBuf[kRxBufLength];	// 1K buffer into which to read fd data
	NSMutableData * rxData;			// buffer into which to read unframed data

	dispatch_queue_t ioQueue;		// async serial dispatch queue in which to perform i/o
	dispatch_semaphore_t syncWrite;

//	dispatch_source_t writeSrc;	// GCD dispatch source for writing data to fd
	NCBuffer * txPageBuf;			// 1K buffer into which to write fd data
	NSMutableData * txData;
	BOOL isSyncWrite;
}
@property(readonly) int fd;
@property(assign) int pipefd;
@property(assign) int timeout;

// public interface
+ (BOOL) isAvailable;

- (NCError) write: (const void *) inData length: (unsigned int) inLength;
- (NCError) writeSync: (const void *) inData length: (unsigned int) inLength;
- (BOOL) willWrite;
- (void) writeDone;

// subclass repsonsibility
- (NCError) listen;
- (NCError) accept;
- (void) handleTickTimer;
- (NCError) read: (unsigned char *) inData length: (NSUInteger) inLength into: (NSMutableData *) ioData;
- (void) writePage: (NCBuffer *) inFrameBuf from: (NSMutableData *) inDataBuf;
- (NCError) close;

// private
- (NCError) readDispatchSource: (id<NTXStreamProtocol>) inputStream;
- (NCError) writeDispatchSource;

@end


/* -----------------------------------------------------------------------------
	N C E n d p o i n t C o n t r o l l e r
	There is a single instance of NCEndpointController that coordinates the
	creation of transports to listen on all available interfaces, then cancels
	transports once one has established a connection.
----------------------------------------------------------------------------- */
#define kMaxNumOfEndpoints 3

@interface NCEndpointController : NSObject
{
	NCEndpoint *	endpoint[kMaxNumOfEndpoints];
	int				numOfEndpoints;
	int				dockErr;
	int				timeoutSuppressionCount;
}
@property(readonly) NCEndpoint * endpoint;
@property(assign) int dockErr;

- (NCError) startListening: (id<NTXStreamProtocol>) inputStream;
- (NCError) addEndpoint: (NCEndpoint *) inEndpoint name: (const char *) inName;
- (NCError) useEndpoint: (NCEndpoint *) inEndpoint;

- (void) suppressTimeout: (BOOL) inDoSuppress;

@end
