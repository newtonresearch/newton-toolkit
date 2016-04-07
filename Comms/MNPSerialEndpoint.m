/*
	File:		MNPSerialEndpoint.m

	Contains:	Implementation of the MNP serial endpoint.
					MNP does not seem to be documented ANYWHERE on the web, but
					MNP is incorporated into the V.42 modem protocol which is: T-REC-V.42-199303

	Written by:	Newton Research Group, 2005.
*/

#import "MNPSerialEndpoint.h"
#import "GeneralPrefsViewController.h"
#import "DockErrors.h"

#define ERRBASE_SERIAL					(-18000)	// Newton SerialTool errors
#define kSerErrCRCError					(ERRBASE_SERIAL -  4)	// CRC error on input framing


/* -----------------------------------------------------------------------------
	C o n s t a n t s
----------------------------------------------------------------------------- */

enum
{
	kLRFrameType = 1,		// link request
	kLDFrameType,			// link disconnect
	kLxFrameType,
	kLTFrameType,			// link transfer
	kLAFrameType,			// link acknowledge
	kLNFrameType,			// link attention
	kLNAFrameType			// link attention acknowledge
};


const unsigned char kLRFrame[] =
{
	23,		/* Length of header */
	kLRFrameType,
	0x02,							/* Constant parameter 1 */
/* Type	Len	Data... */
/* ----	----	----    */
	0x01, 0x06, 0x01, 0x00, 0x00, 0x00, 0x00, 0xFF,	/* Constant parameter 2 */
	0x02, 0x01, 0x02,			/* Framing mode = octet-oriented */
	0x03, 0x01, 0x01,			/* Number of outstanding LT frames, k = 1 */
	0x04, 0x02, 0x40, 0x00,	/* Maximum info field length, N401 = 64 */
	0x08, 0x01, 0x03			/* Data phase optimisation, N401 = 256 & fixed LT, LA frames */
};
/*
	26
	01 02
	01 06 01 00 00 00 00 FF
	02 01 02
	03 01 08
	04 02 40 00
	08 01 03
	09 01 01							MNP-specific compression paramters?
	0E 04 03 04 00 FA
	C5 06 01 04 00 00 E1 00 
*/
const unsigned char kLDFrame[] =
{
	4,			/* Length of header */
	kLDFrameType,
/* Type	Len	Data... */
/* ----	----	----    */
	0x01, 0x01, 0xFF			/* Reason code = user-initiated disconnect */
};

const unsigned char kLTFrame[] =
{
	2,			/* Length of header */
	kLTFrameType,
	0			/* Sequence number */
};

const unsigned char kLAFrame[] =
{
	3,			/* Length of header */
	kLAFrameType,
	0,			/* Receive sequence number */
	1			/* Receive credit number, N(k) = 1 */
};


/* -----------------------------------------------------------------------------
	D a t a
----------------------------------------------------------------------------- */

extern BOOL gTraceIO;

int doHandshaking = 0;

static unsigned char ltFrameHeader[sizeof(kLTFrame)];
static unsigned char laFrameHeader[sizeof(kLAFrame)];


/* -----------------------------------------------------------------------------
	S e r i a l   P o r t
--------------------------------------------------------------------------------
	Return an iterator across all known serial ports.

	Each serial device object has a property with key kIOSerialBSDTypeKey
	and a value that is one of
		kIOSerialBSDAllTypes,
		kIOSerialBSDModemType,
		kIOSerialBSDRS232Type.
	You can experiment with the matching by changing the last parameter
	in the call to CFDictionarySetValue.

	Caller is responsible for releasing the iterator when iteration is complete.
----------------------------------------------------------------------------- */

kern_return_t
FindSerialPorts(io_iterator_t * matchingServices)
{
	kern_return_t		result; 
	CFMutableDictionaryRef	classesToMatch;

	// Serial devices are instances of class IOSerialBSDClient
	classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue);
	if (classesToMatch)
		CFDictionarySetValue(classesToMatch,
									CFSTR(kIOSerialBSDTypeKey),
									CFSTR(kIOSerialBSDAllTypes));		// was kIOSerialBSDRS232Type
	else
		REPprintf("IOServiceMatching returned a NULL dictionary.");

	result = IOServiceGetMatchingServices(kIOMasterPortDefault, classesToMatch, matchingServices);    
	if (result != KERN_SUCCESS)
		REPprintf("IOServiceGetMatchingServices returned %d.", result);

	return result;
}


/* -----------------------------------------------------------------------------
	M N P S e r i a l E n d p o i n t
----------------------------------------------------------------------------- */

@implementation MNPSerialEndpoint

/* -----------------------------------------------------------------------------
	Check availablilty of MNP Serial endpoint.
	Available if IOKit can find any serial ports.
----------------------------------------------------------------------------- */

+ (BOOL) isAvailable
{
	BOOL				result = NO;
	io_iterator_t	serialPortIterator;
	io_object_t		service;

	if (FindSerialPorts(&serialPortIterator) == KERN_SUCCESS)
	{
		if ((service = IOIteratorNext(serialPortIterator)) != 0)
		{
			result = YES;
			IOObjectRelease(service);
		}
		IOObjectRelease(serialPortIterator);
	}
	return result;
}



/* -----------------------------------------------------------------------------
	Return array of strings for names and corresponding /dev paths
	of all known serial ports.
----------------------------------------------------------------------------- */

+ (NCError) getSerialPorts: (NSArray * __strong *) outPorts
{
	NCError			result = -1;
	io_iterator_t	serialPortIterator;
	io_object_t		service;

	NSString * portName, * portPath;
	NSMutableArray * ports = [NSMutableArray arrayWithCapacity: 8];
	NSAssert(outPorts != nil, @"nil pointer to serial ports array");
	*outPorts = nil;

	if (FindSerialPorts(&serialPortIterator) == KERN_SUCCESS)
	{
		while ((service = IOIteratorNext(serialPortIterator)) != 0)
		{
			portName = (__bridge NSString *) IORegistryEntryCreateCFProperty(service,
																					  CFSTR(kIOTTYDeviceKey),
																					  kCFAllocatorDefault,
																					  0);
			// Get the callout device's path (/dev/cu.xxxxx). The callout device should almost always be
			// used: the dialin device (/dev/tty.xxxxx) would be used when monitoring a serial port for
			// incoming calls, e.g. a fax listener.
			portPath = (__bridge NSString *) IORegistryEntryCreateCFProperty(service,
																					  CFSTR(kIOCalloutDeviceKey),
																					  kCFAllocatorDefault,
																					  0);
			[ports addObject: [NSDictionary dictionaryWithObjectsAndKeys: portName, @"name",
																							  portPath, @"path",
																							  nil]];
			result = noErr;
		}
		IOObjectRelease(service);
	}
	IOObjectRelease(serialPortIterator);

	if (result == noErr)
		*outPorts = [NSArray arrayWithArray: ports];
	return result;
}


/* -----------------------------------------------------------------------------
	Initialize.
----------------------------------------------------------------------------- */

- (id) init
{
	if (self = [super init])
	{
		/*int err = */[GeneralPrefsViewController preferredSerialPort:&devPath bitRate:&baudRate];
		doHandshaking = [NSUserDefaults.standardUserDefaults integerForKey:@"SerialHandshake"];

		timerT401 = 0;
		timerT403 = 0;
		isLive = NO;
		isLinkRequest = NO;
		isACKPending = NO;
		txSequence = 0;
		prevSequence = 0;
		memcpy(ltFrameHeader, kLTFrame, sizeof(kLTFrame));
		memcpy(laFrameHeader, kLAFrame, sizeof(kLAFrame));

		rxPacketBuf = [[NCBuffer alloc] init];
		rxFrameBuf = [[NCBuffer alloc] init];
		fGetFrameState = 0;
		rxFCS = [[CRC16 alloc] init];

		txPacketBuf = [[NCBuffer alloc] init];
		txFrameBuf = [[NCBuffer alloc] init];
		txFCS = [[CRC16 alloc] init];
	}
	return self;
}


/* -----------------------------------------------------------------------------
	Open the connection.
----------------------------------------------------------------------------- */

- (NCError) listen
{
	NCError err;

	XTRY
	{
		const char *	dev;
		struct termios	options;

		dev = [devPath fileSystemRepresentation];

		// Open the serial port read/write, with no controlling terminal, and don't wait for a connection.
		// The O_NONBLOCK flag also causes subsequent I/O on the device to be non-blocking.
		// See open(2) ("man 2 open") for details.
		XFAILIF((_fd = open(dev, O_RDWR | O_NOCTTY | O_NONBLOCK)) == -1,
					NSLog(@"Error opening serial port %s - %s (%d).", dev, strerror(errno), errno); )

		// Note that open() follows POSIX semantics: multiple open() calls to the same file will succeed
		// unless the TIOCEXCL ioctl is issued. This will prevent additional opens except by root-owned
		// processes.
		// See tty(4) ("man 4 tty") and ioctl(2) ("man 2 ioctl") for details.
		XFAILIF(ioctl(_fd, TIOCEXCL) == -1,
					NSLog(@"Error setting TIOCEXCL on %s - %s (%d).", dev, strerror(errno), errno); )

		// Get the current options and save them for later reset
		XFAILIF(tcgetattr(_fd, &originalAttrs) == -1,
					NSLog(@"Error getting tty attributes %s - %s (%d).", dev, strerror(errno), errno); )

		// Set raw input (non-canonical) mode, with reads blocking until either a single character 
		// has been received or a one second timeout expires.
		// See tcsetattr(4) ("man 4 tcsetattr") and termios(4) ("man 4 termios") for details.

// --> this block defines whether serial works!
		options = originalAttrs;
		cfmakeraw(&options);
		options.c_cc[VMIN] = 0;
		options.c_cc[VTIME] = 0;

		// Set baud rate, word length, and handshake options
		cfsetspeed(&options, baudRate);
		options.c_iflag |= IGNBRK;								// ignore break (also software flow control)
		options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
		options.c_oflag &= ~OPOST;
		options.c_cflag &= ~(CSIZE | CSTOPB | PARENB);
		options.c_cflag |= (CREAD | CLOCAL | CS8);		// use 8 bit words, no parity; ignore modem control
		if (doHandshaking)
			options.c_cflag |= (CCTS_OFLOW | CRTS_IFLOW);		// KeyspanTestSerial.c uses CCTS_OFLOW | CRTS_IFLOW
																				// could also use CDSR_OFLOW | CDTR_IFLOW
																				// but nobody uses CRTSCTS
// <--
		// Set the options now
		XFAILIF(tcsetattr(_fd, TCSANOW, &options) == -1,
					NSLog(@"\nError setting tty attributes %s - %s (%d).", dev, strerror(errno), errno); )

#if kDebugOn
		int modem;
		XFAILIF(ioctl(_fd, TIOCMGET, &modem) == -1,
					NSLog(@"\nError getting modem signals %s - %s (%d).", dev, strerror(errno), errno); )
		const char * sDCD = (modem & TIOCM_CD) ? "DCD" : "dcd";
		const char * sDTR = (modem & TIOCM_DTR)? "DTR" : "dtr";
		const char * sDSR = (modem & TIOCM_DSR)? "DSR" : "dsr";
		const char * sRTS = (modem & TIOCM_RTS)? "RTS" : "rts";
		const char * sCTS = (modem & TIOCM_CTS)? "CTS" : "cts";
		NSLog(@"Serial port: %d bps,  %s %s %s %s %s", baudRate, sDCD, sDTR, sDSR, sRTS, sCTS);
#endif

		// Success
		return noErr;
	}
	XENDTRY;

	// Failure
	if (_fd >= 0)
	{
		close(_fd);
		_fd = -1;
	}
	return -1;
}


/* -----------------------------------------------------------------------------
	Accept the connection.
	Don’t need to do anything here -- negotiation is handled by -processFrame
----------------------------------------------------------------------------- 

- (NCError) accept
{
	return noErr;
}*/


- (void) handleTickTimer
{
	if (timerT401 > 0) {
		if (--timerT401 == 0)
			[self ackTimeOut];
	}
	if (timerT403 > 0) {
		if (--timerT403 == 0)
			[self inactiveTimeOut];
	}
}


/* -----------------------------------------------------------------------------
	Start acknowledgement timer T401.
	1 second.
----------------------------------------------------------------------------- */

- (void) startT401
{
	timerT401 = 1;
}

- (void) stopT401
{
	timerT401 = 0;
}

- (void) ackTimeOut
{
	// no ack received for LT frame -- send it again
	// should limit number of attempts
	isACKPending = YES;
	[self startT401];
	[txFrameBuf refill];
}


/* -----------------------------------------------------------------------------
	Start inactivity timer T403.
	3 seconds.
----------------------------------------------------------------------------- */

- (void) startT403
{
	timerT403 = 3;
}

- (void) stopT403
{
	timerT403 = 0;
}

- (void) inactiveTimeOut
{
	// no activity for the last 3 seconds -- say we’re alive by re-acking last LT frame
	[self startT403];	// reset inactivity timer
	[self xmitLA];
NSLog(@"tickle!");
}


/* -----------------------------------------------------------------------------
	Read data into a FIFO buffer queue.
	Data in the MNP protocol is packeted and framed, so we need to unframe the
	packets first and handle protocol commands.
----------------------------------------------------------------------------- */

- (NCError) read: (unsigned char *) inData length: (NSUInteger) inLength into: (NSMutableData *) ioData
{
	NCError err;
	[rxPacketBuf setData:inData length:inLength];
	for (err = noErr; err == noErr; )
	{
		// strip packet framing
		if ((err = [self unpacketizeData]) == noErr)	// this uses all the data, but might not build a whole frame
			// despatch to frame handler
			err = [self processFrame: ioData];
	}
	if (err == kCommsPartialData	// packet is not complete
	||  err == kSerErrCRCError)	// packet is malformed -- will go unacknowledged
	{
		err = noErr;
	}
	return err;
}


/* -----------------------------------------------------------------------------
	Read raw framed data from the wire
	and fill the rxFrameBuf (a frame in the MNP protocol).
	This MUST fully drain the rxPacketBuf.
	We use an FSM to perform the unframing.
----------------------------------------------------------------------------- */

- (NCError) unpacketizeData
{
	NCError status = kCommsPartialData;

	XTRY
	{
		int ch;
		for (ch = 0; ch >= 0; )		// start off w/ dummy ch
		{
			switch (fGetFrameState)
			{
			case 0:
//	scan for SYN start-of-frame char
				[rxFrameBuf clear];
				[rxFCS reset];
				fIsGetCharEscaped = NO;
				fIsGetCharStacked = NO;
				do
				{
					XFAIL((ch = rxPacketBuf.nextChar) < 0)
					if (ch == chSYN)
						fGetFrameState = 1;
					else
						fPreHeaderByteCount++;
				} while (ch != chSYN);
				break;

//	next start-of-frame must be DLE
			case 1:
				XFAIL((ch = rxPacketBuf.nextChar) < 0)
				if (ch == chDLE)
					fGetFrameState = 2;
				else
				{
					fGetFrameState = 0;
					fPreHeaderByteCount += 2;
				}
				break;

//	next start-of-frame must be STX
			case 2:
				XFAIL((ch = rxPacketBuf.nextChar) < 0)
				if (ch == chSTX)
					fGetFrameState = 3;
				else
				{
					fGetFrameState = 0;
					fPreHeaderByteCount += 3;
				}
				break;

//	read char from input buffer
			case 3:
				if (fIsGetCharStacked)
				{
					fIsGetCharStacked = NO;
					ch = fStackedGetChar;
				}
				else
					XFAIL((ch = rxPacketBuf.nextChar) < 0)

				if (!fIsGetCharEscaped && ch == chDLE)
					fGetFrameState = 4;
				else
				{
					rxFrameBuf.nextChar = (unsigned char)ch;
					[rxFCS computeCRC: ch];
					fIsGetCharEscaped = NO;
				}
				break;

// escape char
			case 4:
				XFAIL((ch = rxPacketBuf.nextChar) < 0)
				if (ch == chETX)
				{
					// it’s end-of-message
					[rxFCS computeCRC: ch];
					fGetFrameState = 5;
				}
				else if (ch == chDLE)
				{
					// it’s an escaped escape
					fIsGetCharStacked = YES;
					fStackedGetChar = ch;
					fIsGetCharEscaped = YES;
					fGetFrameState = 3;
				}
				else
					// it’s nonsense -- ignore it
					fGetFrameState = 3;
				break;

//	check first byte of FCS
			case 5:
				XFAIL((ch = rxPacketBuf.nextChar) < 0)
				if (ch == [rxFCS get: 0])
					fGetFrameState = 6;
				else
				{
					fGetFrameState = 0;
					status = kSerErrCRCError;
					ch = -1;			// fake value so we break out of the loop
				}
				break;

//	check second byte of FCS
			case 6:
				XFAIL((ch = rxPacketBuf.nextChar) < 0)
				if (ch == [rxFCS get: 1])
					fGetFrameState = 7;
				else
				{
					fGetFrameState = 0;
					status = kSerErrCRCError;
					ch = -1;			// fake value so we break out of the loop
				}
				break;

//	frame done
			case 7:
				// reset FSM for next time
				fGetFrameState = 0;
				status = noErr;	// noErr -- packet fully unframed
				ch = -1;				// fake value so we break out of the loop
				break;
			}
		}
	}
	XENDTRY;

	return status;
}


/* -----------------------------------------------------------------------------
	Process an MNP packet.
	We can assume rxFrameBuf contains a whole frame.
----------------------------------------------------------------------------- */

- (NCError) processFrame: (NSMutableData *) ioDataBuf
{
	NCError err = noErr;
	[self startT403];	// reset inactivity timer
	// start reading frame from the beginning
	[rxFrameBuf reset];
	// first char is header length -- ignore it
	int rxFrameLen = rxFrameBuf.ptr[0];
	// second char is frame type
	int rxFrameType = rxFrameBuf.ptr[1];

	switch (rxFrameType)
	{
	case kLRFrameType:
		[self rcvLR];
		break;
	case kLDFrameType:
		[self rcvLD];
		err = kDockErrDisconnected;
		break;
	case kLTFrameType:
		[self rcvLT: ioDataBuf];
		break;
	case kLAFrameType:
		[self rcvLA];
		break;
	case kLNFrameType:
		[self rcvLN];
		break;
	case kLNAFrameType:
		[self rcvLNA];
		break;
	default:
#if 1 // kDebugOn
NSLog(@" <-- received unknown packet type (%d)", rxFrameType);
#endif
		// err = kCommsBadPacket;?
		// abort?
		break;
	}
	return err;
}


/* -----------------------------------------------------------------------------
	Handle a received LR (link request) negotiation packet.
----------------------------------------------------------------------------- */

- (void) rcvLR
{
	isLive = YES;
	isLinkRequest = YES;
	rxSequence = 0;

	// negotiate connection parameters
	[self xmitLR];
}


/* -----------------------------------------------------------------------------
	Handle a received LT (link transfer) data packet.
	CRC errors have already been handled, so this packet is good.
	Add the data to the read queue.
----------------------------------------------------------------------------- */

- (void) rcvLT: (NSMutableData *) ioDataBuf
{
	prevSequence = rxSequence;
	rxSequence = rxFrameBuf.ptr[2];	// third char in header is packet sequence number
//	check rxSequence so we can handle out-of-sequence packets?

	unsigned int headerLen = 1 + rxFrameBuf.ptr[0];	// first char in header is header length
	[ioDataBuf appendBytes: rxFrameBuf.ptr + headerLen length: rxFrameBuf.count - headerLen];

	// acknowledge receipt
	[self xmitLA];
}


/* -----------------------------------------------------------------------------
	Handle a received LA (link acknowledge) packet.
----------------------------------------------------------------------------- */

- (void) rcvLA
{
	[self stopT401];

	if (isLinkRequest)
	{
		isLinkRequest = NO;
		txSequence = 0;
	}
	else
	{
		isACKPending = NO;
		// #### if ack seq no != sent seq no, we need to resend the frame
	}
}


/* -----------------------------------------------------------------------------
	Handle a received LD (link disconnect) packet.
----------------------------------------------------------------------------- */

- (void) rcvLD
{
#if 1 // kDebugOn
NSLog(@" <-- received LD packet (disconnect)");
#endif
}


/* -----------------------------------------------------------------------------
	Handle a received LN (link attention) packet.
----------------------------------------------------------------------------- */

- (void) rcvLN
{ /* this really does nothing */ }


/* -----------------------------------------------------------------------------
	Handle a received LNA (link attention acknowledge) packet.
----------------------------------------------------------------------------- */

- (void) rcvLNA
{ /* this really does nothing */ }


#pragma mark -

/* -----------------------------------------------------------------------------
	Send Link Request frame.
	We don’t negotiate -- we only ever talk to the Newton MNP implementation
	so just send our capability.
----------------------------------------------------------------------------- */

- (void) xmitLR
{
	[self packetize: kLRFrame data: NULL length: 0];
}


/* -----------------------------------------------------------------------------
	Send Link Transfer frame.
----------------------------------------------------------------------------- */

- (void) xmitLT: (const unsigned char *) inPacketBuf length: (NSUInteger) inCount
{
	ltFrameHeader[2] = ++txSequence;
	[self packetize: ltFrameHeader data: inPacketBuf length: inCount];
	isACKPending = YES;
	[self startT401];
	// if it times out before we receive LA frame, resend the packet
}


/* -----------------------------------------------------------------------------
	Send Link Acknowledge frame.
----------------------------------------------------------------------------- */

- (void) xmitLA
{
	laFrameHeader[2] = rxSequence;
	[self packetize: laFrameHeader data: NULL length: 0];
}


/* -----------------------------------------------------------------------------
	Send Link Disconnect frame.
----------------------------------------------------------------------------- */

- (void) xmitLD
{
	isLive = NO;
	[self stopT401];
	[self stopT403];

	// Send disconnect frame.
	[self packetize: kLDFrame data: NULL length: 0];
}


/* -----------------------------------------------------------------------------
	Send data from the output buffer.
	Have to break the data into 256-byte LT packet sized chunks,
	which are then framed with MNP header/trailer.
----------------------------------------------------------------------------- */

- (void) writePage: (NCBuffer *) inFrameBuf from: (NSMutableData *) inDataBuf
{
	unsigned int count;
	if (txFrameBuf.count == 0 && !isACKPending)
	{
		count = [inDataBuf length];
		if (count > 0)
		{
			unsigned char packetBuf[kMNPPacketSize];
			if (count > kMNPPacketSize)
				count = kMNPPacketSize;
			[inDataBuf getBytes:packetBuf length:count];
			[inDataBuf replaceBytesInRange: NSMakeRange(0, count) withBytes: NULL length: 0];

			[self xmitLT: packetBuf length: count];
		}
	}
	if ((count = txFrameBuf.count) > 0)
	{
		if (count > inFrameBuf.freeSpace)
			count = inFrameBuf.freeSpace;
		[inFrameBuf fill:count from:txFrameBuf.ptr];
		[txFrameBuf drain:count];
	}
}


/* -----------------------------------------------------------------------------
	Send a packet, optionally with data.
	We can assume the data is already sub-packet-sized.
	Actually, we don’t send here, we just prepare txFrameBuf
	and say when asked that we willSend: it.
----------------------------------------------------------------------------- */

- (void) packetize: (const unsigned char *) inHeader data: (const unsigned char *) inBuf length: (unsigned int) inLength
{
	// Create MNP frame from packet data.

	// start the frame
	[txFrameBuf clear];
	[txFCS reset];

	// write frame start
	txFrameBuf.nextChar = chSYN;
	txFrameBuf.nextChar = chDLE;
	txFrameBuf.nextChar = chSTX;

	// copy frame header
	[self addToFrameBuf: inHeader length: 1 + inHeader[0]];

	// copy frame data
	if (inBuf != NULL)
		[self addToFrameBuf: inBuf length: inLength];

	// write frame end
	txFrameBuf.nextChar = chDLE;
	txFrameBuf.nextChar = chETX;
	[txFCS computeCRC: chETX];

	// write CRC
	txFrameBuf.nextChar = [txFCS get: 0];
	txFrameBuf.nextChar = [txFCS get: 1];

	// remember state in case we need to refill on NAK
	[txFrameBuf mark];
}


- (void) addToFrameBuf: (const unsigned char *) inBuf length: (unsigned int) inLength
{
	const unsigned char * p;
	for (p = inBuf; inLength > 0; inLength--, p++)
	{
		const unsigned char ch = *p;
		[txFCS computeCRC: ch];
		if (ch == chDLE)
			// escape frame end start char
			txFrameBuf.nextChar = chDLE;
		txFrameBuf.nextChar = ch;
	}
}


/* -----------------------------------------------------------------------------
	Close the connection.
	Traditionally it is good practice to reset a serial port back to the state
	in which you found it.  Let's continue that tradition.
----------------------------------------------------------------------------- */

- (NCError) close
{
	if (_fd >= 0)
	{
		if (isLive)
			[self xmitLD];	// won’t work in new scheme

#if 0
		// See http://blogs.sun.com/carlson/entry/close_hang_or_4028137 for an explanation of the unkillable serial app.
		// AMSerialPort say: kill pending read by setting O_NONBLOCK
		if (fcntl(_fd, F_SETFL, fcntl(_fd, F_GETFL, 0) | O_NONBLOCK) == -1)
			NSLog(@"Error setting O_NONBLOCK %@ - %s(%d).", devPath, strerror(errno), errno);
#else
		// Block until all written output has been sent from the device.
		// Note that this call is simply passed on to the serial device driver. 
		// See tcsendbreak(3) ("man 3 tcsendbreak") for details.
		if (tcdrain(_fd) == -1)
//		if (tcflush(_fd, TCIOFLUSH) == -1)		// this may discard what we’ve just written, but tcdrain(_fd) blocks possibly forever if the connection is broken
			NSLog(@"Error draining data - %s (%d).", strerror(errno), errno);
#endif

		if (tcsetattr(_fd, TCSANOW, &originalAttrs) == -1)
			NSLog(@"Error resetting tty attributes - %s (%d).", strerror(errno), errno);

		close(_fd);
		_fd = -1;
	}
	return noErr;
}

@end
