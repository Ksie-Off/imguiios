//
//  AppDelegate.mm
//  imgui
//

#import "AppDelegate.h"
#import "ImGuiViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[ImGuiViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
