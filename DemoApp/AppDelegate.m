//
//  AppDelegate.m
//  DemoApp
//
//  Created by Wolfgang Baird on 1/30/21.
//  Copyright © 2021 Wolfgang Baird. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
//    [SIPKit ABI_setEnabled:false];
    
    [SIPKit showMasterWaringinWindow:_window];
    
//    [SIPKit ABI_showWaringinWindow:_window];
//    [SIPKit SIP_showWaringinWindow:_window];
//    [SIPKit AMFI_showWaringinWindow:_window];
//    system("osascript -e 'tell application \"Finder\" to restart'");
    
//    [SIPKit getAuth];
//    [SIPKit getAuth];
//    [SIPKit getAuth];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
