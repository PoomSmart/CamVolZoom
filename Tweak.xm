#import "Header.h"

static NSTimer *incrementTimer;
static NSTimer *incrementZoomTimer;
static BOOL isIncrementing;
static NSTimer *decrementTimer;
static NSTimer *decrementZoomTimer;
static BOOL isDecrementing;

static BOOL CamVolZoom;
static BOOL HookNC = NO;

static float FINE_SLIDER_ADJUSTMENT;
static double SLIDER_ADJUSTMENT;
static double SLIDER_ANIMATION_TIME;
static float ADJUSTMENT_INTERVAL;
static double CONTINUOUS_DELAY;
static double ZOOM_DELAY;

#define pre8Cont [%c(PLCameraController) sharedInstance]
#define the8Cont [%c(CAMCaptureController) sharedInstance]
#define pre8ContDelegate [pre8Cont delegate]
#define the8ContDelegate [the8Cont delegate]

static void CVZLoader()
{
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
	#define readBoolOption(prename, name, defaultValue) \
		id prename = dict[[NSString stringWithUTF8String:#prename]]; \
		name = prename ? [prename boolValue] : defaultValue;
	#define readOption(prename, name, defaultValue) \
		id prename = dict[[NSString stringWithUTF8String:#prename]]; \
		name = prename ? [prename floatValue] : defaultValue;
	#define readOption2(prename, name, defaultValue) \
		id prename = dict[[NSString stringWithUTF8String:#prename]]; \
		name = prename ? [prename doubleValue] : defaultValue;

	readBoolOption(CamVolZoomEnabled, CamVolZoom, YES)
	readOption(FineSliderAdjustment, FINE_SLIDER_ADJUSTMENT, 0.01f)
	readOption2(SliderAdjustment, SLIDER_ADJUSTMENT, 0.1f)
	readOption2(SliderAnimDuration, SLIDER_ANIMATION_TIME, 0.2f)
	readOption(AdjustmentInterval, ADJUSTMENT_INTERVAL, 0.01f)
	readOption2(ContinuousDelay, CONTINUOUS_DELAY, 1.0f)
	readOption2(ZoomDelay, ZOOM_DELAY, 0.0f)
}


%hook NSNotificationCenter

- (void)addObserver:(id)observer selector:(SEL)selector name:(NSString *)name object:(id)object
{
	SEL newSelector = selector;
	if (CamVolZoom) {
		if (HookNC) {
			if ([name isEqualToString:UIApp_Volume_Up_Down])
				newSelector = @selector(_handleVolumeUpButtonDown);
			else if ([name isEqualToString:UIApp_Volume_Up_Up])
				newSelector = @selector(_handleVolumeUpButtonUp);
			else if ([name isEqualToString:UIApp_Volume_Down_Down])
				newSelector = @selector(_handleVolumeDownButtonDown);
			else if ([name isEqualToString:UIApp_Volume_Down_Up])
				newSelector = @selector(_handleVolumeDownButtonUp);
		}
	}
	%orig(observer, newSelector, name, object);
}

%end

static void prepareZoomSlider(NSObject <cameraViewDelegate> *self)
{
	id slider;
	BOOL modernOS = isiOS7Up;
	if (modernOS)
		slider = MSHookIvar<CAMZoomSlider *>(self, "__zoomSlider");
	else
		slider = MSHookIvar<PLCameraZoomSlider *>(self, "_zoomSlider");
	if (slider == nil) {
		if (modernOS)
			[self _createZoomSliderIfNecessary];
		else
			[self showZoomSlider];
	}
	if (((UIView *)slider).hidden)
		((UIView *)slider).hidden = NO;
	if (isiOS5 || modernOS)
		[slider makeVisible];
}

static void genericZoomIn(NSObject <cameraViewDelegate> *self)
{
	prepareZoomSlider(self);
	id slider;
	BOOL modernOS = isiOS7Up;
	if (modernOS)
		slider = MSHookIvar<CAMZoomSlider *>(self, "__zoomSlider");
	else
		slider = MSHookIvar<PLCameraZoomSlider *>(self, "_zoomSlider");
	id controller = isiOS8 ? the8Cont : pre8Cont;
	double value = (modernOS ? [controller videoZoomFactor] : ((UISlider *)slider).value) + (isIncrementing ? FINE_SLIDER_ADJUSTMENT : SLIDER_ADJUSTMENT);
	if (modernOS) {
		if (isIncrementing) {
			if (![slider isMaximumAutozooming])
				[slider _setMaximumAutozooming:YES];
			return;
		}
		[self _setZoomFactor:value];
	} else {
		[self _beginZooming];
		[self _addZoomAnimationDisplayLinkWithSelector:@selector(_incrementZoomSlider)];
		[UIView animateWithDuration:SLIDER_ANIMATION_TIME animations:^{
			[(UISlider *)slider setValue:value];
		}];
		[self _setZoomFactor:((UISlider *)slider).value];
		[self _endZooming];
	}
}

static void genericZoomOut(NSObject <cameraViewDelegate> *self)
{
	prepareZoomSlider(self);
	id slider;
	BOOL modernOS = isiOS7Up;
	if (modernOS)
		slider = MSHookIvar<CAMZoomSlider *>(self, "__zoomSlider");
	else
		slider = MSHookIvar<PLCameraZoomSlider *>(self, "_zoomSlider");
	id controller = isiOS8 ? the8Cont : pre8Cont;
	double value = (modernOS ? [controller videoZoomFactor] : ((UISlider *)slider).value) - (isDecrementing ? FINE_SLIDER_ADJUSTMENT : SLIDER_ADJUSTMENT);
	if (modernOS) {
		if (isDecrementing) {
			if (![slider isMinimumAutozooming])
				[slider _setMinimumAutozooming:YES];
			return;
		}
		[self _setZoomFactor:value];
	} else {
		[self _beginZooming];
		[self _addZoomAnimationDisplayLinkWithSelector:@selector(_decrementZoomSlider)];
		[UIView animateWithDuration:SLIDER_ANIMATION_TIME animations:^{
			[(UISlider *)slider setValue:value];
		}];
		[self _setZoomFactor:((UISlider *)slider).value];
		[self _endZooming];
	}
}

static void modernOSCleanup(NSObject <cameraViewDelegate> *self)
{
	BOOL modernOS = isiOS78;
	if (modernOS) {
		CAMZoomSlider *slider = MSHookIvar<CAMZoomSlider *>(self, "__zoomSlider");
		if ([slider isMinimumAutozooming])
			[slider _setMinimumAutozooming:NO];
		if ([slider isMaximumAutozooming])
			[slider _setMaximumAutozooming:NO];
	}
}

static void _PLhandleVolumeUpButtonDown(NSObject <cameraViewDelegate> *self)
{
	incrementTimer = [NSTimer scheduledTimerWithTimeInterval:CONTINUOUS_DELAY target:self selector:@selector(_PLhandleVolumeUpButtonDownIncrement) userInfo:nil repeats:NO];
	[incrementTimer retain];
	[(NSObject *)self performSelector:@selector(genericZoomIn) withObject:nil afterDelay:ZOOM_DELAY];
}

static void _PLhandleVolumeUpButtonDownIncrement(NSObject <cameraViewDelegate> *self)
{
	isIncrementing = YES;
	incrementZoomTimer = [NSTimer scheduledTimerWithTimeInterval:ADJUSTMENT_INTERVAL target:self selector:@selector(__PLhandleVolumeUpButtonDownIncrement) userInfo:nil repeats:YES];
	[incrementZoomTimer retain];
}

static void __PLhandleVolumeUpButtonDownIncrement(NSObject <cameraViewDelegate> *self)
{
	[(NSObject *)self performSelectorOnMainThread:@selector(genericZoomIn) withObject:nil waitUntilDone:YES];
}

static void _PLhandleVolumeUpButtonUp(NSObject <cameraViewDelegate> *self)
{
	isIncrementing = NO;
	if (incrementZoomTimer != nil) {
       	[incrementZoomTimer invalidate];
        incrementZoomTimer = nil;
    }
	if (incrementTimer != nil) {
       	[incrementTimer invalidate];
        incrementTimer = nil;
    }
    modernOSCleanup(self);
}

static void _PLhandleVolumeDownButtonDown(NSObject <cameraViewDelegate> *self)
{
	decrementTimer = [NSTimer scheduledTimerWithTimeInterval:CONTINUOUS_DELAY target:self selector:@selector(_PLhandleVolumeDownButtonDownDecrement) userInfo:nil repeats:NO];
	[decrementTimer retain];
	[(NSObject *)self performSelector:@selector(genericZoomOut) withObject:nil afterDelay:ZOOM_DELAY];
}

static void _PLhandleVolumeDownButtonDownDecrement(NSObject <cameraViewDelegate> *self)
{
	isDecrementing = YES;
	decrementZoomTimer = [NSTimer scheduledTimerWithTimeInterval:ADJUSTMENT_INTERVAL target:self selector:@selector(__PLhandleVolumeDownButtonDownDecrement) userInfo:nil repeats:YES];
	[decrementZoomTimer retain];
}

static void __PLhandleVolumeDownButtonDownDecrement(NSObject <cameraViewDelegate> *self)
{
	[(NSObject *)self performSelectorOnMainThread:@selector(genericZoomOut) withObject:nil waitUntilDone:YES];
}

static void _PLhandleVolumeDownButtonUp(NSObject <cameraViewDelegate> *self)
{
	isDecrementing = NO;
	if (decrementZoomTimer != nil) {
       	[decrementZoomTimer invalidate];
        decrementZoomTimer = nil;
    }
	if (decrementTimer != nil) {
       	[decrementTimer invalidate];
        decrementTimer = nil;
    }
    modernOSCleanup(self);
}

%group iOS5

%hook PLCameraView

- (void)_handleVolumeUpButtonDown
{
	[self _PLhandleVolumeUpButtonDown];
}

- (void)_handleVolumeUpButtonUp
{
	[self _PLhandleVolumeUpButtonUp];
}

%end

%end

%group iOS67Addition

%hook PLCameraView

%new
- (void)_handleVolumeUpButtonDown
{
	[self _PLhandleVolumeUpButtonDown];
}

%new
- (void)_handleVolumeUpButtonUp
{
	[self _PLhandleVolumeUpButtonUp];
}

%end

%end

%group iOS56

%hook PLCameraPageController

- (void)_createCameraViewControllerWithSessionAlbum:(BOOL)sessionAlbum useCameraLocationBundleID:(BOOL)anId startPreviewImmediately:(BOOL)immediately
{
	HookNC = YES;
	%orig;
	HookNC = NO;
}

%new
- (void)_handleVolumeUpButtonDown
{
	[pre8ContDelegate _PLhandleVolumeUpButtonDown];
}

%new
- (void)_handleVolumeDownButtonDown
{
	[pre8ContDelegate _PLhandleVolumeDownButtonDown];
}

%new
- (void)_handleVolumeUpButtonUp
{
	[pre8ContDelegate _PLhandleVolumeUpButtonUp];
}

%new
- (void)_handleVolumeDownButtonUp
{
	[pre8ContDelegate _PLhandleVolumeDownButtonUp];
}

%end

%hook PLCameraView

- (id)initWithFrame:(CGRect)frame isCameraApp:(BOOL)app
{
	HookNC = YES;
	self = %orig;
	HookNC = NO;
	if (self) {
		if (isiOS5) {
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleVolumeDownButtonDown) name:UIApp_Volume_Down_Down object:nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleVolumeDownButtonUp) name:UIApp_Volume_Down_Up object:nil];
		}
	}
	return self;
}

%end

%end

%group iOS7

%hook PLApplicationCameraViewController

- (id)initWithSessionID:(id)session usesCameraLocationBundleID:(id)bundle startPreviewImmediately:(BOOL)arg3
{
	HookNC = YES;
	self = %orig;
	HookNC = NO;
	return self;
}

%new
- (void)_handleVolumeUpButtonDown
{
	[pre8ContDelegate _PLhandleVolumeUpButtonDown];
}

%new
- (void)_handleVolumeDownButtonDown
{
	[pre8ContDelegate _PLhandleVolumeDownButtonDown];
}

%new
- (void)_handleVolumeUpButtonUp
{
	[pre8ContDelegate _PLhandleVolumeUpButtonUp];
}

%new
- (void)_handleVolumeDownButtonUp
{
	[pre8ContDelegate _PLhandleVolumeDownButtonUp];
}

%end

%hook PLCameraController

- (void)rampToVideoZoomFactor:(double)factor withRate:(float)rate
{
	%orig(factor, (isIncrementing || isDecrementing) ? FINE_SLIDER_ADJUSTMENT/ADJUSTMENT_INTERVAL : rate);
}

%end

%hook PLCameraView

- (id)initWithFrame:(CGRect)frame spec:(id)spec
{
	HookNC = YES;
	self = %orig;
	HookNC = NO;
	return self;
}

%end

%end

%group iOS8

%hook CAMApplicationViewController

- (id)initWithSessionID:(id)session usesCameraLocationBundleID:(id)bundle startPreviewImmediately:(BOOL)arg3
{
	HookNC = YES;
	self = %orig;
	HookNC = NO;
	return self;
}

%new
- (void)_handleVolumeUpButtonDown
{
	[the8ContDelegate _PLhandleVolumeUpButtonDown];
}

%new
- (void)_handleVolumeDownButtonDown
{
	[the8ContDelegate _PLhandleVolumeDownButtonDown];
}

%new
- (void)_handleVolumeUpButtonUp
{
	[the8ContDelegate _PLhandleVolumeUpButtonUp];
}

%new
- (void)_handleVolumeDownButtonUp
{
	[the8ContDelegate _PLhandleVolumeDownButtonUp];
}

%end

%hook CAMCaptureController

- (void)rampToVideoZoomFactor:(double)factor withRate:(float)rate
{
	%orig(factor, (isIncrementing || isDecrementing) ? FINE_SLIDER_ADJUSTMENT/ADJUSTMENT_INTERVAL : rate);
}

%end

%hook CAMCameraView

- (id)initWithFrame:(CGRect)frame spec:(id)spec
{
	HookNC = YES;
	self = %orig;
	HookNC = NO;
	return self;
}

%new - (void)genericZoomIn { genericZoomIn(self); }
%new - (void)genericZoomOut { genericZoomOut(self); }
%new - (void)_PLhandleVolumeUpButtonDown { _PLhandleVolumeUpButtonDown(self); }
%new - (void)_PLhandleVolumeUpButtonDownIncrement { _PLhandleVolumeUpButtonDownIncrement(self); }
%new - (void)__PLhandleVolumeUpButtonDownIncrement { __PLhandleVolumeUpButtonDownIncrement(self); }
%new - (void)_PLhandleVolumeUpButtonUp { _PLhandleVolumeUpButtonUp(self); }
%new - (void)_PLhandleVolumeDownButtonDown { _PLhandleVolumeDownButtonDown(self); }
%new - (void)_PLhandleVolumeDownButtonDownDecrement { _PLhandleVolumeDownButtonDownDecrement(self); }
%new - (void)__PLhandleVolumeDownButtonDownDecrement { __PLhandleVolumeDownButtonDownDecrement(self); }
%new - (void)_PLhandleVolumeDownButtonUp { _PLhandleVolumeDownButtonUp(self); }
%new - (void)_handleVolumeDownButtonDown { [self _PLhandleVolumeDownButtonDown]; }
%new - (void)_handleVolumeDownButtonUp { [self _PLhandleVolumeDownButtonUp]; }

%new
- (void)_handleVolumeUpButtonDown
{
	[self _PLhandleVolumeUpButtonDown];
}

%new
- (void)_handleVolumeUpButtonUp
{
	[self _PLhandleVolumeUpButtonUp];
}

%end

%end

%group preiOS8

%hook PLCameraView

%new - (void)genericZoomIn { genericZoomIn(self); }
%new - (void)genericZoomOut { genericZoomOut(self); }
%new - (void)_PLhandleVolumeUpButtonDown { _PLhandleVolumeUpButtonDown(self); }
%new - (void)_PLhandleVolumeUpButtonDownIncrement { _PLhandleVolumeUpButtonDownIncrement(self); }
%new - (void)__PLhandleVolumeUpButtonDownIncrement { __PLhandleVolumeUpButtonDownIncrement(self); }
%new - (void)_PLhandleVolumeUpButtonUp { _PLhandleVolumeUpButtonUp(self); }
%new - (void)_PLhandleVolumeDownButtonDown { _PLhandleVolumeDownButtonDown(self); }
%new - (void)_PLhandleVolumeDownButtonDownDecrement { _PLhandleVolumeDownButtonDownDecrement(self); }
%new - (void)__PLhandleVolumeDownButtonDownDecrement { __PLhandleVolumeDownButtonDownDecrement(self); }
%new - (void)_PLhandleVolumeDownButtonUp { _PLhandleVolumeDownButtonUp(self); }
%new - (void)_handleVolumeDownButtonDown { [self _PLhandleVolumeDownButtonDown]; }
%new - (void)_handleVolumeDownButtonUp { [self _PLhandleVolumeDownButtonUp]; }

%end

%end

static void PostNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	CVZLoader();
}

%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PostNotification, (CFStringRef)CVZNotificationKey, NULL, CFNotificationSuspensionBehaviorCoalesce);
	CVZLoader();
	if (CamVolZoom) {
		dlopen("/System/Library/PrivateFrameworks/PhotoLibrary.framework/PhotoLibrary", RTLD_LAZY);
		dlopen("/System/Library/PrivateFrameworks/CameraKit.framework/CameraKit", RTLD_LAZY);
		
		if (isiOS5) {
			%init(iOS5);
		}
		else if (isiOS7) {
			%init(iOS7);
		}
		else if (isiOS8) {
			%init(iOS8);
		}
		
		if (isiOS56) {
			%init(iOS56);
		}
		if (isiOS67) {
			%init(iOS67Addition);
		}
		
		if (!isiOS8Up) {
			%init(preiOS8);
		}
		
		%init();
	}
	[pool drain];
}