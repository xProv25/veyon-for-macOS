/*
 * MacInputDeviceFunctions.mm - input device control for macOS
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

#include "MacInputDeviceFunctions.h"
#include "MacKeyboardShortcutTrapper.h"
#include "Logger.h"

MacInputDeviceFunctions::MacInputDeviceFunctions()
{
}

MacInputDeviceFunctions::~MacInputDeviceFunctions()
{
	enableInputDevices();
}

void MacInputDeviceFunctions::disableInputDevices()
{
	if (m_inputDisabled)
	{
		return;
	}

	m_inputDisabled = true;

	CGEventMask mask = CGEventMaskBit(kCGEventKeyDown) |
	                   CGEventMaskBit(kCGEventKeyUp) |
	                   CGEventMaskBit(kCGEventFlagsChanged) |
	                   CGEventMaskBit(kCGEventLeftMouseDown) |
	                   CGEventMaskBit(kCGEventLeftMouseUp) |
	                   CGEventMaskBit(kCGEventRightMouseDown) |
	                   CGEventMaskBit(kCGEventRightMouseUp) |
	                   CGEventMaskBit(kCGEventMouseMoved) |
	                   CGEventMaskBit(kCGEventLeftMouseDragged) |
	                   CGEventMaskBit(kCGEventRightMouseDragged) |
	                   CGEventMaskBit(kCGEventScrollWheel) |
	                   CGEventMaskBit(kCGEventOtherMouseDown) |
	                   CGEventMaskBit(kCGEventOtherMouseUp) |
	                   CGEventMaskBit(kCGEventOtherMouseDragged);

	m_blockTap = CGEventTapCreate(
		kCGHIDEventTap,
		kCGHeadInsertEventTap,
		kCGEventTapOptionDefault,
		mask,
		blockInputCallback,
		this
	);

	if (m_blockTap)
	{
		m_runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, m_blockTap, 0);
		CFRunLoopAddSource(CFRunLoopGetMain(), m_runLoopSource, kCFRunLoopCommonModes);
		CGEventTapEnable(m_blockTap, true);
		vInfo() << "Local input devices disabled";
	}
	else
	{
		vWarning() << "Failed to create event tap to disable input devices";
	}
}

void MacInputDeviceFunctions::enableInputDevices()
{
	if (!m_inputDisabled)
	{
		return;
	}

	m_inputDisabled = false;

	if (m_blockTap)
	{
		CGEventTapEnable(m_blockTap, false);
		if (m_runLoopSource)
		{
			CFRunLoopRemoveSource(CFRunLoopGetMain(), m_runLoopSource, kCFRunLoopCommonModes);
			CFRelease(m_runLoopSource);
			m_runLoopSource = nullptr;
		}
		CFRelease(m_blockTap);
		m_blockTap = nullptr;
		vInfo() << "Local input devices enabled";
	}
}

KeyboardShortcutTrapper* MacInputDeviceFunctions::createKeyboardShortcutTrapper(QObject* parent)
{
	return new MacKeyboardShortcutTrapper(parent);
}

CGEventRef MacInputDeviceFunctions::blockInputCallback(CGEventTapProxy proxy, CGEventType type,
                                                       CGEventRef event, void* refcon)
{
	Q_UNUSED(proxy)
	auto* self = static_cast<MacInputDeviceFunctions*>(refcon);

	if (!self || !self->m_inputDisabled)
	{
		return event;
	}

	if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput)
	{
		if (self->m_blockTap)
		{
			CGEventTapEnable(self->m_blockTap, true);
		}
		return event;
	}

	// Suppress hardware user input
	return nullptr;
}
