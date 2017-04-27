/*
	File:		Endpoint.m

	Contains:	Communications endpoint controller implementation.

	Written by:	Newton Research Group, 2011.
*/

#import "Endpoint.h"
#import "DockErrors.h"

// we need to know all available transports
#import "MNPSerialEndpoint.h"
#import "EinsteinEndpoint.h"
//#import "EthernetEndpoint.h"
//#import "BluetoothEndpoint.h"


/* -----------------------------------------------------------------------------
	D a t a
----------------------------------------------------------------------------- */

BOOL gTraceIO = NO;

/* -----------------------------------------------------------------------------
	N C E n d p o i n t
----------------------------------------------------------------------------- */
@implementation NCEndpoint

+ (BOOL) isAvailable
{ return NO; }


/*------------------------------------------------------------------------------
	Initialize instance.
------------------------------------------------------------------------------*/

- (id)init {
	if (self = [super init]) {
		_rfd = _wfd = -1;
		timeoutSecs = kDefaultTimeoutInSecs;

		rPageBuf = [[NCBuffer alloc] init];
		rData = [[NSMutableData alloc] init];

		wPageBuf = [[NCBuffer alloc] init];
		wData = [[NSMutableData alloc] init];

		syncWrite = dispatch_semaphore_create(0);
		isSyncWrite = NO;

		ioQueue = dispatch_queue_create("com.newton.connection.io", NULL);
	}
	return self;
}


- (int)rfd {
	return _rfd;
}

- (int)wfd {
	return _wfd;
}


/*------------------------------------------------------------------------------
	timeout property accessors
------------------------------------------------------------------------------*/

- (void)setTimeout:(int)inTimeout {
	if (inTimeout < -2) {
		return;	// kNCInvalidParameter
	}

	timeoutSecs = (inTimeout == -1) ? kDefaultTimeoutInSecs : inTimeout;
	return;		// noErr
}


- (int)timeout {
	return timeoutSecs;
}


/*------------------------------------------------------------------------------
	Wait for first data to arrive on this endpoint.
	Args:		--
	Return:	error code
------------------------------------------------------------------------------*/

- (NCError)listen {
	return noErr;	// subclass responsibility
}


/*------------------------------------------------------------------------------
	Accept connection.
	Args:		--
	Return:	error code
------------------------------------------------------------------------------*/

- (NCError)accept {
	return noErr;	// subclass responsibility
}


/*------------------------------------------------------------------------------
	Handle the idle timer, currently set at one second for the MNP serial
	endpoint.
	Args:		--
	Return:	--
------------------------------------------------------------------------------*/

- (void)handleTickTimer {
	// subclass responsibility
}


/*------------------------------------------------------------------------------
	Read from the file descriptor.
	Unframe that data (if necessary: think MNP serial) and add it to the input
	stream.
	Args:		--
	Return:	error code
------------------------------------------------------------------------------*/

- (NCError)readDispatchSource:(id<NTXStreamProtocol>)inputStream {
	NCError err = noErr;

	// read() into a 1K buffer, and pass it to the transport for unframing/packetising
	int count = read(self.rfd, rPageBuf.ptr, rPageBuf.freeSpace);
	if (count > 0) {

#if kDebugOn
if (gTraceIO) {
	NSMutableString * str = [NSMutableString stringWithCapacity:count*3];
	for (int i = 0; i < count; ++i) {
		[str appendFormat:@" %02X", rPageBuf.ptr[i]];
	}
	NSLog(@"<<%@",str);
}
#endif

		[rData setLength:0];
		[rPageBuf fill:count];
		err = [self readPage:rPageBuf into:rData];
		if (err == noErr && (count = rData.length) > 0) {
			[inputStream addData:rData];
		}
	} else if (count == 0) {
		err = kDockErrDisconnected;
	} else {
		err = kDockErrDesktopError;
	}

	return err;
}


/*------------------------------------------------------------------------------
	Process raw framed/packetised data from the fd into plain data.
	If the subclass needs no processing we can use this method which copies
	frame -> data.
	Args:		inFrameBuf		raw data from the fd ->
				inDataBuf		-> unframed user data
	Return:	--
				inFrameBuf MUST be drained of whatever was unframed
------------------------------------------------------------------------------*/

- (NCError)readPage:(NCBuffer *)inFrameBuf into:(NSMutableData *)ioData {
	unsigned int count = inFrameBuf.count;
	[ioData appendBytes:inFrameBuf.ptr length:count];
	[inFrameBuf drain:count];
	return noErr;
}


/*------------------------------------------------------------------------------
	Write to the file descriptor.
	Frame that data (if necessary: think MNP serial) before writing.
	Args:		--
	Return:	error code
------------------------------------------------------------------------------*/

- (BOOL)willWrite {
	__block BOOL willDo = NO;
	dispatch_sync(ioQueue, ^{
		[self writePage:wPageBuf from:wData];
		willDo = wPageBuf.count > 0;
	});
	return willDo;
}


- (NCError)writeDispatchSource {
	NCError err = noErr;
	// fetch a frame from the buffer and write() it
	if (wPageBuf.count > 0) {
		int count = write(self.wfd, wPageBuf.ptr, wPageBuf.count);
		if (count > 0) {

#if kDebugOn
if (gTraceIO) {
	NSMutableString * str = [NSMutableString stringWithCapacity:count*3];
	for (int i = 0; i < count; ++i) {
		[str appendFormat:@" %02X", wPageBuf.ptr[i]];
	}
	NSLog(@">>%@",str);
}
#endif

			[wPageBuf drain:count];
			[self writeDone];
		} else if (count == 0) {
			err = kDockErrDisconnected;
		} else {	// count < 0 => error
			if (errno != EAGAIN && errno != EINTR) {
				err = kDockErrDesktopError;
			}
		}
	}
	return err;
}


/*------------------------------------------------------------------------------
	Copy data from data buffer to output frame buffer.
	Args:		inFrameBuf		framed data to be written to fd <-
				inDataBuf		<- user data to be sent
	Return:	--
				inDataBuf MUST be drained of whatever was sent
------------------------------------------------------------------------------*/

- (void)writePage:(NCBuffer *)inFrameBuf from:(NSMutableData *)inDataBuf {
	unsigned int count = inDataBuf.length;
	if (count > inFrameBuf.freeSpace) {
		count = inFrameBuf.freeSpace;
	}
	[inFrameBuf fill:count from:inDataBuf.bytes];
	[inDataBuf replaceBytesInRange:NSMakeRange(0,count) withBytes:NULL length:0];
}


/*------------------------------------------------------------------------------
	Public interface: write data to the endpoint.
	Args:		inData
				inLength
	Return:	error code
------------------------------------------------------------------------------*/

- (NCError)write:(const void *)inData length:(unsigned int)inLength {
	NCError err = noErr;
	if (inData != NULL && inLength > 0) {
		dispatch_sync(ioQueue, ^{
			BOOL wasEmpty = wData.length == 0;
			[wData appendBytes:inData length:inLength];
			if (wasEmpty) {
				write(self.pipefd, "X", 1);
			}
		});
	}
	return err;
}


/*------------------------------------------------------------------------------
	Public interface: write data to the endpoint.
	Args:		inData
				inLength
	Return:	error code
------------------------------------------------------------------------------*/

- (NCError)writeSync:(const void *)inData length:(unsigned int)inLength {
	NCError err = noErr;
	if (inData != NULL && inLength > 0) {
		dispatch_sync(ioQueue, ^{
			BOOL wasEmpty = wData.length == 0;
			[wData appendBytes:inData length:inLength];
			if (wasEmpty) {
				isSyncWrite = YES;
				write(self.pipefd, "Y", 1);
			}
		});
		dispatch_semaphore_wait(syncWrite, DISPATCH_TIME_FOREVER);
	}
	return err;
}


- (void)writeDone
{
	dispatch_sync(ioQueue, ^{
		if (isSyncWrite && wData.length == 0) {
			isSyncWrite = NO;
			dispatch_semaphore_signal(syncWrite);
		}
	});
}


/*------------------------------------------------------------------------------
	Close this endpoint.
	Args:		--
	Return:	error code
------------------------------------------------------------------------------*/

- (NCError)close {
	return noErr;	// subclass responsibility
}

@end


/*------------------------------------------------------------------------------
	N C E n d p o i n t C o n t r o l l e r
------------------------------------------------------------------------------*/
@interface NCEndpointController ()
{
	NSMutableArray<NCEndpoint *> * listeners;
	NCEndpoint * _endpoint;
	int pipefd[2];		// safe-pipe trick
	int timeoutSuppressionCount;
}
- (NCError)addEndpoint:(NCEndpoint *)inEndpoint name:(const char *)inName;
- (NCError)useEndpoint:(NCEndpoint *)inEndpoint;
- (void)doIOEventLoop:(id<NTXStreamProtocol>)inputStream;
@end

@implementation NCEndpointController

/*------------------------------------------------------------------------------
	Initialize instance.
	Create endpoints for all transports we know about and start listening for
	data.
------------------------------------------------------------------------------*/

- (id)init {
	if (self = [super init]) {
		listeners = nil;
		_endpoint = nil;
		self.error = noErr;
		[self suppressTimeout:NO];
	}
	return self;
}


- (BOOL)isActive {
	return listeners != nil || _endpoint != nil;
}


- (void)stop {
	if (self.isActive) {
		write(pipefd[1], "Z", 1);
	}
	if (_endpoint) {
		[_endpoint close];
		_endpoint = nil;
	} else {
		[self useEndpoint:nil];
	}
}


/*------------------------------------------------------------------------------
	Dispose instance.
	Close all active endpoints.
------------------------------------------------------------------------------*/

- (void)dealloc {
	[self stop];
}


/*------------------------------------------------------------------------------
	Start listening on all available transports, and accept whichever connects
	first.
	Can’t use kevent() to check whether serial port ready to read -- it just returns an EINVAL error.
	Can’t use GCD dispatch sources -- they’re based on kevent.
	Only remains select().
	Args:		--
	Return:	--
------------------------------------------------------------------------------*/

- (NCError)startListening:(id<NTXStreamProtocol>)inputStream {
	NCError err;
	self.error = noErr;

	XTRY
	{
		NCEndpoint * ep;

		// create all available endpoints
		listeners = [[NSMutableArray alloc] initWithCapacity:3];
		// -----	the toolkit can only use serial -----
		//			maybe one day we will do ethernet : but then again maybe not

		if ([MNPSerialEndpoint isAvailable]) {
			ep = [[MNPSerialEndpoint alloc] init];
			[ep setTimeout:1];	// tick timer for ack/inactive timeouts
			err = [self addEndpoint:ep name:"MNP serial"];
		}
		if ([EinsteinEndpoint isAvailable]) {
			ep = [[EinsteinEndpoint alloc] init];
			[ep setTimeout:1];
			err = [self addEndpoint:ep name:"Einstein"];
		}
/*
		if ([TCPIPEndpoint isAvailable]) {
			ep = [[TCPIPEndpoint alloc] init];
			err = [self addEndpoint:ep name:"ethernet"];
		}

		if ([BluetoothEndpoint isAvailable]) {
			ep = [[BluetoothEndpoint alloc] init];
			err = [self addEndpoint:ep name:"bluetooth"];
		}
*/
	}
	XENDTRY;

	// start I/O event loop in a parallel dispatch queue
	NCEndpointController *__weak weakself = self;
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
		[weakself doIOEventLoop:inputStream];
	});

	return err;
}


- (void)doIOEventLoop:(id<NTXStreamProtocol>)inputStream {
	int err;
	NCEndpoint * ep = nil;	// => is listening; once connected, ep is the current endpoint
	int maxfd;

	pipe(pipefd);	// create write-signal pipe

	// this is our I/O event loop
	for (err = noErr; err == noErr; ) {
		int count;
		int nfds;
		fd_set rfds;
		fd_set wfds;
		struct timeval tv;

		if (ep == nil) {
			// we’re listening…
			FD_ZERO(&rfds);
			maxfd = 0;
			for (NCEndpoint * epi in listeners) {
				FD_SET(epi.rfd, &rfds);
				maxfd = MAX(epi.rfd, maxfd);
			}
			nfds = select(maxfd+1, &rfds, NULL, NULL, NULL);
		} else {
			// allow 100ms latency in timeout
			tv.tv_sec = ep.timeout - 1;
			tv.tv_usec = 900000;

			FD_ZERO(&rfds);
			FD_SET(ep.rfd, &rfds);
			FD_SET(pipefd[0], &rfds);
			maxfd = MAX(pipefd[0], maxfd);

			FD_ZERO(&wfds);
			// cf linuxmanpages: only set the wfds if there are data to be sent
			if (ep.willWrite) {
				FD_SET(ep.wfd, &wfds);
				maxfd = MAX(ep.wfd, maxfd);
			}

			// wait for an event on read OR write file descriptor
			nfds = select(maxfd+1, &rfds, &wfds, NULL, &tv);
		}

		if (nfds > 0) {	// socket is available
			if (ep == nil) {
				// we were listening… find the endpoint that connected
				for (NCEndpoint * epi in listeners) {
					if (FD_ISSET(epi.rfd, &rfds)) {
						// accept this connection, cancel other listener transports
						ep = epi;
						[self useEndpoint:ep];
						break;
					}
				}
				// set write-signal pipe in endpoint
				ep.pipefd = pipefd[1];
				// set up select() for this endpoint in future
				// go on to process the data just received
			}

			if (FD_ISSET(ep.rfd, &rfds)) {
				// read() into frame buffer, unframe into data buffer, build dock event from data
				err = [ep readDispatchSource:inputStream];
if (err) NSLog(@"-[NCEndpointController doIOEventLoop] readDispatchSource -> error %d",err);
			}

			if (FD_ISSET(pipefd[0], &rfds)) {
				// endpoint signalled write
				char	x[2];
				count = read(pipefd[0], x, 1);
				if (x[0] == 'Z') {
					err = kDockErrDisconnected;
				}
			}

			if (FD_ISSET(ep.wfd, &wfds)) {
				// we can write
				err = [ep writeDispatchSource];
if (err) NSLog(@"-[NCEndpointController doIOEventLoop] writeDispatchSource -> error %d",err);
			}
		} else if (nfds == 0) {	// timeout
#if 1
			[ep handleTickTimer];
#else
			if (--timeoutSuppressionCount < 0) {
NSLog(@"select(): timeout");
				err = kDockErrIdleTooLong;
			} else {
				err = noErr;	// pretend it did not happen
			}
#endif
		} else {	// nfds < 0: error
NSLog(@"select(): %d, errno = %d", nfds, errno);
			if (nfds == -1 && errno == EINTR)
				continue;	// we were interrupted -- ignore it
			err = kDockErrDisconnected;	// because there are no comms after we break
		}
	}
	self.error = err;
}


/*------------------------------------------------------------------------------
	Add an endpoint to our list of listeners, and start listening.
	Args:		inEndpoint
				inName
	Return:	error code
------------------------------------------------------------------------------*/

- (NCError)addEndpoint:(NCEndpoint *)inEndpoint name:(const char *)inName {
	NCError err = noErr;
	XTRY
	{
		[listeners addObject:inEndpoint];
		// listen for data on this endpoint == connection
		XFAIL(err = [inEndpoint listen])
	}
	XENDTRY;
	XDOFAIL(err)
	{
		[inEndpoint close];
		[listeners removeObject:inEndpoint];
		REPprintf("Not listening on %s connection: error %d.\n", inName, err);
	}
	XENDFAIL;
	return err;
}


/*------------------------------------------------------------------------------
	Use an endpoint for further comms. Cancel any other outstanding listeners.
	Args:		inEndpoint
	Return:	error code
------------------------------------------------------------------------------*/

- (NCError)useEndpoint:(NCEndpoint *)inEndpoint {
	for (NCEndpoint * ep in listeners) {
		if (ep == inEndpoint) {
			[ep accept];
		} else {
			[ep close];
		}
	}
	_endpoint = inEndpoint;
	[listeners removeAllObjects];
	listeners = nil;
	return noErr;
}


/*------------------------------------------------------------------------------
	Return the active endpoint.
	Args:		--
	Return:	the endpoint
				nil => no connection
------------------------------------------------------------------------------*/

- (NCEndpoint *)endpoint {
	return _endpoint;
}


/*------------------------------------------------------------------------------
	Suppress communications timeout.
	We need to do this for keyboard passthrough and screenshot functions, since
	there is no protocol exchange while waiting for user action.
	Args:		inDoSuppress
	Return:	--
 ------------------------------------------------------------------------------*/

- (void)suppressTimeout:(BOOL)inDoSuppress {
	timeoutSuppressionCount = inDoSuppress ? INT32_MAX : 1;
}

@end


