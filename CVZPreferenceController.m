#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>
#import <Preferences/PSSpecifier.h>
#import <Social/Social.h>
#import <dlfcn.h>
#import "Header.h"

@interface PSControlTableCell (Addition)
@property (retain) UIView *accessoryView;
@property (retain) UIView *contentView;
- (UILabel *)textLabel;
- (PSSpecifier *)specifier;
@end

static NSDictionary *prefDict()
{
	return [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
}

static id objectForKey(NSString *key)
{
	return prefDict()[key];
}

static void setObjectForKey(id value, NSString *key)
{
	NSMutableDictionary *dict = [prefDict() mutableCopy] ?: [NSMutableDictionary dictionary];
	[dict setObject:value forKey:key];
	[dict writeToFile:PREF_PATH atomically:YES];
}

@interface CVZSliderTableCell : PSControlTableCell
@end

@implementation CVZSliderTableCell
 
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)spec
{
	if (self == [super initWithStyle:style reuseIdentifier:identifier specifier:spec]) {
		UISlider *slider = [[[UISlider alloc] init] autorelease];
		slider.continuous = NO;
		slider.minimumValue = [[spec propertyForKey:@"min"] floatValue];
		slider.maximumValue = [[spec propertyForKey:@"max"] floatValue];
		NSString *key = [spec propertyForKey:@"key"];
		CGFloat value = objectForKey(key) ? [objectForKey(key) floatValue] : [[spec propertyForKey:@"default"] floatValue];
		slider.value = value;
		self.control = slider;
		
		UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 35.0f, 14.0f)] autorelease];
		label.text = [NSString stringWithFormat:@"%.2f", value];
		label.lineBreakMode = NSLineBreakByWordWrapping;
		label.textAlignment = NSTextAlignmentRight;
		label.backgroundColor = [UIColor clearColor];
		
		self.accessoryView  = label;
		self.textLabel.text = [spec propertyForKey:@"cellName"];
		[slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
	}
	return self;
}

- (void)sliderValueChanged:(UISlider *)slider
{
	setObjectForKey(@(slider.value), [[self specifier] propertyForKey:@"key"]);
	UILabel *label = (UILabel *)(self.accessoryView);
	label.text = [NSString stringWithFormat:@"%.2f", slider.value];
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)CVZNotificationKey, NULL, NULL, YES);
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	CGSize textSize;
	CGFloat textWidth;
	UILabel *label = self.textLabel;
	if (isiOS7Up) {
		textSize = [label.text sizeWithAttributes:@{NSFontAttributeName:label.font}];
		textWidth = textSize.width;
	} else {
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		textSize = [label.text sizeWithFont:label.font];
		textWidth = textSize.width;
		#pragma clang diagnostic pop
	}
	CGFloat leftPad = textWidth + 28.0f;
	CGFloat rightPad = 14.0f;
	UIView *contentView = (UIView *)(self.contentView);
	
	UISlider *slider = (UISlider *)(self.control);
	slider.center = contentView.center;
	slider.frame = CGRectMake(leftPad, slider.frame.origin.y, contentView.frame.size.width - leftPad - rightPad, slider.frame.size.height);
}
 
@end

@interface CVZPreferenceController : PSListController
/*@property (nonatomic, retain) PSSpecifier *FineSliderAmountSliderSpec;
@property (nonatomic, retain) PSSpecifier *FineSliderDelaySliderSpec;
@property (nonatomic, retain) PSSpecifier *SliderAmountSliderSpec;*/
@property (nonatomic, retain) PSSpecifier *SliderAnimDurationSliderSpec;
/*@property (nonatomic, retain) PSSpecifier *ContZoomDelaySliderSpec;
@property (nonatomic, retain) PSSpecifier *ZoomDelaySliderSpec;*/
@end

@implementation CVZPreferenceController

- (id)init
{
	if (self == [super init]) {
		UIButton *heart = [[[UIButton alloc] initWithFrame:CGRectZero] autorelease];
		[heart setImage:[UIImage imageNamed:@"Heart" inBundle:[NSBundle bundleWithPath:@"/Library/PreferenceBundles/CVZSettings.bundle"]] forState:UIControlStateNormal];
		[heart sizeToFit];
		[heart addTarget:self action:@selector(love) forControlEvents:UIControlEventTouchUpInside];
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:heart] autorelease];
	}
	return self;
}

- (void)love
{
	SLComposeViewController *twitter = [[SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter] retain];
	[twitter setInitialText:@"#CamVolZoom by @PoomSmart is awesome!"];
	if (twitter != nil)
		[[self navigationController] presentViewController:twitter animated:YES completion:nil];
	[twitter release];
}

- (void)donate:(id)param
{
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:PS_DONATE_URL]];
}

- (void)twitter:(id)param
{
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:PS_TWITTER_URL]];
}

- (void)killSB:(id)param
{
	if (isiOS8Up) {
		void *open = dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_LAZY);
		if (open != NULL) {
			NSURL *relaunchURL = [NSURL URLWithString:@"prefs:root=CamVolZoom"];
			SBSRestartRenderServerAction *restartAction = [objc_getClass("SBSRestartRenderServerAction") restartActionWithTargetRelaunchURL:relaunchURL];
			[[objc_getClass("FBSSystemService") sharedService] sendActions:[NSSet setWithObject:restartAction] withResult:nil];
			return;
		}
	}
	system("killall SpringBoard");
}

- (void)reset:(id)param
{
	for (PSSpecifier *spec in [self specifiers]) {
		id defaultValue = [spec propertyForKey:@"default"];
		if (defaultValue != nil) {
			NSString *key = [spec propertyForKey:@"key"];
			if (key != nil) {
				setObjectForKey(defaultValue, key);
				[self reloadSpecifier:spec animated:NO];
			}
		}
	}
}

- (id)readPreferenceValue:(PSSpecifier *)specifier
{
	NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
	if (!settings[specifier.properties[@"key"]])
		return specifier.properties[@"default"];
	return settings[specifier.properties[@"key"]];
}
 
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier
{
	NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
	[defaults addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:PREF_PATH]];
	[defaults setObject:value forKey:specifier.properties[@"key"]];
	[defaults writeToFile:PREF_PATH atomically:YES];
	CFStringRef post = (CFStringRef)specifier.properties[@"PostNotification"];
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), post, NULL, NULL, YES);
}

- (NSArray *)specifiers
{
	if (_specifiers == nil) {
		NSMutableArray *specs = [NSMutableArray arrayWithArray:[self loadSpecifiersFromPlistName:@"CVZ" target:self]];
		for (PSSpecifier *spec in specs) {
			if ([[spec identifier] isEqualToString:@"SliderAnimDurationSlider"])
                self.SliderAnimDurationSliderSpec = spec;
		}

		if (isiOS7Up)
			[specs removeObject:self.SliderAnimDurationSliderSpec];

		_specifiers = [specs copy];
  	}
	return _specifiers;
}

@end
