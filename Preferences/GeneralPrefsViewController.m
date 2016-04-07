/*
	File:		GeneralPrefsViewController.m

	Contains:	General preferences view controller for the NTX app.

	Written by:	Newton Research Group, 2015.
*/

#import "GeneralPrefsViewController.h"

// we need to know all available transports
#import "MNPSerialEndpoint.h"

@implementation GeneralPrefsViewController

/*------------------------------------------------------------------------------
	Create the preferences toolbar.
------------------------------------------------------------------------------*/

- (void) awakeFromNib
{
	ports = nil;
	serialPort = nil;

	if ([MNPSerialEndpoint isAvailable]
	&&  [MNPSerialEndpoint getSerialPorts:&ports] == noErr
	&&  ports.count > 0)
	{
		[GeneralPrefsViewController preferredSerialPort: &serialPort bitRate: &serialSpeed];

		// load it up with available serial port names
		NSUInteger count = ports.count;
		NSUInteger serialPortIndex = 999;
		[serialPortPopup removeAllItems];
		for (NSUInteger i = 0; i < count; ++i)
		{
			NSString * port = [[ports objectAtIndex:i] objectForKey:@"name"];
			[serialPortPopup addItemWithTitle:port];
			port = [[ports objectAtIndex:i] objectForKey:@"path"];
			if ([port isEqualToString:serialPort])
				serialPortIndex = i;
		}
		if (serialPortIndex == 999)
		{
			// serialPort isn’t known by IOKit -- maybe user has set their own default
			// add name, path couplet to ports
			NSMutableArray * newPorts = [NSMutableArray arrayWithArray:ports];
			[newPorts addObject:[NSDictionary dictionaryWithObjectsAndKeys:serialPort, @"name",
																								serialPort, @"path",
																								nil]];
			ports = [[NSArray alloc] initWithArray:newPorts];
			[serialPortPopup addItemWithTitle:serialPort];
			serialPortIndex = count;
		}
		[serialPortPopup selectItemAtIndex:serialPortIndex];
	}
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
		if (![serialPort isEqualToString:[NSUserDefaults.standardUserDefaults stringForKey:kSerialPortPref]])
			[[NSNotificationCenter defaultCenter] postNotificationName:kSerialPortChanged
																				 object:self
																			  userInfo:nil];
	}
}


#pragma mark General
/*------------------------------------------------------------------------------
	G e n e r a l   P r e f e r e n c e s
------------------------------------------------------------------------------*/

+ (int) preferredSerialPort: (NSString * __strong *) outPort bitRate: (NSUInteger *) outRate
{
	NSArray * ports;

	NSUserDefaults * defaults = NSUserDefaults.standardUserDefaults;
	NSString * serialPort = [defaults stringForKey:kSerialPortPref];

	if (serialPort == nil)
	{
		// there’s no serial port preference -- use the first one available
		if ([MNPSerialEndpoint isAvailable]
		&&  [MNPSerialEndpoint getSerialPorts:&ports] == noErr
		&&  ports.count > 0)
		{
			serialPort = [[ports objectAtIndex: 0] objectForKey:@"path"];
			[defaults setObject:serialPort forKey:kSerialPortPref];
		}
	}
	else if ([serialPort rangeOfCharacterFromSet: [NSCharacterSet decimalDigitCharacterSet]].location == 0)
	{
		// serial port pref is numeric, convert it to the string in ports[that index].path and write it back out
		if ([MNPSerialEndpoint isAvailable]
		&&  [MNPSerialEndpoint getSerialPorts: &ports] == noErr
		&&  ports.count > 0)
		{
			serialPort = [[ports objectAtIndex:serialPort.intValue] objectForKey:@"path"];
			[defaults setObject:serialPort forKey:kSerialPortPref];
		}
	}
//	else assume we’ve got the device path
	*outPort = serialPort;

	unsigned int rate = [defaults integerForKey:kSerialBaudPref];
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
		NSString * port = [[ports objectAtIndex: i] objectForKey:@"path"];
		[NSUserDefaults.standardUserDefaults setObject:port forKey:kSerialPortPref];
	}
}

@end
