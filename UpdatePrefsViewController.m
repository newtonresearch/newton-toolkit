/*
	File:		UpdatePrefsViewController.m

	Contains:	Software update preferences controller for the NTX app.

	Written by:	Newton Research Group, 2008.
*/

#import "UpdatePrefsViewController.h"
#import <Sparkle/SUUpdater.h>

// SUScheduledCheckInterval is measured in seconds -- convert to days
#define kDays (24 * 60 * 60)


@implementation UpdatePrefsViewController

/*------------------------------------------------------------------------------
	Create the preferences toolbar.
------------------------------------------------------------------------------*/

- (void) awakeFromNib
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
