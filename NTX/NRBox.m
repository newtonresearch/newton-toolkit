/*
	File:		NRBox.m

	Contains:	An NSBox for the project window content view.

	Written by:	Newton Research Group, 2015.
*/

#import "NRBox.h"

/* -----------------------------------------------------------------------------
	N R B o x
	When awoken, set up our font.
	Draw the box filled with a title at the top.
----------------------------------------------------------------------------- */

@implementation NRBox

- (void)awakeFromNib {
	self.titleFont = [NSFont systemFontOfSize:16.0];	// could try [NSFont fontWithName:@"HelveticaNeue-Light" size:18.0] ?
	[self.titleCell setTextColor:[NSColor blackColor]];
}


- (void)drawRect:(NSRect)inRect {
	if (self.boxType == NSBoxCustom && self.borderType == NSLineBorder) {
		NSRect boxRect = self.borderRect;
		CGFloat wd = self.borderWidth;
		CGFloat insetWd = wd / 2.0;

		if (self.titlePosition != NSNoTitle) {
			NSDictionary * attrs = [[self.titleCell attributedStringValue] attributesAtIndex:0 effectiveRange:NULL];
			NSSize titleSize = [self.title sizeWithAttributes:attrs];
			NSRect titleRect = NSMakeRect(boxRect.origin.x + wd + 4,
													boxRect.origin.y + boxRect.size.height - titleSize.height - (wd * 2.0),
													titleSize.width + (wd * 2.0),
													titleSize.height);
			titleRect.size.width = MIN(titleRect.size.width, boxRect.size.width - (wd * 2.0));
			// reduce box height to allow for title
			boxRect.size.height -= (titleRect.size.height + 8);

			[NSColor.whiteColor set];
			NSRectFill(self.borderRect);

			[self.title drawInRect:titleRect withAttributes:attrs];
		}
		[self.fillColor set];
		NSRectFill(boxRect);

		if (self.borderType == NSLineBorder && wd > 0.0) {
			[self.borderColor set];
			NSFrameRectWithWidth(NSInsetRect(boxRect, insetWd, insetWd), wd);
		}
	} else {
		[super drawRect: inRect];
	}
}

@end
