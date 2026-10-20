/*
 * ScreenCaptureKitVncServer.h - VNC server plugin using ScreenCaptureKit
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

#include <memory>
#include <QObject>

#include "PluginInterface.h"
#include "VncServerPluginInterface.h"

class ScreenCaptureKitVncServer : public QObject, public VncServerPluginInterface, public PluginInterface
{
	Q_OBJECT
	Q_PLUGIN_METADATA(IID "io.veyon.Veyon.Plugins.ScreenCaptureKitVncServer")
	Q_INTERFACES(PluginInterface VncServerPluginInterface)
public:
	explicit ScreenCaptureKitVncServer(QObject* parent = nullptr);
	~ScreenCaptureKitVncServer() override;

	Plugin::Uid uid() const override
	{
		return Plugin::Uid{ QStringLiteral("a8e3b2f4-7c91-4d6e-b5a1-f0e2d4c6a8b0") };
	}

	QVersionNumber version() const override
	{
		return QVersionNumber(1, 0);
	}

	QString name() const override
	{
		return QStringLiteral("ScreenCaptureKitVncServer");
	}

	QString description() const override
	{
		return tr("macOS screen capture using ScreenCaptureKit/CoreGraphics");
	}

	QString vendor() const override
	{
		return QStringLiteral("Veyon Community");
	}

	QString copyright() const override
	{
		return QStringLiteral("Tobias Junghans");
	}

	Plugin::Flags flags() const override
	{
		return Plugin::ProvidesDefaultImplementation;
	}

	QStringList supportedSessionTypes() const override
	{
		return { QStringLiteral("Aqua") };
	}

	QWidget* configurationWidget() override
	{
		return nullptr;
	}

	void prepareServer() override;
	bool runServer(int serverPort, const Password& password) override;

	int configuredServerPort() override
	{
		return -1;
	}

	Password configuredPassword() override
	{
		return {};
	}

private:
	struct Impl;
	std::unique_ptr<Impl> m_impl;
};
