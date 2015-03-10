/*
	File:		ToolkitProtocolController.mm

	Abstract:	Toolkit Protocol controller interface.
					The controller knows about the toolkit protocol.
					It translates requests for Newton data to toolkit dock commands
					that it passs to the active session.
					toolkit
					 stream
					  endpointController
						endpoint

	To do:	ntxView context seems to get nil'd after GC
				comms sometimes dropped for no apparent reason
				implement undo in Inspector window
				don’t skip a line on up-arrow from bottom line


	Written by:	Newton Research, 2012.
*/

#import "ToolkitProtocolController.h"
#import "DockEvent.h"
#import "NTKProtocol.h"
#import "DockErrors.h"
#import "PreferenceKeys.h"


extern NewtonErr	GetPackageDetails(NSURL * inURL, NSString ** outName, unsigned int * outSize);
extern "C" const char *	GetFramesErrorString(int inErr);
extern void			PrintFramesErrorMsg(const char * inStr, RefArg inData);


// Ids of events we raise
#define kTInstallPackage	'LPKG'


/* -----------------------------------------------------------------------------
	N T X S t r e a m
----------------------------------------------------------------------------- */
@implementation NTXStream

- (id) init
{
	if (self = [super init])
	{
		readDataReady = dispatch_semaphore_create(0);
		accessQueue = dispatch_queue_create("com.newton.connection.istream", NULL);

		inputStreamBuf = [[NSMutableData alloc] init];

		ep = [[NCEndpointController alloc] init];
		[ep startListening: self];	// call us back <NTXStreamProtocol> when data arrives
	}
	return self;
}


// <NTXStreamProtocol>
- (NewtonErr) addData: (NSData *) inData
{
	// add chunk of data to the input stream

	dispatch_sync(accessQueue,
	^{
		[inputStreamBuf appendData:inData];
		dispatch_semaphore_signal(readDataReady);
	});

	return noErr;
}


- (NewtonErr) read: (char *) inBuf length: (NSUInteger) inLength
{
	// read chunk of data from the input stream

	NewtonErr err = noErr;
	__block NSUInteger reqLength = inLength;
	__block NSUInteger index = 0;

	dispatch_sync(accessQueue,
	^{
		NSUInteger count = [inputStreamBuf length];
		if (count > 0)
		{
			if (count > reqLength)
				count = reqLength;
			[inputStreamBuf getBytes:inBuf+index length:count];
			[inputStreamBuf replaceBytesInRange: NSMakeRange(0, count) withBytes: NULL length: 0];
			index += count;
			reqLength -= count;
		}
	});

	while (reqLength > 0)
	{
		XFAIL(err = ep.dockErr)
		XFAILIF(dispatch_semaphore_wait(readDataReady, DISPATCH_TIME_FOREVER), err = kDockErrIdleTooLong;)	// non-zero result => timeout

		dispatch_sync(accessQueue,
		^{
			NSUInteger count = [inputStreamBuf length];
			if (count > reqLength)
				count = reqLength;
			[inputStreamBuf getBytes:inBuf+index length:count];
			[inputStreamBuf replaceBytesInRange: NSMakeRange(0, count) withBytes: NULL length: 0];
			index += count;
			reqLength -= count;
		});
	}
	return err;
}


- (NewtonErr) send: (char *) inBuf length: (NSUInteger) inLength
{
	return [ep.endpoint write:inBuf length:inLength];
}

@end


@implementation NTXToolkitProtocolController
/*------------------------------------------------------------------------------
	P r o p e r t i e s
------------------------------------------------------------------------------*/

#pragma mark Initialization
/* -----------------------------------------------------------------------------
	Initialize a new instance.
----------------------------------------------------------------------------- */

- (id) init
{	
	if (self = [super init])
	{
		self.isTethered = NO;
		self.breakLoopDepth = 0;
		ioStream = [[NTXStream alloc] init];
		[self startEventLoop];
	}
	return self;
}


- (NewtonErr) readWord: (int *) outWord
{
	NewtonErr err = noErr;
	union
	{
		char chars[4];
		ULong word;
	} buf;

	err = [ioStream read: buf.chars length: sizeof(buf)];
	*outWord = CANONICAL_LONG(buf.word);
if (err) NSLog(@"-[NTXToolkitProtocolController readWord:] error = %d",err);
	return err;
}


/* -----------------------------------------------------------------------------
	Read command header words from Newton.
----------------------------------------------------------------------------- */

- (NewtonErr) readHeader1: (ULong *) outHdr1 header2: (ULong *) outHdr2
{
	NewtonErr err = noErr;
	union
	{
		char chars[8];
		struct
		{
			ULong hdr1;
			ULong hdr2;
		} words;
	} buf;

	// NTXStream* ioStream should return error on disconnection
	// no need for dock event queue any more
	// just read from input stream

	err = [ioStream read: buf.chars length: sizeof(buf)];
	*outHdr1 = CANONICAL_LONG(buf.words.hdr1);
	*outHdr2 = CANONICAL_LONG(buf.words.hdr2);
if (err) NSLog(@"-[NTXToolkitProtocolController readHeader1:header2:] error = %d",err);
	return err;
}


/* -----------------------------------------------------------------------------
	Read command header from Newton.
----------------------------------------------------------------------------- */

- (NewtonErr) readCommand: (EventType *) outCmd length: (NSUInteger *) outLength
{
	NewtonErr	err = noErr;
	ULong		hdr1;
	ULong		hdr2;

	*outCmd = 0;
	*outLength = 0;

	XTRY
	{
		XFAIL(err = [self readHeader1: &hdr1 header2: &hdr2])
		XFAILNOT(hdr1 == kNewtEventClass && hdr2 == kToolkitEventId, err = kDockErrBadHeader;)
		XFAIL(err = [self readHeader1: &hdr1 header2: &hdr2])

		*outCmd = hdr1;
		*outLength = hdr2;

#if kDebugOn
printf("\n     <-- %c%c%c%c ", (*outCmd >> 24) & 0xFF, (*outCmd >> 16) & 0xFF, (*outCmd >> 8) & 0xFF, *outCmd & 0xFF);
if (*outLength > 0) printf("[%ld] ", *(unsigned long *)outLength);
#endif
	}
	XENDTRY;
if (err) NSLog(@"-[NTXToolkitProtocolController readCommand:length:] error = %d",err);
	return err;
}


- (Ref) readRef: (NSUInteger) inLength
{
	NewtonErr err = noErr;
	char * buf = NULL;
	RefVar rref;

	XTRY
	{
		buf = (char *)malloc(inLength);
		XFAILNOT(buf, err = kOSErrNoMemory;)
		err = [ioStream read: buf length: inLength];

		CPtrPipe pipe;
		pipe.init(buf, inLength, NO, nil);
		rref = UnflattenRef(pipe);
	}
	XENDTRY;
	if (buf)
		free(buf);

	return rref;
}


/* -----------------------------------------------------------------------------
	Send command header words to Newton.
----------------------------------------------------------------------------- */

- (NewtonErr) sendHeader1: (ULong) inHdr1 header2: (ULong) inHdr2
{
	NewtonErr err = noErr;
	union
	{
		char chars[8];
		struct
		{
			ULong hdr1;
			ULong hdr2;
		} words;
	} buf;

	buf.words.hdr1 = CANONICAL_LONG(inHdr1);
	buf.words.hdr2 = CANONICAL_LONG(inHdr2);
	err = [ioStream send: buf.chars length: sizeof(buf)];
	
	return err;
}


/* -----------------------------------------------------------------------------
	Send command header to Newton.
----------------------------------------------------------------------------- */

- (NewtonErr) sendCommand: (EventType) inCmd length: (NSUInteger) inLength
{
	NewtonErr	err = noErr;
	XTRY
	{
#if kDebugOn
printf("\n%c%c%c%c --> ", (inCmd >> 24) & 0xFF, (inCmd >> 16) & 0xFF, (inCmd >> 8) & 0xFF, inCmd & 0xFF);
if (inLength > 0) printf("[%ld] ", (unsigned long)inLength);
#endif

		XFAIL(err = [self sendHeader1: kNewtEventClass header2: kToolkitEventId])
		err = [self sendHeader1: inCmd header2: inLength];
	}
	XENDTRY;
	return err;
}


/* -----------------------------------------------------------------------------
	Send simple command to Newton.
----------------------------------------------------------------------------- */

- (NewtonErr) sendCommand: (EventType) inCmd
{
	return [self sendCommand:inCmd length:0];
}


/* -----------------------------------------------------------------------------
	Send command with data to Newton.
----------------------------------------------------------------------------- */

- (NewtonErr) sendCommand: (EventType) inCmd data: (char *) inData length: (NSUInteger) inLength
{
	NewtonErr	err = noErr;
	XTRY
	{
		XFAIL(err = [self sendCommand:inCmd length: inLength])
		XFAIL(err = [ioStream send: inData length: inLength])

		NSUInteger padLength = inLength & 0x03;
		if (padLength != 0)
		{
		// pad with zeroes
			ULong padding = 0;
			err = [ioStream send: (char *)&padding length: 4 - padLength];
		}
	}
	XENDTRY;
	return err;
}


/* -----------------------------------------------------------------------------
	Send command with data to Newton.
----------------------------------------------------------------------------- */

- (NewtonErr) sendCommand: (EventType) inCmd value: (int) inValue
{
	ULong value = CANONICAL_LONG(inValue);
	return [self sendCommand:inCmd data: (char *)&value length: sizeof(ULong)];
}


/*------------------------------------------------------------------------------
	Dispatch a block to the async queue.
	This waits for a toolkit event to arrive then despatches it to its
	event handler.
	Args:		inEvent
	Return:	--
------------------------------------------------------------------------------*/

- (void) startEventLoop
{
	__block NTXToolkitProtocolController * weakself = self;	// use weak reference so async block does not retain self
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
	^{
		[weakself doDockEventLoop];
	});
}

- (void) doDockEventLoop
{
	for ( ; ; )
	{
		NewtonErr	err;
		char			exStr[256];
		EventType	evtCmd;
		NSUInteger	evtLen;
		while ((err = [self readCommand:&evtCmd length:&evtLen]) == noErr)
		{
			switch (evtCmd)
			{
			case kTConnect:
			// - data
				self.isTethered = YES;
				// send kTOK
				err = [self sendCommand:kTOK];
				break;

			case kTText:
			// + C string
				while (evtLen > 0)
				{
					NSUInteger strLen = MIN(evtLen, 255);
					err = [ioStream read: exStr length: strLen];
					exStr[strLen] = 0;
					printf("%s",exStr);
					evtLen -= strLen;
				}
				break;

			case kTObject:
			// + ref
				toolkitObject = [self readRef:evtLen];
				printf("\nkTObject = ");
				PrintObject(toolkitObject, 0);
				printf("\n");
				break;

			case kTResult:
			// + word = error code
				err = [self readWord:&toolkitError];
				if (toolkitError)
					printf("\n\t%d\n", toolkitError);
				break;

			case kTCode:
			// + ref length
			// + ref
				{
				// discard the evtLen -- it’s totally erroneous
				ULong resultLen;
				err = [self readWord:(int *)&resultLen];
				toolkitObject = [self readRef:resultLen];
				PrintObject(toolkitObject, 0);
				printf("\n");
				}
				break;

			case kTEOM:
			// - data
				break;

			case kTEnterBreakLoop:
			// - data
				self.breakLoopDepth++;
				break;

			case kTExitBreakLoop:
			// - data
				if (self.breakLoopDepth > 0)
					self.breakLoopDepth--;
				else
					NSLog(@"NTXToolkitProtocolController.breakLoopDepth underflow");
				break;

			case kTDownload:
			// - data
				// install package
				break;

			case kTExceptionError:
			// + word = exception name length
			// + char[] = exception name (nul-terminated)
			// + word = error code

			// NTK reports this like:
			// <tab> Undefined global function: DefConst
			// <tab> evt.ex.fr.intrp;type.ref.frame
			// <tab> -48808

				{
				NewtonErr exErr;
				ULong exItemLen;
				err = [self readWord:(int *)&exItemLen];
				err = [ioStream read: exStr length: exItemLen];
				err = [self readWord:(int *)&exErr];

				const char * str;
				if ((str = GetFramesErrorString(exErr)) != NULL)
				{
					printf("\n\t");
					PrintFramesErrorMsg(str, AllocateFrame());
				}
				printf("\n\t%s\n\t%d\n",exStr, exErr);
				}
				break;

			case kTExceptionMessage:
			// + word = exception name length
			// + char[] = exception name (nul-terminated)
			// + word = message length
			// + char[] = message (nul-terminated)
				{
				ULong exItemLen;
				err = [self readWord:(int *)&exItemLen];
				err = [ioStream read: exStr length: exItemLen];
				printf("\n\t%s\n\t",exStr);

				err = [self readWord:(int *)&exItemLen];
				while (exItemLen > 0)
				{
					NSUInteger strLen = MIN(exItemLen, 255);
					err = [ioStream read: exStr length: strLen];
					exStr[strLen] = 0;
					printf("%s",exStr);
					exItemLen -= strLen;
				}
				printf("\n");
				}
				break;

			case kTExceptionRef:
			// + ref = exception frame
				{
				const char * str;
				toolkitObject = [self readRef:evtLen];
PrintObject(toolkitObject, 0);
printf("\n");

				RefVar exErr(GetFrameSlot(toolkitObject, SYMA(errorCode)));
				if (ISINT(err) && (str = GetFramesErrorString(RINT(exErr))) != NULL)
				{
					printf("\n\t");
					PrintFramesErrorMsg(str, toolkitObject);
					printf("\n");
				}
				}
				break;

			case kTTerminate:
			// - data
				self.isTethered = NO;
				printf("\nNewton disconnected.\n");
				// that’s the end of THIS session
				// but keep listening for the NEXT session
				err = kDockErrDisconnected;
				break;

			default:
				NSLog(@"NTXToolkitProtocolController does not handle command '%c%c%c%c'", (evtCmd >> 24) & 0xFF, (evtCmd >> 16) & 0xFF, (evtCmd >> 8) & 0xFF, evtCmd & 0xFF);
				break;
			}
		}
		// comms error -- start a new connection
		ioStream = [[NTXStream alloc] init];
	}
}


#pragma mark -
#pragma mark Public Interface
/* -----------------------------------------------------------------------------
	Send NewtonScript for execution on the tethered Newton device.
	Args:		inScript
	Return:	--
----------------------------------------------------------------------------- */
extern "C" Ref	FCompile(RefArg inRcvr, RefArg inStr);
extern void REPExceptionNotify(Exception * inException);

- (void) evaluate: (NSString *) inScript
{
	if (!self.isTethered)
	{
		printf("Not connected to Newton.\n");
		return;
	}

	NSUInteger strLen = [inScript length];
	UniChar * str = (UniChar *)malloc((strLen+1) * sizeof(UniChar));
	[inScript getCharacters:str range:NSMakeRange(0, strLen)];
	str[strLen] = 0;

	char * codeBlockData = NULL;

	newton_try
	{
		// compile codeblock
		RefVar codeBlock(FCompile(RA(NILREF), MakeString(str)));
		free(str), str = NULL;

		// prepare data
		NSUInteger objLength = FlattenRefSize(codeBlock);
		// kTCode requires ULong (unused by Newton -- of unknown purpose) before the codeBlock NSOF
		NSUInteger dataLength = sizeof(ULong) + objLength;
		codeBlockData = (char *)malloc(dataLength);
		memset(codeBlockData, 0, sizeof(ULong));

		CPtrPipe pipe;
		pipe.init(codeBlockData + sizeof(ULong), objLength, NO, nil);
		FlattenRef(codeBlock, pipe);

		[self sendCommand:kTCode data:codeBlockData length:dataLength];
	}
	newton_catch_all
	{
		REPExceptionNotify(CurrentException());
	}
	end_try;
	if (str)
		free(str);
	if (codeBlockData)
		free(codeBlockData);
}


/* -----------------------------------------------------------------------------
	Install a Newton package onto the tethered Newton device.
----------------------------------------------------------------------------- */

- (void) installPackage: (NSURL *) inPackage
{
//	[self doEvent: kTInstallPackage];
}


@end
