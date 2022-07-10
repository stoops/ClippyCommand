//
//  AppDelegate.m
//  ClippyCommand
//
//  Created by jon on 2022-07-10.
// this is a test input message

#import "AppDelegate.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSMenu *menuobjc;
@property (strong) IBOutlet NSScrollView *tabview;
@property (strong) IBOutlet NSTableView *cmdslist;
@property (strong) IBOutlet NSTableColumn *cmdscoln;
@property (strong) IBOutlet NSButton *addbutton;
@property (strong) IBOutlet NSButton *expbutton;

@end

@implementation AppDelegate


NSStatusItem *menubar;
NSMutableArray *commands, *buttonsl, *undolist, *historyl;
unsigned long lastedit, lastsave, clickact;
int loopsave;


/* helper */

- (NSButton *)makeButn:(NSRect)frame {
    return [[NSButton alloc] initWithFrame:frame];
}

- (NSTextField *)makeText:(NSRect)frame {
    return [[NSTextField alloc] initWithFrame:frame];
}

- (NSString *)makeKeys:(unsigned char *)lets firstLet:(unsigned char)letr {
    unsigned char leti = 0, maxl = (65 + 25);
    if ((letr <= 64) || (maxl <= letr)) { letr = 65; }
    for (int j = 65; j < maxl; ++j) {
        if (lets[letr] == 0) { leti = letr; break; }
        letr += 1; if (letr >= maxl) { letr = 65; }
    }
    if (leti != 0) {
        lets[leti] = 1;
        return [NSString stringWithFormat:@"%c", leti];
    }
    return @"";
}

- (NSString *)makeVars:(NSString *)strs {
    NSString *vars = @"";
    for (int i = 0; i < [strs length]; ++i) {
        unsigned char letr = tolower([strs characterAtIndex:i]);
        if ((97 <= letr) && (letr <= 122)) {
            vars = [NSString stringWithFormat:@"%@%c", vars, letr];
        }
    }
    if ([vars length] < 1) { vars = @"x"; }
    return vars;
}

- (void)savePref {
    unsigned long edit = lastedit;
    NSUserDefaults *pref = [NSUserDefaults standardUserDefaults];

    if (edit > lastsave) {
        NSLog(@"pref: write");
        [self procMenu];

        [pref setObject:[commands copy] forKey:@"cmds"];
        [pref synchronize];
        lastsave = edit;
    }

    while ([buttonsl count] > [commands count]) {
        [buttonsl removeLastObject];
    }

    for (int i = 0; i < [buttonsl count]; ++i) {
        NSButton *buta = [[buttonsl objectAtIndex:i] objectAtIndex:0];
        NSButton *butb = [[buttonsl objectAtIndex:i] objectAtIndex:1];
        [buta setTag:(i+1)]; [butb setTag:(i+1)];

        NSTextField *txta = [[buttonsl objectAtIndex:i] objectAtIndex:2];
        NSTextField *txtb = [[buttonsl objectAtIndex:i] objectAtIndex:3];
        [txta setTag:(100+(i+1))]; [txtb setTag:(200+(i+1))];
    }

    clickact = 0;
}

- (void)threadFun:(NSArray *)object {
    NSString *stdstr = [object objectAtIndex:0];
    NSPipe *pipeinpt = [object objectAtIndex:1];
    NSFileHandle *fileinpt = pipeinpt.fileHandleForWriting;
    NSData *stdata = [stdstr dataUsingEncoding:NSASCIIStringEncoding];
    [fileinpt writeData:stdata];
    [fileinpt closeFile];
}

- (NSString *)procComd:(NSString *)args stdInput:(NSString *)stdi trimStr:(bool)trim {
    NSPipe *pipeinpt = [NSPipe pipe];
    NSFileHandle *inptxxxx = pipeinpt.fileHandleForReading;
    NSFileHandle *fileinpt = pipeinpt.fileHandleForWriting;

    NSPipe *pipeoutp = [NSPipe pipe];
    NSFileHandle *fileoutp = pipeoutp.fileHandleForReading;
    NSFileHandle *outpxxxx = pipeoutp.fileHandleForWriting;

    NSMutableDictionary<NSString *,NSString *> *venv = [NSMutableDictionary dictionaryWithCapacity:0];
    for (int i = 0; i < [commands count]; ++i) {
        NSArray *item = [commands objectAtIndex:i];
        NSString *cmdn = [self makeVars:[item objectAtIndex:0]];
        [venv setObject:[item objectAtIndex:1] forKey:cmdn];
    }

    NSLog(@"task: [%@]", args);

    NSTask *task = [[NSTask alloc] init];
    task.environment = venv;
    task.launchPath = @"/bin/bash";
    task.arguments = @[@"-c", args];
    task.standardInput = pipeinpt;
    task.standardOutput = pipeoutp;

    NSThread *threadobj = [[NSThread alloc] initWithTarget:self selector:@selector(threadFun:) object:@[stdi, pipeinpt]];
    [threadobj start];

    [task launch];

    NSData *stdo = [fileoutp readDataToEndOfFile];
    [fileoutp closeFile]; [outpxxxx closeFile];
    [fileinpt closeFile]; [inptxxxx closeFile];

    NSString *outp = [[NSString alloc] initWithBytes:[stdo bytes] length:[stdo length] encoding:NSASCIIStringEncoding];
    if (trim) {
        outp = [outp stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    return outp;
}

- (int)procClip:(long)indx mode:(int)mode {
    NSPasteboard *pb = [[NSPasteboard generalPasteboard] init];
    NSArray *pa = [pb pasteboardItems];

    for (int i = 0; i < [pa count]; ++i) {
        NSPasteboardItem *pi = [pa objectAtIndex:i];
        NSArray *pl = [pi types];

        for (int j = 0; j < [pl count]; ++j) {
            NSPasteboardType pt = [pl objectAtIndex:j];
            NSString *nstr = pt;

            if ([nstr containsString:@"utf8"]) {
                NSData *ndat = [pb dataForType:pt];
                NSString *pz = [[NSString alloc] initWithBytes:[ndat bytes] length:[ndat length] encoding:NSASCIIStringEncoding];

                if (pz && (pz.length > 0)) {
                    //NSLog(@"buffer: [%@] [%@]", pt, pz);

                    if (mode == 0) {
                        if (([commands count] <= 0) || (indx >= [commands count])) { return 2; }

                        NSString *cl = [[commands objectAtIndex:indx] objectAtIndex:1];
                        NSString *rp = [self procComd:cl stdInput:pz trimStr:YES];
                        if (rp && (rp.length > 0)) {
                            if ([undolist count] < 5) { [undolist addObject:pz]; }
                            [pb clearContents];
                            [pb writeObjects:@[rp]];
                        }
                    } else if (mode == 1) {
                        if (pz.length <= 999) {
                            int f = -1;
                            for (int j = 0; (f == -1) && (j < [historyl count]); ++j) {
                                NSString *hp = [historyl objectAtIndex:j];
                                if ([hp isEqualToString:pz]) { f = (j + 1); }
                            }
                            if ((f == -1) || (f > 0)) {
                                int maxl = 15;
                                if (f > 0) { [historyl removeObjectAtIndex:f-1]; }
                                [historyl insertObject:pz atIndex:0];
                                while ([historyl count] > maxl) {
                                    [historyl removeLastObject];
                                }
                                [self procMenu];
                            }
                        }
                    } else if (mode == 2) {
                        if ((-1 < indx) && (indx < [historyl count])) {
                            NSString *hp = [historyl objectAtIndex:indx];
                            [pb clearContents];
                            [pb writeObjects:@[hp]];
                        }
                    }
                }

                return 0;
            }
        }
    }

    return 1;
}

- (void)procMenu {
    long nums = [menubar.button.menu numberOfItems], leng = ([commands count] + 1);
    unsigned char lets[128];

    while (nums < leng) {
        NSMenuItem *item = [[NSMenuItem alloc] init];
        [item setKeyEquivalent:@""];
        [item setTag:0x31337]; [item setTitle:@"..."];
        [item setTarget:self]; [item setAction:@selector(menuItem:)];
        [menubar.button.menu addItem:item];
        nums += 1;
    }
    while (nums > leng) {
        [menubar.button.menu removeItemAtIndex:(nums-1)];
        nums -= 1;
    }

    bzero(lets, 128); lets['Z'] = 1;
    for (int i = 0; i < [commands count]; ++i) {
        NSArray *info = [commands objectAtIndex:i];
        if ([info count] < 1) { continue; }
        NSString *name = [info objectAtIndex:0];
        if ([name length] < 1) { continue; }

        unsigned char letr = [[name uppercaseString] characterAtIndex:0];
        NSMenuItem *item = [menubar.button.menu itemAtIndex:i];
        [item setTag:(i+1)]; [item setTitle:name];
        [item setAction:@selector(menuItem:)];
        [item setKeyEquivalent:[self makeKeys:lets firstLet:letr]];
    }

    NSMenuItem *undo = [menubar.button.menu itemAtIndex:(leng-1)];
    [undo setTag:0]; [undo setTitle:@"Undo"];
    [undo setAction:@selector(menuUndo:)];
    [undo setKeyEquivalent:[NSString stringWithFormat:@"Z"]];

    NSDictionary *atrs = @{
        NSFontAttributeName:[NSFont fontWithName:@"Monaco" size:11.0]
    };
    NSMutableString *sets = [NSMutableString string];
    for (int i = 32; i < 127; i++) {
        [sets appendFormat:@"%c", i];
    }
    NSCharacterSet *invr = [[NSCharacterSet characterSetWithCharactersInString:sets] invertedSet];

    int maxl = 50;
    NSMenu *hist = [[NSMenu alloc] init];
    for (int i = 0; i < [historyl count]; ++i) {
        NSString *hisi = [historyl objectAtIndex:i];
        NSString *hisf = [NSString stringWithFormat:@"%@", hisi];
        hisf = [hisf stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        hisf = [hisf stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"];
        hisf = [[hisf componentsSeparatedByCharactersInSet:invr] componentsJoinedByString:@""];
        NSInteger newl = ([[hisi componentsSeparatedByString:@"\n"] count] - 1);
        NSString *ends = [NSString stringWithFormat:@" [%d:%d]", (int)newl, (int)hisi.length];
        int endl = (int)ends.length;
        int difl = (maxl - endl);
        NSString *limi = (hisf.length > difl) ? [hisf substringToIndex:difl] : hisf;
        NSString *dots = (hisf.length > difl) ? @"..." : @"   ";
        while (limi.length < difl) {
            limi = [NSString stringWithFormat:@"%@ ", limi];
        }
        NSString *mstr = [NSString stringWithFormat:@"%@%@%@", limi, dots, ends];
        NSAttributedString *attr = [[NSAttributedString alloc] initWithString:mstr attributes:atrs];
        NSMenuItem *item = [[NSMenuItem alloc] init];
        [item setTag:(i+1)]; [item setAttributedTitle:attr];
        [item setTarget:self]; [item setAction:@selector(histItem:)];
        [hist addItem:item];
    }
    NSMenuItem *subm = [[NSMenuItem alloc] init];
    [subm setTag:0x31337]; [subm setTitle:@"Last"];
    [menubar.button.menu addItem:subm];
    [menubar.button.menu setSubmenu:hist forItem:subm];
}


/* delegate */

- (void)timeLoop:(NSTimer *)timeObjc {
    NSDate *date = [NSDate date];
    NSTimeInterval ints = [date timeIntervalSince1970];
    int secs = (int)ints;
    if ((secs - loopsave) >= 5) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self savePref];
        });
        loopsave = secs;
    }
    [self procClip:0 mode:1];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSUserDefaults *pref = [NSUserDefaults standardUserDefaults];
    NSArray *cmds = [pref arrayForKey:@"cmds"];
    if (!cmds) {
        cmds = @[@[@"Grep Sed", @"grep -i 'test' | sed -e 's/test input/diff output/g'"]];
        [pref setObject:cmds forKey:@"cmds"];
        [pref synchronize];
    }
    commands = [cmds mutableCopy];

    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSString *file = [NSString stringWithFormat:@"%@/Contents/Resources/data/clippyb.png", path];
    NSImage *mimg = [[NSImage alloc] initWithContentsOfFile:file];
    [mimg setTemplate:YES];

    menubar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    menubar.button.image = mimg;
    menubar.button.menu = self.menuobjc;
    [menubar.button setAction:@selector(menuBar:)];
    [menubar.button.menu removeAllItems];

    lastedit = 0; lastsave = 0; clickact = 0;
    buttonsl = [NSMutableArray arrayWithArray:@[]];
    undolist = [NSMutableArray arrayWithArray:@[]];
    historyl = [NSMutableArray arrayWithArray:@[]];

    [self.addbutton setAction:@selector(addRow:)];
    [self.expbutton setAction:@selector(export:)];

    [self procMenu];
    [self.cmdslist reloadData];
    [self windowDidResize:nil];
    [self.window orderOut:self];

    loopsave = 0;
    [self timeLoop:nil];
    [NSTimer scheduledTimerWithTimeInterval:1.75 target:self selector:@selector(timeLoop:) userInfo:nil repeats:YES];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)flag {
    if (clickact == 0) {
        clickact += 1;
    } else {
        [self.window makeKeyAndOrderFront:self];
        [self windowDidResize:nil];
    }
    return NO;
}

- (void)windowDidResize:(NSNotification *)aNotification {
    float wide = self.window.frame.size.width;
    float high = self.window.frame.size.height;
    NSSize wind = CGSizeMake(wide - 40, high - 120);

    [self.tabview setFrameOrigin:CGPointMake(20, 20)];
    [self.tabview setFrameSize:wind];
    [self.cmdscoln setWidth:((wide - 200) - 120)];

    for (int x = 0; x < [buttonsl count]; ++x) {
        NSTextField *text = [[buttonsl objectAtIndex:x] objectAtIndex:3];
        [text setFrameSize:NSMakeSize(self.cmdscoln.width - 20, 21 + 1)];
    }
}


/* callback */

- (void)menuBar:(NSNotification *)aNotification {
    CGFloat offs = 8;
    CGPoint posi = menubar.button.window.frame.origin;
    [menubar.button.menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(posi.x, posi.y-offs) inView:nil];
}

- (void)menuItem:(NSNotification *)aNotification {
    NSMenuItem *item = (NSMenuItem *)aNotification;
    long indx = [item tag];
    if (indx > 0) { indx = (indx - 1); }
    [self procClip:indx mode:0];
}

- (void)histItem:(NSNotification *)aNotification {
    NSMenuItem *item = (NSMenuItem *)aNotification;
    long indx = [item tag];
    if (indx > 0) { indx = (indx - 1); }
    [self procClip:indx mode:2];
}

- (void)menuUndo:(NSNotification *)aNotification {
    if ([undolist count] > 0) {
        NSString *ub = [undolist lastObject];
        NSPasteboard *pb = [[NSPasteboard generalPasteboard] init];
        [pb clearContents];
        [pb writeObjects:@[ub]];
        [undolist removeLastObject];
    }
}

- (void)export:(NSNotification *)aNotification {
    NSString *o = @"";
    for (int x = 0; x < [commands count]; ++x) {
        NSArray *i = [commands objectAtIndex:x];
        o = [NSString stringWithFormat:@"%@\n%@\n%@\n", o, [i objectAtIndex:0], [i objectAtIndex:1]];
    }
    if (o && ([o length] > 0)) {
        NSPasteboard *pb = [[NSPasteboard generalPasteboard] init];
        [pb clearContents];
        [pb writeObjects:@[o]];
    }
}


/* NSTableViewDelegate */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [commands count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *identifier = tableColumn.identifier;
    NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:self];
    NSArray *cmdi = nil;

    NSLog(@"add row:%ld col:%@ num:%lu", row, identifier, [[cell subviews] count]);
    cell.textField.stringValue = @"";

    while ([[cell subviews] count] > 0) {
        [[[cell subviews] lastObject] removeFromSuperview];
    }

    while (row >= [buttonsl count]) {
        NSButton *buta = [self makeButn:NSMakeRect(0, 5, 40, 30)];
        NSButton *butb = [self makeButn:NSMakeRect(30, 5, 40, 30)];
        NSTextField *txta = [self makeText:NSMakeRect(0, 9, 200, 22)];
        NSTextField *txtb = [self makeText:NSMakeRect(0, 9, 800, 22)];
        [buttonsl addObject:@[buta, butb, txta, txtb]];
    }

    if (row < [commands count]) {
        cmdi = [commands objectAtIndex:row];
    }

    if (cmdi == nil) {
        NSLog(@"load: row [%ld] >= [%lu]", row, [commands count]);
        return cell;
    }

    if ([identifier containsString:@".0"]) {
        NSButton *buta = [[buttonsl objectAtIndex:row] objectAtIndex:0];
        [buta setTitle:@"x"];
        [buta setButtonType:NSButtonTypeMomentaryLight];
        [buta setBezelStyle:NSBezelStyleRounded];
        [buta setTag:(row+1)];
        [buta setAction:@selector(delRow:)];
        [cell addSubview:buta];

        NSButton *butb = [[buttonsl objectAtIndex:row] objectAtIndex:1];
        [butb setTitle:@"+"];
        [butb setButtonType:NSButtonTypeMomentaryLight];
        [butb setBezelStyle:NSBezelStyleRounded];
        [butb setTag:(row+1)];
        [butb setAction:@selector(addRow:)];
        [cell addSubview:butb];
    }

    else if ([identifier containsString:@".1"]) {
        NSTextField *txta = [[buttonsl objectAtIndex:row] objectAtIndex:2];
        [txta setStringValue:[cmdi objectAtIndex:0]];
        [txta setTag:(100+(row+1))];
        [txta setDelegate:self];
        [txta setFocusRingType:NSFocusRingTypeNone];
        [cell addSubview:txta];
    }

    else {
        NSTextField *txtb = [[buttonsl objectAtIndex:row] objectAtIndex:3];
        [txtb setStringValue:[cmdi objectAtIndex:1]];
        [txtb setTag:(200+(row+1))];
        [txtb setDelegate:self];
        [txtb setFocusRingType:NSFocusRingTypeNone];
        [txtb setFont:[NSFont fontWithName:@"Menlo" size:12]];
        [cell addSubview:txtb];
    }

    return cell;
}

- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    for (int i = 0; i < [rowView numberOfColumns]; ++i) {
        NSTableCellView *cell = [rowView viewAtColumn:i];
        NSLog(@"del row:%ld col:%d num:%lu", row, i, [[cell subviews] count]);
        while ([[cell subviews] count] > 0) {
            [[[cell subviews] lastObject] removeFromSuperview];
        }
    }
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    return NO;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    CGFloat height = 40;
    return height;
}

- (void)delRow:(NSNotification *)aNotification {
    NSButton *butn = (NSButton *)aNotification;
    long idx = [butn tag];
    if (idx > 0) { idx = (idx - 1); }
    if (idx < [commands count]) {
        [commands removeObjectAtIndex:idx];
        [self.cmdslist reloadData];
        lastedit += 1;
    }
}

- (void)addRow:(NSNotification *)aNotification {
    NSButton *butn = (NSButton *)aNotification;
    long idx = [butn tag];
    if ([commands count] < 21) {
        if ((idx <= 0) || ([commands count] <= idx)) {
            [commands addObject:@[@"", @""]];
        }
        else {
            [commands insertObject:@[@"", @""] atIndex:idx];
        }
        [self.cmdslist reloadData];
    }
}


/* NSTextFieldDelegate */

- (void)controlTextDidChange:(NSNotification *)aNotification {
    NSTextField *textField = [aNotification object];

    long tagn = [textField tag];
    long indx = (tagn % 100); if (indx > 0) { indx = (indx - 1); }
    long item = (tagn / 100); if (item > 0) { item = (item - 1); }

    if ((indx < [commands count]) && (item < [[commands objectAtIndex:indx] count])) {
        NSMutableArray *edit = [[commands objectAtIndex:indx] mutableCopy];
        [edit replaceObjectAtIndex:item withObject:[textField stringValue]];
        [commands replaceObjectAtIndex:indx withObject:edit];
        lastedit += 1;
    }
}


@end
