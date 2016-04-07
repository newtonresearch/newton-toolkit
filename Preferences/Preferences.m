/*
	File:		Preferences.m

	Contains:	Preference controller for the NTX app.

	Written by:	Newton Research Group, 2008.
*/

#import "Preferences.h"
#import <Sparkle/SUUpdater.h>

// we need to know all available transports
#import "MNPSerialEndpoint.h"


#define TOOLBAR_GENERAL		@"GeneralPrefs"
#define TOOLBAR_SERIAL		@"SerialPrefs"
#define TOOLBAR_ADVANCED	@"AdvancedPrefs"
#define TOOLBAR_UPDATE		@"UpdatePrefs"

// SUScheduledCheckInterval is measured in seconds -- convert to days
#define kDays					(24 * 60 * 60)


/**
 * This class controls the preferences window of NCX. Default values for
 * all preferences and user defaults are specified in class method
 * @c registerUserDefaults. The preferences window is loaded from
 * Preferences.nib file when NTXPreferenceController is initialized.
 *
 * All preferences are bound to user defaults in Interface Builder, therefore
 * no getter/setter code is needed in this file (unless more complicated
 * preference settings are added that cannot be handled with Cocoa bindings).
 */
 
@interface NTXPreferenceController (Private)
- (void) setSerialView;
- (void) setUpdateView;
@end

@implementation NTXPreferenceController

/*------------------------------------------------------------------------------
	Return shared preferences controller.
------------------------------------------------------------------------------*/

+ (NTXPreferenceController *) sharedController
{
	static NTXPreferenceController * sharedController = nil;

	if (sharedController == nil)
		sharedController = [[self alloc] init];

	return sharedController;
}


/*------------------------------------------------------------------------------
	Handle Preferences application menu item.
	Args:		sender
	Return:	--
------------------------------------------------------------------------------*/

- (IBAction) showPreferencesPanel: (id) sender
{
	NSWindow * window = [self window];
	if (![window isVisible])
		[window center];

	[window makeKeyAndOrderFront: nil];
}


/*------------------------------------------------------------------------------
	Initialize the preferences controller by loading Preferences.nib file.
------------------------------------------------------------------------------*/

- (id) init
{
	if (self = [super initWithWindowNibName: @"Preferences"])
	{
		NSAssert([self window], @"-[NTXPreferenceController init] window outlet is not connected in Preferences.xib");
	}
	return self; 
}


/*------------------------------------------------------------------------------
	Create the preferences toolbar.
------------------------------------------------------------------------------*/

- (void) awakeFromNib
{
	[self setSerialView];
	[self setUpdateView];

	[[[self window] toolbar] setSelectedItemIdentifier: TOOLBAR_GENERAL];
	[self setPrefsView: nil];
}


/*------------------------------------------------------------------------------
	Called when the receiver is about to close.
	If the serial port has been changed, tell the app so it can reset the
	connection using the new port.
	Args:		notification
	Return:	--
------------------------------------------------------------------------------*/

- (void) windowWillClose: (NSNotification *) notification
{
	// only need to do anything if we have a serial port
	if (serialPort != nil)
	{
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

		if (![serialPort isEqualToString: [defaults stringForKey: kSerialPortPref]])
			[[NSNotificationCenter defaultCenter] postNotificationName: kSerialPortChanged
																				 object: self
																			  userInfo: nil];
	}
}


/*------------------------------------------------------------------------------
	A toolbar icon has been clicked -- change the preference view.
------------------------------------------------------------------------------*/

- (IBAction) setPrefsView: (id) sender
{
	NSView * view = fGeneralView;
	if (sender)
	{
		NSString * identifier = [sender itemIdentifier];
		if ([identifier isEqualToString: TOOLBAR_UPDATE])
			view = fUpdateView;
	}

	NSWindow * window = [self window];
	if ([window contentView] == view)
		return;

	NSRect windowRect = [window frame];
	float delta = [view frame].size.height - [[window contentView] frame].size.height;
	windowRect.origin.y -= delta;
	windowRect.size.height += delta;

	[view setHidden: YES];
	[window setContentView: view];
	[window setFrame: windowRect display: YES animate: YES];
	[view setHidden: NO];

	//set title label
	if (sender)
		[window setTitle: [sender label]];
	else
	{
		NSToolbar * toolbar = [window toolbar];
		NSString * itemIdentifier = [toolbar selectedItemIdentifier];
		for (NSToolbarItem * item in [toolbar items])
		{
			if ([[item itemIdentifier] isEqualToString: itemIdentifier])
			{
				[window setTitle: [item label]];
				break;
			}
		}
	}
}


#pragma mark General
/*------------------------------------------------------------------------------
	G e n e r a l   P r e f e r e n c e s
------------------------------------------------------------------------------*/

+ (int) preferredSerialPort: (NSString * __strong *) outPort bitRate: (NSUInteger *) outRate
{
	NSArray * ports;
	int i, count;

	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	NSString * serialPort = [defaults stringForKey: kSerialPortPref];

	if (serialPort == nil)
	{
		// there’s no serial port preference -- use the first one available
		if ([MNPSerialEndpoint isAvailable]
		&&  [MNPSerialEndpoint getSerialPorts: &ports] == noErr
		&&  (count = [ports count]) > 0)
		{
			serialPort = [[ports objectAtIndex: 0] objectForKey: @"path"];
			[defaults setObject: serialPort forKey: kSerialPortPref];
		}
	}
	else if ([serialPort rangeOfCharacterFromSet: [NSCharacterSet decimalDigitCharacterSet]].location == 0)
	{
		// serial port pref is numeric, convert it to the string in ports[that index].path and write it back out
		if ([MNPSerialEndpoint isAvailable]
		&&  [MNPSerialEndpoint getSerialPorts: &ports] == noErr
		&&  (count = [ports count]) > 0)
		{
			i = [serialPort intValue];
			serialPort = [[ports objectAtIndex: i] objectForKey: @"path"];
			[defaults setObject: serialPort forKey: kSerialPortPref];
		}
	}
//	else assume we’ve got the device path
	*outPort = serialPort;

	unsigned int rate = [defaults integerForKey: kSerialBaudPref];
	if (rate == 0)
		rate = 38400;
	*outRate = rate;

	return 0;	// ought to return error code if appropriate
}


/*------------------------------------------------------------------------------
	Keep the serial port default in sync with the UI.
	Args:		sender		the user interface element
	Return:	--
------------------------------------------------------------------------------*/

- (IBAction) updateSerialPort: (id) sender
{
	NSInteger i = [(NSPopUpButton *)sender indexOfSelectedItem];
	if (i >= 0)
	{
		NSString * port = [[ports objectAtIndex: i] objectForKey: @"path"];
		[[NSUserDefaults standardUserDefaults] setObject: port forKey: kSerialPortPref];
	}
}


#pragma mark Software Update
/*------------------------------------------------------------------------------
	S o f t w a r e   U p d a t e   P r e f e r e n c e s
------------------------------------------------------------------------------*/

enum CheckFrequencyMark
{
	kCheckNever,
	kCheckDaily,
	kCheckWeekly,
	kCheckMonthly
};

- (IBAction) updateFrequency: (id) sender
{
	if (sender == autoCheck)
	{
		// this is the “Check for updates” checkbox
		[[SUUpdater sharedUpdater] setAutomaticallyChecksForUpdates: [sender state] == NSOnState];
	}

	else
	{
		// this is the frequency popup menu
		NSTimeInterval checkInterval;	// seconds
		switch ([[sender selectedItem] tag])
		{
		default:
		case kCheckDaily:
			checkInterval = kDays;
			break;
		case kCheckWeekly:
			checkInterval = 7 * kDays;
			break;
		case kCheckMonthly:
			checkInterval = 28 * kDays; // lunar month!
			break;
		}
		[[SUUpdater sharedUpdater] setUpdateCheckInterval: checkInterval];
	}
}

@end


@implementation NTXPreferenceController (Private)

/*------------------------------------------------------------------------------
	Set up the General Preferences view.
	TO DO:
	set up the popup by hand
		populate w/ ports.name
		set up initialIndex
	on windowWillClose, if selected index has changed write new ports.path to defaults
	can bind selected index, surely?
------------------------------------------------------------------------------*/

- (void) setSerialView
{
	ports = nil;
	serialPort = nil;

	if ([MNPSerialEndpoint isAvailable]
	&&  [MNPSerialEndpoint getSerialPorts: &ports] == noErr
	&&  [ports count] > 0)
	{
		[NTXPreferenceController preferredSerialPort: &serialPort bitRate: &serialSpeed];

		// load it up with available serial port names
		NSUInteger i, count = [ports count];
		NSUInteger serialPortIndex = 999;
		[serialPortPopup removeAllItems];
		for (i = 0; i < count; ++i)
		{
			NSString * port = [[ports objectAtIndex: i] objectForKey: @"name"];
			[serialPortPopup addItemWithTitle: port];
			port = [[ports objectAtIndex: i] objectForKey: @"path"];
			if ([port isEqualToString: serialPort])
				serialPortIndex = i;
		}
		if (serialPortIndex == 999)
		{
			// serialPort isn’t known by IOKit -- maybe user has set their own default
			// add name, path couplet to ports
			NSMutableArray * newPorts = [NSMutableArray arrayWithArray: ports];
			[newPorts addObject: [NSDictionary dictionaryWithObjectsAndKeys: serialPort, @"name",
																								  serialPort, @"path",
																								  nil]];
			ports = [[NSArray alloc] initWithArray: newPorts];
			[serialPortPopup addItemWithTitle: serialPort];
			serialPortIndex = count;
		}
		[serialPortPopup selectItemAtIndex: serialPortIndex];
	}
	else
	{
		// hide the serial port picker and reduce the size of the view accordingly
		NSRect bounds = [fGeneralView frame];
		NSSize shrunkenSize = bounds.size;
		shrunkenSize.height -= 88;

		[fGeneralView setFrameSize: shrunkenSize];
	}
}


/*------------------------------------------------------------------------------
	Set up the Software Update Preferences view.
------------------------------------------------------------------------------*/

- (void) setUpdateView
{
	NSTimeInterval checkFrequencyInDays;
	int itemIndexToSelect;

	checkFrequencyInDays = [[SUUpdater sharedUpdater] updateCheckInterval] / kDays;

	if (checkFrequencyInDays > 27)
		itemIndexToSelect = [frequencyPopUp indexOfItemWithTag: kCheckMonthly];
	else if (checkFrequencyInDays > 6)
		itemIndexToSelect = [frequencyPopUp indexOfItemWithTag: kCheckWeekly];
	else
		itemIndexToSelect = [frequencyPopUp indexOfItemWithTag: kCheckDaily];

	[frequencyPopUp selectItemAtIndex: itemIndexToSelect];
	[autoCheck setState: [[SUUpdater sharedUpdater] automaticallyChecksForUpdates] ? NSOnState : NSOffState];
}

@end
