/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ViStatusView.h"

@implementation ViStatusView

- (ViStatusView *)init
{
	if (self = [super init]) {
		_messageField = nil;

		[self setAutoresizesSubviews:YES];
	}

	return self;
}

#pragma mark --
#pragma mark Simple message handling

- (void)initMessageField
{
	_messageField = [[[NSTextField alloc] init] retain];
	[_messageField setBezeled:NO];
	[_messageField setDrawsBackground:NO];
	[_messageField setEditable:NO];
	[_messageField setSelectable:NO];
    [_messageField setFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height + 2)];
    [_messageField setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable | NSViewMinXMargin | NSViewMaxXMargin];
	[self hideMessage];

	[self addSubview:_messageField];
}

- (void)setMessage:(NSString *)message
{
	if (! _messageField)
	  [self initMessageField];

	[_messageField setStringValue:message];
	[_messageField setHidden:NO];
}

- (void)hideMessage
{
	[_messageField setHidden:YES];
}

#pragma mark --
#pragma mark Pattern handling

- (void)setPatternString:(NSString *)pattern
{
	//[self setStatusComponents:[NSArray arrayWithObject:message]];
}

#pragma mark --
#pragma mark Status component handling

// ViStatusViewComponent
// Can subscribe to a ViEvent to update itself.
// - (NSView *)view -> the view that gets added to ViStatusView
// - (NSString *)placement?

- (void)setStatusComponents:(NSArray *)components
{
	[_components enumerateObjectsUsingBlock:^(id component, NSUInteger i, BOOL *stop) {
		if ([component respondsToSelector:@selector(removeFromSuperview)]) {
			[component removeFromSuperview];
		}
		[component release];
	}];

	NSLog(@"Setting things to %@", components);

	__block BOOL isLeftAligned = true;
	__block ViStatusComponent *lastComponent = nil;
	[components enumerateObjectsUsingBlock:^(id component, NSUInteger i, BOOL *stop) {
		if ([component isEqual:@"%="]) {
			isLeftAligned = false;
		}

		if ([component isKindOfClass:[ViStatusComponent class]]) {
			ViStatusComponent *statusComponent = (ViStatusComponent *)component;

			if (! isLeftAligned) {
				statusComponent.alignment = ViStatusComponentAlignRight;
			}

			[component retain];

			if (lastComponent) {
				lastComponent.nextComponent = statusComponent;
				statusComponent.previousComponent = lastComponent;
			}

			[statusComponent addViewTo:self];
			lastComponent = statusComponent;
		}
	}];

	[components enumerateObjectsUsingBlock:^(id component, NSUInteger i, BOOL *stop) {
		if ([component isKindOfClass:[ViStatusComponent class]]) {
			ViStatusComponent *statusComponent = (ViStatusComponent *)component;

			[statusComponent adjustSize];
		}
	}];

	[_components release];
	[components retain];
	_components = components;
}

#pragma mark --
#pragma mark Housekeeping

- (void)dealloc
{
	[_components makeObjectsPerformSelector:@selector(release)];

	[super dealloc];
}

@end

#pragma mark --
#pragma mark Status components

@implementation ViStatusComponent

@synthesize control = _control;
@synthesize nextComponent = _nextComponent;
@synthesize previousComponent = _previousComponent;
@synthesize alignment = _alignment;

- (ViStatusComponent *)init
{
	if (self = [super init]) {
		isCacheValid = NO;
		_previousComponent = nil;
		_nextComponent = nil;
		_control = nil;
	}

	return self;
}

- (ViStatusComponent *)initWithControl:(NSControl *)control
{
	if (self = [self init]) {
		self.control = control;
	}

	return self;
}

- (void)addViewTo:(NSView *)parentView withAlignment:(NSString *)alignment
{
	_alignment = alignment;
	[self addViewTo:parentView];
}

- (void)addViewTo:(NSView *)parentView
{
	[parentView addSubview:_control];
}

- (void)adjustSize
{
	// If the cache is still valid or we have no superview, don't
	// try to do any math or cache values.
	if (isCacheValid || ! [_control superview]) return;

	[_control sizeToFit];
	_cachedWidth = _control.frame.size.width;

	NSView *parentView = [_control superview];
	NSUInteger resizingMask = NSViewHeightSizable,
	           xPosition = 0;
	if (_alignment == ViStatusComponentAlignCenter) {
		resizingMask |= NSViewMinXMargin | NSViewMaxXMargin;

		// For center, we have to do math on all center aligned things
		// left and right of us. We then determine where this item should
		// be. To do this, we ask for everyone's width, which is cached
		// until something invalidates it.

		// Spot where the center point for the center block is, then
		// figure out where we have to be with respect to that.
		NSUInteger totalWidth = _cachedWidth;
		NSUInteger prevWidth = 0;
		ViStatusComponent *currentComponent = [self previousComponent];
		while (currentComponent && ([currentComponent alignment] == ViStatusComponentAlignCenter || [currentComponent alignment] == ViStatusComponentAlignAutomatic)) {
			totalWidth += [currentComponent controlWidth];
			prevWidth += [currentComponent controlWidth];
			currentComponent = [currentComponent previousComponent];
		}
		currentComponent = [self nextComponent];
		while (currentComponent && ([currentComponent alignment] == ViStatusComponentAlignCenter || [currentComponent alignment] == ViStatusComponentAlignAutomatic)) {
			totalWidth += [currentComponent controlWidth];
			currentComponent = [currentComponent nextComponent];
		}

		NSUInteger centerPoint = parentView.frame.size.width / 2;
		NSUInteger startingPoint = centerPoint - (totalWidth / 2);

		xPosition = startingPoint + prevWidth;
	} else if (_alignment == ViStatusComponentAlignRight) {
		resizingMask |= NSViewMinXMargin;

		// For right, ask the next item for its x value. If we are the last
		// item, our x value is the parentView width - our width.
		// We cache the x value until something invalidates it.
		NSUInteger followingX = parentView.frame.size.width;
		if ([self nextComponent]) {
			followingX = [[self nextComponent] controlX];
		}

		xPosition = followingX - _cachedWidth;
	} else {
		resizingMask |= NSViewMaxXMargin;

		if ([self previousComponent]) {
			xPosition = [[self previousComponent] controlX] + [[self previousComponent] controlWidth];
		}
	}

	[self.control setAutoresizingMask:resizingMask];
	[self.control setFrame:CGRectMake(xPosition, 0, _cachedWidth, parentView.frame.size.height + 1)];

	_cachedX = _control.frame.origin.x;

	isCacheValid = true;
}

- (NSUInteger)controlX
{
	if (! isCacheValid) [self adjustSize];

	return _cachedX;
}

- (NSUInteger)controlWidth
{
	if (! isCacheValid) [self adjustSize];

	return _cachedWidth;
}

- (void)removeFromSuperview
{
	[_control removeFromSuperview];
}

- (void)dealloc
{
	[_control release];

	[super dealloc];
}

@end

@implementation ViStatusLabel

- (ViStatusLabel *)init
{
	if (self = [super init]) {
		NSTextField *field = [[NSTextField alloc] init];
		[field setBezeled:NO];
		[field setDrawsBackground:NO];
		[field setEditable:NO];
		[field setSelectable:NO];

		self.control = field;
	}

	return self;
}

- (ViStatusLabel *)initWithText:(NSString *)text
{
	if (self = [self init]) {
		[_control setStringValue:text];
	}

	return self;
}

@end

@implementation ViStatusNotificationLabel

@synthesize notificationTransformer = _notificationTransformer;

+ (ViStatusNotificationLabel *)statusLabelForNotification:(NSString *)notification withTransformer:(NotificationTransformer)transformer
{
	return [[self alloc] initWithNotification:notification transformer:transformer];
}

- (ViStatusNotificationLabel *)initWithNotification:(NSString *)notification transformer:(NotificationTransformer)transformer
{
	if (self = [super initWithText:@""]) {
		self.notificationTransformer = transformer;

		[[NSNotificationCenter defaultCenter] addObserver:self
									             selector:@selector(changeOccurred:)
		                                             name:notification
		                                           object:nil];
	}

	return self;
}

- (void)changeOccurred:(NSNotification *)notification
{
	[self.control setStringValue:(self.notificationTransformer(notification))];
	isCacheValid = false;
	[self adjustSize];
}

- (void)dealloc
{
	[self.notificationTransformer release];

	[super dealloc];
}

@end