/*
 Erica Sadun, http://ericasadun.com
 iPhone Developer's Cookbook, 3.0 Edition
 BSD License for anything not specifically marked as developed by a third party.
 Apple's code excluded.
 Use at your own risk
 */

#import <SystemConfiguration/SystemConfiguration.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <net/if.h>
#include <ifaddrs.h>
#import "UIDevice_Extended.h"

SCNetworkConnectionFlags connectionFlags;

@implementation UIDevice (Reachability)
// Matt Brown's get WiFi IP addy solution
// http://mattbsoftware.blogspot.com/2009/04/how-to-get-ip-address-of-iphone-os-v221.html
+ (NSString *) ipAddressWithPredicate:(NSPredicate *)isMatchNetworkInterfaceName
{
	BOOL success;
    NSString * wifiIPAddress = nil;
	struct ifaddrs * addrList = NULL;
	const struct ifaddrs * cursor;
	
	success = getifaddrs(&addrList) == 0;
	if (success)
    {
        for (cursor = addrList; cursor != NULL; cursor = cursor->ifa_next)
        {
			// the second test keeps from picking up the loopback address
			if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0) 
			{
				NSString *name = @(cursor->ifa_name);

				if ([isMatchNetworkInterfaceName evaluateWithObject:name])
				{
					wifiIPAddress = [NSString stringWithUTF8String:
                                     (inet_ntoa(((struct sockaddr_in *)cursor->ifa_addr)->sin_addr))];
                    break;
                }
			}
		}
        
		freeifaddrs(addrList);
	}
	return wifiIPAddress;
}

+ (NSString *) localWiFiIPAddress
{
    NSString * wifiIPAddress = nil;

    NSPredicate * isMatchWIFIInterfaceName = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"en\\d+"];
    // Get wifi adapter IP adress
    wifiIPAddress = [[self class] ipAddressWithPredicate:isMatchWIFIInterfaceName];

    if (wifiIPAddress == nil)
    {
        // Get hotspot IP address, if the bridge presents
        NSPredicate * isMatchHotspotInterfaceName = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"bridge\\d+"];
        wifiIPAddress = [[self class] ipAddressWithPredicate:isMatchHotspotInterfaceName];
    }

    return wifiIPAddress;
}

#pragma mark Checking Connections

+ (void) pingReachabilityInternal
{
	BOOL ignoresAdHocWiFi = NO;
	struct sockaddr_in ipAddress;
	bzero(&ipAddress, sizeof(ipAddress));
	ipAddress.sin_len = sizeof(ipAddress);
	ipAddress.sin_family = AF_INET;
	ipAddress.sin_addr.s_addr = htonl(ignoresAdHocWiFi ? INADDR_ANY : IN_LINKLOCALNETNUM);
    
    // Recover reachability flags
    SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (struct sockaddr *)&ipAddress);    
    BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &connectionFlags);
    CFRelease(defaultRouteReachability);
	
	if (!didRetrieveFlags) 
	{
        LOG_NETWORK_SOCKS(NSLOGGER_LEVEL_ERROR, @"Error. Could not recover network reachability flags");
	}
}

+ (BOOL)isNetworkAvailable
{
	[self pingReachabilityInternal];
	
	BOOL isReachable = ((connectionFlags & kSCNetworkFlagsReachable) != 0);
    BOOL needsConnection = ((connectionFlags & kSCNetworkFlagsConnectionRequired) != 0);
	
    return (isReachable && !needsConnection) ? YES : NO;
}

+ (BOOL)hasActiveWWAN
{
	if (![self isNetworkAvailable]) 
			return NO;
	
	return ((connectionFlags & kSCNetworkReachabilityFlagsIsWWAN) != 0);
}

+ (BOOL) activeWLAN
{
	return ([UIDevice localWiFiIPAddress] != nil);
}
@end
