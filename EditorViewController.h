/*
	File:		EditorViewController.h

	Abstract:	Interface for NTXEditorViewController class.

	Written by:		Newton Research, 2011.
*/

#import <AppKit/AppKit.h>


/* -----------------------------------------------------------------------------
	N T X E d i t o r V i e w C o n t r o l l e r
	Every document in an NTX project has an editor. This is its view controller.
----------------------------------------------------------------------------- */

@interface NTXEditorViewController : NSViewController
{
//	BOOL isRegisteredForDraggedTypes;
}
@property(readonly) NSView * containerView;
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

@interface NTXIconViewController : NTXEditorViewController
@property(strong) NSImage * image;
@end

