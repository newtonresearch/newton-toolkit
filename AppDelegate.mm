/*
	File:		Controller.mm

	Contains:	Cocoa controller delegate for the NTX app.

	Written by:	Newton Research Group, 2007.
*/

#import "AppDelegate.h"
#import "ProjectWindowController.h"
#import "ToolkitProtocolController.h"
#import "Preferences.h"
#import "Utilities.h"
#import "NTK/Pipes.h"

extern void	HoldSchedule(void);
extern "C" void	StopScheduler(void);

extern Ref	UnflattenRef(CPipe & inPipe);
extern Ref	ParseFile(const char * inFilename);


NSNumberFormatter * gNumberFormatter;
NSDateFormatter * gDateFormatter;

/*------------------------------------------------------------------------------
	N T X C o n t r o l l e r
-------------------------------------------------------------------------------*/

@implementation NTXController

#pragma mark App
/*------------------------------------------------------------------------------
	Application is up; open the inspector window and start listening for a
	Toolkit connection.
	Args:		inNotification
	Return:	--
------------------------------------------------------------------------------*/

- (void) applicationDidFinishLaunching: (NSNotification *) inNotification
{
	[NSUserDefaults.standardUserDefaults registerDefaults:@{
	//	System
		@"Platform":@"Newton 2.1",
	//	General
		@"MainHeapSize":@"4096",
		@"BuildHeapSize":@"1024",
		@"AutoSave":@"YES",
		@"AutoDownload":@"YES"
	//	Layout
	//	Browser
	}];

//	set up preferred platform
	self.currentPlatform = nil;
	[self setPlatform: [NSUserDefaults.standardUserDefaults stringForKey: @"Platform"]];

//	set up the editor: stream in protoEditor from EditorCommands stream
// it looks like { variables: { protoEditor: {...} }
//						 InstallScript:<function, 0 args, #03C7A4CD> }
// we just need to call the InstallScript
	NSURL * url = [NSBundle.mainBundle URLForResource:@"EditorCommands" withExtension:@""];
	CStdIOPipe pipe(url.fileSystemRepresentation, "r");
	RefVar obj(UnflattenRef(pipe));
	DoMessage(obj, MakeSymbol("InstallScript"), RA(NILREF));

// compile/execute GlobalData and GlobalFunctions files
	url = [NSBundle.mainBundle URLForResource:@"GlobalData" withExtension:@"newtonscript"];
	ParseFile(url.fileSystemRepresentation);

	url = [NSBundle.mainBundle URLForResource:@"GlobalFunctions" withExtension:@"newtonscript"];
	ParseFile(url.fileSystemRepresentation);

// start listening for notifications re: serial port changes
	[[NSNotificationCenter defaultCenter] addObserver:self
														  selector:@selector(serialPortChanged:)
																name:kSerialPortChanged
															 object:nil];

	// start listening for notifications re: cmd-return
	[[NSNotificationCenter defaultCenter] addObserver:self
														  selector:@selector(evaluateNewtonScript:)
																name:kEvaluateNewtonScript
															 object:nil];

// create a session that listens for a Newton device trying to connect
	self.ntkNub = [[NTXToolkitProtocolController alloc] init];

	[[NSDocumentController sharedDocumentController] setAutosavingDelay:5.0];	// auto save project documents every five seconds

	// initialize the number formatter used throughout the UI
	gNumberFormatter = [[NSNumberFormatter alloc] init];
	[gNumberFormatter setNumberStyle: NSNumberFormatterDecimalStyle];
	// and the date formatter
	gDateFormatter = [[NSDateFormatter alloc] init];
	[gDateFormatter setDateStyle: NSDateFormatterFullStyle];
	[gDateFormatter setTimeStyle: NSDateFormatterShortStyle];
}


/*------------------------------------------------------------------------------
	Respond to serial port change notification.
	We need to reset the connection to listen on the new serial port.
	Args:		inNotification
	Return:	--
------------------------------------------------------------------------------*/

- (void) serialPortChanged: (NSNotification *) inNotification
{
	self.ntkNub = [[NTXToolkitProtocolController alloc] init];
}


/*------------------------------------------------------------------------------
	Respond to cmd-return.
	Evaluate the selected text.
	Args:		inNotification
	Return:	--
------------------------------------------------------------------------------*/

- (void) evaluateNewtonScript: (NSNotification *) inNotification
{
	[self.ntkNub evaluate:[inNotification object]];
}


/*------------------------------------------------------------------------------
	We don’t want to quit if our only window is closed.
	Args:		sender
	Return:	always NO
------------------------------------------------------------------------------*/

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *) sender
{
	return NO;
}


/*------------------------------------------------------------------------------
	If there’s a transaction in progress we shouldn’t go to sleep.
	Args:		--
	Return:	always NO until the docker part comes up
------------------------------------------------------------------------------*/

- (BOOL) applicationCanSleep
{
	return YES;//(!isNewtConnected);
}

- (void) applicationWillSleep
{
/*
	if (isNewtConnected)
		[docker disconnect];
*/
}


/*------------------------------------------------------------------------------
	Defer termination until we’re properly disconnected.
	We want to tell newton we’re disconnecting, and disconnect cleanly when the
	application terminates.
	Args:		sender
	Return:	NSTerminateNow
------------------------------------------------------------------------------

- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *) sender
{
//	[docker die];
//	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];
	return NSTerminateNow;
}*/


/*------------------------------------------------------------------------------
	Clean up before termination.
	Save the Inspector text.
	Args:		sender
	Return:	--
------------------------------------------------------------------------------*/

- (void) applicationWillTerminate: (NSApplication *) sender
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


/*------------------------------------------------------------------------------
	Handle Report Bugs application menu item.
	Args:		sender
	Return:	--
------------------------------------------------------------------------------*/

- (IBAction) reportBugs: (id) sender
{
	NSURL * url = [NSURL URLWithString:@"mailto:simon@newtonresearch.org"
													"?subject=Newton%20Toolkit%20Bug%20Report"
												 /*"&body=Share%20and%20Enjoy"*/ ];
	[[NSWorkspace sharedWorkspace] openURL:url];
}


#pragma mark Toolkit
/*------------------------------------------------------------------------------
	Set platform functions and variables.
	gVarFrame = vars
		.__platform := unflattened platform file which contains
			MagicPointerTable			empty array
			platformFunctions			toolkit functions
			platformWeakFunctions	more of the same
			platformVariables			toolkit variables
			platformConstants			constants used to build package for platform
			TemplateArray				toolkit browser function templates
			installer

	We can just call the old platform.installer:Remove() function (if it exists) to remove cleanly the previous platform
	then the new platform.installer:Install() function to install it

	We already have these:
	DefGlobalVar: func(sym, val) vars.(EnsureInternal(sym)) := val,
	UnDefGlobalVar: func(sym) begin RemoveSlot(vars, sym); nil end,
	And these:
	DefGlobalFn:	plainC.FDefGlobalFn,
	UnDefGlobalFn: func(sym) begin RemoveSlot(functions, sym); nil end,

	For NTX we add:
	DefineGlobalConstant:	(native)
	UnDefineGlobalConstant:	(native)

	DefPureFn: func(sym, fn) constantFunctions.(sym) := fn,	// constantFunctions is a frame in vars

	Also in NTX, we access constant vars and functions.
	FUNCTIONS
	constantFunctions		{ LocObj, ButtonBounds et al }
		is a frame in vars
		is generally platform-independent, but:
		DefPureFn adds functions to it
=>		add constantFunctions to function lookup chain -- after normal function lookup

	CONSTANTS
	DefineGlobalConstant is a native function
=>		add value to internal globalConstants frame
		since the globalConstants frame is inaccessible from vars, it cannot be modified
	UnDefineGlobalConstant is a native function
=>		remove value from internal globalConstants frame
	The compiler uses globalConstants.

	Args:		inPlatform			name of platform NSOF file
	Return:	--
------------------------------------------------------------------------------*/

- (void) setPlatform: (NSString *) inPlatform
{
	if ([inPlatform isEqualToString: self.currentPlatform])
		return;	// no change

	RefVar installerFrame;
	if (self.currentPlatform) {
		// remove former platform
		installerFrame = GetFrameSlot(RA(gVarFrame), SYMA(__platform));
		installerFrame = GetFrameSlot(installerFrame, MakeSymbol("installer"));
		DoMessage(installerFrame, MakeSymbol("Remove"), RA(NILREF));
	}

	self.currentPlatform = inPlatform;

	//	stream in platform file definitions
	NSURL * path = [NSBundle.mainBundle URLForResource: inPlatform withExtension: nil subdirectory: @"Platforms"];
	CStdIOPipe pipe(path.fileSystemRepresentation, "r");
	RefVar platform(UnflattenRef(pipe));

	// set global __platform frame
	installerFrame = GetFrameSlot(platform, MakeSymbol("installer"));
	DoMessage(installerFrame, MakeSymbol("Install"), RA(NILREF));

}


/* -----------------------------------------------------------------------------
	Enable main menu items as per app logic.
		App
			Report Bugs…		always
		Edit
			Delete				enable if we have a selection
			Select All			let the system handle it
		Build
			Install Toolkit	if we are tethered
			Screen Shot			if we are tethered
			Disconnect			if we are tethered

	Args:		inItem
	Return:	YES => enable
----------------------------------------------------------------------------- */

- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>) inItem
{
	if (inItem.action == @selector(installToolkit:)
	||  inItem.action == @selector(takeScreenshot:)
	||  inItem.action == @selector(disconnect:)) {
		return self.ntkNub.isTethered;
	}
	if (inItem.action == @selector(reportBugs:)) {
		return YES;
	}
	return NO;
}


#pragma mark Build menu actions

/* -----------------------------------------------------------------------------
	Download the Toolkit package to Newton device.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction)installToolkit:(id)sender
{
	[self.ntkNub installPackage:[NSBundle.mainBundle URLForResource:@"Toolkit" withExtension:@"newtonpkg"]];
}


/* -----------------------------------------------------------------------------
	Take a screenshot of the tethered Newton device.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction)takeScreenshot:(id)sender
{
	[self.ntkNub takeScreenshot];
}

- (void)showScreenshot:(NSImage *)inShot
{
	if (inShot != nil)
	{
	// play shutter release sound
		NSSound * shutterClick = [NSSound soundNamed: @"click"];
		if (shutterClick) {
			[shutterClick play];
		}

//		if inShot were an NSBitmapImageRep then we could:
//		NSData *pngData = [inShot representationUsingType:NSPNGFileType properties:nil];
		NSData * tiffData = [inShot TIFFRepresentationUsingCompression: NSTIFFCompressionLZW factor: 1.0];
		if (tiffData) {
#if 1
			//	save into temporary file
			NSString * fileName = [NSString stringWithFormat:@"Screenshot-%@.tiff", [[NSProcessInfo processInfo] globallyUniqueString]];
			NSURL * fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
			//	open it in Preview
			[[NSWorkspace sharedWorkspace] openURL:fileURL];
#else
			//	save into file chosen by user
			NSSavePanel * chooser = [NSSavePanel savePanel];
			chooser.nameFieldStringValue = @"Screenshot";
			chooser.allowedFileTypes = [NSArray arrayWithObject:(__bridge NSString *)kUTTypeTIFF];
			if ([chooser runModal] == NSFileHandlingPanelOKButton) {
				// save image
				if ([tiffData writeToURL:chooser.URL atomically:NO])
				//	open it in Preview
					[[NSWorkspace sharedWorkspace] openURL:chooser.URL];
			}
#endif
		}
	}

// better to open our own window with an image that can be copied/dragged?
}


/* -----------------------------------------------------------------------------
	Disconnect from the tethered Newton device.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction)disconnect:(id)sender
{
	[self.ntkNub disconnect];
}

@end
