/*
 * MacSessionFunctions.mm - session management functions for macOS
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

#include "MacSessionFunctions.h"
#include "Logger.h"

#import <SystemConfiguration/SystemConfiguration.h>
#import <Security/Security.h>
#import <Security/AuthSession.h>
#include <utmpx.h>
#include <unistd.h>
#include <ctime>

MacSessionFunctions::MacSessionFunctions(QObject* parent)
	: QObject(parent)
{
}

MacSessionFunctions::~MacSessionFunctions()
{
	stopSessionMonitoring();
}

void MacSessionFunctions::startSessionMonitoring()
{
	if (m_dynamicStore)
	{
		return;
	}

	SCDynamicStoreContext context = {0, this, nullptr, nullptr, nullptr};

	m_dynamicStore = SCDynamicStoreCreate(
		kCFAllocatorDefault,
		CFSTR("io.veyon.session-monitor"),
		consoleUserChangedCallback,
		&context
	);

	if (!m_dynamicStore)
	{
		vWarning() << "Failed to create SCDynamicStore for session monitoring";
		return;
	}

	CFStringRef key = SCDynamicStoreKeyCreateConsoleUser(kCFAllocatorDefault);
	CFArrayRef keys = CFArrayCreate(kCFAllocatorDefault,
	                                reinterpret_cast<const void**>(&key), 1,
	                                &kCFTypeArrayCallBacks);

	SCDynamicStoreSetNotificationKeys(m_dynamicStore, keys, nullptr);

	m_runLoopSource = SCDynamicStoreCreateRunLoopSource(
		kCFAllocatorDefault, m_dynamicStore, 0
	);
	CFRunLoopAddSource(CFRunLoopGetMain(), m_runLoopSource, kCFRunLoopCommonModes);

	CFRelease(key);
	CFRelease(keys);

	vInfo() << "Session monitoring started via SCDynamicStore";
}

void MacSessionFunctions::stopSessionMonitoring()
{
	if (m_runLoopSource)
	{
		CFRunLoopRemoveSource(CFRunLoopGetMain(), m_runLoopSource, kCFRunLoopCommonModes);
		CFRelease(m_runLoopSource);
		m_runLoopSource = nullptr;
	}
	if (m_dynamicStore)
	{
		CFRelease(m_dynamicStore);
		m_dynamicStore = nullptr;
	}
}

void MacSessionFunctions::consoleUserChangedCallback(SCDynamicStoreRef store,
                                                     CFArrayRef changedKeys,
                                                     void* info)
{
	Q_UNUSED(store)
	Q_UNUSED(changedKeys)

	auto* self = static_cast<MacSessionFunctions*>(info);
	if (!self)
	{
		return;
	}

	uid_t uid = 0;
	gid_t gid = 0;
	CFStringRef userName = SCDynamicStoreCopyConsoleUser(store, &uid, &gid);

	if (userName)
	{
		QString user = QString::fromCFString(userName);
		CFRelease(userName);

		vInfo() << "Console user changed to:" << user
		        << "uid:" << uid << "gid:" << gid;

		Q_EMIT self->consoleSessionChanged(user, static_cast<int>(uid));
	}
	else
	{
		vInfo() << "Console user logged out (loginwindow)";
		Q_EMIT self->consoleSessionChanged(QString(), 0);
	}
}

PlatformSessionFunctions::SessionId MacSessionFunctions::currentSessionId()
{
	SecuritySessionId sessionId = 0;
	SessionAttributeBits attributes = 0;

	if (SessionGetInfo(callerSecuritySession, &sessionId, &attributes) == errSecSuccess)
	{
		return static_cast<SessionId>(sessionId);
	}

	return DefaultSessionId;
}

bool MacSessionFunctions::currentSessionHasUser() const
{
	uid_t uid = 0;
	CFStringRef userName = SCDynamicStoreCopyConsoleUser(nullptr, &uid, nullptr);

	if (userName)
	{
		bool hasUser = (CFStringGetLength(userName) > 0 &&
		                CFStringCompare(userName, CFSTR("loginwindow"), 0) != kCFCompareEqualTo);
		CFRelease(userName);
		return hasUser;
	}

	return false;
}

QString MacSessionFunctions::currentSessionType() const
{
	return QStringLiteral("Aqua");
}

PlatformSessionFunctions::SessionUptime MacSessionFunctions::currentSessionUptime() const
{
	struct utmpx* entry = nullptr;
	setutxent();

	SessionUptime uptime = InvalidSessionUptime;

	while ((entry = getutxent()) != nullptr)
	{
		if (entry->ut_type == USER_PROCESS &&
		    strcmp(entry->ut_line, "console") == 0)
		{
			time_t loginTime = entry->ut_tv.tv_sec;
			time_t now = time(nullptr);
			uptime = static_cast<SessionUptime>(now - loginTime);
			break;
		}
	}

	endutxent();
	return uptime;
}

QString MacSessionFunctions::currentSessionClientAddress() const
{
	return {};
}

QString MacSessionFunctions::currentSessionClientName() const
{
	char hostname[256];
	if (gethostname(hostname, sizeof(hostname)) == 0)
	{
		return QString::fromLocal8Bit(hostname);
	}
	return {};
}

QString MacSessionFunctions::currentSessionHostName() const
{
	return currentSessionClientName();
}

PlatformSessionFunctions::EnvironmentVariables MacSessionFunctions::currentSessionEnvironmentVariables() const
{
	EnvironmentVariables vars;
	const auto env = QProcessEnvironment::systemEnvironment();
	const auto keys = env.keys();
	for (const auto& key : keys)
	{
		vars.insert(key, env.value(key));
	}
	return vars;
}

QVariant MacSessionFunctions::querySettingsValueInCurrentSession(const QString& key) const
{
	Q_UNUSED(key)
	return {};
}
