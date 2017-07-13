#import <substrate.h>
#import "../PS.h"

NSString *const UIApp_Volume_Down_Down = @"_UIApplicationVolumeDownButtonDownNotification";
NSString *const UIApp_Volume_Down_Up = @"_UIApplicationVolumeDownButtonUpNotification";
NSString *const UIApp_Volume_Up_Down = @"_UIApplicationVolumeUpButtonDownNotification";
NSString *const UIApp_Volume_Up_Up = @"_UIApplicationVolumeUpButtonUpNotification";

NSString *const PREF_PATH = @"/var/mobile/Library/Preferences/com.PS.CamVolZoom.plist";
NSString *const CVZIdent = @"com.PS.CamVolZoom";
NSString *const CVZNotificationKey = @"com.PS.CamVolZoom.prefs";

@interface PLCameraView (CVZ)
- (void)_PLhandleVolumeUpButtonDown;
- (void)_PLhandleVolumeUpButtonUp;
- (void)_PLhandleVolumeDownButtonDown;
- (void)_PLhandleVolumeDownButtonUp;
@end

@interface CAMCameraView (CVZ)
- (void)_PLhandleVolumeUpButtonDown;
- (void)_PLhandleVolumeUpButtonUp;
- (void)_PLhandleVolumeDownButtonDown;
- (void)_PLhandleVolumeDownButtonUp;
@end
