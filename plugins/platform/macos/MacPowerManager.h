/*
 * MacPowerManager.h - IOKit Power Management assertion and notification handler
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

#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>
#include <QObject>

class MacPowerManager : public QObject
{
	Q_OBJECT
public:
	explicit MacPowerManager(QObject* parent = nullptr);
	~MacPowerManager() override;

	bool preventSleep();
	void allowSleep();

	bool preventNetworkSleep();
	void allowNetworkSleep();

	void registerSleepWakeNotifications();

	bool isSleepPrevented() const { return m_sleepAssertionID != kIOPMNullAssertionID; }
	bool isNetworkSleepPrevented() const { return m_networkAssertionID != kIOPMNullAssertionID; }

private:
	static void sleepWakeCallback(void* refCon, io_service_t service,
	                              natural_t messageType, void* messageArgument);

	IOPMAssertionID m_sleepAssertionID{kIOPMNullAssertionID};
	IOPMAssertionID m_networkAssertionID{kIOPMNullAssertionID};
	io_connect_t m_rootPort{0};
	IONotificationPortRef m_notifyPort{nullptr};
	io_object_t m_notifierObject{0};
};
