#import <AppKit/AppKit.h>
#import <dispatch/dispatch.h>
#import <fcntl.h>

static NSString * const CQErrorDomain = @"CodexQuotaErrorDomain";
static NSImage *CQMenuBarIconImage(void);

typedef NS_ENUM(NSInteger, CQErrorCode) {
    CQErrorSessionsDirectoryMissing = 1,
    CQErrorRolloutFileMissing = 2,
    CQErrorTokenCountMissing = 3,
};

@interface CQRateWindow : NSObject
@property (nonatomic, assign) double usedPercent;
@property (nonatomic, assign) NSInteger windowMinutes;
@property (nonatomic, assign) NSTimeInterval resetsAt;
@end

@implementation CQRateWindow
@end

@interface CQRateLimits : NSObject
@property (nonatomic, copy) NSString *planType;
@property (nonatomic, strong) CQRateWindow *primary;
@property (nonatomic, strong) CQRateWindow *secondary;
@end

@implementation CQRateLimits
@end

@interface CQSnapshot : NSObject
@property (nonatomic, strong) CQRateLimits *rateLimits;
@property (nonatomic, strong) NSURL *sourceURL;
@property (nonatomic, strong) NSDate *updatedAt;
@property (nonatomic, strong) NSDate *eventAt;
@end

@implementation CQSnapshot
@end

@interface CQStatusMetricView : NSView
@property (nonatomic, strong) NSTextField *labelField;
@property (nonatomic, strong) NSTextField *valueField;
- (instancetype)initWithLabel:(NSString *)label;
- (void)setMetricValue:(NSString *)value;
- (void)setMetricColor:(NSColor *)color;
@end

@implementation CQStatusMetricView

- (instancetype)initWithLabel:(NSString *)label {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _labelField = [NSTextField labelWithString:label];
        _labelField.font = [NSFont monospacedSystemFontOfSize:6 weight:NSFontWeightMedium];
        _labelField.textColor = [NSColor labelColor];
        _labelField.translatesAutoresizingMaskIntoConstraints = NO;

        _valueField = [NSTextField labelWithString:@"--"];
        _valueField.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
        _valueField.textColor = [NSColor labelColor];
        _valueField.translatesAutoresizingMaskIntoConstraints = NO;

        NSStackView *stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
        stack.orientation = NSUserInterfaceLayoutOrientationVertical;
        stack.alignment = NSLayoutAttributeLeading;
        stack.spacing = -3.0;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [stack addArrangedSubview:_labelField];
        [stack addArrangedSubview:_valueField];
        [self addSubview:stack];

        [NSLayoutConstraint activateConstraints:@[
            [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:1.0],
            [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-1.0],
        ]];
    }
    return self;
}

- (void)setMetricValue:(NSString *)value {
    self.valueField.stringValue = value;
}

- (void)setMetricColor:(NSColor *)color {
    self.valueField.textColor = color ?: [NSColor labelColor];
}

- (NSSize)intrinsicContentSize {
    return NSMakeSize(34.0, 22.0);
}

@end

@interface CQStatusSummaryView : NSView
@property (nonatomic, strong) NSImageView *iconView;
@property (nonatomic, strong) CQStatusMetricView *primaryMetricView;
@property (nonatomic, strong) CQStatusMetricView *secondaryMetricView;
- (void)setPrimaryValue:(NSString *)primaryValue secondaryValue:(NSString *)secondaryValue;
- (void)setPrimaryColor:(NSColor *)primaryColor secondaryColor:(NSColor *)secondaryColor;
@end

@implementation CQStatusSummaryView

- (instancetype)init {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _iconView = [[NSImageView alloc] initWithFrame:NSZeroRect];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.image = CQMenuBarIconImage();
        _iconView.imageScaling = NSImageScaleProportionallyUpOrDown;

        _primaryMetricView = [[CQStatusMetricView alloc] initWithLabel:@"5H"];
        _secondaryMetricView = [[CQStatusMetricView alloc] initWithLabel:@"7D"];

        NSStackView *stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
        stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        stack.alignment = NSLayoutAttributeCenterY;
        stack.distribution = NSStackViewDistributionFill;
        stack.spacing = 4.0;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [stack addArrangedSubview:_iconView];
        [stack addArrangedSubview:_primaryMetricView];
        [stack addArrangedSubview:_secondaryMetricView];
        [self addSubview:stack];

        [NSLayoutConstraint activateConstraints:@[
            [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:1.0],
            [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-1.0],
            [stack.topAnchor constraintEqualToAnchor:self.topAnchor],
            [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:14.0],
            [_iconView.heightAnchor constraintEqualToConstant:14.0],
        ]];
    }
    return self;
}

- (void)setPrimaryValue:(NSString *)primaryValue secondaryValue:(NSString *)secondaryValue {
    [self.primaryMetricView setMetricValue:primaryValue];
    [self.secondaryMetricView setMetricValue:secondaryValue];
}

- (void)setPrimaryColor:(NSColor *)primaryColor secondaryColor:(NSColor *)secondaryColor {
    [self.primaryMetricView setMetricColor:primaryColor];
    [self.secondaryMetricView setMetricColor:secondaryColor];
}

- (NSView *)hitTest:(NSPoint)point {
    return nil;
}

- (NSSize)intrinsicContentSize {
    return NSMakeSize(88.0, 22.0);
}

@end

static NSError *CQMakeError(CQErrorCode code, NSString *description) {
    return [NSError errorWithDomain:CQErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

static NSString *CQPercentString(double value) {
    double bounded = MIN(MAX(value, 0.0), 100.0);
    return [NSString stringWithFormat:@"%.0f%%", bounded];
}

static NSString *CQRemainingPercentString(CQRateWindow *window) {
    return CQPercentString(100.0 - window.usedPercent);
}

static NSString *CQShortResetString(CQRateWindow *window) {
    NSDate *resetDate = [NSDate dateWithTimeIntervalSince1970:window.resetsAt];
    if (window.windowMinutes <= 300) {
        static NSDateFormatter *timeFormatter;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            timeFormatter = [[NSDateFormatter alloc] init];
            timeFormatter.locale = [NSLocale currentLocale];
            timeFormatter.dateStyle = NSDateFormatterNoStyle;
            timeFormatter.timeStyle = NSDateFormatterShortStyle;
        });
        return [timeFormatter stringFromDate:resetDate];
    }

    static NSDateFormatter *dateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.locale = [NSLocale currentLocale];
        dateFormatter.dateFormat = @"MMM d";
    });
    return [dateFormatter stringFromDate:resetDate];
}

static NSString *CQDateTimeString(NSDate *date) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale currentLocale];
        formatter.dateFormat = @"MM-dd HH:mm";
    });
    return [formatter stringFromDate:date];
}

static NSColor *CQMetricColorForRemainingPercent(CQRateWindow *window) {
    double remaining = 100.0 - window.usedPercent;
    if (remaining < 40.0) {
        return [NSColor colorWithSRGBRed:1.0 green:0.48 blue:0.34 alpha:1.0];
    }
    if (remaining < 70.0) {
        return [NSColor colorWithSRGBRed:0.98 green:0.82 blue:0.43 alpha:1.0];
    }
    return [NSColor labelColor];
}

static NSImage *CQMenuBarIconImage(void) {
    NSSize size = NSMakeSize(18.0, 18.0);
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image lockFocus];

    [[NSColor blackColor] setStroke];

    NSBezierPath *outerArc = [NSBezierPath bezierPath];
    outerArc.lineWidth = 1.8;
    [outerArc appendBezierPathWithArcWithCenter:NSMakePoint(9.0, 9.0)
                                         radius:6.5
                                     startAngle:140.0
                                       endAngle:405.0];
    [outerArc stroke];

    NSBezierPath *innerArc = [NSBezierPath bezierPath];
    innerArc.lineWidth = 1.8;
    [innerArc appendBezierPathWithArcWithCenter:NSMakePoint(9.0, 9.0)
                                         radius:3.7
                                     startAngle:200.0
                                       endAngle:110.0];
    [innerArc stroke];

    NSBezierPath *needle = [NSBezierPath bezierPath];
    needle.lineWidth = 1.6;
    [needle moveToPoint:NSMakePoint(9.0, 9.0)];
    [needle lineToPoint:NSMakePoint(12.2, 6.5)];
    [needle stroke];

    NSBezierPath *centerDot = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(7.7, 7.7, 2.6, 2.6)];
    [[NSColor blackColor] setFill];
    [centerDot fill];

    [image unlockFocus];
    image.template = YES;
    return image;
}

static CQRateWindow *CQParseRateWindow(NSDictionary *dictionary) {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    CQRateWindow *window = [[CQRateWindow alloc] init];
    window.usedPercent = [dictionary[@"used_percent"] doubleValue];
    window.windowMinutes = [dictionary[@"window_minutes"] integerValue];
    window.resetsAt = [dictionary[@"resets_at"] doubleValue];
    return window;
}

static CQRateLimits *CQParseRateLimits(NSDictionary *dictionary) {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    CQRateWindow *primary = CQParseRateWindow(dictionary[@"primary"]);
    CQRateWindow *secondary = CQParseRateWindow(dictionary[@"secondary"]);
    if (primary == nil || secondary == nil) {
        return nil;
    }

    CQRateLimits *rateLimits = [[CQRateLimits alloc] init];
    rateLimits.planType = [dictionary[@"plan_type"] isKindOfClass:[NSString class]] ? dictionary[@"plan_type"] : @"unknown";
    rateLimits.primary = primary;
    rateLimits.secondary = secondary;
    return rateLimits;
}

@interface CQQuotaReader : NSObject
@property (nonatomic, strong, readonly) NSURL *sessionsRoot;
- (instancetype)initWithSessionsRoot:(NSURL *)sessionsRoot;
- (CQSnapshot *)loadLatestSnapshot:(NSError **)error;
+ (NSURL *)defaultSessionsRoot;
@end

@implementation CQQuotaReader

- (instancetype)initWithSessionsRoot:(NSURL *)sessionsRoot {
    self = [super init];
    if (self) {
        _sessionsRoot = sessionsRoot;
    }
    return self;
}

+ (NSURL *)defaultSessionsRoot {
    return [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@".codex/sessions"]];
}

- (CQSnapshot *)loadLatestSnapshot:(NSError **)error {
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.sessionsRoot.path isDirectory:&isDirectory] || !isDirectory) {
        if (error != NULL) {
            *error = CQMakeError(CQErrorSessionsDirectoryMissing,
                                 [NSString stringWithFormat:@"Sessions directory not found: %@", self.sessionsRoot.path]);
        }
        return nil;
    }

    NSArray<NSURLResourceKey> *keys = @[NSURLContentModificationDateKey, NSURLIsRegularFileKey];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:self.sessionsRoot
                                                             includingPropertiesForKeys:keys
                                                                                options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                           errorHandler:nil];
    CQSnapshot *bestSnapshot = nil;

    for (NSURL *fileURL in enumerator) {
        if (![fileURL.lastPathComponent hasPrefix:@"rollout-"] || ![fileURL.pathExtension isEqualToString:@"jsonl"]) {
            continue;
        }

        NSNumber *isRegularFile = nil;
        NSDate *modifiedAt = nil;
        [fileURL getResourceValue:&isRegularFile forKey:NSURLIsRegularFileKey error:nil];
        [fileURL getResourceValue:&modifiedAt forKey:NSURLContentModificationDateKey error:nil];

        if (![isRegularFile boolValue]) {
            continue;
        }

        CQSnapshot *snapshot = [self latestSnapshotFromRolloutURL:fileURL error:nil];
        if (snapshot == nil) {
            continue;
        }

        NSDate *candidateDate = snapshot.eventAt ?: modifiedAt ?: [NSDate distantPast];
        NSDate *currentBestDate = bestSnapshot.eventAt ?: bestSnapshot.updatedAt ?: [NSDate distantPast];
        if (bestSnapshot == nil || [candidateDate compare:currentBestDate] == NSOrderedDescending) {
            bestSnapshot = snapshot;
        }
    }

    if (bestSnapshot == nil && error != NULL) {
        *error = CQMakeError(CQErrorTokenCountMissing, @"No usable token_count event found under ~/.codex/sessions.");
    }

    return bestSnapshot;
}

- (CQSnapshot *)latestSnapshotFromRolloutURL:(NSURL *)url error:(NSError **)error {
    NSData *fileData = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (fileData == nil) {
        return nil;
    }

    NSString *text = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
    if (text == nil) {
        if (error != NULL) {
            *error = CQMakeError(CQErrorTokenCountMissing,
                                 [NSString stringWithFormat:@"Unable to decode UTF-8 from %@", url.lastPathComponent]);
        }
        return nil;
    }

    NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    CQSnapshot *latestSnapshot = nil;
    NSDate *latestEventAt = [NSDate distantPast];

    for (NSString *line in lines) {
        if ([line rangeOfString:@"\"type\":\"token_count\""].location == NSNotFound ||
            [line rangeOfString:@"\"type\":\"event_msg\""].location == NSNotFound) {
            continue;
        }

        NSData *lineData = [line dataUsingEncoding:NSUTF8StringEncoding];
        if (lineData == nil) {
            continue;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:lineData options:0 error:nil];
        NSDictionary *payload = [json[@"payload"] isKindOfClass:[NSDictionary class]] ? json[@"payload"] : nil;
        if (![[payload objectForKey:@"type"] isEqual:@"token_count"]) {
            continue;
        }

        CQRateLimits *rateLimits = CQParseRateLimits(payload[@"rate_limits"]);
        if (rateLimits == nil) {
            continue;
        }

        NSString *timestampString = [json[@"timestamp"] isKindOfClass:[NSString class]] ? json[@"timestamp"] : nil;
        NSDate *eventAt = [self.class dateFromTimestampString:timestampString] ?: [NSDate distantPast];
        if ([eventAt compare:latestEventAt] != NSOrderedDescending) {
            continue;
        }

        NSDate *modifiedAt = nil;
        [url getResourceValue:&modifiedAt forKey:NSURLContentModificationDateKey error:nil];

        CQSnapshot *snapshot = [[CQSnapshot alloc] init];
        snapshot.rateLimits = rateLimits;
        snapshot.sourceURL = url;
        snapshot.updatedAt = modifiedAt ?: [NSDate date];
        snapshot.eventAt = eventAt;
        latestSnapshot = snapshot;
        latestEventAt = eventAt;
    }

    if (latestSnapshot != nil) {
        return latestSnapshot;
    }

    if (error != NULL) {
        *error = CQMakeError(CQErrorTokenCountMissing,
                             [NSString stringWithFormat:@"No token_count event found in %@.", url.lastPathComponent]);
    }
    return nil;
}

+ (NSDate *)dateFromTimestampString:(NSString *)timestampString {
    if (timestampString.length == 0) {
        return nil;
    }

    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    });

    NSDate *date = [formatter dateFromString:timestampString];
    if (date != nil) {
        return date;
    }

    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    date = [formatter dateFromString:timestampString];
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    return date;
}

@end

typedef void (^CQMonitorUpdateHandler)(CQSnapshot *snapshot, NSError *error);

@interface CQQuotaMonitor : NSObject
@property (nonatomic, copy) CQMonitorUpdateHandler onUpdate;
- (void)start;
- (void)refreshAndRebind:(BOOL)rebind;
@end

@interface CQQuotaMonitor ()
@property (nonatomic, strong) CQQuotaReader *reader;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) dispatch_source_t directoryWatcher;
@property (nonatomic) dispatch_source_t fileWatcher;
@property (nonatomic) dispatch_source_t timer;
@property (nonatomic) int directoryFD;
@property (nonatomic) int fileFD;
@property (nonatomic, strong) NSURL *watchedFileURL;
@end

@implementation CQQuotaMonitor

- (instancetype)init {
    self = [super init];
    if (self) {
        _reader = [[CQQuotaReader alloc] initWithSessionsRoot:[CQQuotaReader defaultSessionsRoot]];
        _queue = dispatch_queue_create("codex.quota.monitor", DISPATCH_QUEUE_SERIAL);
        _directoryFD = -1;
        _fileFD = -1;
    }
    return self;
}

- (void)dealloc {
    [self teardown];
}

- (void)start {
    [self setupDirectoryWatcher];
    [self setupTimer];
    [self refreshAndRebind:YES];
}

- (void)refreshAndRebind:(BOOL)rebind {
    dispatch_async(self.queue, ^{
        [self refreshOnQueueWithRebind:rebind];
    });
}

- (void)refreshOnQueueWithRebind:(BOOL)rebind {
    NSError *error = nil;
    CQSnapshot *snapshot = [self.reader loadLatestSnapshot:&error];
    if (snapshot != nil) {
        if (rebind || ![self.watchedFileURL isEqual:snapshot.sourceURL]) {
            [self bindFileWatcherToURL:snapshot.sourceURL];
        }

        if (self.onUpdate != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.onUpdate(snapshot, nil);
            });
        }
        return;
    }

    if (self.onUpdate != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.onUpdate(nil, error);
        });
    }
}

- (void)setupTimer {
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    dispatch_source_set_timer(self.timer,
                              dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC),
                              10 * NSEC_PER_SEC,
                              1 * NSEC_PER_SEC);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.timer, ^{
        [weakSelf refreshOnQueueWithRebind:NO];
    });
    dispatch_resume(self.timer);
}

- (void)setupDirectoryWatcher {
    int fd = open(self.reader.sessionsRoot.path.fileSystemRepresentation, O_EVTONLY);
    self.directoryFD = fd;
    if (fd < 0) {
        return;
    }

    self.directoryWatcher = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,
                                                   fd,
                                                   DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_DELETE,
                                                   self.queue);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.directoryWatcher, ^{
        [weakSelf refreshOnQueueWithRebind:YES];
    });
    dispatch_source_set_cancel_handler(self.directoryWatcher, ^{
        close(fd);
    });
    dispatch_resume(self.directoryWatcher);
}

- (void)bindFileWatcherToURL:(NSURL *)url {
    if (self.fileWatcher != nil) {
        dispatch_source_cancel(self.fileWatcher);
        self.fileWatcher = nil;
        self.fileFD = -1;
    }

    self.watchedFileURL = url;
    int fd = open(url.path.fileSystemRepresentation, O_EVTONLY);
    self.fileFD = fd;
    if (fd < 0) {
        return;
    }

    self.fileWatcher = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,
                                              fd,
                                              DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_DELETE,
                                              self.queue);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.fileWatcher, ^{
        [weakSelf refreshOnQueueWithRebind:YES];
    });
    dispatch_source_set_cancel_handler(self.fileWatcher, ^{
        close(fd);
    });
    dispatch_resume(self.fileWatcher);
}

- (void)teardown {
    if (self.timer != nil) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }

    if (self.directoryWatcher != nil) {
        dispatch_source_cancel(self.directoryWatcher);
        self.directoryWatcher = nil;
    }

    if (self.fileWatcher != nil) {
        dispatch_source_cancel(self.fileWatcher);
        self.fileWatcher = nil;
    }
}

@end

@interface CQStatusController : NSObject <NSMenuDelegate>
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *menu;
@property (nonatomic, strong) CQQuotaMonitor *monitor;
@property (nonatomic, strong) CQSnapshot *latestSnapshot;
@property (nonatomic, copy) NSString *lastError;
@property (nonatomic, strong) NSMenuItem *fiveHourItem;
@property (nonatomic, strong) NSMenuItem *weekItem;
@property (nonatomic, strong) NSMenuItem *planItem;
@property (nonatomic, strong) NSMenuItem *updatedItem;
@property (nonatomic, strong) NSMenuItem *sourceItem;
@property (nonatomic, strong) NSMenuItem *errorItem;
@property (nonatomic, strong) NSMenuItem *launchAtLoginItem;
@property (nonatomic, strong) CQStatusSummaryView *summaryView;
@end

@implementation CQStatusController

- (instancetype)init {
    self = [super init];
    if (self) {
        [self configureStatusItem];
        [self configureMenu];

        self.monitor = [[CQQuotaMonitor alloc] init];
        __weak typeof(self) weakSelf = self;
        self.monitor.onUpdate = ^(CQSnapshot *snapshot, NSError *error) {
            [weakSelf handleSnapshot:snapshot error:error];
        };
        [self.monitor start];
    }
    return self;
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [self updateLaunchAtLoginMenuState];
    [self.monitor refreshAndRebind:NO];
}

- (void)configureStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:96.0];
    self.statusItem.button.image = nil;
    self.statusItem.button.title = @"";
    self.statusItem.button.toolTip = @"5 hours: --\n7 days: --";
    self.summaryView = [[CQStatusSummaryView alloc] init];
    [self.summaryView setPrimaryValue:@"--" secondaryValue:@"--"];
    [self.summaryView setPrimaryColor:[NSColor labelColor] secondaryColor:[NSColor labelColor]];
    [self.statusItem.button addSubview:self.summaryView];

    [NSLayoutConstraint activateConstraints:@[
        [self.summaryView.leadingAnchor constraintEqualToAnchor:self.statusItem.button.leadingAnchor constant:4.0],
        [self.summaryView.trailingAnchor constraintEqualToAnchor:self.statusItem.button.trailingAnchor constant:-4.0],
        [self.summaryView.centerYAnchor constraintEqualToAnchor:self.statusItem.button.centerYAnchor],
        [self.summaryView.heightAnchor constraintEqualToConstant:22.0],
    ]];
}

- (void)configureMenu {
    self.menu = [[NSMenu alloc] init];
    self.menu.delegate = self;

    self.fiveHourItem = [self disabledItemWithTitle:@"5H: Loading..."];
    self.weekItem = [self disabledItemWithTitle:@"7D: Loading..."];
    self.planItem = [self disabledItemWithTitle:@"Plan: --"];
    self.updatedItem = [self disabledItemWithTitle:@"Updated: --"];
    self.sourceItem = [self disabledItemWithTitle:@"Source: --"];
    self.errorItem = [self disabledItemWithTitle:@""];

    for (NSMenuItem *item in @[self.fiveHourItem, self.weekItem, self.planItem, self.updatedItem, self.sourceItem, self.errorItem]) {
        [self.menu addItem:item];
    }

    [self.menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:@"Refresh Now"
                                                         action:@selector(refreshNow)
                                                  keyEquivalent:@"r"];
    refreshItem.target = self;
    [self.menu addItem:refreshItem];

    self.launchAtLoginItem = [[NSMenuItem alloc] initWithTitle:@"Launch At Login"
                                                        action:@selector(toggleLaunchAtLogin)
                                                 keyEquivalent:@""];
    self.launchAtLoginItem.target = self;
    [self.menu addItem:self.launchAtLoginItem];

    NSMenuItem *openSessionsItem = [[NSMenuItem alloc] initWithTitle:@"Open Sessions Folder"
                                                              action:@selector(openSessionsFolder)
                                                       keyEquivalent:@"s"];
    openSessionsItem.target = self;
    [self.menu addItem:openSessionsItem];

    NSMenuItem *openCodexItem = [[NSMenuItem alloc] initWithTitle:@"Open ~/.codex"
                                                           action:@selector(openCodexHome)
                                                    keyEquivalent:@"o"];
    openCodexItem.target = self;
    [self.menu addItem:openCodexItem];

    [self.menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                      action:@selector(quitApp)
                                               keyEquivalent:@"q"];
    quitItem.target = self;
    [self.menu addItem:quitItem];

    self.statusItem.menu = self.menu;
    [self updateLaunchAtLoginMenuState];
    [self updateUI];
}

- (NSMenuItem *)disabledItemWithTitle:(NSString *)title {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    item.enabled = NO;
    return item;
}

- (void)handleSnapshot:(CQSnapshot *)snapshot error:(NSError *)error {
    if (snapshot != nil) {
        self.latestSnapshot = snapshot;
        self.lastError = nil;
    } else if (error != nil) {
        self.lastError = error.localizedDescription;
    }

    [self updateUI];
}

- (void)updateUI {
    if (self.latestSnapshot == nil) {
        [self.summaryView setPrimaryValue:@"--" secondaryValue:@"--"];
        [self.summaryView setPrimaryColor:[NSColor labelColor] secondaryColor:[NSColor labelColor]];
        self.statusItem.button.toolTip = @"5 hours: --\n7 days: --";
        self.fiveHourItem.title = @"5H: Waiting for Codex usage data";
        self.weekItem.title = @"7D: Waiting for Codex usage data";
        self.planItem.title = @"Plan: --";
        self.updatedItem.title = @"Updated: --";
        self.sourceItem.title = @"Source: --";
        self.errorItem.title = self.lastError.length > 0 ? [@"Error: " stringByAppendingString:self.lastError] : @"";
        self.errorItem.hidden = (self.lastError.length == 0);
        return;
    }

    CQRateWindow *primary = self.latestSnapshot.rateLimits.primary;
    CQRateWindow *secondary = self.latestSnapshot.rateLimits.secondary;

    [self.summaryView setPrimaryValue:CQRemainingPercentString(primary)
                       secondaryValue:CQRemainingPercentString(secondary)];
    [self.summaryView setPrimaryColor:CQMetricColorForRemainingPercent(primary)
                       secondaryColor:CQMetricColorForRemainingPercent(secondary)];
    self.statusItem.button.toolTip = [NSString stringWithFormat:@"5 hours: %@, resets %@\n7 days: %@, resets %@",
                                      CQRemainingPercentString(primary),
                                      CQShortResetString(primary),
                                      CQRemainingPercentString(secondary),
                                      CQShortResetString(secondary)];

    self.fiveHourItem.title = [self menuLineForLabel:@"5H" window:primary];
    self.weekItem.title = [self menuLineForLabel:@"7D" window:secondary];
    self.planItem.title = [NSString stringWithFormat:@"Plan: %@", [self.latestSnapshot.rateLimits.planType uppercaseString]];
    self.updatedItem.title = [NSString stringWithFormat:@"Updated: %@", CQDateTimeString(self.latestSnapshot.eventAt ?: self.latestSnapshot.updatedAt)];
    self.sourceItem.title = [NSString stringWithFormat:@"Source: %@", self.latestSnapshot.sourceURL.lastPathComponent];
    self.errorItem.hidden = YES;
}

- (NSString *)menuLineForLabel:(NSString *)label window:(CQRateWindow *)window {
    return [NSString stringWithFormat:@"%@: %@  %@",
            label,
            CQRemainingPercentString(window),
            CQShortResetString(window)];
}

- (void)refreshNow {
    [self.monitor refreshAndRebind:YES];
}

- (NSURL *)launchAgentsDirectoryURL {
    return [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents"]];
}

- (NSURL *)launchAgentPlistURL {
    return [[self launchAgentsDirectoryURL] URLByAppendingPathComponent:@"local.codex.quota.plist"];
}

- (NSString *)launchAgentLabel {
    return @"local.codex.quota";
}

- (BOOL)isLaunchAtLoginEnabled {
    return [[NSFileManager defaultManager] fileExistsAtPath:self.launchAgentPlistURL.path];
}

- (void)updateLaunchAtLoginMenuState {
    self.launchAtLoginItem.state = [self isLaunchAtLoginEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
}

- (NSArray<NSString *> *)launchAgentProgramArguments {
    NSString *bundlePath = [NSBundle mainBundle].bundlePath;
    if ([bundlePath.pathExtension.lowercaseString isEqualToString:@"app"]) {
        return @[@"/usr/bin/open", bundlePath];
    }

    NSString *executablePath = [NSBundle mainBundle].executablePath ?: [NSProcessInfo processInfo].arguments.firstObject;
    return executablePath != nil ? @[executablePath] : @[];
}

- (NSDictionary *)launchAgentPlistContents {
    NSMutableDictionary *plist = [NSMutableDictionary dictionary];
    plist[@"Label"] = [self launchAgentLabel];
    plist[@"ProgramArguments"] = [self launchAgentProgramArguments];
    plist[@"RunAtLoad"] = @YES;
    plist[@"ProcessType"] = @"Interactive";
    plist[@"LimitLoadToSessionType"] = @[@"Aqua"];
    return plist;
}

- (BOOL)runLaunchctlWithArguments:(NSArray<NSString *> *)arguments error:(NSError **)error {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/launchctl";
    task.arguments = arguments;

    NSPipe *stderrPipe = [[NSPipe alloc] init];
    task.standardError = stderrPipe;

    @try {
        [task launch];
    } @catch (NSException *exception) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:CQErrorDomain
                                         code:100
                                     userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Failed to start launchctl."}];
        }
        return NO;
    }

    [task waitUntilExit];
    if (task.terminationStatus == 0) {
        return YES;
    }

    NSData *stderrData = [stderrPipe.fileHandleForReading readDataToEndOfFile];
    NSString *stderrText = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding];
    if (error != NULL) {
        *error = [NSError errorWithDomain:CQErrorDomain
                                     code:task.terminationStatus
                                 userInfo:@{NSLocalizedDescriptionKey: stderrText.length > 0 ? stderrText : @"launchctl failed."}];
    }
    return NO;
}

- (BOOL)installLaunchAgent:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager createDirectoryAtURL:[self launchAgentsDirectoryURL] withIntermediateDirectories:YES attributes:nil error:error];
    if (error != NULL && *error != nil) {
        return NO;
    }

    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:[self launchAgentPlistContents]
                                                                   format:NSPropertyListXMLFormat_v1_0
                                                                  options:0
                                                                    error:error];
    if (plistData == nil) {
        return NO;
    }

    if (![plistData writeToURL:[self launchAgentPlistURL] options:NSDataWritingAtomic error:error]) {
        return NO;
    }

    NSString *domain = [NSString stringWithFormat:@"gui/%u", getuid()];
    NSError *launchctlError = nil;
    [self runLaunchctlWithArguments:@[@"bootout", domain, [self launchAgentPlistURL].path] error:nil];
    if (![self runLaunchctlWithArguments:@[@"bootstrap", domain, [self launchAgentPlistURL].path] error:&launchctlError]) {
        if (error != NULL) {
            *error = launchctlError;
        }
        return NO;
    }

    return YES;
}

- (BOOL)removeLaunchAgent:(NSError **)error {
    NSString *domain = [NSString stringWithFormat:@"gui/%u", getuid()];
    [self runLaunchctlWithArguments:@[@"bootout", domain, [self launchAgentPlistURL].path] error:nil];

    if ([[NSFileManager defaultManager] fileExistsAtPath:[self launchAgentPlistURL].path] &&
        ![[NSFileManager defaultManager] removeItemAtURL:[self launchAgentPlistURL] error:error]) {
        return NO;
    }

    return YES;
}

- (void)presentLaunchAtLoginError:(NSError *)error {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"Launch At Login Failed";
    alert.informativeText = error.localizedDescription ?: @"Unknown error.";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)toggleLaunchAtLogin {
    NSError *error = nil;
    BOOL enabled = [self isLaunchAtLoginEnabled];
    BOOL success = enabled ? [self removeLaunchAgent:&error] : [self installLaunchAgent:&error];

    if (!success && error != nil) {
        [self presentLaunchAtLoginError:error];
    }

    [self updateLaunchAtLoginMenuState];
}

- (void)openSessionsFolder {
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[CQQuotaReader defaultSessionsRoot]]];
}

- (void)openCodexHome {
    NSURL *codexHome = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@".codex"]];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[codexHome]];
}

- (void)quitApp {
    [NSApp terminate:nil];
}

@end

@interface CQAppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) CQStatusController *controller;
@end

@implementation CQAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    self.controller = [[CQStatusController alloc] init];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        CQAppDelegate *delegate = [[CQAppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
