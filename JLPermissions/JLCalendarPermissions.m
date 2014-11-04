//
//  JLCalendarPermissions.m
//
//  Created by Joseph Laws on 11/3/14.
//  Copyright (c) 2014 Joe Laws. All rights reserved.
//

#import "JLCalendarPermissions.h"

@import EventKit;

#import "JLPermissionsCore+Internal.h"

@implementation JLCalendarPermissions {
  AuthorizationHandler _completion;
}

+ (instancetype)sharedInstance {
  static JLCalendarPermissions *_instance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{ _instance = [[JLCalendarPermissions alloc] init]; });

  return _instance;
}

#pragma mark - Calendar

- (BOOL)calendarAuthorized {
  return [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent] ==
         EKAuthorizationStatusAuthorized;
}

- (void)authorizeCalendar:(AuthorizationHandler)completion {
  [self authorizeCalendarWithTitle:[self defaultTitle:@"Calendar"]
                           message:[self defaultMessage]
                       cancelTitle:[self defaultCancelTitle]
                        grantTitle:[self defaultGrantTitle]
                        completion:completion];
}

- (void)authorizeCalendarWithTitle:(NSString *)messageTitle
                           message:(NSString *)message
                       cancelTitle:(NSString *)cancelTitle
                        grantTitle:(NSString *)grantTitle
                        completion:(AuthorizationHandler)completion {
  EKAuthorizationStatus authorizationStatus =
      [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];

  switch (authorizationStatus) {
    case EKAuthorizationStatusAuthorized: {
      if (completion) {
        completion(true, nil);
      }
    } break;
    case EKAuthorizationStatusNotDetermined: {
      _completion = completion;
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:messageTitle
                                                      message:message
                                                     delegate:self
                                            cancelButtonTitle:cancelTitle
                                            otherButtonTitles:grantTitle, nil];
      [alert show];
    } break;
    case EKAuthorizationStatusRestricted:
    case EKAuthorizationStatusDenied: {
      if (completion) {
        completion(false, [self previouslyDeniedError]);
      }
    } break;
  }
}

- (void)displayCalendarErrorDialog {
  [self displayErrorDialog:@"Calendars"];
}

- (void)actuallyAuthorize {
  EKAuthorizationStatus authorizationStatus =
      [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];

  switch (authorizationStatus) {
    case EKAuthorizationStatusAuthorized: {
      if (_completion) {
        _completion(true, nil);
      }
    } break;
    case EKAuthorizationStatusNotDetermined: {
      EKEventStore *eventStore = [[EKEventStore alloc] init];
      [eventStore requestAccessToEntityType:EKEntityTypeEvent
                                 completion:^(BOOL granted, NSError *error) {
                                     if (_completion) {
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           if (granted) {
                                             _completion(true, nil);
                                           } else {
                                             _completion(false, [self systemDeniedError:error]);
                                           }
                                       });
                                     }
                                 }];
    } break;
    case EKAuthorizationStatusRestricted:
    case EKAuthorizationStatusDenied: {
      if (_completion) {
        _completion(false, [self previouslyDeniedError]);
      }
    } break;
  }
}

- (void)canceledAuthorization:(NSError *)error {
  if (_completion) {
    _completion(false, error);
  }
}

@end
