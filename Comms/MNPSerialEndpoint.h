/*
	File:		MNPSerialEndpoint.h

	Contains:	MNPSerialEndpoint communications transport interface.

	Written by:	Newton Research Group, 2005-2011.
*/

#import "Endpoint.h"

#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <paths.h>
#include <termios.h>
#include <sysexits.h>
#include <sys/param.h>
#include <sys/ioctl.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/serial/ioss.h>
#include <IOKit/IOBSD.h>

#include "CRC.h"
#include "NCBuffer.h"

#define kCaptureOn 1

//	Standard ASCII Mnemonics

#define	chNUL						0x00
#define	chSOH						0x01	/* Control-A */
#define	chSTX						0x02	/* Control-B */
#define	chETX						0x03	/* Control-C */
#define	chEOT						0x04	/* Control-D */
#define	chENQ						0x05	/* Control-E */
#define	chACK						0x06	/* Control-F */
#define	chBEL						0x07	/* Control-G */
#define	chBS						0x08	/* Control-H */
#define	chHT						0x09	/* Control-I */
#define	chLF						0x0A	/* Control-J */
#define	chVT						0x0B	/* Control-K */
#define	chFF						0x0C	/* Control-L */
#define	chCR						0x0D	/* Control-M */
#define	chSO						0x0E	/* Control-N */
#define	chSI						0x0F	/* Control-O */
#define	chDLE						0x10	/* Control-P */
#define	chDC1						0x11	/* Control-Q */
#define	chDC2						0x12	/* Control-R */
#define	chDC3						0x13	/* Control-S */
#define	chDC4						0x14	/* Control-T */
#define	chNAK						0x15	/* Control-U */
#define	chSYN						0x16	/* Control-V */
#define	chETB						0x17	/* Control-W */
#define	chCAN						0x18	/* Control-X */
#define	chEM						0x19	/* Control-Y */
#define	chSUB						0x1A	/* Control-Z */
#define	chESC						0x1B	/* Control-[ */
#define	chFS						0x1C
#define	chGS						0x1D
#define	chRS						0x1E
#define	chUS						0x1F


#define kMNPPacketSize	256
#define kMNPFrameSize	(kMNPPacketSize*2 + 10)

/* -----------------------------------------------------------------------------
	M N P S e r i a l E n d p o i n t
----------------------------------------------------------------------------- */

@interface MNPSerialEndpoint : NCEndpoint
{
	NSString *			devPath;
	NSUInteger			baudRate;
	struct termios		originalAttrs;

	unsigned char		rxSequence;
	unsigned char		prevSequence;

	CRC16 *				rxFCS;
	int					fGetFrameState;
	int					fPreHeaderByteCount;
	BOOL					fIsGetCharEscaped;
	BOOL					fIsGetCharStacked;
	unsigned char		fStackedGetChar;
	BOOL					isLinkRequest;
	NCBufferAccess *	rxPacketBuf;
	NCBuffer *			rxFrameBuf;

	NCBuffer *			txPacketBuf;
	unsigned char		txSequence;
	NCBuffer *			txFrameBuf;
	CRC16 *				txFCS;

	BOOL					isLive;
	BOOL					isACKPending;
	int					timerT401;
	int					timerT403;
}
+ (NCError) getSerialPorts: (NSArray * __strong  *) outPorts;

- (NCError) unpacketizeData;
- (NCError) processFrame: (NSMutableData *) ioDataBuf;
- (void) rcvLR;
- (void) rcvLT: (NSMutableData *) ioDataBuf;
- (void) rcvLA;
- (void) rcvLD;
- (void) rcvLN;
- (void) rcvLNA;

- (void) xmitLR;
- (void) xmitLT: (const unsigned char *) inPacketBuf length: (NSUInteger) inCount;
- (void) xmitLA;
- (void) xmitLD;

- (void) packetize: (const unsigned char *) inHeader data: (const unsigned char *) inBuf length: (unsigned int) inSize;
- (void) addToFrameBuf: (const unsigned char *) inBuf length: (unsigned int) inLength;

- (void) startT401;
- (void) stopT401;
- (void) ackTimeOut;
- (void) startT403;
- (void) stopT403;
- (void) inactiveTimeOut;

@end
