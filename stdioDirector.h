/*
	File:		stdioDirector.h

	Contains:	Declarations for class that redirects stdout and stderr.

	Written by:	Newton Research Group, 2008.
					Shamelessly pinched from the Handbrake project.
*/

#import <Cocoa/Cocoa.h>

/*------------------------------------------------------------------------------
	This class is used to redirect @c stdout and @c stderr outputs. It is never
	created directly; @c redirect_stdout and @c redirect_stderr class methods
	should be use instead.

	@note Redirection is done by replacing @c _write functions for @c stdout and
		@c stderr streams. Because of this messages written by NSLog(), for
		example are not redirected. I consider this a good thing, but if more
		universal redirecting is needed, it can be done at file descriptor
		level.
------------------------------------------------------------------------------*/

@interface NTXOutputRedirect : NSObject
{
	id listener;
	// Selector that is called on listener to forward the output.
	SEL forwardingSelector;

	// Output stream (@c stdout or @c stderr) redirected by this object.
	FILE * stream;
	
	// Pointer to old write function for the stream.
	int	(*oldWriteFunc)(void *, const char *, int);
}

+ (id) redirect_stdout;
+ (id) redirect_stderr;

- (void) setListener: (id) inListener;

@end

/*
	Here is another technique to redirect stderr, but it is done at lower level
	which also redirects NSLog() and other writes that are done directly to the
	file descriptor. This method is not used by HBOutputRedirect, but should
	be easy to implement if needed. Code is untested, but this is shows basic 
	idea for future reference.

	// Create a pipe
	NSPipe *pipe = [[NSPipe alloc] init];

	// Connect stderr to the writing end of the pipe
	dup2([[pipe fileHandleForWriting] fileDescriptor], STDERR_FILENO);	

	// Get reading end of the pipe, we can use this to read stderr
	NSFileHandle *fh = [pipe fileHandleForReading];
*/
