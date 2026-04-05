#import <AppKit/AppKit.h>

static NSColor *CQColorFromRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    return [NSColor colorWithSRGBRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:alpha];
}

static NSImage *CQBuildAppIcon(CGFloat size) {
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(size, size)];
    [image lockFocus];

    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

    NSRect bounds = NSMakeRect(0.0, 0.0, size, size);
    CGFloat cornerRadius = size * 0.23;

    NSBezierPath *backgroundPath = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:cornerRadius yRadius:cornerRadius];
    NSGradient *backgroundGradient = [[NSGradient alloc] initWithStartingColor:CQColorFromRGB(13, 18, 24, 1.0)
                                                                   endingColor:CQColorFromRGB(24, 33, 42, 1.0)];
    [backgroundGradient drawInBezierPath:backgroundPath angle:-90.0];

    NSBezierPath *sheenPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, size * 0.055, size * 0.055)
                                                              xRadius:cornerRadius * 0.8
                                                              yRadius:cornerRadius * 0.8];
    [[CQColorFromRGB(255, 255, 255, 0.05) colorWithAlphaComponent:0.05] setStroke];
    sheenPath.lineWidth = MAX(2.0, size * 0.018);
    [sheenPath stroke];

    NSPoint center = NSMakePoint(size / 2.0, size / 2.0);
    CGFloat outerRadius = size * 0.285;
    CGFloat innerRadius = size * 0.16;

    NSBezierPath *outerTrack = [NSBezierPath bezierPath];
    outerTrack.lineWidth = size * 0.075;
    [outerTrack appendBezierPathWithArcWithCenter:center radius:outerRadius startAngle:146.0 endAngle:392.0];
    [[CQColorFromRGB(78, 96, 113, 0.45) colorWithAlphaComponent:0.45] setStroke];
    [outerTrack stroke];

    NSBezierPath *outerArc = [NSBezierPath bezierPath];
    outerArc.lineWidth = size * 0.075;
    [outerArc appendBezierPathWithArcWithCenter:center radius:outerRadius startAngle:146.0 endAngle:338.0];
    NSGradient *outerGradient = [[NSGradient alloc] initWithColors:@[
        CQColorFromRGB(106, 237, 255, 1.0),
        CQColorFromRGB(68, 193, 255, 1.0)
    ]];
    [outerGradient drawInBezierPath:outerArc angle:-35.0];

    NSBezierPath *innerTrack = [NSBezierPath bezierPath];
    innerTrack.lineWidth = size * 0.072;
    [innerTrack appendBezierPathWithArcWithCenter:center radius:innerRadius startAngle:214.0 endAngle:116.0];
    [[CQColorFromRGB(78, 96, 113, 0.42) colorWithAlphaComponent:0.42] setStroke];
    [innerTrack stroke];

    NSBezierPath *innerArc = [NSBezierPath bezierPath];
    innerArc.lineWidth = size * 0.072;
    [innerArc appendBezierPathWithArcWithCenter:center radius:innerRadius startAngle:214.0 endAngle:36.0];
    NSGradient *innerGradient = [[NSGradient alloc] initWithColors:@[
        CQColorFromRGB(163, 255, 96, 1.0),
        CQColorFromRGB(81, 230, 125, 1.0)
    ]];
    [innerGradient drawInBezierPath:innerArc angle:35.0];

    NSBezierPath *needle = [NSBezierPath bezierPath];
    needle.lineWidth = MAX(4.0, size * 0.034);
    needle.lineCapStyle = NSLineCapStyleRound;
    [needle moveToPoint:center];
    [needle lineToPoint:NSMakePoint(center.x + size * 0.17, center.y - size * 0.11)];
    [[CQColorFromRGB(245, 248, 250, 1.0) colorWithAlphaComponent:0.96] setStroke];
    [needle stroke];

    NSBezierPath *centerDot = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - size * 0.05,
                                                                                center.y - size * 0.05,
                                                                                size * 0.10,
                                                                                size * 0.10)];
    [[CQColorFromRGB(245, 248, 250, 1.0) colorWithAlphaComponent:0.98] setFill];
    [centerDot fill];

    [image unlockFocus];
    return image;
}

static BOOL CQWritePNG(NSImage *image, NSString *outputPath) {
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    if (cgImage == nil) {
        return NO;
    }

    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [pngData writeToFile:outputPath atomically:YES];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            fprintf(stderr, "Usage: render_icon <output.png> <size>\n");
            return 1;
        }

        NSString *outputPath = [NSString stringWithUTF8String:argv[1]];
        CGFloat size = (CGFloat)atof(argv[2]);
        if (size <= 0) {
            fprintf(stderr, "Size must be positive.\n");
            return 1;
        }

        NSImage *image = CQBuildAppIcon(size);
        if (!CQWritePNG(image, outputPath)) {
            fprintf(stderr, "Failed to write PNG: %s\n", argv[1]);
            return 1;
        }
    }

    return 0;
}
