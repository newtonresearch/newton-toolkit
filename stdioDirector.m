/*
	File:		stdioDirector.m

	Contains:	Implementation of class that redirects stdout and stderr.

	Written by:	Newton Research Group, 2008.
					Shamelessly pinched from the Handbrake project.
*/

#import "stdioDirector.h"

/// Global pointer to NTXOutputRedirect object that manages redirects for stdout.
static NTXOutputRedirect * g_stdoutDirector = nil;

/// Global pointer to NTXOutputRedirect object that manages redirects for stderr.
static NTXOutputRedirect * g_stderrDirector = nil;

@interface NTXOutputRedirect (Private)
- (id) initWithStream: (FILE *) aStream selector: (SEL) aSelector;
- (void) startRedirect;
- (void) stopRedirect;
- (void) forwardOutput: (NSData *) data;
@end

/**
 * Function that replaces stdout->_write and forwards stdout to g_stdoutDirector.
 */
int stdoutwrite(void * inFD, const char * buffer, int size)
{
	@autoreleasepool
	{
		NSData * data = [[NSData alloc] initWithBytes: buffer length: size];
		[g_stdoutDirector performSelectorOnMainThread:@selector(forwardOutput:) withObject:data waitUntilDone:NO];
	}
	return size;
}

/**
 * Function that replaces stderr->_write and forwards stderr to g_stderrDirector.
 */
int stderrwrite(void * inFD, const char * buffer, int size)
{
	@autoreleasepool
	{
		NSData * data = [[NSData alloc] initWithBytes:buffer length:size];
		[g_stderrDirector performSelectorOnMainThread:@selector(forwardOutput:) withObject:data waitUntilDone:NO];
	}
	return size;
}

@implementation NTXOutputRedirect

/**
 * Returns NTXOutputRedirect object used to redirect stdout.
 */
+ (id) redirect_stdout
{
	if (!g_stdoutDirector)
		g_stdoutDirector = [[NTXOutputRedirect alloc] initWithStream:stdout selector:@selector(insertText:)];
		
	return g_stdoutDirector;
}

/**
 * Returns NTXOutputRedirect object used to redirect stderr.
 */
+ (id) redirect_stderr
{
	if (!g_stderrDirector)
		g_stderrDirector = [[NTXOutputRedirect alloc] initWithStream:stderr selector:@selector(insertText:)];
		
	return g_stderrDirector;
}


- (void) setListener: (id) inListener
{
	if (inListener)
	{
		listener = inListener;
		[self startRedirect];
	}
	else
	{
		[self stopRedirect];

		if (self == g_stdoutDirector)
			g_stdoutDirector = NULL;
		else if (self == g_stderrDirector)
			g_stderrDirector = NULL;
	}
}

@end

@implementation NTXOutputRedirect (Private)

/**
 * Private constructor which should not be called from outside. This is used to
 * initialize the class at @c stdoutRedirect and @c stderrRedirect.
 *
 * @param aStream	Stream that wil be redirected (stdout or stderr).
 * @param aSelector	Selector that will be called in listeners to redirect the stream.
 *
 * @return New NTXOutputRedirect object.
 */
- (id)initWithStream:(FILE *)aStream selector:(SEL)aSelector
{
	if (self = [super init])
	{
		listener = nil;
		forwardingSelector = aSelector;
		stream = aStream;
		oldWriteFunc = NULL;
	}
	return self;
}

/**
 * Starts redirecting the stream by redirecting its output to function
 * @c stdoutwrite() or @c stderrwrite(). Old _write function is stored to
 * @c oldWriteFunc so it can be restored. 
 */
- (void)startRedirect
{
	if (!oldWriteFunc)
	{
		oldWriteFunc = stream->_write;
		stream->_write = stream == stdout ? stdoutwrite : stderrwrite;
	}
}

/**
 * Stops redirecting of the stream by returning the stream's _write function
 * to original.
 */
- (void)stopRedirect
{
	if (oldWriteFunc)
	{
		stream->_write = oldWriteFunc;
		oldWriteFunc = NULL;
	}
}

/**
 * Called from @c stdoutwrite() and @c stderrwrite() to forward the output to 
 * listeners.
 */ 
- (void)forwardOutput:(NSData *)data
{
	NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	[listener performSelector:forwardingSelector withObject:string];
}

@end
