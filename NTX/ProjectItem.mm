/*
	File:		ProjectItem.mm

	Abstract:	An NTXProjectItem knows its own name.

	Written by:		Newton Research, 2012.
*/

#import "ProjectItem.h"
#import "ProjectTypes.h"

/* -----------------------------------------------------------------------------
	D a t a
----------------------------------------------------------------------------- */

NSArray * gTypeNames;

/* -----------------------------------------------------------------------------
	N T X D o c u m e n t C o n t r o l l e r
----------------------------------------------------------------------------- */
@interface NTXDocumentController : NSDocumentController
@end

@implementation NTXDocumentController
- (void)noteNewRecentDocumentURL:(NSURL *)inURL {
/* don’t add project items to the Open Recent menu */
}
@end


/* -----------------------------------------------------------------------------
	N T X P r o j e c t I t em
----------------------------------------------------------------------------- */
@implementation NTXProjectItem

@synthesize url;
@synthesize type;
@synthesize isMainLayout;
@synthesize isExcluded;

/* -----------------------------------------------------------------------------
	Read file type map (NSUInteger) -> (NSString *)
	Args:		--
	Return:	--
----------------------------------------------------------------------------- */

+ (void)initialize
{
	NSURL * rsrcURL = [NSBundle.mainBundle URLForResource:@"projectfiletype" withExtension:@"plist"];
	gTypeNames = [[NSArray alloc] initWithContentsOfURL:rsrcURL];
}


/* -----------------------------------------------------------------------------
	Initialize source item.
	Args:		--
	Return:	self
----------------------------------------------------------------------------- */

- (id)init {
	if (self = [super init]) {
		self.url = nil;
		self.type = kMetafileType;	// default file type => unused
		self.isMainLayout = NO;
		_document = nil;
	}
	return self;
}


/* -----------------------------------------------------------------------------
	Initialize source item instance with its URL.
	Args:		inURL
				intype
	Return:	self
----------------------------------------------------------------------------- */

- (id)initWithURL:(NSURL *)inURL type:(NSInteger)inType {
	if (self = [super init]) {
		self.url = inURL;
		self.type = inType;
		self.isMainLayout = NO;
		_document = nil;
	}
	return self;
}


- (Ref)build {
	RefVar result = [self.document build];
	if (self.isMainLayout) {
		return result;
	}
	return NILREF;
}

- (BOOL)isContainer {
	return self.type == kGroupType;
}

- (void)setIsContainer:(BOOL)inContainer {
	self.type = inContainer ? kGroupType : kMetafileType;
}


- (NTXDocument *)document {
	if (_document == nil) {
//		document = [[NSDocumentController sharedController] openDocumentWithContentsOfURL:url display:NO completionHandler:NULL];
//			is the official way to open a document, but we need to associate the right file type with the URL -- with legacy projects we can’t be sure the path has the right extension
//			so imitate that method
		NTXDocumentController * documentController = [NTXDocumentController sharedDocumentController];
		NSString * typeName = @"metafile";	// somwething invalid
		if (self.type < gTypeNames.count)
			typeName = [gTypeNames objectAtIndex:self.type];
		typeName = [NSString stringWithFormat:@"com.newton.%@", typeName];
		NSError *__autoreleasing err = nil;
		_document = [documentController makeDocumentWithContentsOfURL:self.url ofType:typeName error:&err];
//			does [document initWithContentsOfURL:url ofType:typeName error:&err];
//		check err -- document may not exist at that URL
		if (_document) {
			[documentController addDocument: _document];
			[_document makeWindowControllers];
//			[_document showWindows];		// documents don’t have separate windows
		}
	}
	return _document;
}


/* -----------------------------------------------------------------------------
	Return the icon for this item. This depends on the type of file:
		0 Layout file (also used for user-proto and print layout files)
		1 Bitmap file
		2 Metafile file (unused)
		3 Sound file
		4 Book file (deprecated in favor of script items)
		5 Script file (NewtonScript source file)
		6 Package file
		7 Stream file
		8 Native C++ code module file
	Args:		--
	Return:	icon
----------------------------------------------------------------------------- */

- (NSImage *)image {
	if (self.type < gTypeNames.count) {
		return [NSImage imageNamed:gTypeNames[self.type]];
	}
	return nil;
}


/* -----------------------------------------------------------------------------
	For UI: so we can disable items when not valid.
	Args:		--
	Return:	name
----------------------------------------------------------------------------- */

- (BOOL)isProject {
	return self.type == kProjectFileType;
}

/* -----------------------------------------------------------------------------
	For UI: so we can disable the Main Layout checkbox when not valid.
	Args:		--
	Return:	name
----------------------------------------------------------------------------- */

- (BOOL)isLayout {
	return self.type == kLayoutFileType;
}

/* -----------------------------------------------------------------------------
	Return the name for this item.
	It’s the file name -- the URL’s last path component.
	Args:		--
	Return:	name
----------------------------------------------------------------------------- */

- (NSString *)name {
	return self.url.lastPathComponent;
}

- (void)setName:(NSString *)inName {
	if (self.url == nil) {
		// file doesn’t exist: create it
		[self.document saveDocumentWithDelegate:self didSaveSelector:@selector(document:didSave:contextInfo:) contextInfo:NULL];

		/*
		NSSavePanel * chooser = [NSSavePanel savePanel];
		chooser.nameFieldStringValue = inName;
		chooser.allowedFileTypes = [NSArray arrayWithObject:NTXProjectFileType];
		if ([chooser runModal] == NSFileHandlingPanelOKButton) {
			// save image
			if ([tiffData writeToURL:chooser.URL atomically:NO])
		}
		*/
		return;
	}

	NSURL * destination = [self.url.URLByDeletingLastPathComponent URLByAppendingPathComponent:inName];
	// rename file
	// could use -[NSDocument moveToURL:completionHandler:] ? this would replace any existing file
	NSError *__autoreleasing err = nil;
	if ([NSFileManager.defaultManager moveItemAtURL:self.url toURL:destination error:&err]) {
		self.url = destination;
	}
	// should handle error cases: filename is already in use, for example
}

- (void)document:(NSDocument *)document didSave:(BOOL)didSaveSuccessfully contextInfo:(void *)contextInfo {
}


#pragma mark - NSPasteboardWriting support

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)inPasteboard {
	// These are the types we can write.
	NSArray *ourTypes = [NSArray arrayWithObjects:NSPasteboardTypeString, nil];
	// Also include the images on the pasteboard too!
	NSArray *imageTypes = [self.image writableTypesForPasteboard:inPasteboard];
	if (imageTypes)
		ourTypes = [ourTypes arrayByAddingObjectsFromArray:imageTypes];
	return ourTypes;
}


- (NSPasteboardWritingOptions)writingOptionsForType:(NSString *)inType pasteboard:(NSPasteboard *)inPasteboard {
	if ([inType isEqualToString:NSPasteboardTypeString]) {
	  return 0;
	}
	// Everything else is delegated to the image
	if ([self.image respondsToSelector:@selector(writingOptionsForType:inPasteboard:)])
	  return [self.image writingOptionsForType:inType pasteboard:inPasteboard];

	return 0;
}


- (id)pasteboardPropertyListForType:(NSString *)inType {
	if ([inType isEqualToString:NSPasteboardTypeString]) {
		return self.name;
	}
	return [self.image pasteboardPropertyListForType:inType];
}


#pragma mark - NSPasteboardReading support

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)inPasteboard {
	// We allow creation from URLs so Finder items can be dragged to us
	return [NSArray arrayWithObjects:(id)kUTTypeURL, NSPasteboardTypeString, nil];
}


+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)inPasteboard {
	if ([type isEqualToString:NSPasteboardTypeString] || UTTypeConformsTo((__bridge CFStringRef)type, kUTTypeURL)) {
		return NSPasteboardReadingAsString;
	}
	return NSPasteboardReadingAsData;
}


- (id)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)inType {
	// See if an NSURL can be created from this type
	if (UTTypeConformsTo((__bridge CFStringRef)inType, kUTTypeURL)) {
		// It does, so create a URL and use that to initialize our properties
		self = [super init];
		self.url = [[NSURL alloc] initWithPasteboardPropertyList:propertyList ofType:inType];

		// See if the URL was a container; if so, make us marked as a container too
/*		NSNumber *value;
		if ([url getResourceValue:&value forKey:NSURLIsDirectoryKey error:NULL] && [value boolValue])
			self.isContainer = YES;
		else
			self.isContainer = NO;
*/

	} else if ([inType isEqualToString:NSPasteboardTypeString]) {
	  self = [super init];
	  self.name = propertyList;
	} else {
	  NSAssert(NO, @"internal error: type not supported");
	}
	return self;
}

@end


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X P r o j e c t S e t t i n g s I t em
----------------------------------------------------------------------------- */
#import "ProjectDocument.h"

@implementation NTXProjectSettingsItem

- (id)initWithProject:(NTXProjectDocument *)inProject {
	if (self = [super init]) {
		self.url = inProject.fileURL;
		self.type = kProjectFileType;
		_document = (NTXDocument *)inProject;
	}
	return self;
}

- (NSString *)name {
	if (self.url != nil) {
		return self.url.lastPathComponent.stringByDeletingPathExtension;
	}
	return @"Untitled";
}

- (NSImage *)image {
	return [NSImage imageNamed:@"project"];
}

- (BOOL)isContainer {
	return YES;
}

@end

