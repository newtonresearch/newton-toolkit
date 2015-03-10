/*
	File:		ProjectItem.h

	Abstract:	An NTXProjectItem is the Cocoa representation of an item extracted from projectRef.projectItems.items[].
					It contains enough information to be represented in the source list.
					The NSDocument* field is instantiated lazily, when needed.

	Written by:		Newton Research, 2012.
*/

#import <Cocoa/Cocoa.h>

/* -----------------------------------------------------------------------------
	N T X P r o j e c t I t e m
	It represents a source file: name and icon.
	When selected, it shows an editor for its represented file.
----------------------------------------------------------------------------- */
@class NTXDocument;

@interface NTXProjectItem : NSObject <NSPasteboardWriting, NSPasteboardReading>
{
	NTXDocument * _document;					// we provide the getter so we need the ivar
}
@property(strong) NSURL * url;				// the URL of the document, stored in the project
@property(assign) NSUInteger type;
@property(readonly) NTXDocument * document;	//	the document this item represents; it is lazily created from the URL when the item is selected
// derived for UI
@property(assign) NSString * name;			// [url lastPathComponent]
@property(readonly) NSImage * image;		// looked up from type
@property(assign) BOOL isMainLayout;
@property(assign) BOOL isContainer;			// looked up from type (using private NTX code)

- (id) initWithURL:(NSURL *)inURL type:(NSUInteger)inType;
@end


/* -----------------------------------------------------------------------------
	N T X P r o j e c t S e t t i n g s I t e m
----------------------------------------------------------------------------- */
@class NTXProjectDocument;

@interface NTXProjectSettingsItem : NTXProjectItem
- (id) initWithProject:(NTXProjectDocument *)inProject;
@end


/* -----------------------------------------------------------------------------
	N T X F i l e I t e m
	A file item represents a source file. Or group.
----------------------------------------------------------------------------- */

@interface NTXFileItem : NTXProjectItem
@end
