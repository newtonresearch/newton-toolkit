/*
	File:		NTXSettingsViewController.h

	Abstract:	Interface for NTXProjectViewController class.

	Written by:		Newton Research, 2014.
*/

#import <Cocoa/Cocoa.h>

@interface NTXPopupCell : NSPopUpButtonCell
//- (void) drawImageWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (void)drawBorderAndBackgroundWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
@end


@interface NTXSettingsViewController : NSViewController
{
	NSArray * settings;
	IBOutlet NSOutlineView * outlineView;
	NSFont * menuFont;
	IBOutlet NSMenu * booleanMenu;
	IBOutlet NSMenu * partMenu;
	IBOutlet NSMenu * platformMenu;
}
@end
