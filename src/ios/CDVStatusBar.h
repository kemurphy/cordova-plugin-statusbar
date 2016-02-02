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

#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>

@interface CDVStatusBar : CDVPlugin {
    @protected
    BOOL m_statusBarVisible;
    UIStatusBarStyle m_statusBarStyle;
    NSString* m_eventCallbackId;
    BOOL m_uiviewControllerBasedStatusBarAppearance;
    UIWindow *m_statusBarBackgroundView;
}

@property (atomic, assign) BOOL statusBarVisible;
@property (atomic, assign) UIStatusBarStyle statusBarStyle;

- (void) styleDefault:(CDVInvokedUrlCommand*)command;
- (void) styleLightContent:(CDVInvokedUrlCommand*)command;
- (void) styleBlackTranslucent:(CDVInvokedUrlCommand*)command;
- (void) styleBlackOpaque:(CDVInvokedUrlCommand*)command;

- (void) backgroundColorByName:(CDVInvokedUrlCommand*)command;
- (void) backgroundColorByHexString:(CDVInvokedUrlCommand*)command;
   
- (void) hide:(CDVInvokedUrlCommand*)command;
- (void) show:(CDVInvokedUrlCommand*)command;

- (void) registerEventCallback:(CDVInvokedUrlCommand*)command;
- (void) fireEventCallback:(NSString*)type;
- (void) fireEventCallback:(NSString*)type withData:(NSDictionary*)data;

@end
