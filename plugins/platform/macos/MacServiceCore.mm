/*
 * MacServiceCore.mm - service core process and session manager for macOS
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

#include "MacServiceCore.h"
#include "MacPowerManager.h"
#include "MacSessionFunctions.h"
#include "Logger.h"
#include "VeyonConfiguration.h"

#import <SystemConfiguration/SystemConfiguration.h>
#include <QCoreApplication>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QProcessEnvironment>
#include <QTimer>

MacServiceCore::MacServiceCore(QObject* parent)
	: QObject(parent)
	, m_powerManager(new MacPowerManager(this))
	, m_sessionFunctions(new MacSessionFunctions(this))
{
}

MacServiceCore::~MacServiceCore()
{
	stopAllServers();
}

void MacServiceCore::run()
{
	m_powerManager->preventSleep();
	m_powerManager->preventNetworkSleep();

	m_sessionFunctions->startSessionMonitoring();

	connect(m_sessionFunctions, &MacSessionFunctions::consoleSessionChanged,
	        this, &MacServiceCore::onConsoleSessionChanged);

	startServerForCurrentSession();

	QEventLoop eventLoop;
	eventLoop.exec();
}

void MacServiceCore::onConsoleSessionChanged(const QString& userName, int uid)
{
	vInfo() << "Console session changed: user =" << userName << "uid =" << uid;
	stopAllServers();
	startServerForCurrentSession();
}

void MacServiceCore::startServerForCurrentSession()
{
	uid_t uid = 0;
	gid_t gid = 0;
	CFStringRef cfUserName = SCDynamicStoreCopyConsoleUser(nullptr, &uid, &gid);

	QString sessionKey;
	QProcessEnvironment serverEnv = QProcessEnvironment::systemEnvironment();

	if (cfUserName)
	{
		QString userName = QString::fromCFString(cfUserName);
		CFRelease(cfUserName);

		if (userName == QLatin1String("loginwindow") || userName.isEmpty())
		{
			sessionKey = QStringLiteral("loginwindow");
			vInfo() << "Starting server for loginwindow session";
		}
		else
		{
			sessionKey = QStringLiteral("user-%1").arg(uid);
			vInfo() << "Starting server for user session:" << userName << "uid:" << uid;

			serverEnv.insert(QStringLiteral("USER"), userName);
			serverEnv.insert(QStringLiteral("HOME"), QStringLiteral("/Users/%1").arg(userName));
			serverEnv.insert(QStringLiteral("SHELL"), QStringLiteral("/bin/zsh"));
		}
	}
	else
	{
		sessionKey = QStringLiteral("loginwindow");
		vInfo() << "No console user - starting server for loginwindow";
	}

	if (m_serverProcesses.contains(sessionKey))
	{
		vDebug() << "Server already running for session" << sessionKey;
		return;
	}

	serverEnv.insert(QStringLiteral("QT_QPA_PLATFORM"), QStringLiteral("cocoa"));
	serverEnv.insert(QStringLiteral("PATH"),
	                 QStringLiteral("/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"));
	serverEnv.insert(QLatin1String(ServiceDataManager::serviceDataTokenEnvironmentVariable()),
	                 QString::fromUtf8(m_dataManager.token().toByteArray()));

	auto sessionId = m_sessionManager.openSession(sessionKey);

	QString serverBin = QCoreApplication::applicationDirPath() + QStringLiteral("/veyon-server");
	if (!QFile::exists(serverBin))
	{
		serverBin = QStringLiteral(CMAKE_INSTALL_PREFIX "/bin/veyon-server");
	}

	auto* serverProcess = new QProcess(this);
	serverProcess->setProcessEnvironment(serverEnv);
	serverProcess->setProgram(serverBin);
	serverProcess->setArguments({});

	connect(serverProcess, &QProcess::stateChanged, this,
	        [this, sessionKey](QProcess::ProcessState state) {
		if (state == QProcess::NotRunning)
		{
			vWarning() << "Server for session" << sessionKey
			           << "stopped - restarting in"
			           << ServerRestartInterval << "ms";
			QTimer::singleShot(ServerRestartInterval, this, [this, sessionKey]() {
				if (m_serverProcesses.contains(sessionKey))
				{
					m_serverProcesses[sessionKey]->start();
				}
			});
		}
	});

	serverProcess->start();
	m_serverProcesses[sessionKey] = serverProcess;

	vInfo() << "Server started for session" << sessionKey
	        << "with ID" << sessionId;
}

void MacServiceCore::stopAllServers()
{
	for (auto it = m_serverProcesses.begin(); it != m_serverProcesses.end(); ++it)
	{
		vInfo() << "Stopping server for session" << it.key();
		m_sessionManager.closeSession(it.key());
		it.value()->disconnect(this);
		it.value()->terminate();
		if (!it.value()->waitForFinished(5000))
		{
			it.value()->kill();
		}
		it.value()->deleteLater();
	}
	m_serverProcesses.clear();
}
