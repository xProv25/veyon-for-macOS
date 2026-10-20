/*
 * MacSessionFunctions.h - session management functions for macOS
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

#include <QObject>
#include <SystemConfiguration/SystemConfiguration.h>
#include "PlatformSessionFunctions.h"

class MacSessionFunctions : public QObject, public PlatformSessionFunctions
{
	Q_OBJECT
public:
	explicit MacSessionFunctions(QObject* parent = nullptr);
	~MacSessionFunctions() override;

	SessionId currentSessionId() override;

	SessionUptime currentSessionUptime() const override;
	QString currentSessionClientAddress() const override;
	QString currentSessionClientName() const override;
	QString currentSessionHostName() const override;

	QString currentSessionType() const override;
	bool currentSessionHasUser() const override;

	EnvironmentVariables currentSessionEnvironmentVariables() const override;
	QVariant querySettingsValueInCurrentSession(const QString& key) const override;

	void startSessionMonitoring();
	void stopSessionMonitoring();

Q_SIGNALS:
	void consoleSessionChanged(const QString& username, int uid);

private:
	static void consoleUserChangedCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void* info);

	SCDynamicStoreRef m_dynamicStore{nullptr};
	CFRunLoopSourceRef m_runLoopSource{nullptr};
};
