/*
	File:		DockEvent.mm

	Contains:	Newton Dock event implementation.

	Written by:	Newton Research Group, 2011.
*/

#import "DockEvent.h"
#import "DockErrors.h"

#define kDebugOn 1


NCDockEventQueue * gDockEventQueue;		// required for endpoints to build events w/ read data

@implementation NCDockEventQueue

/*------------------------------------------------------------------------------
	Initialize the queue.
	Create an endpoint controller to listen for data.
	Create an empty event for construction once data arrives, and a semaphore
	to signal when an event has been completely received.
	Args:		--
	Return:	self
------------------------------------------------------------------------------*/

- (id) init
{
	if (self = [super init])
	{
		eventQueue = [[NSMutableArray alloc] initWithCapacity: 2];
		eventUnderConstruction = [[NCDockEvent alloc] init];
		eventReady = dispatch_semaphore_create(0);
		accessQueue = dispatch_queue_create("com.newton.connection.event", NULL);
		ep = [[NCEndpointController alloc] init];
		[ep startListening];
		[ep addObserver:self forKeyPath:@"dockErr" options:NSKeyValueObservingOptionNew context:nil];
	}
	gDockEventQueue = self;
	return self;
}

- (void) observeValueForKeyPath:(NSString *) inKeyPath
							  ofObject:(id) inObject
								 change:(NSDictionary *) inChange
								context:(void *) inContext
{
	NSNumber * err = [inChange objectForKey:NSKeyValueChangeNewKey];
	// if (err == kDockErrDisconnected)
	[self addEvent:nil];
}


/*------------------------------------------------------------------------------
	Dispose the queue.
	Args:		--
	Return:	--
------------------------------------------------------------------------------*/

- (void) dealloc
{
	gDockEventQueue = nil;
	[ep removeObserver:self forKeyPath:@"dockErr"];
	[ep release], ep = nil;
	dispatch_release(accessQueue), accessQueue = nil;
	dispatch_release(eventReady), eventReady = nil;
	[eventUnderConstruction release], eventUnderConstruction = nil;
	[eventQueue release], eventQueue = nil;
	[super dealloc];
}


/*------------------------------------------------------------------------------
	Flush the queue.
	Args:		--
	Return:	--
------------------------------------------------------------------------------*/

- (void) flush
{
	ep.dockErr = kDockErrAccessDenied;
}


- (void) suppressEndpointTimeout: (BOOL) inDoSuppress
{
	[ep suppressTimeout:inDoSuppress];
}


/*------------------------------------------------------------------------------
	Construct an event from data received.
	Once the event has been completely received, signal its readiness.
	Args:		inData
	Return:	--
------------------------------------------------------------------------------*/

- (void) readEvent: (NCBuffer *) inData
{
	while ([eventUnderConstruction build: inData] == noErr)
	{
		// queue up the completed event
		[self addEvent: eventUnderConstruction];
		// start building a new event
		eventUnderConstruction = [[NCDockEvent alloc] init];
	}
}


/*------------------------------------------------------------------------------
	Add an event to the queue.
	This can be used for local (desktop) event generation.
	Args:		inCmd
	Return:	--
------------------------------------------------------------------------------*/

- (void) addEvent: (NCDockEvent *) inEvt
{
	dispatch_sync(accessQueue,
	^{
		if (inEvt)
			[eventQueue addObject: inEvt];
		dispatch_semaphore_signal(eventReady);
	});
}


/*------------------------------------------------------------------------------
	Remove an event from the queue.
	Will block on eventReady semaphore.
	Args:		--
	Return:	event object
				caller must explicitly release
------------------------------------------------------------------------------*/

- (NCDockEvent *) getNextEvent
{
	__block NCDockEvent * evt = nil;
	if (ep.dockErr == noErr)
		dispatch_semaphore_wait(eventReady, DISPATCH_TIME_FOREVER);
	dispatch_sync(accessQueue,
	^{
		if ([eventQueue count] > 0)
		{
			evt = [eventQueue objectAtIndex:0];
			[evt retain];
			[eventQueue removeObjectAtIndex:0];
		}
	});
	return evt;
}

- (BOOL) isEventReady
{
	if (ep.dockErr)
		return YES;

	__block BOOL isReady = NO;
	dispatch_sync(accessQueue,
	^{
		if ([eventQueue count] > 0)
		{
			isReady = YES;
		}
	});
	return isReady;
}


#pragma mark Event Transmission
/*------------------------------------------------------------------------------
	Send an event over the endpoint.
	Args:		inCmd
	Return:	error code
------------------------------------------------------------------------------*/

- (NewtonErr) sendEvent: (EventType) inCmd
{
	NewtonErr err = ep.dockErr;
	return err ? err : [[NCDockEvent makeEvent: inCmd] send: ep.endpoint];
}


- (NewtonErr) sendEvent: (EventType) inCmd value: (int) inValue
{
	NewtonErr err = ep.dockErr;
	return err ? err : [[NCDockEvent makeEvent: inCmd value: inValue] send: ep.endpoint];
}


- (NewtonErr) sendEvent: (EventType) inCmd ref: (RefArg) inRef
{
	NewtonErr err = ep.dockErr;
	return err ? err : [[NCDockEvent makeEvent: inCmd ref: inRef] send: ep.endpoint];
}


- (NewtonErr) sendEvent: (EventType) inCmd file: (NSURL *) inURL callback: (NCProgressCallback) inCallback frequency: (unsigned int) inFrequency
{
	NewtonErr err = ep.dockErr;
	return err ? err : [[NCDockEvent makeEvent: inCmd file: inURL] send: ep.endpoint callback: inCallback frequency: inFrequency];
}


- (NewtonErr) sendEvent: (EventType) inCmd length: (unsigned int) inLength data: (const void *) inData length: (unsigned int) inDataLength
{
	NewtonErr err = ep.dockErr;
	return err ? err : [[NCDockEvent makeEvent: inCmd length: inLength data: inData length: inDataLength] send: ep.endpoint];
}


- (NewtonErr) sendEvent: (EventType) inCmd data: (const void *) inData length: (unsigned int) inLength callback: (NCProgressCallback) inCallback frequency: (unsigned int) inFrequency
{
	NewtonErr err = ep.dockErr;
	return err ? err : [[NCDockEvent makeEvent: inCmd length: inLength data: inData length: inLength] send: ep.endpoint callback: inCallback frequency: inFrequency];
}

@end


@implementation NCDockEvent

/*------------------------------------------------------------------------------
	Make an event.
	Args:		inCmd
	Return:	an auto-released event object
------------------------------------------------------------------------------*/

+ (NCDockEvent *) makeEvent: (EventType) inCmd
{
	NCDockEvent * evt = [[[NCDockEvent alloc] initEvent: inCmd] autorelease];
	return evt;
}


/*------------------------------------------------------------------------------
	Make an event.
	Args:		inCmd
				inValue
	Return:	an auto-released event object
------------------------------------------------------------------------------*/

+ (NCDockEvent *) makeEvent: (EventType) inCmd value: (int) inValue
{
	NCDockEvent * evt = [[[NCDockEvent alloc] initEvent: inCmd] autorelease];
	evt.dataLength = sizeof(ULong);
	evt.value = inValue;
	return evt;
}


/*------------------------------------------------------------------------------
	Make an event.
	Args:		inCmd
				inRef
	Return:	an auto-released event object
------------------------------------------------------------------------------*/

+ (NCDockEvent *) makeEvent: (EventType) inCmd ref: (RefArg) inRef
{
	NCDockEvent * evt = [[[NCDockEvent alloc] initEvent: inCmd] autorelease];
	evt.dataLength = FlattenRefSize(inRef);
	evt.ref = inRef;
	return evt;
}


/*------------------------------------------------------------------------------
	Make an event.
	Args:		inCmd
				inURL
	Return:	an auto-released event object
------------------------------------------------------------------------------*/

+ (NCDockEvent *) makeEvent: (EventType) inCmd file: (NSURL *) inURL
{
	NCDockEvent * evt = [[[NCDockEvent alloc] initEvent: inCmd] autorelease];
	// open the file and determine its length
	FILE * fref = fopen([[inURL path] fileSystemRepresentation], "r");
	fseek(fref, 0, SEEK_END);
	evt.dataLength = ftell(fref);
	fclose(fref);
	evt.file = inURL;
	return evt;
}


/*------------------------------------------------------------------------------
	Make an event.
	The crazy, crazy dock protocol uses a length word in all events - but this
	does not necessarily indicate the length of data. It might mean a number of
	Unicode characters, for example.
	Args:		inCmd				event code
				inLength			length to use for event
				inData			event data
				inDataLength	actual length of event data
	Return:	an auto-released event object
------------------------------------------------------------------------------*/

+ (NCDockEvent *) makeEvent: (EventType) inCmd length: (unsigned int) inLength data: (const void *) inData length: (unsigned int) inDataLength
{
	NCDockEvent * evt = [[[NCDockEvent alloc] initEvent: inCmd] autorelease];
	evt.dataLength = inDataLength;	// MUST set this first...
	evt.length = inLength;				// overwriting protocol’s idea of data length
	evt.data = (void *)inData;			// ...so data can be alloc’d at the right size

	return evt;
}


/*------------------------------------------------------------------------------
	Initialize null event instance.
	Args:		--
	Return:	self
------------------------------------------------------------------------------*/

- (id) init
{
	if (self = [super init])
	{
		header.evtClass = kNewtEventClass;
		header.evtId = kToolkitEventId;
		header.tag = 0;
		header.length = 0;
		dataLength = 0;
		alignedLength = 0;
		*(int32_t *)buf = 0;
		data = NULL;
		file = nil;
	}
	return self;
}


/*------------------------------------------------------------------------------
	Initialize event instance.
	Args:		--
	Return:	self
------------------------------------------------------------------------------*/

- (id) initEvent: (EventType) inCmd
{
	if ([self init])
	{
		header.tag = inCmd;
	}
	return self;
}


/*------------------------------------------------------------------------------
	Dispose event instance.
	Args:		--
	Return:	--
------------------------------------------------------------------------------*/

- (void) dealloc
{
	if (data)
		free(data), data = NULL;
	[file release], file = nil;
	[super dealloc];
}


/* -----------------------------------------------------------------------------
	Description for debug output.
	In the format:
		newt-dock-dres [4] -10221
----------------------------------------------------------------------------- */
void
FillIn(char * ioBuf, uint32_t inCmd, char inSeparator)
{
	ioBuf[0] = inCmd >> 24;
	ioBuf[1] = inCmd >> 16;
	ioBuf[2] = inCmd >>  8;
	ioBuf[3] = inCmd;
	ioBuf[4] = inSeparator;
}

- (NSString *) description
{
	int len;
	char dbuf[1024];
	FillIn(dbuf+ 0, header.evtClass, '-');
	FillIn(dbuf+ 5, header.evtId, '-');
	FillIn(dbuf+10, header.tag, ' ');
	len = sprintf(dbuf+15, "[%u]", dataLength) + 15;
	if (dataLength > 0)
	{
		if (dataLength == 4)
			len += sprintf(dbuf+len, " %d", self.value);
		char * s = dbuf+len;
		unsigned char * p = (unsigned char *)self.data;
		for (int i = MIN(dataLength,256); i > 0; i--, p++, s+=3)
		{
			sprintf(s, " %02X", *p);
		}
		if (dataLength > 256)
			sprintf(s, "..."), s+=3;
		*s = 0;
	}
	return [NSString stringWithUTF8String:dbuf];
}


/*------------------------------------------------------------------------------
	getters
------------------------------------------------------------------------------*/

@synthesize file;

- (EventType) tag
{
	return header.tag;
}


- (unsigned int) length
{
	return header.length;
}


- (NSString *) command
{
	return [NSString stringWithFormat: @"%c%c%c%c", (header.tag >> 24) & 0xFF, (header.tag >> 16) & 0xFF, (header.tag >> 8) & 0xFF, header.tag & 0xFF];
}


- (unsigned int) dataLength
{
	return dataLength;
}


- (void *) data
{
	return data ? data : buf;
}


- (int) value
{
	int32_t * p = (int32_t *)self.data;
	return CANONICAL_LONG(*p);
}


- (Ref) ref
{
	CPtrPipe pipe;
	pipe.init(self.data, header.length, NO, nil);
	return UnflattenRef(pipe);
}


- (Ref) ref1
{
	CPtrPipe pipe;
	pipe.init(((char*)self.data)+4, header.length-4, NO, nil);	// skip value
	return UnflattenRef(pipe);
}


- (Ref) ref2
{
	CPtrPipe pipe;
	pipe.init(self.data, header.length, NO, nil);
	UnflattenRef(pipe);	// discard first ref
	return UnflattenRef(pipe);
}


/*------------------------------------------------------------------------------
	setters
------------------------------------------------------------------------------*/

- (void) setLength: (unsigned int) inLength
{
	header.length = inLength;
}


- (void) setDataLength: (unsigned int) inLength
{
	header.length = inLength;
	dataLength = inLength;
	alignedLength = LONGALIGN(inLength);
}


- (void) setValue: (int) inValue
{
	if (data)
	{
		free(data);
		data = NULL;
	}
	self.dataLength = sizeof(int32_t);
	*(int32_t *)buf = CANONICAL_LONG(inValue);
}


- (void) setRef: (Ref) inRef
{
	if (data)
		free(data), data = NULL;

	self.dataLength = FlattenRefSize(inRef);
	if (header.length > kEventBufSize)
		data = malloc(alignedLength);

	CPtrPipe pipe;
	pipe.init(self.data, header.length, NO, nil);
	FlattenRef(inRef, pipe);

	// pad with zeroes
	int delta = alignedLength - header.length;
	if (delta > 0)
		memset((char *)self.data + header.length, 0, delta);
}


- (void) setData: (void *) inData
{
	if (data)
		free(data), data = NULL;

	// length MUST have been set previously
	if (dataLength > kEventBufSize)
		data = malloc(alignedLength);

	memcpy(self.data, inData, dataLength);

	// pad with zeroes
	int delta = alignedLength - dataLength;
	if (delta > 0)
		memset((char *)self.data + dataLength, 0, delta);
}


/*------------------------------------------------------------------------------
	Add data from buffer to build event *including* data.
	Args:		inData
	Return:					noErr => we have built a full dock event
				kCommsPartialData => not enough data yet
------------------------------------------------------------------------------*/

- (NCError) build: (NCBuffer *) inData
{
	static const unsigned char kDockHeader[8] = { 'n','e','w','t', 'n','t','p',' ' };
	static int evtState = 0;
	static unsigned int reqLen;
	static char * dp;
	unsigned int actLen;
	NCError status = kCommsPartialData;

	XTRY
	{
		int ch;
		for (ch = 0; ch >= 0; )
		{
			switch (evtState)
			{
			case 0:
				header.tag = 0;
				self.dataLength = 0;
				if (data != nil && data != buf)
					free(data);
				data = nil;
			case 1:
			case 2:
			case 3:
			case 4:
			case 5:
			case 6:
			case 7:
//	scan for newt dock start-of-event
				XFAIL((ch = inData.nextChar) < 0)
				if (ch == kDockHeader[evtState])
					evtState++;
				else
					evtState = 0;
				break;

			case 8:
			case 9:
			case 10:
			case 11:
//	read 4-char tag
				XFAIL((ch = inData.nextChar) < 0)
				header.tag = (header.tag << 8) + ch;
				evtState++;
				break;

			case 12:
			case 13:
			case 14:
			case 15:
//	read 4-char length
				XFAIL((ch = inData.nextChar) < 0)
				header.length = (header.length << 8) + ch;
				evtState++;
				break;

			case 16:
//	set up data/buffer
				if (header.length == kIndeterminateLength)
				{
					// length is indeterminate!
					self.dataLength = 0;
					data = buf;
					bufLength = kEventBufSize;
					evtState = 20;
					break;
				}
				self.dataLength = header.length;
				reqLen = alignedLength;
				if (header.length <= kEventBufSize)
					data = buf;
				else
					data = malloc(reqLen);
				dp = (char *)data;
				evtState++;

			case 17:
//	read data
				if (reqLen != 0)
				{
					actLen = [inData drain:reqLen into:dp];
					dp += actLen;
					reqLen -= actLen;
					XFAILIF(reqLen != 0, ch = -1;)	// break out of the loop because we don’t have enough data yet
																// but return to this state next time data is received
				}
				// at this point data has been read, including any long-align padding
				// reset FSM for next time
				evtState = 0;
				status = noErr;	// noErr -- packet fully unframed
				ch = -1;				// fake value so we break out of the loop

#if kDebugOn
REPprintf("\n     <-- %c%c%c%c ", (header.tag >> 24) & 0xFF, (header.tag >> 16) & 0xFF, (header.tag >> 8) & 0xFF, header.tag & 0xFF);
if (header.length == sizeof(int32_t)) { int v = self.value; REPprintf("%d (0x%08X) ", v, v); }
else if (header.length > 0) REPprintf("[%d] ", header.length);
#endif
				break;

			case 20:
			case 21:
			case 22:
			case 23:
			case 24:
			case 25:
			case 26:
			case 27:
// keep buffering data until we encounter newtdock header in the stream
				XFAIL((ch = inData.nextChar) < 0)
				if (ch == kDockHeader[evtState-20])
				{
					// stream matches header
					evtState++;
					break;
				}
				if (evtState > 20)
				{
					const unsigned char * p = kDockHeader;
					while (evtState-- > 20)
						[self addIndeterminateData: *p++];
				}
				[self addIndeterminateData: ch];
				break;

			case 28:
				// at this point a header has been read
				// set up the actual length of data read
				self.dataLength = header.length;
				// reset FSM for next time, starting at the tag
				evtState = 8;
				status = noErr;	// noErr -- packet fully unframed
				ch = -1;				// fake value so we break out of the loop

#if kDebugOn
REPprintf("\n     <-- %c%c%c%c [%d] indeterminate", (header.tag >> 24) & 0xFF, (header.tag >> 16) & 0xFF, (header.tag >> 8) & 0xFF, header.tag & 0xFF, header.length);
#endif
			}
		}
	}
	XENDTRY;

	return status;
}


/*------------------------------------------------------------------------------
	Add a byte of indeterminately-sized data.
	Args:		inData
	Return:	--
------------------------------------------------------------------------------*/

- (void) addIndeterminateData: (unsigned char) inData
{
	if (header.length == bufLength)
	{
		// we will overrun our buffer: alloc a larger one
		bufLength += 256;
		if (data == buf)
			data = malloc(bufLength);
		else
			data = realloc(data, bufLength);
	}
	*((unsigned char *)data + header.length++) = inData;
}


/*------------------------------------------------------------------------------
	Send an event -- first 4 longs of self followed by the data.
	Need to pad the data sent to align on long.
		'newt'
		'dock'
		tag
		length
		data
	Args:		ep			endpoint
	Return:	--
------------------------------------------------------------------------------*/

- (NewtonErr) send: (NCEndpoint *) ep
{
	return [self send: ep callback: 0 frequency: 0];
}


- (NewtonErr) send: (NCEndpoint *) ep callback: (NCProgressCallback) inCallback frequency: (unsigned int) inChunkSize
{
	NewtonErr err = noErr;

#if kDebugOn
//NSLog(@"%@",[self description]);
REPprintf("\n%c%c%c%c --> ", (header.tag >> 24) & 0xFF, (header.tag >> 16) & 0xFF, (header.tag >> 8) & 0xFF, header.tag & 0xFF);
if (header.length == sizeof(int32_t)) { int v = self.value; REPprintf("%d (0x%08X) ", v, v); }
else if (header.length > 0) REPprintf("[%d] ", header.length);
#endif

	if (inChunkSize == 0)
	{
		// send all in one go
		if (file)
			inChunkSize = dataLength;
		else
			inChunkSize = alignedLength;
	}
	else
	{
		// sanity check
		if (inChunkSize < 256)
			inChunkSize = 256;
		if (inChunkSize > 4096)
			inChunkSize = 4096;
	}

#if defined(hasByteSwapping)
	header.evtClass = BYTE_SWAP_LONG(header.evtClass);
	header.evtId = BYTE_SWAP_LONG(header.evtId);
	header.tag = BYTE_SWAP_LONG(header.tag);
	header.length = BYTE_SWAP_LONG(header.length);
#endif

	XTRY
	{
		XFAILNOT(ep, err = kNCErrorWritingToPipe;)

// ideally what we should do is write to buffer until it’s full or we -flush

		if (file)
		{
			FILE * fref = fopen([[file path] fileSystemRepresentation], "r");
			XFAILIF(fref == NULL, err = kNCInvalidFile; )
			XTRY
			{
				int padding = alignedLength - dataLength;
				off_t offset;
				void * chunk = malloc(sizeof(DockEventHeader) + LONGALIGN(inChunkSize));
				XFAILIF(chunk == NULL, err = kNCOutOfMemory; )

				memcpy(chunk, &header, sizeof(DockEventHeader));
				offset = sizeof(DockEventHeader);

				int amountRead, amountRemaining, amountDone = 0;
				if (inCallback)
					dispatch_async(dispatch_get_main_queue(), ^{ inCallback(dataLength, amountDone); });

				fseek(fref, 0, SEEK_SET);
				for (amountRemaining = dataLength; amountRemaining > 0; amountRemaining -= amountRead)
				{
					amountRead = inChunkSize;
					if (amountRead > amountRemaining)
						amountRead = amountRemaining;
					amountRead = fread((char *)chunk+offset, 1, amountRead, fref);
					if (padding > 0 && amountRemaining - (amountDone + amountRead) == 0)
					{
						memset((char *)chunk+offset+amountRead, 0, padding);
						amountRead += padding;
					}
					if (inCallback)
					{
						// we want progress reporting so write synchronously
						XFAIL(err = [ep writeSync: chunk length: offset + amountRead])
						if (gDockEventQueue.isEventReady)	// Newton is trying to tell us something
							break;
					}
					else
						XFAIL(err = [ep write: chunk length: offset + amountRead])
					offset = 0;
					amountDone += amountRead;
					if (inCallback)
						dispatch_async(dispatch_get_main_queue(), ^{ inCallback(dataLength, amountDone); });
				}
				free(chunk);
			}
			XENDTRY;
			fclose(fref);
		}

		else if (data)
		{
			XFAIL(err = [ep write: &header length: sizeof(DockEventHeader)])

			char * chunk = (char *)self.data;

			int amountRead, amountRemaining, amountDone = 0;
			if (inCallback)
				dispatch_async(dispatch_get_main_queue(), ^{ inCallback(alignedLength, amountDone); });

			for (amountRemaining = alignedLength; amountRemaining > 0; amountRemaining -= amountRead)
			{
				amountRead = inChunkSize;
				if (amountRead > amountRemaining)
					amountRead = amountRemaining;
				if (inCallback)
				{
					// we want progress reporting so write synchronously
					XFAIL(err = [ep writeSync: chunk length: amountRead])
					if (gDockEventQueue.isEventReady)	// Newton is trying to tell us something
						break;
				}
				else
					XFAIL(err = [ep write: chunk length: amountRead])
				chunk += amountRead;
				amountDone += amountRead;
				if (inCallback)
					dispatch_async(dispatch_get_main_queue(), ^{ inCallback(alignedLength, amountDone); });
			}
		}

		else if (header.length == kIndeterminateLength)
			// WTF was that Dock Protocol engineer thinking?
			// if we send refs we MUST NOT send the actual length with the command
			// and we MUST NOT align the data
			XFAIL(err = [ep write: &header length: sizeof(DockEventHeader) + dataLength])

		else
			XFAIL(err = [ep write: &header length: sizeof(DockEventHeader) + alignedLength])
	}
	XENDTRY;

#if defined(hasByteSwapping)
	header.evtClass = BYTE_SWAP_LONG(header.evtClass);
	header.evtId = BYTE_SWAP_LONG(header.evtId);
	header.tag = BYTE_SWAP_LONG(header.tag);
	header.length = BYTE_SWAP_LONG(header.length);
#endif

	return err;
}

@end

