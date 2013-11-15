#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDLib.h>
#include <stdlib.h>

#define OFF 0x00
#define BLUE 0x01
#define RED 0x02
#define GREEN 0x03
#define LTBLUE 0x04
#define PURPLE 0x05
#define YELLOW 0x06
#define WHITE 0x07
#define WAIT 0.05

void MyInputCallback(void *context, IOReturn result, void *sender, IOHIDReportType type, uint32_t reportID, uint8_t *report, CFIndex reportLength)
{
    //NSLog(@"MyInputCallback called");
    //process device response buffer (report) here
}

//http://developer.apple.com/library/mac/#documentation/DeviceDrivers/Conceptual/HID/new_api_10_5/tn2187.html
// function to get a long device property
// returns FALSE if the property isn't found or can't be converted to a long
static Boolean IOHIDDevice_GetLongProperty(IOHIDDeviceRef inDeviceRef, CFStringRef inKey, long * outValue)
{
    Boolean result = FALSE;
    CFTypeRef tCFTypeRef = IOHIDDeviceGetProperty(inDeviceRef, inKey);
    if (tCFTypeRef) {
        // if this is a number
        if (CFNumberGetTypeID() == CFGetTypeID(tCFTypeRef)) {
            // get its value
            result = CFNumberGetValue((CFNumberRef) tCFTypeRef, kCFNumberSInt32Type, outValue);
        }
    }
    return result;
}



// this will be called when the HID Manager matches a new (hot plugged) HID device
static void Handle_DeviceMatchingCallback(void* inContext, IOReturn inResult, void* inSender, IOHIDDeviceRef inIOHIDDeviceRef)
{
    @autoreleasepool {
        long reportSize = 0;
        IOReturn sendRet;
        uint8_t *report;
        size_t bufferSize = 5;
        NSMutableArray* pattern = (__bridge NSMutableArray*) inContext;
        //char *inputBuffer = malloc(bufferSize);
        char *outputBuffer = malloc(bufferSize);
        memset(outputBuffer, 0, bufferSize);
        
        NSLog(@"Device connected");
        (void)IOHIDDevice_GetLongProperty(inIOHIDDeviceRef, CFSTR(kIOHIDMaxInputReportSizeKey), &reportSize);
        if (reportSize) {
            report = calloc(1, reportSize);
            if (report) {
                IOHIDDeviceRegisterInputReportCallback(inIOHIDDeviceRef, report, reportSize, MyInputCallback, inContext);
                for (NSNumber *n in [pattern objectEnumerator]){
                    outputBuffer[0] = [n integerValue];
                    if (outputBuffer[0] > WHITE) continue; //Skip invalid values
                    sendRet = IOHIDDeviceSetReport(inIOHIDDeviceRef, kIOHIDReportTypeOutput, 0, (uint8_t *)outputBuffer, bufferSize);
                    [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:WAIT]];
                }
            }
        }
    }
}

// this will be called when a HID device is removed (unplugged)
static void Handle_DeviceRemovalCallback(void* inContext, IOReturn inResult, void* inSender, IOHIDDeviceRef inIOHIDDeviceRef)
{
    NSLog(@"Device disconnected");
}


int main (int argc, const char * argv[])
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    const long productId = 0x1320;
    const long vendorId = 0x1294;

	NSMutableArray *pattern = [[NSMutableArray alloc] init];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
	for(int i = 1; i < argc; i++){
		[pattern addObject:[NSNumber numberWithInt:atoi(argv[i])]];
	}
    
    IOHIDManagerRef managerRef = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    IOHIDManagerScheduleWithRunLoop(managerRef, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    IOHIDManagerOpen(managerRef, 0L);
    
    dict[@kIOHIDProductIDKey] = @(productId);
    dict[@kIOHIDVendorIDKey] = @(vendorId);
    IOHIDManagerSetDeviceMatching(managerRef, (__bridge CFMutableDictionaryRef)dict);
    IOHIDManagerRegisterDeviceMatchingCallback(managerRef, Handle_DeviceMatchingCallback, pattern);
    IOHIDManagerRegisterDeviceRemovalCallback(managerRef, Handle_DeviceRemovalCallback, pattern);

    //NSLog(@"Starting runloop");
    //[[NSRunLoop currentRunLoop] run];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:(1 + pattern.count * WAIT * 2)]];
    [pool drain];
    return 0;
}


