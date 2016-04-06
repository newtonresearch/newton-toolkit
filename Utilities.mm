/*
	File:		Utilities.mm

	Contains:	Utility functions for the NCX app.

	Written by:	Newton Research Group, 2005.
*/

#import "Utilities.h"
#import "NTK/PackageParts.h"

extern "C" Ref MakeStringOfLength(const UniChar * str, size_t numChars);

NSString * gDesktopName;


/*------------------------------------------------------------------------------
	U t i l i t i e s
------------------------------------------------------------------------------*/

// these funcs in Newton/View.cc don’t appear in the Newton framework

Ref
SetBoundsRect(RefArg ioFrame, const Rect * inBounds)
{
	RefVar	r;

	r = MAKEINT(inBounds->top);
	SetFrameSlot(ioFrame, SYMA(top), r);
	r = MAKEINT(inBounds->left);
	SetFrameSlot(ioFrame, SYMA(left), r);
	r = MAKEINT(inBounds->bottom);
	SetFrameSlot(ioFrame, SYMA(bottom), r);
	r = MAKEINT(inBounds->right);
	SetFrameSlot(ioFrame, SYMA(right), r);

	return ioFrame;
}

Ref
ToObject(const Rect * inBounds)
{
	Ref	Rbounds = MAKEMAGICPTR(36);	//SYS_boundsFrame;
	Ref *	RSbounds = &Rbounds;
	RefVar	frame(Clone(RA(bounds)));
	return SetBoundsRect(frame, inBounds);
}


/*------------------------------------------------------------------------------
	Read a stream file.
	Args:		inRcvr
				inFilename
	Return:	the streamed object
------------------------------------------------------------------------------*/

extern "C" Ref
ReadStreamFile(RefArg inRcvr, RefArg inFilename)
{
	char filename[256];
	ConvertFromUnicode(GetUString(inFilename), filename, 255);

	CStdIOPipe pipe(filename, "r");
	return UnflattenRef(pipe);
}



/*------------------------------------------------------------------------------
	Make a NextStep string from a NewtonScript string.
	Args:		inStr			a NewtonScript string
	Return:	an autoreleased NSString
------------------------------------------------------------------------------*/

NSString *
MakeNSString(RefArg inStr)
{
	if (IsString(inStr))
		return [NSString stringWithCharacters: GetUString(inStr)
												 length: (Length(inStr) - sizeof(UniChar))/sizeof(UniChar)];
	return nil;
}


/*------------------------------------------------------------------------------
	Make a NewtonScript string from a NextStep string.
	Args:		inStr			an NSString
	Return:	a NewtonScript string
------------------------------------------------------------------------------*/

Ref
MakeString(NSString * inStr)
{
	RefVar s;
	UniChar buf[128];
	UniChar * str = buf;
	unsigned int strLen = [inStr length];
	if (strLen > 128)
		str = (UniChar *) malloc(strLen*sizeof(UniChar));
	[inStr getCharacters: str];
	// NO LINEFEEDS!
	for (UniChar * p = str; p < str + strLen; p++)
		if (*p == 0x0A)
			*p = 0x0D;
	s = MakeStringOfLength(str, strLen);
	if (str != buf)
		free(str);
	return s;
}


/*------------------------------------------------------------------------------
	Make a NextStep date from a NewtonScript date.
	Args:		inDate			a NewtonScript date
	Return:	an autoreleased NSDate
------------------------------------------------------------------------------*/

#define kMinutesSince1904 34714080

NSDate *
MakeNSDate(RefArg inDate)
{
	if (ISINT(inDate))
	{
		NSTimeInterval interval = RVALUE(inDate);
//NSLog(@"MakeNSDate(%d) -> %@", RVALUE(inDate), [[NSDate dateWithTimeIntervalSince1970: (interval - kMinutesSince1904)*60] description]);
		return [NSDate dateWithTimeIntervalSince1970: (interval - kMinutesSince1904)*60];
	}
	return nil;
}


/*------------------------------------------------------------------------------
	Make a NewtonScript date (number of minutes since 1904) from a NextStep date.
	Args:		inDate			an NSDate
	Return:	a NewtonScript integer
------------------------------------------------------------------------------*/

Ref
MakeDate(NSDate * inDate)
{
	NSTimeInterval interval = [inDate timeIntervalSince1970]/60;	// seconds -> minutes
//NSLog(@"MakeDate(%@) -> %d", [inDate description], kMinutesSince1904 + (int)interval);
	return MAKEINT(kMinutesSince1904 + interval);
}


/*------------------------------------------------------------------------------
	Build a NewtonScript array of filenames in the current folder.
	Used when browsing from the newton.
	Filter the list so that only packages, importable files or sync files
	are visible depending on the type of browsing in progress.
	Args:		inPath		NSString of path to current folder
				inFilter		NSString of types of file to return in the list
	Return:	an array of frames describing the files
------------------------------------------------------------------------------*/

NSString *
Stringer(NSArray * inArray)
{
	NSString * str = [NSString stringWithString: [inArray objectAtIndex: 0]];
	for (int i = 0, count = [inArray count]; i < count; ++i)
		str = [str stringByAppendingFormat: @",%@", [inArray objectAtIndex: i]];
	return str;
}


int
FindStringInArray(NSArray * inArray, NSString * inStr)
{
	NSString * str;
	for (int i = 0, count = [inArray count]; i < count; ++i)
	{
		str = [inArray objectAtIndex: i];
		if ([str caseInsensitiveCompare: inStr] == NSOrderedSame)
			return i;
	}
	return -1;
}


/*------------------------------------------------------------------------------
	Return the URL of a file in our application support folder.
	Args:		--
	Return:	an autoreleased NSURL
------------------------------------------------------------------------------*/

NSURL *
ApplicationSupportFolder(void)
{
	NSFileManager * fmgr = [NSFileManager defaultManager];
	NSURL * baseURL = [fmgr URLForDirectory: NSApplicationSupportDirectory inDomain: NSUserDomainMask appropriateForURL: nil create: YES error: nil];
	NSURL * appFolder = [baseURL URLByAppendingPathComponent: @"Newton Inspector"];
	// if folder doesn’t exist, create it
	NSError * __autoreleasing err = nil;
	[fmgr createDirectoryAtPath: [appFolder path] withIntermediateDirectories: NO attributes: nil error: &err];
	return appFolder;
}

NSURL *
ApplicationSupportFile(NSString * inFilename)
{
	return [ApplicationSupportFolder() URLByAppendingPathComponent: inFilename];
}


const char *
StoreBackingFile(const char * inStoreName)
{
	NSURL * stor = [ApplicationSupportFolder() URLByAppendingPathComponent: @"Stores" isDirectory: YES];
	stor = [stor URLByAppendingPathComponent: [NSString stringWithUTF8String:inStoreName] isDirectory: NO];
	return [stor fileSystemRepresentation];
}


/*------------------------------------------------------------------------------
	Return the URL of the log file in the user’s logs folder.
	Args:		--
	Return:	an autoreleased NSURL
------------------------------------------------------------------------------*/

NSURL *
ApplicationLogFile(void)
{
	NSFileManager * fmgr = [NSFileManager defaultManager];
	// find /Library
	NSURL * url = [fmgr URLForDirectory: NSLibraryDirectory inDomain: NSUserDomainMask appropriateForURL: nil create: NO error: nil];
	// cd /Library/Logs
	url = [url URLByAppendingPathComponent: @"Logs"];
	// if folder doesn’t exist, create it
//	[fmgr createDirectoryAtPath: [url path] withIntermediateDirectories: NO attributes: nil error:(NSError **) nil];
	// create /Library/Logs/NewtonConnection.log
	return [url URLByAppendingPathComponent: @"NewtonInspector.log"];
}

