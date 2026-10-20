/*
 * MacScreenCapture.mm - Screen capture backend using ScreenCaptureKit and CGDisplayStream
 *
 * Copyright (c) 2026 Tobias Junghans <tobydox@veyon.io>
 *
 * This file is part of Veyon - https://veyon.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program (see COPYING); if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#include "MacScreenCapture.h"
#import <IOSurface/IOSurface.h>

@interface MacScreenCapture ()
{
	CGDisplayStreamRef _cgDisplayStream;
}
#ifdef HAVE_SCREENCAPTUREKIT
@property (nonatomic, strong) SCStream *captureStream;
@property (nonatomic, strong) SCContentFilter *contentFilter;
#endif
@property (nonatomic, strong) dispatch_queue_t captureQueue;
@property (nonatomic, assign) BOOL isCapturing;

- (void)startCGDisplayStreamForDisplay:(CGDirectDisplayID)displayID
                                 width:(size_t)width
                                height:(size_t)height
                                   fps:(float)fps;
@end

@implementation MacScreenCapture

+ (BOOL)hasScreenCapturePermission
{
	if (@available(macOS 10.15, *))
	{
		return CGPreflightScreenCaptureAccess();
	}

	CGImageRef image = CGWindowListCreateImage(
		CGRectMake(0, 0, 1, 1),
		kCGWindowListOptionOnScreenOnly,
		kCGNullWindowID,
		kCGWindowImageDefault
	);

	if (image == NULL)
	{
		return NO;
	}

	size_t width = CGImageGetWidth(image);
	CGImageRelease(image);

	return width > 0;
}

+ (void)requestPermissionIfNeeded
{
	if (![self hasScreenCapturePermission])
	{
		if (@available(macOS 11.0, *))
		{
			CGRequestScreenCaptureAccess();
		}
	}
}

- (instancetype)init
{
	self = [super init];
	if (self)
	{
		_captureQueue = dispatch_queue_create("io.veyon.screencapture", DISPATCH_QUEUE_SERIAL);
		_hasPermission = [MacScreenCapture hasScreenCapturePermission];
		_cgDisplayStream = nullptr;
		_isCapturing = NO;
	}
	return self;
}

- (void)dealloc
{
	[self stopCapture];
}

- (void)startCaptureForDisplay:(CGDirectDisplayID)displayID
                         width:(size_t)width
                        height:(size_t)height
                           fps:(float)fps
{
	if (self.isCapturing)
	{
		return;
	}
	self.isCapturing = YES;

#ifdef HAVE_SCREENCAPTUREKIT
	if (@available(macOS 12.3, *))
	{
		[SCShareableContent getShareableContentWithCompletionHandler:
			^(SCShareableContent * _Nullable content, NSError * _Nullable error)
		{
			if (error || !content || content.displays.count == 0)
			{
				NSLog(@"[Veyon] ScreenCaptureKit shareable content error: %@ - falling back to CGDisplayStream", error);
				[self startCGDisplayStreamForDisplay:displayID width:width height:height fps:fps];
				return;
			}

			SCDisplay *targetDisplay = nil;
			for (SCDisplay *d in content.displays)
			{
				if (d.displayID == displayID)
				{
					targetDisplay = d;
					break;
				}
			}

			if (!targetDisplay)
			{
				targetDisplay = content.displays.firstObject;
			}

			self.contentFilter = [[SCContentFilter alloc] initWithDisplay:targetDisplay excludingWindows:@[]];

			SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
			config.width = width;
			config.height = height;
			config.minimumFrameInterval = CMTimeMake(1, (int32_t)fps);
			config.pixelFormat = kCVPixelFormatType_32BGRA;
			config.queueDepth = 3;
			config.showsCursor = YES;

			self.captureStream = [[SCStream alloc] initWithFilter:self.contentFilter
			                                       configuration:config
			                                            delegate:self];

			NSError *addOutputError = nil;
			[self.captureStream addStreamOutput:self
			                               type:SCStreamOutputTypeScreen
			                 sampleHandlerQueue:self.captureQueue
			                              error:&addOutputError];

			if (addOutputError)
			{
				NSLog(@"[Veyon] Failed to add stream output: %@ - falling back", addOutputError);
				[self startCGDisplayStreamForDisplay:displayID width:width height:height fps:fps];
				return;
			}

			[self.captureStream startCaptureWithCompletionHandler:^(NSError * _Nullable startError) {
				if (startError)
				{
					NSLog(@"[Veyon] Failed to start ScreenCaptureKit: %@ - falling back", startError);
					[self startCGDisplayStreamForDisplay:displayID width:width height:height fps:fps];
				}
				else
				{
					NSLog(@"[Veyon] ScreenCaptureKit stream started successfully");
					self.hasPermission = YES;
				}
			}];
		}];
		return;
	}
#endif

	[self startCGDisplayStreamForDisplay:displayID width:width height:height fps:fps];
}

#ifdef HAVE_SCREENCAPTUREKIT
- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type
{
	if (type != SCStreamOutputTypeScreen)
	{
		return;
	}

	CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	if (!imageBuffer)
	{
		return;
	}

	CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

	void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
	size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
	size_t width = CVPixelBufferGetWidth(imageBuffer);
	size_t height = CVPixelBufferGetHeight(imageBuffer);

	if (self.framebufferUpdateBlock && baseAddress)
	{
		self.framebufferUpdateBlock(baseAddress, bytesPerRow, width, height);
	}

	CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
}
#endif

- (void)startCGDisplayStreamForDisplay:(CGDirectDisplayID)displayID
                                 width:(size_t)width
                                height:(size_t)height
                                   fps:(float)fps
{
	NSDictionary *properties = @{
		(__bridge NSString *)kCGDisplayStreamMinimumFrameTime: @(1.0 / fps),
		(__bridge NSString *)kCGDisplayStreamShowCursor: @YES,
	};

	__weak typeof(self) weakSelf = self;
	_cgDisplayStream = CGDisplayStreamCreateWithDispatchQueue(
		displayID,
		width,
		height,
		'BGRA',
		(__bridge CFDictionaryRef)properties,
		self.captureQueue,
		^(CGDisplayStreamFrameStatus status,
		  uint64_t displayTime,
		  IOSurfaceRef frameSurface,
		  CGDisplayStreamUpdateRef updateRef)
	{
		Q_UNUSED(displayTime)
		Q_UNUSED(updateRef)

		if (status != kCGDisplayStreamFrameStatusFrameComplete || !frameSurface)
		{
			return;
		}

		IOSurfaceLock(frameSurface, kIOSurfaceLockReadOnly, NULL);

		void *baseAddress = IOSurfaceGetBaseAddress(frameSurface);
		size_t bytesPerRow = IOSurfaceGetBytesPerRow(frameSurface);
		size_t w = IOSurfaceGetWidth(frameSurface);
		size_t h = IOSurfaceGetHeight(frameSurface);

		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (strongSelf && strongSelf.framebufferUpdateBlock && baseAddress)
		{
			strongSelf.framebufferUpdateBlock(baseAddress, bytesPerRow, w, h);
		}

		IOSurfaceUnlock(frameSurface, kIOSurfaceLockReadOnly, NULL);
	});

	if (_cgDisplayStream)
	{
		CGDisplayStreamStart(_cgDisplayStream);
		NSLog(@"[Veyon] CGDisplayStream started successfully");
	}
	else
	{
		NSLog(@"[Veyon] Failed to create CGDisplayStream");
	}
}

- (void)stopCapture
{
	if (!self.isCapturing)
	{
		return;
	}
	self.isCapturing = NO;

#ifdef HAVE_SCREENCAPTUREKIT
	if (@available(macOS 12.3, *))
	{
		if (self.captureStream)
		{
			[self.captureStream stopCaptureWithCompletionHandler:^(NSError * _Nullable error) {
				Q_UNUSED(error)
			}];
			self.captureStream = nil;
			self.contentFilter = nil;
		}
	}
#endif

	if (_cgDisplayStream)
	{
		CGDisplayStreamStop(_cgDisplayStream);
		CFRelease(_cgDisplayStream);
		_cgDisplayStream = nullptr;
	}
}

@end
