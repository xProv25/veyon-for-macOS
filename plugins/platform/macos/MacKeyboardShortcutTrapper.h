/*
 * MacKeyboardShortcutTrapper.h - keyboard shortcut interceptor for macOS
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

#pragma once

#include "KeyboardShortcutTrapper.h"
#include <CoreGraphics/CoreGraphics.h>

class MacKeyboardShortcutTrapper : public KeyboardShortcutTrapper
{
	Q_OBJECT
public:
	explicit MacKeyboardShortcutTrapper(QObject* parent = nullptr);
	~MacKeyboardShortcutTrapper() override;

	void setEnabled(bool on) override;

private:
	static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type,
	                                   CGEventRef event, void* refcon);

	CFMachPortRef m_eventTap{nullptr};
	CFRunLoopSourceRef m_runLoopSource{nullptr};
	bool m_enabled{false};
};
