/*
	File:		ContentViewController.mm

	Abstract:	Implementation of NTXContentViewController subclasses.

	Written by:		Newton Research, 2015.
*/

#import "ContentViewController.h"
#import "ProjectWindowController.h"


/* -----------------------------------------------------------------------------
	N T X C o n t e n t V i e w C o n t r o l l e r
----------------------------------------------------------------------------- */

@implementation NTXContentViewController

- (void)viewWillAppear
{
	NTXProjectWindowController * wc = self.view.window.windowController;
	wc.contentController = self;
	[super viewWillAppear];
}


- (void)show:(NTXEditorViewController *)inViewController
{
	if (![self.childViewControllers containsObject:inViewController]) {
		[self addChildViewController:inViewController];
	}
	[self transitionToViewController:inViewController];
//	[self transitionFromViewController:theVC toViewController:inViewController options:0 completionHandler:nil];
	theVC = inViewController;
}


#pragma mark Item View
/* -----------------------------------------------------------------------------
	Change the information subview.
----------------------------------------------------------------------------- */

- (void) transitionToViewController:(NTXEditorViewController *)inViewController
{
	// remove any previous item view
	if (theVC) {
		[theVC.containerView removeFromSuperview];
	}

	if (inViewController) {
		NSView * itemView = [inViewController containerView];
		// make sure our added subview is placed and resizes correctly
		if (itemView) {
			NSDictionary *views = NSDictionaryOfVariableBindings(itemView);
			[itemView setTranslatesAutoresizingMaskIntoConstraints:NO];
			[self.view addSubview:itemView];
			[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[itemView]|" options:0 metrics:nil views:views]];
			[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[itemView]|" options:0 metrics:nil views:views]];
		}
	}
}

@end
