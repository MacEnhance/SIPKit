//
//  SIPKit.m
//  SIPKit
//
//  Created by Wolfgang Baird on 4/20/20.
//  Copyright © 2020 Wolfgang Baird. All rights reserved.
//

#import "STPrivilegedTask.h"
#import "SIPKit.h"

#include <mach-o/arch.h>

//  SYSTEM INTEGRITY PROTECTION RELATED
//  https://github.com/JayBrown/csrstat-NG

typedef uint32_t csr_config_t;
csr_config_t config = 0;

/* Rootless configuration flags */
#define CSR_ALLOW_UNTRUSTED_KEXTS               (1 << 0)    // 1
#define CSR_ALLOW_UNRESTRICTED_FS               (1 << 1)    // 2
#define CSR_ALLOW_TASK_FOR_PID                  (1 << 2)    // 4
#define CSR_ALLOW_KERNEL_DEBUGGER               (1 << 3)    // 8
#define CSR_ALLOW_APPLE_INTERNAL                (1 << 4)    // 16
#define CSR_ALLOW_UNRESTRICTED_DTRACE           (1 << 5)    // 32
#define CSR_ALLOW_UNRESTRICTED_NVRAM            (1 << 6)    // 64
#define CSR_ALLOW_DEVICE_CONFIGURATION          (1 << 7)    // 128
#define CSR_ALLOW_ANY_RECOVERY_OS               (1 << 8)    // 256
#define CSR_ALLOW_UNAPPROVED_KEXTS              (1 << 9)    // 512
#define CSR_ALLOW_EXECUTABLE_POLICY_OVERRIDE    (1 << 10)   // 1024

#define CSR_VALID_FLAGS (CSR_ALLOW_UNTRUSTED_KEXTS | \
    CSR_ALLOW_UNRESTRICTED_FS | \
    CSR_ALLOW_TASK_FOR_PID | \
    CSR_ALLOW_KERNEL_DEBUGGER | \
    CSR_ALLOW_APPLE_INTERNAL | \
    CSR_ALLOW_UNRESTRICTED_DTRACE | \
    CSR_ALLOW_UNRESTRICTED_NVRAM  | \
    CSR_ALLOW_DEVICE_CONFIGURATION | \
    CSR_ALLOW_ANY_RECOVERY_OS | \
    CSR_ALLOW_UNAPPROVED_KEXTS | \
    CSR_ALLOW_EXECUTABLE_POLICY_OVERRIDE)

extern int csr_check(csr_config_t mask) __attribute__((weak_import));
extern int csr_get_active_config(csr_config_t* config) __attribute__((weak_import));

bool _csr_check(int aMask, bool aFlipflag) {
    if (!csr_check)
        return (aFlipflag) ? 0 : 1; // return "UNRESTRICTED" when on old macOS version
    bool bit = (config & aMask);
    return bit;
}

// END SYSTEM INTEGRITY PROTECTION RELATED

static AuthorizationRef authorizationRef = NULL;

@implementation SIPKit

NSString *const MFAMFIWarningKey = @"MF_AMFIShowWarning";

+ (SIPKit*)kit {
    static SIPKit* share = nil;
    if (share == nil) {
        share = SIPKit.new;
    }
    return share;
}

+ (Boolean)runSTPrivilegedTask:(NSString*)launchPath :(NSArray*)args {
    STPrivilegedTask *privilegedTask = [[STPrivilegedTask alloc] init];
    NSMutableArray *components = [args mutableCopy];
    [privilegedTask setLaunchPath:launchPath];
    [privilegedTask setArguments:components];
    [privilegedTask setCurrentDirectoryPath:[[NSBundle mainBundle] resourcePath]];
    Boolean result = false;
    OSStatus err = [privilegedTask launch];
    if (err != errAuthorizationSuccess) {
        if (err == errAuthorizationCanceled) {
            NSLog(@"User cancelled");
        }  else {
            NSLog(@"Something went wrong: %d", (int)err);
        }
    } else {
        result = true;
    }
    return result;
}

+ (NSString*)runScript:(NSString*)script {
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/zsh";
    task.arguments = @[@"-c", script];
    task.standardOutput = pipe;
    [task launch];
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    return output;
}

+ (void)getAuth {
    AuthorizationItemSet *info;
    OSStatus status = AuthorizationCopyInfo(authorizationRef, kAuthorizationRightExecute, &info);
    if (status == errAuthorizationSuccess) {
        NSLog(@"Bing bong");
    } else {
        status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
        if (status != errAuthorizationSuccess) {
            NSLog(@"Failed to create AuthorizationRef, return code %ld", (long)status);
        }

        AuthorizationItem right = { kAuthorizationRightExecute, 0, NULL, 0 };
        AuthorizationRights rights = {1, &right};
        AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed |
        kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
      
        status = AuthorizationCopyRights(authorizationRef, &rights, NULL, flags, NULL);
        if (status != errAuthorizationSuccess) {
            NSLog(@"Auth Rights Unsuccessful: %d", status);
        } else {
            NSLog(@"We're authorized: %d", status);
        }
    }
}

+ (BOOL)isARM {
    const NXArchInfo *info = NXGetLocalArchInfo();
    NSString *typeOfCpu = [NSString stringWithUTF8String:info->description];
    BOOL isARM = false;
    if ([typeOfCpu containsString:@"ARM64"]) isARM = true;
    return isARM;
}

+ (void)reboot {
    // Alternate method
//    system("osascript -e 'tell application \"Finder\" to restart'");
    
    // Reboot via terminal
    [SIPKit getAuth];
    [STPrivilegedTask launchedPrivilegedTaskWithLaunchPath:@"/sbin/reboot"
                                                 arguments:@[]
                                          currentDirectory:[[NSBundle mainBundle] resourcePath]
                                             authorization:authorizationRef];
}

+ (Boolean)NVRAM_arg_present:(NSString*)arg {
    Boolean present = false;
    NSString *result = [SIPKit runScript:@"nvram boot-args 2>&1"];
    if ([result rangeOfString:arg].length > 0) present = true;
    return present;
}

+ (Boolean)toggleBootArg:(NSString*)arg {
    NSString *newBootArgs = [SIPKit runScript:@"nvram boot-args"];
    NSString *argEnabled = [arg stringByAppendingString:@"=1"];
    
    // Remove cs_enforcement_disable=1
    if ([newBootArgs containsString:argEnabled]) {
        newBootArgs = [newBootArgs stringByReplacingOccurrencesOfString:argEnabled withString:@""];
    } else {
    // Add cs_enforcement_disable=1
        newBootArgs = [newBootArgs stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        newBootArgs = [newBootArgs stringByAppendingFormat:@" %@", argEnabled];
    }
    
    newBootArgs = [newBootArgs stringByReplacingOccurrencesOfString:@"boot-args" withString:@""];
    newBootArgs = [newBootArgs stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    newBootArgs = [newBootArgs stringByReplacingOccurrencesOfString: @"[ \t]+"
                                                         withString: @" "
                                                            options: NSRegularExpressionSearch
                                                              range: NSMakeRange(0, newBootArgs.length)];
    
    newBootArgs = [NSString stringWithFormat:@"boot-args=%@", newBootArgs];
    [SIPKit runSTPrivilegedTask:@"/usr/sbin/nvram" :@[newBootArgs]];
    return !([newBootArgs rangeOfString:argEnabled].length);
}

/* ------------------ Wanring Windows ------------------ */

- (CGFloat)heightForAttributedString:(NSAttributedString *)text maxWidth:(CGFloat)maxWidth {
    if ([text isKindOfClass:[NSString class]] && !text.length) {
        // no text means no height
        return 0;
    }
    
    NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading;
    CGSize size = [text boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX) options:options context:nil].size;

    CGFloat height = ceilf(size.height) + 1; // add 1 point as padding
    
    return height;
}

- (CGFloat)heightForString:(NSString *)text font:(NSFont *)font maxWidth:(CGFloat)maxWidth {
    if (![text isKindOfClass:[NSString class]] || !text.length) {
        // no text means no height
        return 0;
    }
    
    NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading;
    NSDictionary *attributes = @{ NSFontAttributeName : font };
    CGSize size = [text boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX) options:options attributes:attributes context:nil].size;
    CGFloat height = ceilf(size.height) + 1; // add 1 point as padding
    
    return height;
}

+ (void)SIPKit_showWaringinWindow:(NSWindow*)window
                         withText:(NSString*)file
                        withVideo:(Boolean)video
                            reply:(void (^)(NSUInteger response))callback {
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Reboot"];
    [alert addButtonWithTitle:@"Quit"];

    NSError *err;
    NSString *app = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (app == nil) app = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    if (app == nil) app = @"macOS Plugin Framework";
    NSString *sipFile = file;
    NSString *text = [NSString stringWithContentsOfURL:[[NSBundle bundleForClass:[SIPKit class]]
                                                        URLForResource:sipFile withExtension:@""]
                                              encoding:NSUTF8StringEncoding
                                                 error:&err];
    text = [text stringByReplacingOccurrencesOfString:@"<appname>" withString:app];
    
    int viewHeight = 0;
    int originY = 0;
    int originX = 0;
    NSView *customView = [NSView.alloc initWithFrame:NSMakeRect(0, 0, 400, 0)];

    if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 11)
        originX = 20;
    
    if (video) {
        AVPlayerView *avpv = [AVPlayerView.alloc initWithFrame:NSMakeRect(originX, originY, 360, 240)];
        [avpv setControlsStyle:AVPlayerViewControlsStyleMinimal];
        NSURL* url = [[NSBundle bundleForClass:[SIPKit class]] URLForResource:@"sipvid" withExtension:@"mp4"];
        AVURLAsset *asset = [AVURLAsset assetWithURL: url];
        AVPlayerItem *item = [AVPlayerItem playerItemWithAsset: asset];
        AVPlayer *avp = [[AVPlayer alloc] initWithPlayerItem: item];
        avpv.player = avp;
        [avp play];
        viewHeight = 240;
        originY += 240;
        [customView addSubview:avpv];
    }
    
    NSTextField *warning = NSTextField.new;//[NSTextField.alloc initWithFrame:NSMakeRect(18, origin, 364, 1000)];
    [warning setStringValue:text];
    CGFloat minHeight = [((NSTextFieldCell *)[warning cell]) cellSizeForBounds:NSMakeRect(0, 0, 364, FLT_MAX)].height;
    [warning setFrame:NSMakeRect(originX, originY, 364, minHeight)];
    [warning setSelectable:false];
    [warning setDrawsBackground:false];
    [warning setBordered:false];
    viewHeight += minHeight;
    originY += minHeight;
    [customView addSubview:warning];
 
    [customView setFrame:NSMakeRect(0, 0, 400, viewHeight)];
    [alert setMessageText:@"Problem Detected"];
    [alert setAccessoryView:customView];
    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        callback(returnCode);
    }];
}

+ (void)showMasterWaringinWindow:(NSWindow *)window reply:(void (^)(NSUInteger))callback {
    NSString *windowType = @"";
    BOOL showVideo = false;
    
    // First check for SIP
    if ([SIPKit SIP_enabled]) {
        windowType = @"eng";
        showVideo = true;
    } else if (![SIPKit AMFI_isEnabled]) {
        windowType = @"eng_amfi";
    } else if ([SIPKit isARM]) {
        if ([SIPKit ABI_isEnabled])
            windowType = @"eng_abi";
    }
    
    if (windowType.length > 0) {
        [SIPKit SIPKit_showWaringinWindow:window withText:windowType withVideo:showVideo reply:^(NSUInteger response) {
            callback(response);
        }];
    }
}

+ (void)showMasterWaringinWindow:(NSWindow *)window {
    NSString *windowType = @"";
    BOOL showVideo = false;
    
    
    // First check for SIP
    if ([SIPKit SIP_enabled]) {
        windowType = @"eng";
        showVideo = true;
    } else if (![SIPKit AMFI_isEnabled]) {
        windowType = @"eng_amfi";
    } else if ([SIPKit isARM]) {
        if ([SIPKit ABI_isEnabled])
            windowType = @"eng_abi";
    }
    
    if (windowType.length > 0) {
        [SIPKit SIPKit_showWaringinWindow:window withText:windowType withVideo:showVideo reply:^(NSUInteger response) {
            if (response == 1001) {
                [NSApp terminate:nil];
            } else {
                if ([windowType isEqualToString:@"eng"]) {
                    [SIPKit SIP_disableWithReboot:true];
                }
                    
                if ([windowType isEqualToString:@"eng_abi"]) {
                    [SIPKit ABI_setEnabled:false];
                    [SIPKit reboot];
                }
                
                if ([windowType isEqualToString:@"eng_amfi"]) {
                    [SIPKit AMFI_NUKE];
                    [SIPKit reboot];
                }
            }
        }];
    }
}

+ (void)SIP_showWaringinWindow:(NSWindow*)window reply:(void (^)(NSUInteger response))callback {
    [SIPKit SIPKit_showWaringinWindow:window withText:@"eng" withVideo:true reply:^(NSUInteger response) {
        callback(response);
    }];
}

+ (void)SIP_showWaringinWindow:(NSWindow*)window {
    [SIPKit SIPKit_showWaringinWindow:window withText:@"eng" withVideo:true reply:^(NSUInteger response) {
        if (response == 1001) {
            [NSApp terminate:nil];
        } else {
            [SIPKit SIP_disableWithReboot:true];
        }
    }];
}

+ (void)AMFI_showWaringinWindow:(NSWindow *)window {
    [SIPKit SIPKit_showWaringinWindow:window withText:@"eng_amfi" withVideo:false reply:^(NSUInteger response) {
        if (response == 1001) {
            [NSApp terminate:nil];
        } else {
            [SIPKit AMFI_NUKE];
            [SIPKit reboot];
        }
    }];
}

+ (void)AMFI_showWaringinWindow:(NSWindow *)window reply:(void (^)(NSUInteger))callback {
    [SIPKit SIPKit_showWaringinWindow:window withText:@"eng_amfi" withVideo:false reply:^(NSUInteger response) {
        callback(response);
    }];
}

+ (void)ABI_showWaringinWindow:(NSWindow *)window {
    [SIPKit SIPKit_showWaringinWindow:window withText:@"eng_abi" withVideo:false reply:^(NSUInteger response) {
        if (response == 1001) {
            [NSApp terminate:nil];
        } else {
            [SIPKit ABI_setEnabled:false];
            [SIPKit reboot];
        }
    }];
}

+ (void)ABI_showWaringinWindow:(NSWindow *)window reply:(void (^)(NSUInteger))callback {
    [SIPKit SIPKit_showWaringinWindow:window withText:@"eng_abi" withVideo:false reply:^(NSUInteger response) {
        callback(response);
    }];
}

/* ------------------ SIP ------------------ */

+ (void)setRecoveryBoot {
    [SIPKit getAuth];
    
    if ([SIPKit isARM]) {
        // ARM has no internet recovery
        [STPrivilegedTask launchedPrivilegedTaskWithLaunchPath:@"/usr/sbin/nvram"
                                                     arguments:@[@"recovery-boot-mode=unused"]
                                              currentDirectory:[[NSBundle mainBundle] resourcePath]
                                                 authorization:authorizationRef];
    } else {
        // For Intel use internet recovery because it's possible the user has no local recovery
        [STPrivilegedTask launchedPrivilegedTaskWithLaunchPath:@"/usr/sbin/nvram"
                                                     arguments:@[@"internet-recovery-mode=RecoveryModeDisk"]
                                              currentDirectory:[[NSBundle mainBundle] resourcePath]
                                                 authorization:authorizationRef];
    }
}

+ (void)SIP_enableWithReboot:(Boolean)reboot {
    [SIPKit getAuth];
    [STPrivilegedTask launchedPrivilegedTaskWithLaunchPath:@"/usr/bin/csrutil"
                                                 arguments:@[@"clear"]
                                          currentDirectory:[[NSBundle mainBundle] resourcePath]
                                             authorization:authorizationRef];
    
    if (reboot)
        [SIPKit reboot];
}

+ (void)SIP_disableWithReboot:(Boolean)reboot {
    [SIPKit getAuth];
    [STPrivilegedTask launchedPrivilegedTaskWithLaunchPath:@"/usr/bin/defaults"
                                                 arguments:@[@"write", @"/Library/Preferences/com.apple.security.libraryvalidation.plist", @"DisableLibraryValidation", @"-bool", @"true"]
                                          currentDirectory:[[NSBundle mainBundle] resourcePath]
                                             authorization:authorizationRef];
    if (reboot) {
        [SIPKit setRecoveryBoot];
        [SIPKit reboot];
    }
}

+ (Boolean)SIP_enabled {
    csr_get_active_config(&config);
    // SIP fully disabled
    if (!_csr_check(CSR_ALLOW_APPLE_INTERNAL, 0) &&
        _csr_check(CSR_ALLOW_UNTRUSTED_KEXTS, 1) &&
        _csr_check(CSR_ALLOW_TASK_FOR_PID, 1) &&
        _csr_check(CSR_ALLOW_UNRESTRICTED_FS, 1) &&
        _csr_check(CSR_ALLOW_UNRESTRICTED_NVRAM, 1) &&
        !_csr_check(CSR_ALLOW_DEVICE_CONFIGURATION, 0)) {
        return false;
    }
    // SIP is at least partially or fully enabled
    return true;
}

+ (Boolean)SIP_HasRequiredFlags {
    csr_get_active_config(&config);
    // These are the two flags required for code injection to work
    return (_csr_check(CSR_ALLOW_UNRESTRICTED_FS, 1) && _csr_check(CSR_ALLOW_TASK_FOR_PID, 1));
}

+ (Boolean)SIP_NVRAM {
    csr_get_active_config(&config);
    BOOL allowsNVRAM = _csr_check(CSR_ALLOW_UNRESTRICTED_NVRAM, 1);
    return !allowsNVRAM;
}

+ (Boolean)SIP_TASK_FOR_PID {
    csr_get_active_config(&config);
    BOOL allowsTFPID = _csr_check(CSR_ALLOW_TASK_FOR_PID, 1);
    return !allowsTFPID;
}

+ (Boolean)SIP_Filesystem {
    csr_get_active_config(&config);
    BOOL allowsFS = _csr_check(CSR_ALLOW_UNRESTRICTED_FS, 1);
    return !allowsFS;
}

/* ------------------ ABI ------------------ */

+ (Boolean)ABI_isEnabled {
    return ![SIPKit NVRAM_arg_present:@"-arm64e_preview_abi"];
}

+ (Boolean)ABI_setEnabled:(BOOL)state {
    NSString *abiStr = @"-arm64e_preview_abi";
    NSString *nvram = [SIPKit runScript:@"nvram boot-args 2>&1"];
    nvram = [nvram stringByReplacingOccurrencesOfString:@"boot-args" withString:@""];
    nvram = [nvram stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *newram = nvram;
    // error fetching gives iokit/common error
    if ([nvram containsString:@"iokit/common"])
        newram = @"";
    BOOL hasVar = [nvram containsString:abiStr];
    if (state) {
        if (hasVar)
            newram = [newram stringByReplacingOccurrencesOfString:abiStr withString:@""];
    } else {
        if (!hasVar)
            newram = [newram stringByAppendingString:@" -arm64e_preview_abi"];
    }
    if (![newram isEqualToString:nvram]) {
        newram = [NSString stringWithFormat:@"boot-args=%@", newram];
        NSLog(@"%@", newram);
        [SIPKit getAuth];
        [STPrivilegedTask launchedPrivilegedTaskWithLaunchPath:@"/usr/sbin/nvram"
                                                     arguments:@[newram]
                                              currentDirectory:[[NSBundle mainBundle] resourcePath]
                                                 authorization:authorizationRef];
    }
    return true;
}

/* ------------------ Library Validation ------------------ */

+ (void)showAMFIWarning:(NSWindow*)inWindow {
    NSError *err;
    NSString *app = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (app == nil) app = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    if (app == nil) app = @"macOS Plugin Framework";
    NSString *sipFile = @"eng_amfi";
    NSString *text = [NSString stringWithContentsOfURL:[[NSBundle bundleForClass:[self class]]
                                                        URLForResource:sipFile withExtension:@"txt"]
                                              encoding:NSUTF8StringEncoding
                                                 error:&err];
    
    text = [text stringByReplacingOccurrencesOfString:@"<appname>" withString:app];
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Apple Mobile File Integrity Warning!"];
    [alert setInformativeText:text];
    [alert addButtonWithTitle:@"Okay"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert setShowsSuppressionButton:true];
    alert.suppressionButton.title = @"Don't show this again";
    if (inWindow != nil) {
        [alert beginSheetModalForWindow:inWindow completionHandler:^(NSModalResponse returnCode) {
            if (alert.suppressionButton.state == NSControlStateValueOn) [SIPKit AMFI_setShowAMFIWarning:false];
            if (returnCode == NSAlertSecondButtonReturn) {
                return;
            } else {
                [SIPKit AMFI_NUKE_NOCHECK];
            }
        }];
    } else {
        NSModalResponse res = alert.runModal;
        if (alert.suppressionButton.state == NSControlStateValueOn) [SIPKit AMFI_setShowAMFIWarning:false];
        if (res == NSAlertSecondButtonReturn) {
            return;
        } else {
            [SIPKit AMFI_NUKE_NOCHECK];
        }
    }
}

+ (void)AMFI_setShowAMFIWarning:(Boolean)shouldWarn {
    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:shouldWarn] forKey:MFAMFIWarningKey];
}

+ (Boolean)AMFI_shouldShowWarning {
    Boolean result = true;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d valueForKey:MFAMFIWarningKey])
        result = [[d valueForKey:MFAMFIWarningKey] boolValue];
    return result;
}

/* ------------------ Library Validation ------------------ */

+ (Boolean)LIBRARYVALIDATION_isEnabled {
    Boolean enabled = true;
    NSString *result = [SIPKit runScript:@"defaults read /Library/Preferences/com.apple.security.libraryvalidation.plist DisableLibraryValidation"];
    if ([result rangeOfString:@"1"].length > 0) enabled = false;
    return enabled;
}

+ (Boolean)LIBRARYVALIDATION_setEnabled:(BOOL)state {
    NSString *newBootArgs = @"true";
    if (!state) newBootArgs = @"false";
    [SIPKit runSTPrivilegedTask:@"/usr/bin/defaults" :@[@"write", @"/Library/Preferences/com.apple.security.libraryvalidation.plist", @"DisableLibraryValidation", @"-bool", newBootArgs]];
    NSString *result = [SIPKit runScript:@"defaults read /Library/Preferences/com.apple.security.libraryvalidation.plist DisableLibraryValidation"];
    return ![result isEqualToString:newBootArgs];
}

+ (Boolean)LIBRARYVALIDATION_toggle {
//    sudo defaults write /Library/Preferences/com.apple.security.libraryvalidation.plist DisableLibraryValidation -bool true
    NSString *newBootArgs = [SIPKit runScript:@"defaults read /Library/Preferences/com.apple.security.libraryvalidation.plist DisableLibraryValidation"];
    if ([newBootArgs containsString:@"0"] || newBootArgs == nil) {
        newBootArgs = @"true";
    } else {
        newBootArgs = @"false";
    }
    [SIPKit runSTPrivilegedTask:@"/usr/bin/defaults" :@[@"write", @"/Library/Preferences/com.apple.security.libraryvalidation.plist", @"DisableLibraryValidation", @"-bool", newBootArgs]];
    NSString *result = [SIPKit runScript:@"defaults read /Library/Preferences/com.apple.security.libraryvalidation.plist DisableLibraryValidation"];
    return ![result isEqualToString:newBootArgs];
}

/* ------------------ AMFI ------------------ */

+ (void)AMFI_NUKE_NOCHECK {
    [SIPKit getAuth];
    
    [STPrivilegedTask launchedPrivilegedTaskWithLaunchPath:@"/usr/sbin/nvram"
                                                 arguments:@[@"-d", @"boot-args"]
                                          currentDirectory:[[NSBundle mainBundle] resourcePath]
                                             authorization:authorizationRef];
    
    [STPrivilegedTask launchedPrivilegedTaskWithLaunchPath:@"/usr/bin/defaults"
                                                 arguments:@[@"write", @"/Library/Preferences/com.apple.security.libraryvalidation.plist", @"DisableLibraryValidation", @"-bool", @"true"]
                                          currentDirectory:[[NSBundle mainBundle] resourcePath]
                                             authorization:authorizationRef];
}

+ (void)AMFI_NUKE {
    NSString *result = [SIPKit runScript:@"nvram boot-args 2>&1"];
    if ([result containsString:@"amfi_get_out_of_my_way"]) {
        [SIPKit getAuth];
        
        [STPrivilegedTask launchedPrivilegedTaskWithLaunchPath:@"/usr/sbin/nvram"
                                                     arguments:@[@"-d", @"boot-args"]
                                              currentDirectory:[[NSBundle mainBundle] resourcePath]
                                                 authorization:authorizationRef];
        
        [STPrivilegedTask launchedPrivilegedTaskWithLaunchPath:@"/usr/bin/defaults"
                                                     arguments:@[@"write", @"/Library/Preferences/com.apple.security.libraryvalidation.plist", @"DisableLibraryValidation", @"-bool", @"true"]
                                              currentDirectory:[[NSBundle mainBundle] resourcePath]
                                                 authorization:authorizationRef];
    }
}

+ (Boolean)AMFI_isEnabled {
    return ![SIPKit NVRAM_arg_present:@"amfi_get_out_of_my_way=1"];
}

+ (Boolean)AMFI_amfi_allow_any_signature_toggle {
    return [SIPKit toggleBootArg:@"amfi_allow_any_signature"];
}

+ (Boolean)AMFI_cs_enforcement_disable_toggle {
    return [SIPKit toggleBootArg:@"cs_enforcement_disable"];
}

+ (Boolean)AMFI_amfi_get_out_of_my_way_toggle {
    return [SIPKit toggleBootArg:@"amfi_get_out_of_my_way"];
}

@end
