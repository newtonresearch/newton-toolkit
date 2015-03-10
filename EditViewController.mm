/*
	File:		EditViewController.mm

	Abstract:	Implementation of NTXEditViewController subclasses.

	Written by:		Newton Research, 2014.
*/

#import "EditViewController.h"


/* -----------------------------------------------------------------------------
	N T X E d i t V i e w C o n t r o l l e r
----------------------------------------------------------------------------- */

@implementation NTXEditViewController

- (NSView *) containerView
{ return self.view; }

- (void) willShow
{
//	isRegisteredForDraggedTypes = NO;
}

- (void) willHide
{
}

@end


/* -----------------------------------------------------------------------------
	N T X I c o n V i e w C o n t r o l l e r
----------------------------------------------------------------------------- */

@implementation NTXIconViewController
@end
