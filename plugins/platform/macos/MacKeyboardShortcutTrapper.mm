/*
 * MacKeyboardShortcutTrapper.mm - keyboard shortcut interceptor for macOS
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

#include "MacKeyboardShortcutTrapper.h"
#include "Logger.h"

MacKeyboardShortcutTrapper::MacKeyboardShortcutTrapper(QObject* parent)
	: KeyboardShortcutTrapper(parent)
{
}

MacKeyboardShortcutTrapper::~MacKeyboardShortcutTrapper()
{
	setEnabled(false);
}

void MacKeyboardShortcutTrapper::setEnabled(bool on)
{
	if (m_enabled == on)
	{
		return;
	}

	m_enabled = on;

	if (m_enabled)
	{
		CGEventMask mask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventFlagsChanged);

		m_eventTap = CGEventTapCreate(
			kCGHIDEventTap,
			kCGHeadInsertEventTap,
			kCGEventTapOptionDefault,
			mask,
			eventTapCallback,
			this
		);

		if (m_eventTap)
		{
			m_runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, m_eventTap, 0);
			CFRunLoopAddSource(CFRunLoopGetMain(), m_runLoopSource, kCFRunLoopCommonModes);
			CGEventTapEnable(m_eventTap, true);
		}
		else
		{
			vWarning() << "Could not create event tap for keyboard shortcut trapping";
		}
	}
	else
	{
		if (m_eventTap)
		{
			CGEventTapEnable(m_eventTap, false);
			if (m_runLoopSource)
			{
				CFRunLoopRemoveSource(CFRunLoopGetMain(), m_runLoopSource, kCFRunLoopCommonModes);
				CFRelease(m_runLoopSource);
				m_runLoopSource = nullptr;
			}
			CFRelease(m_eventTap);
			m_eventTap = nullptr;
		}
	}
}

CGEventRef MacKeyboardShortcutTrapper::eventTapCallback(CGEventTapProxy proxy, CGEventType type,
                                                       CGEventRef event, void* refcon)
{
	Q_UNUSED(proxy)
	auto* self = static_cast<MacKeyboardShortcutTrapper*>(refcon);

	if (!self || !self->m_enabled)
	{
		return event;
	}

	if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput)
	{
		if (self->m_eventTap)
		{
			CGEventTapEnable(self->m_eventTap, true);
		}
		return event;
	}

	CGEventFlags flags = CGEventGetFlags(event);
	int64_t keycode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);

	// Intercept Command-Tab (keycode 48), Command-Space (keycode 49), Command-Option-Esc (keycode 53)
	bool isCmd = (flags & kCGEventFlagMaskCommand) != 0;
	if (isCmd)
	{
		if (keycode == 48 || keycode == 49 || keycode == 53)
		{
			return nullptr; // Drop the event
		}
	}

	return event;
}
