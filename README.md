# SIPKit 

SIPKit is an open-source framework to make it easy for your app to handle SIP, AMFI, and Library Validation on macOS. 

[![Discord](https://discordapp.com/api/guilds/608740492561219617/widget.png?style=banner2)](https://discordapp.com/channels/608740492561219617/608740492640911378)

### Installation 📂

-

### Usage 📝

```objectivec
// AMFI controls

/// Get rid of AMFI
+ (void)AMFI_NUKE;
/// 1 = enabled, 0 = disabled
+ (Boolean)AMFI_enabled;
/// 1 = success, 0 = fail
+ (Boolean)AMFI_amfi_allow_any_signature_toggle;
/// 1 = success, 0 = fail
+ (Boolean)AMFI_cs_enforcement_disable_toggle;
/// 1 = success, 0 = fail
+ (Boolean)AMFI_amfi_get_out_of_my_way_toggle;




// AMFI warnings

/// If a window is povided the warning will be shown as a sheet attached to the window otherwise it will be shown as it's own window
/// @param inWindow inWindow
+ (void)showAMFIWarning:(NSWindow*)inWindow;
/// Set wether or not your app will show  AMFI warnings -- 1 = show, 0 = don't show
+ (void)setShowAMFIWarning:(Boolean)shouldWarn;
/// Check if your app has set to hide AMFI warnings -- 1 = show, 0 = don't show
+ (Boolean)shouldWarnAboutAMFI;




// NVRAM

/// Check if an NVRAM arg is currently present -- 1 = arg present, 0 = arg missing
+ (Boolean)NVRAM_arg_present:(NSString*)arg;




// Library Validation

/// Check if Library Validation is enabled -- 1 = enabled, 0 = disabled
+ (Boolean)LIBRARYVALIDATION_enabled;
/// Toogle Library Validation 1 = success, 0 = fail
+ (Boolean)LIBRARYVALIDATION_toggle;




// System Integrity Protection

/// 1 = enabled, 0 = disabled
+ (Boolean)SIP_enabled;
/// 1 = has flags required for code injection, 0 = flags missing
+ (Boolean)SIP_HasRequiredFlags;
/// 1 = nvram flag enabled, 0 = disabled
+ (Boolean)SIP_NVRAM;
/// 1 = task for pid flag enabled, 0 = disabled
+ (Boolean)SIP_TASK_FOR_PID;
/// 1 = filesystem flag enabled, 0 = disabled
+ (Boolean)SIP_Filesystem;
```

### System Requirements 🖥

- SIPKit supports macOS 10.10 and above

### Developement ❤️

- [MacEnhance](https://github.com/macenhance) ([@MacEnhance](https://github.com/macenhance)) ([MacEnhance](https://www.macenhance.com/))
