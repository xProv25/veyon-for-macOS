/*
 * MacPlatformPlugin.h - declaration of MacPlatformPlugin class
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

#include "ConfigurationPagePluginInterface.h"
#include "PluginInterface.h"
#include "PlatformPluginInterface.h"
#include "MacCoreFunctions.h"
#include "MacFilesystemFunctions.h"
#include "MacInputDeviceFunctions.h"
#include "MacNetworkFunctions.h"
#include "MacServiceFunctions.h"
#include "MacSessionFunctions.h"
#include "MacUserFunctions.h"

class MacPlatformPlugin : public QObject, PlatformPluginInterface, PluginInterface, ConfigurationPagePluginInterface
{
	Q_OBJECT
	Q_PLUGIN_METADATA(IID "io.veyon.Veyon.Plugins.MacPlatform")
	Q_INTERFACES(PluginInterface PlatformPluginInterface ConfigurationPagePluginInterface)
public:
	explicit MacPlatformPlugin(QObject* parent = nullptr);
	~MacPlatformPlugin() override;

	Plugin::Uid uid() const override
	{
		return Plugin::Uid{ QStringLiteral("d4e5f6a7-b8c9-0123-def0-456789abcdef") };
	}

	QVersionNumber version() const override
	{
		return QVersionNumber(1, 0);
	}

	QString name() const override
	{
		return QStringLiteral("MacPlatformPlugin");
	}

	QString description() const override
	{
		return tr("Plugin implementing abstract functions for the macOS platform");
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

	PlatformCoreFunctions& coreFunctions() override
	{
		return m_coreFunctions;
	}

	PlatformFilesystemFunctions& filesystemFunctions() override
	{
		return m_filesystemFunctions;
	}

	PlatformInputDeviceFunctions& inputDeviceFunctions() override
	{
		return m_inputDeviceFunctions;
	}

	PlatformNetworkFunctions& networkFunctions() override
	{
		return m_networkFunctions;
	}

	PlatformServiceFunctions& serviceFunctions() override
	{
		return m_serviceFunctions;
	}

	PlatformSessionFunctions& sessionFunctions() override
	{
		return m_sessionFunctions;
	}

	PlatformUserFunctions& userFunctions() override
	{
		return m_userFunctions;
	}

	ConfigurationPage* createConfigurationPage() override
	{
		return nullptr;
	}

	static void abort(int signal);
	static QString formattedBacktraceString();

private:
	MacCoreFunctions m_coreFunctions{};
	MacFilesystemFunctions m_filesystemFunctions{};
	MacInputDeviceFunctions m_inputDeviceFunctions{};
	MacNetworkFunctions m_networkFunctions{};
	MacServiceFunctions m_serviceFunctions{};
	MacSessionFunctions m_sessionFunctions{};
	MacUserFunctions m_userFunctions{};
};
