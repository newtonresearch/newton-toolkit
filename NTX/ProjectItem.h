/*
	File:		ProjectItem.h

	Abstract:	An NTXProjectItem is the Cocoa representation of an item extracted from projectRef.projectItems.items[].
					It contains enough information to be represented in the source list.
					The NTXDocument* field is instantiated lazily, when needed.

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
	NTXDocument * _document;
}
@property(strong) NSURL * url;				// the URL of the document, stored in the project
@property(assign) NSInteger type;
@property(assign) BOOL isMainLayout;		// only valid if type == layout
@property(readonly) NTXDocument * document;	//	the document this item represents; it is lazily created from the URL when the item is selected
// derived for UI
@property(assign) NSString * name;			// url.lastPathComponent
@property(readonly) NSImage * image;		// looked up from type
@property(assign) BOOL isContainer;			// looked up from type (using private NTX code)

- (id)initWithURL:(NSURL *)inURL type:(NSInteger)inType;	// by default isMainLayout=NO
@end


/* -----------------------------------------------------------------------------
	N T X P r o j e c t S e t t i n g s I t e m
----------------------------------------------------------------------------- */
@class NTXProjectDocument;

@interface NTXProjectSettingsItem : NTXProjectItem
- (id) initWithProject:(NTXProjectDocument *)inProject;
@end

