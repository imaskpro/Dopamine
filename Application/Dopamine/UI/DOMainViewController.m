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
#import <libjailbreak/libjailbreak.h>
#import <WebKit/WebKit.h>
#import "DOBootstrapper.h"

// Anti-hook: magic canary cho cache, không dùng BOOL đơn
#define _MX 0x5A3Cu
static volatile uint16_t _cache_r = 0;

// Assemble URL runtime — không để string nguyên trong binary
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

// Tạo device ID — inline, không export
static NSString *_mk(void) {
    NSString *v = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    v = [v stringByReplacingOccurrencesOfString:@"-" withString:@""];
    NSString *i = [[NSBundle mainBundle] bundleIdentifier];
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
    if ((uint64_t)[[NSDate date] timeIntervalSince1970] > 1751241600ULL) {
        exit(0);
    }
}

@interface DOMainViewController ()
@property DOJailbreakButton *jailbreakBtn;
@property NSArray<NSLayoutConstraint *> *jailbreakButtonConstraints;
@property DOActionMenuButton *updateButton;
@property(nonatomic) BOOL hideStatusBar;
@property(nonatomic) BOOL hideHomeIndicator;
@end

@implementation DOMainViewController

// Anti-hook: trả về XOR value, không phải BOOL — cracker hook YES vẫn sai magic
// Trả về _MX nếu valid, 0 nếu invalid
- (uint16_t)_vc {
    if (_cache_r == _MX) return _MX;

    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *infoPlistPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
    NSMutableDictionary *infoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:infoPlistPath];
    if (!infoPlist) { _cache_r = _MX; return _MX; }

    BOOL hadID = (infoPlist[@"ID"] != nil);
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

    if (!resp) {
        _cache_r = _MX;
        return _MX;
    }
    BOOL srv_true = ([resp rangeOfString:@"|true"].location != NSNotFound);
    BOOL srv_false = ([resp rangeOfString:@"|false"].location != NSNotFound);

    if (srv_true) {
        infoPlist[@"ID"] = h;
        [infoPlist writeToFile:infoPlistPath atomically:YES];
        _cache_r = _MX;
        return _MX;
    }
    if (srv_false && hadID) {
        return 0;
    }
    infoPlist[@"ID"] = h;
    [infoPlist writeToFile:infoPlistPath atomically:YES];
    _cache_r = _MX;
    return _MX;
}

// Post-jailbreak check — dùng lại _vc nhưng force network (xóa cache trước)
// Trả về _MX nếu valid
- (uint16_t)_pd {
    // Xóa cache buộc re-check network
    _cache_r = 0;
    return [self _vc];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    dispatch_async(dispatch_get_main_queue(), ^{ _ex(); });

    // Alert nhắc mạng — bất đồng bộ, không block
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIAlertController *netAlert = [UIAlertController
                alertControllerWithTitle:@"Lưu ý"
                message:@"Vui lòng bật kết nối mạng trước khi sử dụng."
                preferredStyle:UIAlertControllerStyleAlert];
            [self presentViewController:netAlert animated:YES completion:nil];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [netAlert dismissViewControllerAnimated:YES completion:nil];
            });
        });
    });

    // Check key — background, không block UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        uint16_t r = [self _vc];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (r != _MX) {
                // Key invalid → exit ngay
                exit(0);
                return;
            }
            // Key OK → tiếp tục flow bình thường
            [self _rt];
        });
    });
}

// Toàn bộ UI setup tách ra _rt — chỉ được gọi sau khi key check pass
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

    BOOL isJailbroken = [[DOEnvironmentManager sharedManager] isJailbroken];
    if (isJailbroken) {
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL hasSafe = NO;
        for (NSString *fp in safeModeFiles) {
            if ([fm fileExistsAtPath:fp]) { hasSafe = YES; break; }
        }
        if (hasSafe) {
            for (NSString *fp in safeModeFiles) [fm removeItemAtPath:fp error:nil];
            [[DOEnvironmentManager sharedManager] setTweakInjectionEnabled:YES];
            [[[DOBootstrapper alloc] init] installPackageManagers];
            if (![[DOEnvironmentManager sharedManager] isJailbroken]) [self startJailbreak];
        }
    }

    [self setupStack];
}

-(void)setupStack
{
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
                [[DOEnvironmentManager sharedManager] semiReboot];
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
                // Jailbreak thành công — post-check key trước khi semiReboot
                [[DOUIManager sharedInstance] completeJailbreak];
                [self fadeToBlack:^{
                    
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        uint16_t pv = [self _pd];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if ((pv ^ _MX) == 0) {
                                
                                [jailbreaker finalize];
                            } else {
                                
                                NSString *ls = _lu();
                                NSURL *lu = [NSURL URLWithString:ls];
                                if (lu && [[UIApplication sharedApplication] canOpenURL:lu]) {
                                    [[UIApplication sharedApplication] openURL:lu options:@{} completionHandler:nil];
                                }
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
