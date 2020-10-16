#import <UIKit/UIKit.h>
#import "STHTTPRequest.h"

NSString *challengeReponseId;

BOOL loginDoOrig = false;

@interface RobinhoodLoginViewController: UIViewController
    - (void) sendCode:(NSString*)code forChallengeId:(NSString*)challengeId;
    - (void) didTapLoginButton;
@end

%hook RobinhoodLoginViewController
    %new
    - (void) sendCode:(NSString*)code forChallengeId:(NSString*)challengeId {
        NSString *challengeReponseURLString = [NSString stringWithFormat: @"https://api.robinhood.com/challenge/%@/respond/", challengeId];

        STHTTPRequest *req = [STHTTPRequest requestWithURLString: challengeReponseURLString];

        [req setHeaderWithName: @"User-Agent" value: @"Robinhood/8.49.0 (com.robinhood.release.Robinhood; build:15222; iOS 13.2) Alamofire/8.49.0"];

        NSDictionary *reqData = @{
			@"device_label": @"iPhone - iPhone",
            @"device_token": [[[UIDevice currentDevice] identifierForVendor] UUIDString],
            @"response"    : code
		};

        NSError *jsonEncodingError = nil;
		NSData *reqJson = [NSJSONSerialization dataWithJSONObject: reqData
                                                   options: kNilOptions
                                                     error: &jsonEncodingError];

		[req setHeaderWithName: @"content-type" value: @"application/json; charset=utf-8"];

		req.rawPOSTData = reqJson;

        req.completionBlock = ^(NSDictionary *headers, NSString *body) {
			NSError* jsonDecodingError;
			NSData *resData = [body dataUsingEncoding: NSUTF8StringEncoding];
			NSDictionary* json = (NSDictionary*) [NSJSONSerialization JSONObjectWithData: resData options: kNilOptions error: &jsonDecodingError];
			if (jsonDecodingError != nil) {
				return;
			}

            if ([json objectForKey: @"status"]) {
                NSString *status = (NSString*) [json objectForKey: @"status"];
                if (![status isEqual: @"validated"]) {
                    UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"Wrong code"
                                                                            message: @"You entered the wrong code"
                                                                            preferredStyle: UIAlertControllerStyleAlert];

                    [alertController addAction:[UIAlertAction actionWithTitle: @"Close" style: UIAlertActionStyleDefault handler: nil]];

                    [((UIViewController*) self) presentViewController: alertController animated: true completion: nil];

                    return;
                }
            } else {
                return;
            }

            challengeReponseId = challengeId;
            loginDoOrig = true;
            [self didTapLoginButton];
        };

        req.errorBlock = ^(NSError *error) {
            UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"An error occured"
                                                                    message: error.localizedDescription
                                                                    preferredStyle: UIAlertControllerStyleAlert];

            [alertController addAction:[UIAlertAction actionWithTitle: @"Close" style: UIAlertActionStyleDefault handler: nil]];

            [((UIViewController*) self) presentViewController: alertController animated: true completion: nil];
		};

		[req startAsynchronous];
    }

    - (void) didTapLoginButton {
        if (loginDoOrig) {
            %orig;
            return;
        }

        UITextField *passwordField;
        UITextField *usernameField;

        for (UIView *subview in [((UIView*) [self valueForKey: @"view"]) subviews]) {
            if ([subview isKindOfClass: NSClassFromString(@"Robinhood.ButtonTextField")]) {
                passwordField = (UITextField*) subview;
            } else if ([subview isKindOfClass: %c(RHTextField)]) {
                usernameField = (UITextField*) subview;
            }
        }

        if (!passwordField || !usernameField) {
            return;
        }

        STHTTPRequest *req = [STHTTPRequest requestWithURLString: @"https://api.robinhood.com/oauth2/token/"];

        [req setHeaderWithName: @"User-Agent" value: @"Robinhood/8.49.0 (com.robinhood.release.Robinhood; build:15222; iOS 13.2) Alamofire/8.49.0"];

		NSDictionary *reqData = @{
			@"device_label": @"iPhone - iPhone",
            @"scope"       : @"internal",
            @"grant_type"  : @"password",
            @"client_id"   : @"c82SH0WZOsabOXGP2sxqcj34FxkvfnWRZBKlBjFS",
            @"username"    : usernameField.text,
            @"password"    : passwordField.text,
            @"device_token": [[[UIDevice currentDevice] identifierForVendor] UUIDString]
		};

		NSError *jsonEncodingError = nil;
		NSData *reqJson = [NSJSONSerialization dataWithJSONObject: reqData
                                                   options: kNilOptions
                                                     error: &jsonEncodingError];

		[req setHeaderWithName: @"content-type" value: @"application/json; charset=utf-8"];

		req.rawPOSTData = reqJson;

		req.completionBlock = ^(NSDictionary *headers, NSString *body) {
			NSError* jsonDecodingError;
			NSData *resData = [body dataUsingEncoding: NSUTF8StringEncoding];
			NSDictionary* json = (NSDictionary*) [NSJSONSerialization JSONObjectWithData: resData options: kNilOptions error: &jsonDecodingError];
			if (jsonDecodingError != nil) {
				return;
			}

            if ([json objectForKey: @"challenge"]) {
                NSDictionary *challenge = (NSDictionary*) [json objectForKey: @"challenge"];
                NSString *challengeId = [challenge objectForKey: @"id"];

                UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"SMS Code"
                                                                        message: @"A code should've been sent to your phone. Please enter it here to sign in."
                                                                        preferredStyle: UIAlertControllerStyleAlert];

                [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                    textField.placeholder = @"Code";
                    textField.borderStyle = UITextBorderStyleRoundedRect;
                }];

                [alertController addAction:[UIAlertAction actionWithTitle:@"Verify code" style: UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    UITextField *codeField = alertController.textFields[0];
                    NSString *code = codeField.text;

                    [self sendCode: code forChallengeId: challengeId];
                }]];

                [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style: UIAlertActionStyleCancel handler: nil]];

                [((UIViewController*) self) presentViewController: alertController animated: true completion: nil];
            } else {
                %orig;
            }
		};

		req.errorBlock = ^(NSError *error) {
            UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"An error occured"
                                                                    message: error.localizedDescription
                                                                    preferredStyle: UIAlertControllerStyleAlert];

            [alertController addAction:[UIAlertAction actionWithTitle: @"Close" style: UIAlertActionStyleDefault handler: nil]];

            [((UIViewController*) self) presentViewController: alertController animated: true completion: nil];
		};

		[req startAsynchronous];
    }
%end

%hook NSMutableURLRequest
    - (void) setHTTPBody:(NSData*)reqData {
        if (![reqData isKindOfClass: [NSData class]]) {
            %orig(reqData);
            return;
        }
        NSError *jsonDecodingError;
        NSDictionary *uJson = (NSDictionary*) [NSJSONSerialization JSONObjectWithData: [reqData copy] options: kNilOptions error: &jsonDecodingError];
        if (jsonDecodingError || !uJson || ![uJson isKindOfClass: [NSDictionary class]]) {
            %orig(reqData);
            return;
        }

        NSMutableDictionary *json = [uJson mutableCopy];

        if ([json objectForKey: @"scope"]) {
            json[@"device_token"] = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
            json[@"device_label"] = @"iPhone - iPhone";

            if (challengeReponseId) {
                [self addValue: challengeReponseId forHTTPHeaderField: @"X-Robinhood-Challenge-Response-ID"];
            }
        }

        NSError *jsonEncodingError;
        %orig([NSJSONSerialization dataWithJSONObject: [json copy]
                  options: NSJSONWritingPrettyPrinted error: &jsonEncodingError]);
    }
%end

%hook NSBundle
    - (NSDictionary*) infoDictionary {
        NSMutableDictionary* hd = [%orig mutableCopy];

        hd[@"CFBundleShortVersionString"] = @"8.49.0";
        hd[@"CFBundleVersion"] = @"15222";

        return [hd copy];
    }
%end

%ctor {
    %init(RobinhoodLoginViewController = NSClassFromString(@"Robinhood.LoginViewController"));
}
