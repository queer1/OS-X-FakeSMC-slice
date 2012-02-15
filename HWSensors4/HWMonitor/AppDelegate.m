//
//  AppDelegate.m
//  HWMonitor
//
//  Created by mozo on 20.10.11.
//  Copyright (c) 2011 mozo. All rights reserved.
//

#import "AppDelegate.h"

#include "FakeSMCDefinitions.h"

@implementation AppDelegate

- (void)updateTitles
{
    io_service_t service = IOServiceGetMatchingService(0, IOServiceMatching(kFakeSMCDeviceService));
    
    if (service) {
        
        NSEnumerator * enumerator = nil;
        HWMonitorSensor * sensor = nil;
        int count = 0;
    
        CFMutableArrayRef favorites = (CFMutableArrayRef)CFArrayCreateMutable(kCFAllocatorDefault, 0, nil);
        
        enumerator = [sensorsList  objectEnumerator];
        
        while (sensor = (HWMonitorSensor *)[enumerator nextObject]) {
            if (isMenuVisible || [sensor favorite]) {
                CFTypeRef name = (CFTypeRef) CFStringCreateWithCString(kCFAllocatorDefault, [[sensor key] cStringUsingEncoding:NSASCIIStringEncoding], kCFStringEncodingASCII);
                
                CFArrayAppendValue(favorites, name);
            }
        }
        
        NSMutableString * statusString = [[NSMutableString alloc] init];
        
        if (kIOReturnSuccess == IORegistryEntrySetCFProperty(service, CFSTR(kFakeSMCDevicePopulateList), favorites)) 
        {           
            NSDictionary * values = (__bridge_transfer NSDictionary *)IORegistryEntryCreateCFProperty(service, CFSTR(kFakeSMCDeviceValues), kCFAllocatorDefault, 0);
            
            if (values) {
                
                enumerator = [sensorsList  objectEnumerator];
                
                while (sensor = (HWMonitorSensor *)[enumerator nextObject]) {
                    
                    if (isMenuVisible) {
                        NSString * value =[[NSString alloc] initWithString:[sensor formateValue:[values objectForKey:[sensor key]]]];
                        
                        NSMutableAttributedString * title = [[NSMutableAttributedString alloc] initWithString:[[NSString alloc] initWithFormat:@"%S\t%S",[[sensor caption] cStringUsingEncoding:NSUTF16StringEncoding],[value cStringUsingEncoding:NSUTF16StringEncoding]] attributes:statusMenuAttributes];
                        
                        [title addAttribute:NSFontAttributeName value:statusMenuFont range:NSMakeRange(0, [title length])];
                        
                        // Update menu item title
                        [(NSMenuItem *)[sensor object] setAttributedTitle:title];
                    }
                    
                    if ([sensor favorite]) {
                        NSString * value =[[NSString alloc] initWithString:[sensor formateValue:[values objectForKey:[sensor key]]]];
                        
                        [statusString appendString:@" "];
                        [statusString appendString:value];
                        
                        count++;
                    }
                }
            }
        }
        
        CFArrayRemoveAllValues(favorites);
        CFRelease(favorites);
        
        IOObjectRelease(service);
        
        if (count > 0) {
            // Update status bar title
            NSMutableAttributedString * title = [[NSMutableAttributedString alloc] initWithString:statusString attributes:statusItemAttributes];
            [title addAttribute:NSFontAttributeName value:statusItemFont range:NSMakeRange(0, [title length])];
            [statusItem setAttributedTitle:title];
        }
        else [statusItem setTitle:@""];
    }
}

- (HWMonitorSensor *)addSensorWithKey:(NSString *)key andCaption:(NSString *)caption intoGroup:(SensorGroup)group
{
    if ([HWMonitorSensor populateValueForKey:key]) {
        HWMonitorSensor * sensor = [[HWMonitorSensor alloc] initWithKey:key andGroup:group withCaption:caption];
        
        [sensor setFavorite:[[NSUserDefaults standardUserDefaults] boolForKey:key]];
        
        NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:caption action:nil keyEquivalent:@""];
        
        [menuItem setRepresentedObject:sensor];
        [menuItem setAction:@selector(menuItemClicked:)];
        
        if ([sensor favorite]) [menuItem setState:TRUE];
        
        [statusMenu insertItem:menuItem atIndex:menusCount++];
        
        [sensor setObject:menuItem];
        
        [sensorsList addObject:sensor];
        
        return sensor;
    }
    
    return NULL;
}

- (void)insertFooterAndTitle:(NSString *)title
{
    if (lastMenusCount < menusCount) {
        NSMenuItem * titleItem = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
        
        [titleItem setEnabled:FALSE];
        //[titleItem setIndentationLevel:1];
        
        [statusMenu insertItem:titleItem atIndex:lastMenusCount]; menusCount++;       
        [statusMenu insertItem:[NSMenuItem separatorItem] atIndex:menusCount++];
        
        lastMenusCount = menusCount;
    }
}

// Events

- (void)menuWillOpen:(NSMenu *)menu {
    isMenuVisible = YES;
    
    [self updateTitles];
}

- (void)menuDidClose:(NSMenu *)menu {
    isMenuVisible = NO;
}

- (void)menuItemClicked:(id)sender {
    NSMenuItem * menuItem = (NSMenuItem *)sender;
    
    [menuItem setState:![menuItem state]];
    
    HWMonitorSensor * sensor = (HWMonitorSensor *)[menuItem representedObject];
    
    [sensor setFavorite:[menuItem state]];
    
    [self updateTitles];
    
    [[NSUserDefaults standardUserDefaults] setBool:[menuItem state] forKey:[sensor key]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                [self methodSignatureForSelector:@selector(updateTitles)]];
    [invocation setTarget:self];
    [invocation setSelector:@selector(updateTitles)];
    [[NSRunLoop mainRunLoop] addTimer:[NSTimer timerWithTimeInterval:2 invocation:invocation repeats:YES] forMode:NSRunLoopCommonModes];
    
    [self updateTitles];
}

- (void)awakeFromNib
{
    menusCount = 0;
    
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
    [statusItem setImage:[NSImage imageNamed:@"thermo"]];
    [statusItem setAlternateImage:[NSImage imageNamed:@"thermotemplate"]];
    
    statusItemFont = [NSFont fontWithName:@"Lucida Grande Bold" size:9.0];
    
    NSMutableParagraphStyle * style = [[NSMutableParagraphStyle alloc] init];
    [style setLineSpacing:0];

    statusItemAttributes = [NSDictionary dictionaryWithObject:style forKey:NSParagraphStyleAttributeName];
    
    statusMenuFont = [NSFont fontWithName:@"Lucida Grande Bold" size:10];
    [statusMenu setFont:statusMenuFont];
    
    style = [[NSMutableParagraphStyle alloc] init];
    [style setTabStops:[NSArray array]];
    [style addTabStop:[[NSTextTab alloc] initWithType:NSRightTabStopType location:190.0]];
    //[style setDefaultTabInterval:390.0];
    statusMenuAttributes = [NSDictionary dictionaryWithObject:style forKey:NSParagraphStyleAttributeName];
    
    // Init sensors
    sensorsList = [[NSMutableArray alloc] init];
    lastMenusCount = menusCount;
    
    //Temperatures
    
    for (int i=0; i<0xA; i++)
        [self addSensorWithKey:[[NSString alloc] initWithFormat:@"TC%XD",i] andCaption:[[NSString alloc] initWithFormat:@"CPU %X",i] intoGroup:TemperatureSensorGroup];
    
    [self addSensorWithKey:@"Th0H" andCaption:@"CPU Heatsink" intoGroup:TemperatureSensorGroup];
    [self addSensorWithKey:@"TN0P" andCaption:@"Motherboard" intoGroup:TemperatureSensorGroup];
    [self addSensorWithKey:@"TA0P" andCaption:@"Ambient" intoGroup:TemperatureSensorGroup];
    
    for (int i=0; i<0xA; i++) {
        [self addSensorWithKey:[[NSString alloc] initWithFormat:@"TG%XD",i] andCaption:[[NSString alloc] initWithFormat:@"GPU %X Core",i] intoGroup:TemperatureSensorGroup];
        [self addSensorWithKey:[[NSString alloc] initWithFormat:@"TG%XH",i] andCaption:[[NSString alloc] initWithFormat:@"GPU %X Board",i] intoGroup:TemperatureSensorGroup];
        [self addSensorWithKey:[[NSString alloc] initWithFormat:@"TG%XP",i] andCaption:[[NSString alloc] initWithFormat:@"GPU %X Proximity",i] intoGroup:TemperatureSensorGroup];
    }
    
    [self insertFooterAndTitle:@"TEMPERATURES"];  
    
    //Multipliers
    
    for (int i=0; i<0xA; i++)
        [self addSensorWithKey:[[NSString alloc] initWithFormat:@"MC%XC",i] andCaption:[[NSString alloc] initWithFormat:@"CPU %X Multiplier",i] intoGroup:MultiplierSensorGroup];
    
    [self addSensorWithKey:@"MPkC" andCaption:@"CPU Package Multiplier" intoGroup:MultiplierSensorGroup];
    
    [self insertFooterAndTitle:@"MULTIPLIERS"];
    
    // Voltages

    [self addSensorWithKey:@"VC0C" andCaption:@"CPU Voltage" intoGroup:VoltageSensorGroup];
    [self addSensorWithKey:@"VM0R" andCaption:@"DIMM Voltage" intoGroup:VoltageSensorGroup];
    
    [self insertFooterAndTitle:@"VOLTAGES"];
    
    // Fans
    
    for (int i=0; i<10; i++)
        [self addSensorWithKey:[[NSString alloc] initWithFormat:@"F%XAc",i] andCaption:[[NSString alloc] initWithFormat:@"Fan %X",i] intoGroup:TachometerSensorGroup];
    
    [self insertFooterAndTitle:@"FANS"];
    
    if (![sensorsList count]) {
        NSMenuItem * item = [[NSMenuItem alloc]initWithTitle:@"No sensors found or FakeSMCDevice unavailable" action:nil keyEquivalent:@""];
        
        [item setEnabled:FALSE];
        
        [statusMenu insertItem:item atIndex:0];
    }
}

@end