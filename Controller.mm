/*
	File:		Controller.mm

	Contains:	Cocoa controller delegate for the NTX app.

	Written by:	Newton Research Group, 2007.
*/

#import "Controller.h"
#import "ToolkitProtocolController.h"
#import "Utilities.h"
#import "NTK/Pipes.h"

extern Ref	UnflattenRef(CPipe & inPipe);
extern Ref	ParseFile(const char * inFilename);


/*------------------------------------------------------------------------------
	N T X C o n t r o l l e r
	General policy:
	We’ve got an amazing Newton framework -- use it.
	All files to be NSOF (like WinNTK).
-------------------------------------------------------------------------------*/

@implementation NTXController

/*------------------------------------------------------------------------------
	Application is up; open the inspector window and start listening for a
	Toolkit connection.
	Args:		inNotification
	Return:	--
------------------------------------------------------------------------------*/
extern void	HoldSchedule(void);
extern "C" void	StopScheduler(void);

- (void) applicationDidFinishLaunching: (NSNotification *) inNotification
{
	[[NSUserDefaults standardUserDefaults] registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
	//	System
		@"Newton 2.1",	@"Platform",
	//	General
		@"4096",			@"MainHeapSize",
		@"256",			@"BuildHeapSize",
		@"YES",			@"AutoSave",
		@"YES",			@"AutoDownload",
	//	Layout
	//	Browser
		nil]];

//	set up preferred platform
	self.currentPlatform = nil;
	[self setPlatform: [[NSUserDefaults standardUserDefaults] stringForKey: @"Platform"]];

//	set up the editor: stream in protoEditor from EditorCommands stream
// it looks like { variables: { protoEditor: {...} }
//						 installScript:<function, 0 args, #03C7A4CD> }
// we just need to call the installScript
	NSURL * url = [[NSBundle mainBundle] URLForResource: @"EditorCommands" withExtension: @""];
	CStdIOPipe pipe([[url path] fileSystemRepresentation], "r");
	RefVar obj(UnflattenRef(pipe));
	DoMessage(obj, MakeSymbol("installScript"), RA(NILREF));

// compile/execute GlobalData and GlobalFunctions files
	url = [[NSBundle mainBundle] URLForResource: @"GlobalData" withExtension: @"newtonscript"];
	ParseFile([[url path] fileSystemRepresentation]);

	url = [[NSBundle mainBundle] URLForResource: @"GlobalFunctions" withExtension: @"newtonscript"];
	ParseFile([[url path] fileSystemRepresentation]);

// start listening for notifications re: serial port changes
	[[NSNotificationCenter defaultCenter] addObserver: self
														  selector: @selector(serialPortChanged:)
																name: kSerialPortChanged
															 object: nil];

	// start listening for notifications re: cmd-return
	[[NSNotificationCenter defaultCenter] addObserver: self
														  selector: @selector(evaluateNewtonScript:)
																name: kEvaluateNewtonScript
															 object: nil];

// create a session that listens for a Newton device trying to connect
	self.ntkNub = [[NTXToolkitProtocolController alloc] init];

	[[NSDocumentController sharedDocumentController] setAutosavingDelay:5.0];	// auto save project documents every five seconds
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
	[self.ntkNub evaluate: [inNotification object]];
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
	[[NSNotificationCenter defaultCenter] removeObserver: self];
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

	Also in NYX, we access constant vars and functions.
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
	if (self.currentPlatform)
	{
		// remove former platform
		installerFrame = GetFrameSlot(RA(gVarFrame), SYMA(__platform));
		installerFrame = GetFrameSlot(installerFrame, MakeSymbol("installer"));
		DoMessage(installerFrame, MakeSymbol("Remove"), RA(NILREF));
	}

	self.currentPlatform = inPlatform;

	//	stream in platform file definitions
	NSURL * path = [[NSBundle mainBundle] URLForResource: inPlatform withExtension: nil subdirectory: @"Platforms"];
	const char * filenameStr = [[path path] fileSystemRepresentation];

	CStdIOPipe pipe(filenameStr, "r");
	RefVar platform(UnflattenRef(pipe));

	// set global __platform frame
	installerFrame = GetFrameSlot(platform, MakeSymbol("installer"));
	DoMessage(installerFrame, MakeSymbol("Install"), RA(NILREF));

}


/* -----------------------------------------------------------------------------
	Enable main menu items as per app logic.
		Edit
			Delete				enable if we have a selection
			Select All			let the system handle it
		Build
			Connect inspector	if we are NOT tethered
			Screen Shot			if we ARE tethered

	Args:		inItem
	Return:	YES => enable
----------------------------------------------------------------------------- */
#if 0
- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>) inItem
{
	if ([inItem action] == @selector(delete:))
	{
		if (![document isKindOfClass: [NBDocument class]]
		&&  entries.selectionIndex != NSNotFound)
		{
			// we have an NCX2 document and a selection
			if (self.dock.isTethered
			||  !soup.app.isPackages)
				// we are not looking at archived packages
				return YES;
		}
	}
	return NO;
}
#endif

#pragma mark File menu actions

/* -----------------------------------------------------------------------------
	Save the currently selected project item.
	Not necessarily this document, since it’s a container for other documents.
	Args:		sender
	Return:	--
-----------------------------------------------------------------------------

- (IBAction) saveDocument: (id) sender
{
NSLog(@"-[NTXController saveDocument:]");
}*/


#pragma mark Build menu actions

/* -----------------------------------------------------------------------------
	Connect to a Newton device.
	The current project window’s inspector pane will become live.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction) connectInspector: (id) sender
{}


/* -----------------------------------------------------------------------------
	Download the Toolkit package to Newton device.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction) installToolkit: (id) sender
{}


/* -----------------------------------------------------------------------------
	Take a screenshot of the tethered Newton device.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction) takeScreenshot: (id) sender
{}


#pragma mark Connection
/* -----------------------------------------------------------------------------
	Download the specified package to Newton device.
	Connect first if not already tethered.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (void) download: (NSURL *) inURL
{}

@end
