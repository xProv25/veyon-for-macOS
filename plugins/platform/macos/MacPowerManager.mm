/*
 * MacPowerManager.mm - IOKit Power Management assertion and notification handler
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

#include "MacPowerManager.h"
#include "Logger.h"

#import <IOKit/pwr_mgt/IOPMLib.h>
#import <IOKit/IOMessage.h>
#import <CoreFoundation/CoreFoundation.h>

MacPowerManager::MacPowerManager(QObject* parent)
	: QObject(parent)
{
	registerSleepWakeNotifications();
}

MacPowerManager::~MacPowerManager()
{
	allowSleep();
	allowNetworkSleep();

	if (m_notifierObject)
	{
		IODeregisterForSystemPower(&m_notifierObject);
		m_notifierObject = 0;
	}
	if (m_notifyPort)
	{
		IONotificationPortDestroy(m_notifyPort);
		m_notifyPort = nullptr;
	}
}

bool MacPowerManager::preventSleep()
{
	if (m_sleepAssertionID != kIOPMNullAssertionID)
	{
		return true;
	}

	IOReturn ret = IOPMAssertionCreateWithName(
		kIOPMAssertPreventUserIdleSystemSleep,
		kIOPMAssertionLevelOn,
		CFSTR("Veyon Service - Continuous Monitoring Active"),
		&m_sleepAssertionID
	);

	if (ret != kIOReturnSuccess)
	{
		vWarning() << "Failed to create sleep prevention assertion:"
		           << QString::number(ret, 16);
		m_sleepAssertionID = kIOPMNullAssertionID;
		return false;
	}

	vInfo() << "System sleep prevention assertion created (ID:"
	        << m_sleepAssertionID << ")";
	return true;
}

void MacPowerManager::allowSleep()
{
	if (m_sleepAssertionID != kIOPMNullAssertionID)
	{
		IOPMAssertionRelease(m_sleepAssertionID);
		vInfo() << "System sleep prevention assertion released";
		m_sleepAssertionID = kIOPMNullAssertionID;
	}
}

bool MacPowerManager::preventNetworkSleep()
{
	if (m_networkAssertionID != kIOPMNullAssertionID)
	{
		return true;
	}

	IOReturn ret = IOPMAssertionCreateWithName(
		kIOPMAssertNetworkClientActive,
		kIOPMAssertionLevelOn,
		CFSTR("Veyon VNC Server - Network Client Active"),
		&m_networkAssertionID
	);

	if (ret != kIOReturnSuccess)
	{
		vWarning() << "Failed to create network assertion:"
		           << QString::number(ret, 16);
		m_networkAssertionID = kIOPMNullAssertionID;
		return false;
	}

	vInfo() << "Network sleep prevention assertion created (ID:"
	        << m_networkAssertionID << ")";
	return true;
}

void MacPowerManager::allowNetworkSleep()
{
	if (m_networkAssertionID != kIOPMNullAssertionID)
	{
		IOPMAssertionRelease(m_networkAssertionID);
		vInfo() << "Network sleep prevention assertion released";
		m_networkAssertionID = kIOPMNullAssertionID;
	}
}

void MacPowerManager::registerSleepWakeNotifications()
{
	m_rootPort = IORegisterForSystemPower(
		this,
		&m_notifyPort,
		sleepWakeCallback,
		&m_notifierObject
	);

	if (m_rootPort == 0)
	{
		vWarning() << "Failed to register for system power notifications";
		return;
	}

	CFRunLoopAddSource(
		CFRunLoopGetCurrent(),
		IONotificationPortGetRunLoopSource(m_notifyPort),
		kCFRunLoopDefaultMode
	);

	vInfo() << "Registered for sleep/wake system power notifications";
}

void MacPowerManager::sleepWakeCallback(void* refCon, io_service_t service,
                                        natural_t messageType, void* messageArgument)
{
	Q_UNUSED(service)
	auto* self = static_cast<MacPowerManager*>(refCon);

	switch (messageType)
	{
	case kIOMessageCanSystemSleep:
		if (self->isSleepPrevented())
		{
			IOCancelPowerChange(self->m_rootPort, reinterpret_cast<intptr_t>(messageArgument));
			vDebug() << "Denied system idle sleep request";
		}
		else
		{
			IOAllowPowerChange(self->m_rootPort, reinterpret_cast<intptr_t>(messageArgument));
		}
		break;

	case kIOMessageSystemWillSleep:
		vInfo() << "System will sleep";
		IOAllowPowerChange(self->m_rootPort, reinterpret_cast<intptr_t>(messageArgument));
		break;

	case kIOMessageSystemHasPoweredOn:
		vInfo() << "System has powered on - restoring assertions";
		self->preventSleep();
		self->preventNetworkSleep();
		break;

	default:
		break;
	}
}
