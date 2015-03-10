/*
	File:		EditViewController.h

	Abstract:	Interface for NTXEditViewController class.

	Written by:		Newton Research, 2011.
*/

#import <AppKit/AppKit.h>


/* -----------------------------------------------------------------------------
	N T X E d i t V i e w C o n t r o l l e r
	Controller for the editor view.
----------------------------------------------------------------------------- */

@interface NTXEditViewController : NSViewController
{
//	BOOL isRegisteredForDraggedTypes;
}
@property(readonly) NSView * containerView;

- (void) willShow;
- (void) willHide;

@end


@protocol NTXUIValidation
- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>) inItem;
- (void) performDeleteAction;
@end


/* -----------------------------------------------------------------------------
	N T X I c o n V i e w C o n t r o l l e r
	Really, unimplemented view controller.
	Just show the image for this source item type.
----------------------------------------------------------------------------- */

@interface NTXIconViewController : NTXEditViewController
@property(strong) NSImage * image;
@end

