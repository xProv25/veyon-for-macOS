/*
 * ScreenCaptureKitConfiguration.h - configuration for ScreenCaptureKit VNC server
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

#include "Configuration/Proxy.h"

#define FOREACH_SCREENCAPTUREKIT_CONFIG_PROPERTY(OP) \
	OP( ScreenCaptureKitConfiguration, m_configuration, int, captureFramerate, setCaptureFramerate, "CaptureFramerate", "ScreenCaptureKitVncServer", 30, Configuration::Property::Flag::Advanced ) \
	OP( ScreenCaptureKitConfiguration, m_configuration, bool, showCursor, setShowCursor, "ShowCursor", "ScreenCaptureKitVncServer", true, Configuration::Property::Flag::Advanced )

DECLARE_CONFIG_PROXY(ScreenCaptureKitConfiguration, FOREACH_SCREENCAPTUREKIT_CONFIG_PROPERTY)
