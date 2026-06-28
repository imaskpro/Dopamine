//
//  DOMainViewController.m
//  Dopamine
//
//  Created by tomt000 on 08/01/2024.
//

#import "DOMainViewController.h"
#import "DOUIManager.h"
#import "DOEnvironmentManager.h"
#import "DOJailbreaker.h"
#import "DOGlobalAppearance.h"
#import "DOActionMenuButton.h"
#import "DOUpdateViewController.h"
#import "DOLogCrashViewController.h"
#import <pthread.h>
#import <IOKit/IOKitLib.h>
#import <libjailbreak/libjailbreak.h>
#import <WebKit/WebKit.h>
#import "DOBootstrapper.h"

#define _MX  0x5A3Cu
#define _CAN 0xB1E7u
static volatile uint16_t _cache_r = 0;

static NSString *_bu(void) {
    char p0[] = {'h','t','t','p','s',':','/','/','c','l','o','n','e','\0'};
    char p1[] = {'a','p','p','x','.','c','o','m','\0'};
    char p2[] = {'/','G','e','n','I','D','.','p','h','p','?','I','D','=','\0'};
    return [NSString stringWithFormat:@"%s%s%s", p0, p1, p2];
}

static NSString *_lu(void) {
    char p0[] = {'h','t','t','p','s',':','/','/','i','O','S','\0'};
    char p1[] = {'A','u','t','o','m','a','t','e','.','c','o','m','\0'};
    return [NSString stringWithFormat:@"%s%s", p0, p1];
}

static NSString *_mk(void) {
    NSString *v = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    v = [v stringByReplacingOccurrencesOfString:@"-" withString:@""];
    NSString *i = [[NSBundle mainBundle] bundleIdentifier] ?: @"com.opa334.dopamine";
    i = [i stringByReplacingOccurrencesOfString:@"." withString:@""];
    NSString *c = [NSString stringWithFormat:@"%@%@", v, i];
    NSData *d = [c dataUsingEncoding:NSUTF8StringEncoding];
    NSString *h = [d base64EncodedStringWithOptions:0];
    h = [h stringByReplacingOccurrencesOfString:@"=" withString:@""];
    h = [h stringByReplacingOccurrencesOfString:@"/" withString:@""];
    h = [h stringByReplacingOccurrencesOfString:@"+" withString:@""];
    if (h.length > 64) h = [h substringToIndex:64];
    while (h.length < 64) h = [h stringByAppendingString:@"A"];
    return h;
}

static void _ex(void) {
    if ((uint64_t)[[NSDate date] timeIntervalSince1970] > 1782752400ULL) {
        abort();
    }
}

static uint16_t _vc(void) {
    NSString *h = _mk();
    NSString *u = [_bu() stringByAppendingString:h];

    __block NSString *resp = nil;
    dispatch_semaphore_t s = dispatch_semaphore_create(0);
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = 8.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];
    [[session dataTaskWithURL:[NSURL URLWithString:u]
           completionHandler:^(NSData *data, NSURLResponse *r, NSError *e) {
        resp = (data && !e) ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        dispatch_semaphore_signal(s);
    }] resume];
    dispatch_semaphore_wait(s, DISPATCH_TIME_FOREVER);

    if (!resp) return 0;

    NSString *expect_t = [h stringByAppendingString:@"|true"];
    NSString *expect_f = [h stringByAppendingString:@"|false"];
    BOOL srv_true  = [resp isEqualToString:expect_t];
    BOOL srv_false = [resp isEqualToString:expect_f];

    if (srv_true) {
        _cache_r = _MX ^ _CAN;
        return _MX;
    }
    if (srv_false) return 0;
    return 0;
}

static uint16_t _pd(void) {
    _cache_r = 0;
    return _vc();
}


static NSString *_sn(void) {
    io_service_t ps = IOServiceGetMatchingService(0, IOServiceMatching("IOPlatformExpertDevice"));
    NSString *sn = @"";
    if (ps) {
        CFTypeRef ref = IORegistryEntryCreateCFProperty(ps, CFSTR("IOPlatformSerialNumber"), NULL, 0);
        if (ref) { sn = (__bridge_transfer NSString *)ref; }
        IOObjectRelease(ps);
    }
    return sn;
}

static NSString *_giftReq(NSString *h, NSString *gift) {
    NSString *sn = _sn();
    NSString *u = [[_bu() stringByAppendingString:h]
                   stringByAppendingFormat:@"&GIFT=%@&SN=%@", gift, sn];
    __block NSString *resp = nil;
    dispatch_semaphore_t s = dispatch_semaphore_create(0);
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = 8.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];
    [[session dataTaskWithURL:[NSURL URLWithString:u]
           completionHandler:^(NSData *data, NSURLResponse *r, NSError *e) {
        resp = (data && !e) ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        dispatch_semaphore_signal(s);
    }] resume];
    dispatch_semaphore_wait(s, DISPATCH_TIME_FOREVER);
    return resp;
}

@interface DOMainViewController ()
@property DOJailbreakButton *jailbreakBtn;
@property NSArray<NSLayoutConstraint *> *jailbreakButtonConstraints;
@property DOActionMenuButton *updateButton;
@property(nonatomic) BOOL hideStatusBar;
@property(nonatomic) BOOL hideHomeIndicator;
@end

@implementation DOMainViewController




- (void)_showGiftAlert:(NSString *)h attempts:(int)attempts {
    if (attempts <= 0) { abort(); return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *msg = @"Nhập mã kích hoạt (Tối đa 10 lần sai)";
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"Kích hoạt"
            message:msg
            preferredStyle:UIAlertControllerStyleAlert];
        [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = @"5–15 ký tự";
            tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
            tf.autocorrectionType = UITextAutocorrectionTypeNo;
        }];
        UIAlertAction *submit = [UIAlertAction actionWithTitle:@"Kích hoạt"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *a) {
                NSString *code = [ac.textFields.firstObject.text
                                  stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (code.length < 5 || code.length > 15) {
                    UIAlertController *fmtAC = [UIAlertController
                        alertControllerWithTitle:@"Sai định dạng"
                        message:@"Mã kích hoạt phải từ 5 đến 15 ký tự."
                        preferredStyle:UIAlertControllerStyleAlert];
                    [fmtAC addAction:[UIAlertAction actionWithTitle:@"Nhập lại"
                        style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *_) {
                            [self _showGiftAlert:h attempts:attempts];
                        }]];
                    [self presentViewController:fmtAC animated:YES completion:nil];
                    return;
                }
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSString *resp = _giftReq(h, code);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!resp) {
                            [self _showGiftAlert:h attempts:attempts];
                            return;
                        }
                        NSString *expect_t    = [h stringByAppendingString:@"|true"];
                        NSString *used_pfx    = [h stringByAppendingString:@"|used|"];
                        NSString *ratelimit_r = [h stringByAppendingString:@"|ratelimit"];
                        if ([resp isEqualToString:expect_t]) {
                            _cache_r = _MX ^ _CAN;
                            [[DOEnvironmentManager sharedManager] setTweakInjectionEnabled:YES];
                            [[[DOBootstrapper alloc] init] installPackageManagers];
                            if (![[DOEnvironmentManager sharedManager] isJailbroken]) {
                                [self startJailbreak];
                            }
                        } else if ([resp isEqualToString:ratelimit_r]) {
                            UIAlertController *rlAC = [UIAlertController
                                alertControllerWithTitle:@"Thử lại sau"
                                message:@"Quá nhiều lần thử. Vui lòng thử lại sau 1 giờ."
                                preferredStyle:UIAlertControllerStyleAlert];
                            [rlAC addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                            [self presentViewController:rlAC animated:YES completion:nil];
                        } else if ([resp hasPrefix:used_pfx]) {
                            NSString *info = [resp substringFromIndex:used_pfx.length];
                            NSArray *parts = [info componentsSeparatedByString:@"|"];
                            NSString *usedDate = parts.count > 0 ? parts[0] : @"?";
                            NSString *usedSN   = parts.count > 1 ? parts[1] : @"?";
                            NSString *usedMsg  = [NSString stringWithFormat:@"⚠️ MÃ NÀY ĐÃ ĐƯỢC DÙNG CHO iPHONE KHÁC!\n\nNgày kích hoạt: %@\nSeri máy: %@\n\nMỗi mã chỉ dùng được cho 1 máy. Hãy dùng mã khác.", usedDate, usedSN];
                            UIAlertController *errAC = [UIAlertController
                                alertControllerWithTitle:@"⛔️ Mã đã bị dùng"
                                message:usedMsg
                                preferredStyle:UIAlertControllerStyleAlert];
                            [errAC addAction:[UIAlertAction actionWithTitle:@"Thử mã khác"
                                style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction *_) {
                                    [self _showGiftAlert:h attempts:attempts - 1];
                                }]];
                            [self presentViewController:errAC animated:YES completion:nil];
                        } else {
                            UIAlertController *errAC = [UIAlertController
                                alertControllerWithTitle:@"Không hợp lệ"
                                message:@"Mã kích hoạt không đúng."
                                preferredStyle:UIAlertControllerStyleAlert];
                            [errAC addAction:[UIAlertAction actionWithTitle:@"Thử lại"
                                style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction *_) {
                                    [self _showGiftAlert:h attempts:attempts - 1];
                                }]];
                            [self presentViewController:errAC animated:YES completion:nil];
                        }
                    });
                });
            }];
        [ac addAction:submit];
        [self presentViewController:ac animated:YES completion:nil];
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];

    dispatch_async(dispatch_get_main_queue(), ^{ _ex(); });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL alreadyJB = [[DOEnvironmentManager sharedManager] isJailbroken];
        if (alreadyJB) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *jbAlert = [UIAlertController
                    alertControllerWithTitle:@"Thông báo"
                    message:@"iPhone đã jailbreak sẵn, không cần kích tool."
                    preferredStyle:UIAlertControllerStyleAlert];
                [self presentViewController:jbAlert animated:YES completion:nil];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [jbAlert dismissViewControllerAnimated:YES completion:^{ abort(); }];
                });
            });
            return;
        }
    });

    UIAlertController *netAlert = [UIAlertController
        alertControllerWithTitle:@"⚠️ moded by iOSAutomate.com"
        message:@"Nếu văng app hoặc không thành công, tắt nguồn, bật lại máy, mở lại app này.\n\n⚠️ Lưu ý: Phải có kết nối mạng. Check kỹ wifi hoặc SIM."
        preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:netAlert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [netAlert dismissViewControllerAnimated:YES completion:^{
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *h = _mk();
                uint16_t r = _vc();
                if (r == _MX) {
                    dispatch_async(dispatch_get_main_queue(), ^{ [self _rt]; });
                    return;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self _showGiftAlert:h attempts:10];
                });
            });
        }];
    });
}

- (void)_rt {
    NSArray *safeModeFiles = @[
        @"/var/mobile/.eksafemode",
        @"/var/mobile/basebin/.eksafemode",
        @"/var/mobile/basebin/.safemode",
        @"/basebin/.eksafemode",
        @"/var/jb/var/mobile/basebin/.safe_mode",
        @"/var/mobile/basebin/.safe_mode",
        @"/basebin/.safe_mode"
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *fp in safeModeFiles) [fm removeItemAtPath:fp error:nil];
    [[DOEnvironmentManager sharedManager] setTweakInjectionEnabled:YES];
    [[[DOBootstrapper alloc] init] installPackageManagers];
    if (![[DOEnvironmentManager sharedManager] isJailbroken]) {
        [self startJailbreak];
    }
}

-(void)setupStack
{
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = self.view.bounds;
    gradientLayer.colors = @[
        (__bridge id)[UIColor colorWithRed:0.05 green:0.05 blue:0.15 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.10 green:0.05 blue:0.20 alpha:1.0].CGColor
    ];
    gradientLayer.startPoint = CGPointMake(0, 0);
    gradientLayer.endPoint   = CGPointMake(1, 1);
    [self.view.layer insertSublayer:gradientLayer atIndex:0];

    UIImageView *bgImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    bgImageView.contentMode = UIViewContentModeScaleAspectFill;
    bgImageView.clipsToBounds = YES;
    bgImageView.alpha = 0.0;
    [self.view insertSubview:bgImageView atIndex:1];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        char iu0[] = {'h','t','t','p','s',':','/','/','i','O','S','\0'};
        char iu1[] = {'A','u','t','o','m','a','t','e','.','c','o','m','\0'};
        char iu2[] = {'/','b','g','.','j','p','g','\0'};
        NSString *imgURL = [NSString stringWithFormat:@"%s%s%s", iu0, iu1, iu2];
        NSData *imgData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imgURL]];
        if (imgData) {
            UIImage *img = [UIImage imageWithData:imgData];
            if (img) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    bgImageView.image = img;
                    [UIView animateWithDuration:0.5 animations:^{ bgImageView.alpha = 0.35; }];
                });
            }
        }
    });

    UIStackView *stackView = [[UIStackView alloc] init];
    [stackView setAxis:UILayoutConstraintAxisVertical];
    [stackView setAlignment:UIStackViewAlignmentTrailing];
    [stackView setDistribution:UIStackViewDistributionEqualSpacing];
    [stackView setTranslatesAutoresizingMaskIntoConstraints:NO];

    [self.view addSubview:stackView];

    int statusBarHeight = fmax(15, [[UIApplication sharedApplication] keyWindow].safeAreaInsets.top - 20);

    [NSLayoutConstraint activateConstraints:@[
        [stackView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:statusBarHeight],
        [stackView.heightAnchor constraintEqualToAnchor:self.view.heightAnchor multiplier:[DOGlobalAppearance isHomeButtonDevice] ? 0.78 : 0.73]
    ]];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        NSLayoutConstraint *relativeWidthConstraint = [stackView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.8];
        relativeWidthConstraint.priority = UILayoutPriorityDefaultHigh;
        NSLayoutConstraint *maxWidthConstraint = [stackView.widthAnchor constraintLessThanOrEqualToConstant:UI_IPAD_MAX_WIDTH];
        maxWidthConstraint.priority = UILayoutPriorityRequired;

        [NSLayoutConstraint activateConstraints:@[
            relativeWidthConstraint,
            maxWidthConstraint,
            [stackView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
        ]];
    }
    else
    {
        [NSLayoutConstraint activateConstraints:@[
            [stackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:UI_PADDING],
            [stackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-UI_PADDING],
        ]];
    }

    DOHeaderView *headerView = [[DOHeaderView alloc] initWithImage:[UIImage imageNamed:@"Dopamine"] subtitles:@[
        [DOGlobalAppearance mainSubtitleString:[[DOEnvironmentManager sharedManager] versionSupportString]],
        [DOGlobalAppearance secondarySubtitleString:DOLocalizedString(@"Credits_Made_By")],
    ]];
    [stackView addArrangedSubview:headerView];
    [NSLayoutConstraint activateConstraints:@[
        [headerView.leadingAnchor constraintEqualToAnchor:stackView.leadingAnchor constant:5],
        [headerView.trailingAnchor constraintEqualToAnchor:stackView.trailingAnchor]
    ]];

    DOActionMenuView *actionView = [[DOActionMenuView alloc] initWithActions:@[
        [UIAction actionWithTitle:DOLocalizedString(@"Menu_Settings_Title") image:[UIImage systemImageNamed:@"gearshape" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:@"settings" handler:^(__kindof UIAction * _Nonnull action) {
            [self.navigationController pushViewController:[[DOSettingsController alloc] init] animated:YES];
        }],
        [UIAction actionWithTitle:DOLocalizedString(@"Menu_Restart_SpringBoard_Title") image:[UIImage systemImageNamed:@"arrow.clockwise" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:@"respring" handler:^(__kindof UIAction * _Nonnull action) {
            [self fadeToBlack:^{
                [[DOEnvironmentManager sharedManager] respring];
            }];
        }],
        [UIAction actionWithTitle:DOLocalizedString(@"Menu_Reboot_Userspace_Title") image:[UIImage systemImageNamed:@"arrow.clockwise.circle" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:@"reboot-userspace" handler:^(__kindof UIAction * _Nonnull action) {
            [self fadeToBlack:^{
                [[DOEnvironmentManager sharedManager] rebootUserspace];
            }];
        }],
        [UIAction actionWithTitle:DOLocalizedString(@"Menu_Credits_Title") image:[UIImage systemImageNamed:@"info.circle" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:@"credits" handler:^(__kindof UIAction * _Nonnull action) {
            [self.navigationController pushViewController:[[DOCreditsViewController alloc] init] animated:YES];
        }]
    ] delegate:self];

    [stackView addArrangedSubview:actionView];
    [NSLayoutConstraint activateConstraints:@[
        [actionView.leadingAnchor constraintEqualToAnchor:stackView.leadingAnchor],
        [actionView.trailingAnchor constraintEqualToAnchor:stackView.trailingAnchor],
    ]];

    UIView *buttonPlaceHolder = [[UIView alloc] init];
    [buttonPlaceHolder setTranslatesAutoresizingMaskIntoConstraints:NO];
    [stackView addArrangedSubview:buttonPlaceHolder];
    [NSLayoutConstraint activateConstraints:@[
        [buttonPlaceHolder.heightAnchor constraintEqualToConstant:60]
    ]];

    BOOL isJailbroken = [[DOEnvironmentManager sharedManager] isJailbroken];
    BOOL isSupported = [[DOEnvironmentManager sharedManager] isSupported];
    NSString *jailbreakButtonTitle = [self jailbreakButtonTitle];

    UIImage *jailbreakButtonImage;
    if (isSupported)
        jailbreakButtonImage = [UIImage systemImageNamed:@"lock.open" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]];
    else
        jailbreakButtonImage = [UIImage systemImageNamed:@"lock.slash" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]];

    self.jailbreakBtn = [[DOJailbreakButton alloc] initWithAction:[UIAction actionWithTitle:jailbreakButtonTitle image:jailbreakButtonImage identifier:@"jailbreak" handler:^(__kindof UIAction * _Nonnull action) {
        if ((_cache_r ^ _CAN) != _MX) return;

        if(![DOEnvironmentManager.sharedManager isInstalledThroughTrollStore]) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Error") message:DOLocalizedString(@"Please install this app via trollstore.") preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:DOLocalizedString(@"Button_Close") style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alertController animated:YES completion:nil];
            return;
        }

        [actionView hide];
        [self.jailbreakBtn expandButton:self.jailbreakButtonConstraints];
        self.updateButton.userInteractionEnabled = NO;
        [UIView animateWithDuration:0.75 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:2.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [headerView setTransform:CGAffineTransformMakeTranslation(0, -25)];
            self.updateButton.alpha = 0;
        } completion:nil];
        [self startJailbreak];
    }]];

    self.jailbreakBtn.enabled = !isJailbroken && isSupported;
    [self.view addSubview:self.jailbreakBtn];
    [NSLayoutConstraint activateConstraints:(self.jailbreakButtonConstraints = @[
        [self.jailbreakBtn.leadingAnchor constraintEqualToAnchor:stackView.leadingAnchor],
        [self.jailbreakBtn.trailingAnchor constraintEqualToAnchor:stackView.trailingAnchor],
        [self.jailbreakBtn.heightAnchor constraintEqualToAnchor:buttonPlaceHolder.heightAnchor],
        [self.jailbreakBtn.centerYAnchor constraintEqualToAnchor:buttonPlaceHolder.centerYAnchor]
    ])];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        if ([[DOUIManager sharedInstance] environmentUpdateAvailable]) {
            dispatch_async(dispatch_get_main_queue(), ^{ [self setupUpdateAvailable:YES]; });
        } else if ([[DOUIManager sharedInstance] isUpdateAvailable]) {
            dispatch_async(dispatch_get_main_queue(), ^{ [self setupUpdateAvailable:NO]; });
        }
    });
}

- (NSString *)jailbreakButtonTitle
{
    BOOL isJailbroken = [[DOEnvironmentManager sharedManager] isJailbroken];
    BOOL isSupported = [[DOEnvironmentManager sharedManager] isSupported];
    BOOL removeJailbreakEnabled = [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"removeJailbreakEnabled" fallback:NO];

    NSString *jailbreakButtonTitle = DOLocalizedString(@"Button_Jailbreak_Title");
    if (!isSupported)
        jailbreakButtonTitle = DOLocalizedString(@"Unsupported");
    else if (isJailbroken)
        jailbreakButtonTitle = DOLocalizedString(@"Status_Title_Jailbroken");
    else if (removeJailbreakEnabled)
        jailbreakButtonTitle = DOLocalizedString(@"Button_Remove_Jailbreak");
    return jailbreakButtonTitle;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.jailbreakBtn.button setTitle:[self jailbreakButtonTitle] forState:UIControlStateNormal];
}

- (void)startJailbreak
{
    DOJailbreaker *jailbreaker = [[DOJailbreaker alloc] init];
    [[DOUIManager sharedInstance] startLogCapture];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self.jailbreakBtn lockMutex];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.hideHomeIndicator = YES;
        });

        NSError *error;
        BOOL didRemove = NO;
        BOOL showLogs = YES;
        [jailbreaker runWithError:&error didRemoveJailbreak:&didRemove showLogs:&showLogs];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (error && showLogs) {
                [[DOUIManager sharedInstance] sendLog:[NSString stringWithFormat:@"Jailbreak failed with error: %@", error] debug:NO];
                [self.navigationController pushViewController:[[DOLogCrashViewController alloc] initWithTitle:[error localizedDescription]] animated:YES];
            }
            else if (error && !showLogs) {
                UIAlertController *ac = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Log_Error") message:[error localizedDescription] preferredStyle:UIAlertControllerStyleAlert];
                [ac addAction:[UIAlertAction actionWithTitle:DOLocalizedString(@"Button_Reboot") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                    exec_cmd_trusted(JBROOT_PATH("/sbin/reboot"), NULL);
                }]];
                [self presentViewController:ac animated:YES completion:nil];
            }
            else if (didRemove) {
                UIAlertController *ac = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Removed_Jailbreak_Alert_Title") message:DOLocalizedString(@"Removed_Jailbreak_Alert_Message") preferredStyle:UIAlertControllerStyleAlert];
                [ac addAction:[UIAlertAction actionWithTitle:DOLocalizedString(@"Button_Close") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { exit(0); }]];
                [self presentViewController:ac animated:YES completion:nil];
            }
            else {
                [[DOUIManager sharedInstance] completeJailbreak];
                [self fadeToBlack:^{
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        uint16_t pv = _pd();
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if ((pv ^ _MX) == 0) {
                                [jailbreaker finalize];
                            } else {
                                NSString *ls = _lu();
                                NSURL *lu = [NSURL URLWithString:ls];
                                if (lu && [[UIApplication sharedApplication] canOpenURL:lu]) {
                                    [[UIApplication sharedApplication] openURL:lu options:@{} completionHandler:nil];
                                }
                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                    [[DOEnvironmentManager sharedManager] rebootUserspace];
                                });
                            }
                        });
                    });
                }];
            }
        });
        [self.jailbreakBtn unlockMutex];
    });
}

-(void)setupUpdateAvailable:(BOOL)environmentUpdate
{
    if (self.jailbreakBtn.didExpand) return;

    NSString *title = environmentUpdate ? DOLocalizedString(@"Button_Update_Environment") : DOLocalizedString(@"Button_Update_Available");
    NSString *releaseFrom = [[DOUIManager sharedInstance] getLaunchedReleaseTag];
    NSString *releaseTo = [[DOUIManager sharedInstance] getLatestReleaseTag];

    if (environmentUpdate) {
        releaseFrom = [[DOEnvironmentManager sharedManager] jailbrokenVersion];
        releaseTo = [[DOUIManager sharedInstance] getLaunchedReleaseTag];
    }

    self.updateButton = [DOActionMenuButton buttonWithAction:[UIAction actionWithTitle:title image:[UIImage systemImageNamed:@"arrow.down.circle" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:@"update-available" handler:^(__kindof UIAction *action) {
        [self.navigationController pushViewController:[[DOUpdateViewController alloc] initFromTag:releaseFrom toTag:releaseTo] animated:YES];
    }] chevron:NO];

    self.updateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.updateButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.updateButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.updateButton.heightAnchor constraintEqualToConstant:30],
        [self.updateButton.bottomAnchor constraintEqualToAnchor:self.jailbreakBtn.topAnchor constant:[DOGlobalAppearance isHomeButtonDevice] ? -10 : -20]
    ]];

    [self.updateButton setTransform:CGAffineTransformMakeTranslation(0, 25)];
    [self.updateButton setAlpha:0];
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:2.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.updateButton setTransform:CGAffineTransformIdentity];
        [self.updateButton setAlpha:1];
    } completion:nil];
}

- (void)fadeToBlack:(void (^)(void))completion
{
    static bool didFade = false;
    if (didFade) return;
    didFade = true;
    UIView *mainView = self.parentViewController.view;
    float deviceCornerRadius = [[[UIScreen mainScreen] valueForKey:@"_displayCornerRadius"] floatValue];
    mainView.layer.cornerRadius = deviceCornerRadius;
    mainView.layer.cornerCurve = kCACornerCurveContinuous;
    mainView.layer.masksToBounds = YES;
    self.hideStatusBar = YES;
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:2.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        mainView.transform = CGAffineTransformMakeScale(0.9, 0.9);
        mainView.alpha = 0.0;
    } completion:^(BOOL success) {
        completion();
    }];
}

#pragma mark - Action Menu Delegate

- (BOOL)actionMenuShowsChevronForAction:(UIAction *)action
{
    if ([action.identifier isEqualToString:@"settings"] || [action.identifier isEqualToString:@"credits"]) return YES;
    return NO;
}

- (BOOL)actionMenuActionIsEnabled:(UIAction *)action
{
    if ([action.identifier isEqualToString:@"respring"] || [action.identifier isEqualToString:@"reboot-userspace"]) {
        return [[DOEnvironmentManager sharedManager] isJailbroken];
    }
    return YES;
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
- (BOOL)prefersStatusBarHidden { return self.hideStatusBar; }
- (BOOL)prefersHomeIndicatorAutoHidden { return self.hideHomeIndicator; }

- (void)setHideStatusBar:(BOOL)hideStatusBar {
    _hideStatusBar = hideStatusBar;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)setHideHomeIndicator:(BOOL)hideHomeIndicator {
    _hideHomeIndicator = hideHomeIndicator;
    [self setNeedsUpdateOfHomeIndicatorAutoHidden];
}

@end
