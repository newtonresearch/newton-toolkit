/*
	File:		InspectorWindowController.h

	Contains:	Cocoa controller delegate declarations for the Newton Inspector.

	Written by:	Newton Research Group, 2007.
*/

#import <Cocoa/Cocoa.h>
#import "NTXEditorView.h"
#import "stdioDirector.h"


/* -----------------------------------------------------------------------------
	N T X W i n d o w C o n t r o l l e r
----------------------------------------------------------------------------- */

@interface NTXWindowController : NSWindowController
{
	NTXOutputRedirect * redirector;
	NSDictionary * txAttrs;

	IBOutlet NSTextField * infoView;
	IBOutlet NTXEditorView * txView;
}
- (void) loadText: (NSURL *) inURL;
- (void) saveText: (NSURL *) inURL;
@end

