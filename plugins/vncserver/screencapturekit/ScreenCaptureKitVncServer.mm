/*
 * ScreenCaptureKitVncServer.mm - VNC server plugin using ScreenCaptureKit
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

#include "ScreenCaptureKitVncServer.h"
#include "ScreenCaptureKitConfiguration.h"
#include "MacScreenCapture.h"
#include "Logger.h"

extern "C" {
#include <rfb/rfb.h>
}

#include <QMutex>
#include <QMutexLocker>
#import <CoreGraphics/CoreGraphics.h>

struct ScreenCaptureKitVncServer::Impl {
	rfbScreenInfoPtr rfbScreen{nullptr};
	MacScreenCapture* capture{nil};
	QMutex framebufferMutex;
	char* framebuffer{nullptr};
	int width{0};
	int height{0};
	char* vncPassword{nullptr};
	char* vncPasswords[2]{nullptr, nullptr};
};

static void onKbdAddEvent(rfbBool down, rfbKeySym keySym, rfbClientRec* cl)
{
	Q_UNUSED(cl)

	// Map common keysyms or post unicode / key events
	CGKeyCode keyCode = 0;
	if (keySym >= 'a' && keySym <= 'z')
	{
		static const CGKeyCode letterCodes[] = {
			0, 11, 8, 2, 14, 3, 5, 4, 34, 38, 40, 37, 46,
			45, 31, 35, 12, 15, 1, 17, 32, 9, 13, 7, 16, 6
		};
		keyCode = letterCodes[keySym - 'a'];
	}
	else if (keySym == 0xff08) // BackSpace
	{
		keyCode = 51;
	}
	else if (keySym == 0xff09) // Tab
	{
		keyCode = 48;
	}
	else if (keySym == 0xff0d) // Return
	{
		keyCode = 36;
	}
	else if (keySym == 0xff1b) // Escape
	{
		keyCode = 53;
	}
	else if (keySym == 0x0020) // Space
	{
		keyCode = 49;
	}

	CGEventRef event = CGEventCreateKeyboardEvent(nullptr, keyCode, down);
	if (event)
	{
		CGEventPost(kCGHIDEventTap, event);
		CFRelease(event);
	}
}

static void onPtrAddEvent(int buttonMask, int x, int y, rfbClientRec* cl)
{
	Q_UNUSED(cl)

	static int lastButtonMask = 0;
	CGPoint point = CGPointMake(x, y);

	CGEventType type = kCGEventMouseMoved;
	CGMouseButton button = kCGMouseButtonLeft;

	if (buttonMask & 1)
	{
		type = (lastButtonMask & 1) ? kCGEventLeftMouseDragged : kCGEventLeftMouseDown;
		button = kCGMouseButtonLeft;
	}
	else if (lastButtonMask & 1)
	{
		type = kCGEventLeftMouseUp;
		button = kCGMouseButtonLeft;
	}
	else if (buttonMask & 4)
	{
		type = (lastButtonMask & 4) ? kCGEventRightMouseDragged : kCGEventRightMouseDown;
		button = kCGMouseButtonRight;
	}
	else if (lastButtonMask & 4)
	{
		type = kCGEventRightMouseUp;
		button = kCGMouseButtonRight;
	}

	lastButtonMask = buttonMask;

	CGEventRef event = CGEventCreateMouseEvent(nullptr, type, point, button);
	if (event)
	{
		CGEventPost(kCGHIDEventTap, event);
		CFRelease(event);
	}
}

ScreenCaptureKitVncServer::ScreenCaptureKitVncServer(QObject* parent)
	: QObject(parent)
	, m_impl(std::make_unique<Impl>())
{
}

ScreenCaptureKitVncServer::~ScreenCaptureKitVncServer()
{
	if (m_impl->capture)
	{
		[m_impl->capture stopCapture];
		m_impl->capture = nil;
	}

	if (m_impl->rfbScreen)
	{
		rfbScreenCleanup(m_impl->rfbScreen);
		m_impl->rfbScreen = nullptr;
	}

	delete[] m_impl->framebuffer;
	m_impl->framebuffer = nullptr;
}

void ScreenCaptureKitVncServer::prepareServer()
{
	CGDirectDisplayID displayID = CGMainDisplayID();
	m_impl->width = static_cast<int>(CGDisplayPixelsWide(displayID));
	m_impl->height = static_cast<int>(CGDisplayPixelsHigh(displayID));

	if (m_impl->width <= 0 || m_impl->height <= 0)
	{
		m_impl->width = 1920;
		m_impl->height = 1080;
	}

	size_t fbSize = static_cast<size_t>(m_impl->width * m_impl->height * 4);
	m_impl->framebuffer = new char[fbSize];
	memset(m_impl->framebuffer, 0, fbSize);
}

bool ScreenCaptureKitVncServer::runServer(int serverPort, const Password& password)
{
	if (!m_impl->framebuffer)
	{
		prepareServer();
	}

	int argc = 0;
	m_impl->rfbScreen = rfbGetScreen(&argc, nullptr,
	                                 m_impl->width, m_impl->height,
	                                 8, 3, 4);

	if (!m_impl->rfbScreen)
	{
		vCritical() << "Failed to allocate rfbScreen";
		return false;
	}

	m_impl->rfbScreen->frameBuffer = m_impl->framebuffer;
	m_impl->rfbScreen->port = serverPort;
	m_impl->rfbScreen->ipv6port = serverPort;
	m_impl->rfbScreen->alwaysShared = TRUE;
	m_impl->rfbScreen->desktopName = "Veyon macOS";
	m_impl->rfbScreen->kbdAddEvent = onKbdAddEvent;
	m_impl->rfbScreen->ptrAddEvent = onPtrAddEvent;

	if (!password.isEmpty())
	{
		m_impl->vncPassword = strdup(password.toByteArray().constData());
		m_impl->vncPasswords[0] = m_impl->vncPassword;
		m_impl->vncPasswords[1] = nullptr;
		m_impl->rfbScreen->authPasswdData = reinterpret_cast<void*>(m_impl->vncPasswords);
		m_impl->rfbScreen->passwordCheck = rfbCheckPasswordByList;
	}

	rfbInitServer(m_impl->rfbScreen);

	m_impl->capture = [[MacScreenCapture alloc] init];

	Impl* implPtr = m_impl.get();
	[m_impl->capture setFramebufferUpdateBlock:
		^(void* pixels, size_t bytesPerRow, size_t w, size_t h)
	{
		if (!implPtr || !implPtr->rfbScreen || !implPtr->framebuffer)
		{
			return;
		}

		QMutexLocker lock(&implPtr->framebufferMutex);

		size_t copyLines = std::min<size_t>(h, static_cast<size_t>(implPtr->height));
		size_t lineBytes = std::min<size_t>(bytesPerRow, static_cast<size_t>(implPtr->width * 4));

		for (size_t y = 0; y < copyLines; ++y)
		{
			memcpy(implPtr->framebuffer + y * implPtr->width * 4,
			       static_cast<char*>(pixels) + y * bytesPerRow,
			       lineBytes);
		}

		rfbMarkRectAsModified(implPtr->rfbScreen, 0, 0, implPtr->width, implPtr->height);
	}];

	CGDirectDisplayID displayID = CGMainDisplayID();
	[m_impl->capture startCaptureForDisplay:displayID
	                                  width:m_impl->width
	                                 height:m_impl->height
	                                    fps:30.0f];

	vInfo() << "VNC server running on port" << serverPort;

	while (rfbIsActive(m_impl->rfbScreen))
	{
		rfbProcessEvents(m_impl->rfbScreen, 33000);
	}

	if (m_impl->vncPassword)
	{
		free(m_impl->vncPassword);
		m_impl->vncPassword = nullptr;
	}

	return true;
}
