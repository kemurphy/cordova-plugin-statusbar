/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

/*
 NOTE: plugman/cordova cli should have already installed this,
 but you need the value UIViewControllerBasedStatusBarAppearance
 in your Info.plist as well to set the styles in iOS 7
 */

#import "CDVStatusBar.h"
#import <objc/runtime.h>
#import <Cordova/CDVViewController.h>

// @interface UIApplication (Private)
// - (UIWindow *)statusBarWindow;
// @end

@interface CDVStatusBarViewController : UIViewController {
    CDVStatusBar *m_plugin;
}
@property (atomic, assign) CDVStatusBar *plugin;
@end

@interface CDVStatusBar () <UIScrollViewDelegate>
@end

@implementation CDVStatusBarViewController

- (id)initWithPlugin:(CDVStatusBar*)plugin {
    if (self = [super init]) {
        self.plugin = plugin;
    }
    return self;
}

- (CDVStatusBar*)plugin {
    return m_plugin;
}

- (void)setPlugin:(CDVStatusBar*)plugin {
    m_plugin = plugin;
}

- (BOOL)prefersStatusBarHidden {
    return !self.plugin.statusBarVisible;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return self.plugin.statusBarStyle;
}

@end

@implementation CDVStatusBar

- (id)settingForKey:(NSString*)key {
    return [self.commandDelegate.settings objectForKey:[key lowercaseString]];
}

- (void)pluginInitialize {
    UIApplication *app = [UIApplication sharedApplication];

    NSString *vcBasedBarPropKey = @"UIViewControllerBasedStatusBarAppearance";
    NSNumber *vcBasedBarProp = [[NSBundle mainBundle] objectForInfoDictionaryKey:vcBasedBarPropKey];
    BOOL vcBasedBar =!vcBasedBarProp || [vcBasedBarProp boolValue]; // defaults to YES if not set
    
    // init background bar
    m_statusBarBackgroundView = [[UIWindow alloc] initWithFrame:[[UIApplication sharedApplication] statusBarFrame]];
    m_statusBarBackgroundView.backgroundColor = [UIColor clearColor];

    // defaults
    m_statusBarVisible = !app.statusBarHidden;
    m_statusBarStyle = app.statusBarStyle;
    m_uiviewControllerBasedStatusBarAppearance = vcBasedBar;

    id setting;

    setting  = @"StatusBarBackgroundColor";
    if ([self settingForKey:setting]) {
        [self setBackgroundColorFromString:[self settingForKey:setting]];
    }

    setting = [self settingForKey:@"StatusBarStyle"];
    if (setting) {
        [self updateStyleFromSetting:setting];
    }

    // show background bar
    m_statusBarBackgroundView.windowLevel = UIWindowLevelNormal;
    m_statusBarBackgroundView.rootViewController = [[CDVStatusBarViewController alloc] initWithPlugin:self];
    m_statusBarBackgroundView.hidden = NO;

    // blank scroll view to intercept status bar taps
    self.webView.scrollView.scrollsToTop = NO;
    UIScrollView *fakeScrollView = [[UIScrollView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    fakeScrollView.delegate = self;
    fakeScrollView.scrollsToTop = YES;
    [self.viewController.view addSubview:fakeScrollView]; // Add scrollview to the view heirarchy so that it will begin accepting status bar taps
    [self.viewController.view sendSubviewToBack:fakeScrollView]; // Send it to the very back of the view heirarchy
    fakeScrollView.contentSize = CGSizeMake(UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height * 2.0f); // Make the scroll view longer than the screen itself
    fakeScrollView.contentOffset = CGPointMake(0.0f, UIScreen.mainScreen.bounds.size.height); // Scroll down so a tap will take scroll view back to the top
}

- (void)onAppTerminate {
}

- (void)setBackgroundColorFromString:(NSString*)colorString
{
    SEL selector = NSSelectorFromString([colorString stringByAppendingString:@"Color"]);
    if ([UIColor respondsToSelector:selector]) {
        m_statusBarBackgroundView.backgroundColor = [UIColor performSelector:selector];
    } else if ([colorString hasPrefix:@"#"] && [colorString length] == 7) {
        unsigned int rgbValue = 0;
        NSScanner* scanner = [NSScanner scannerWithString:colorString];
        [scanner setScanLocation:1];
        [scanner scanHexInt:&rgbValue];

        UIColor *color = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16) /255.0
                                         green:((rgbValue & 0x00FF00) >> 8)  /255.0
                                          blue:((rgbValue & 0x0000FF) >> 0)  /255.0
                                         alpha:1.0];

        m_statusBarBackgroundView.backgroundColor = color;
    }


}

- (void) backgroundColorByName:(CDVInvokedUrlCommand*)command
{
    id value = [command argumentAtIndex:0];
    if (!([value isKindOfClass:[NSString class]])) {
        value = @"black";
    }

    [self setBackgroundColorFromString:value];
}

- (void) backgroundColorByHexString:(CDVInvokedUrlCommand*)command
{
    NSString* value = [command argumentAtIndex:0];
    if (!([value isKindOfClass:[NSString class]])) {
        value = @"#000000";
    }

    [self setBackgroundColorFromString:value];
}

- (void)fireEventCallback:(NSString*)type {
    [self fireEventCallback:type withData:nil];
}

- (void)fireEventCallback:(NSString*)type withData:(NSDictionary*)data {
    if (m_eventCallbackId == nil) {
        return;
    }

    NSDictionary* payload = (data != nil)
        ? @{@"type": type, @"data": data}
        : @{@"type": type};
    CDVPluginResult* result =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:payload];

    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:m_eventCallbackId];
}

- (void)fireTapEvent {
    [self fireEventCallback:@"tap"];
}

- (void)fireVisibleChangeEvent {
    [self fireEventCallback:(self.statusBarVisible ? @"show" : @"hide")];
}

- (void) setStatusBarVisible:(BOOL)statusBarVisible {
    // we only care about the latest iOS version or a change in setting
    if (statusBarVisible == m_statusBarVisible) {
        return;
    }
    
    m_statusBarVisible = statusBarVisible;
    
    [self refreshStatusBarAppearance];
    [self fireVisibleChangeEvent];
}

- (BOOL) statusBarVisible {
    return m_statusBarVisible;
}

- (void) setStatusBarStyle:(UIStatusBarStyle)statusBarStyle {
    // we only care about the latest iOS version or a change in setting
    if (statusBarStyle == m_statusBarStyle) {
        return;
    }
    
    m_statusBarStyle = statusBarStyle;

    [self refreshStatusBarAppearance];
}

- (UIStatusBarStyle) statusBarStyle {
    return m_statusBarStyle;
}

- (void)updateIsVisible:(BOOL)visible {
    if (m_uiviewControllerBasedStatusBarAppearance) {
        self.statusBarVisible = visible;
    } else {
        [[UIApplication sharedApplication] setStatusBarHidden:!visible];
    }
}

- (void)registerEventCallback:(CDVInvokedUrlCommand*)command {
    m_eventCallbackId = command.callbackId;
    [self fireVisibleChangeEvent];
}

- (void)onReset {
    if (m_eventCallbackId != nil) {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:m_eventCallbackId];
        m_eventCallbackId = nil;
    }
}

- (CGRect) invertFrameIfNeeded:(CGRect)rect orientation:(UIInterfaceOrientation)orientation {
    // landscape is where (width > height). On iOS < 8, we need to invert since frames are
    // always in Portrait context
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]) && (rect.size.width < rect.size.height)) {
        CGFloat temp = rect.size.width;
        rect.size.width = rect.size.height;
        rect.size.height = temp;
        rect.origin = CGPointZero;
    }
    
    return rect;
}

- (void) refreshStatusBarAppearance {
    UIViewController *vc = m_statusBarBackgroundView.rootViewController;
    if ([vc respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [vc setNeedsStatusBarAppearanceUpdate];
    }
}

- (void) updateStyle:(UIStatusBarStyle)style {
    if (m_uiviewControllerBasedStatusBarAppearance) {
        self.statusBarStyle = style;
    } else {
        [[UIApplication sharedApplication] setStatusBarStyle:style];
    }

    [self refreshStatusBarAppearance];
}

- (void) updateStyleFromSetting:(NSString*)statusBarStyle {
    // default, lightContent, blackTranslucent, blackOpaque
    NSString* lcStatusBarStyle = [statusBarStyle lowercaseString];

    if ([lcStatusBarStyle isEqualToString:@"default"]) {
        [self styleDefault:nil];
    } else if ([lcStatusBarStyle isEqualToString:@"lightcontent"]) {
        [self styleLightContent:nil];
    } else if ([lcStatusBarStyle isEqualToString:@"blacktranslucent"]) {
        [self styleBlackTranslucent:nil];
    } else if ([lcStatusBarStyle isEqualToString:@"blackopaque"]) {
        [self styleBlackOpaque:nil];
    }
}

- (void) styleDefault:(CDVInvokedUrlCommand*)command {
    [self updateStyle:UIStatusBarStyleDefault];
}

- (void) styleLightContent:(CDVInvokedUrlCommand*)command {
    [self updateStyle:UIStatusBarStyleLightContent];
}

- (void) styleBlackTranslucent:(CDVInvokedUrlCommand*)command {
    [self updateStyle:UIStatusBarStyleLightContent];
}

- (void) styleBlackOpaque:(CDVInvokedUrlCommand*)command {
    [self updateStyle:UIStatusBarStyleLightContent];
}

- (void) hide:(CDVInvokedUrlCommand*)command {
    [self updateIsVisible:NO];
}

- (void) show:(CDVInvokedUrlCommand*)command {
    [self updateIsVisible:YES];
}

#pragma mark - UIScrollViewDelegate

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    [self fireTapEvent];
    return NO;
}

@end
