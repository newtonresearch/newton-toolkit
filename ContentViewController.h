/*
	File:		ContentViewController.h

	Abstract:	The NTXContentViewController (top half of window content split view)
					switches document editor view controller according to the current source list selection.

	Written by:		Newton Research, 2015.
*/

#import <AppKit/AppKit.h>
#import "EditorViewController.h"


/* -----------------------------------------------------------------------------
	N T X C o n t e n t V i e w C o n t r o l l e r
----------------------------------------------------------------------------- */

@interface NTXContentViewController : NSViewController
{
	NTXEditorViewController * theVC;
}
- (void)show:(NTXEditorViewController *)inViewController;
@end
