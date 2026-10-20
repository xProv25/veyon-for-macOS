/*
 * MacCoreFunctions.mm - core platform functions for macOS
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

#include "MacCoreFunctions.h"
#include "Logger.h"

#import <Cocoa/Cocoa.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#include <unistd.h>
#include <QProcess>
#include <QScreen>
#include <QWidget>

MacCoreFunctions::MacCoreFunctions()
{
}

MacCoreFunctions::~MacCoreFunctions()
{
	restoreScreenSaverSettings();
}

bool MacCoreFunctions::applyConfiguration()
{
	return true;
}

bool MacCoreFunctions::prepareSessionBusAccess()
{
	return true;
}

void MacCoreFunctions::initNativeLoggingSystem(const QString& appName)
{
	Q_UNUSED(appName)
}

void MacCoreFunctions::writeToNativeLoggingSystem(const QString& message, Logger::LogLevel loglevel)
{
	NSString* nsMessage = message.toNSString();
	switch (loglevel)
	{
	case Logger::LogLevel::Error:
	case Logger::LogLevel::Critical:
		NSLog(@"[Veyon ERROR] %@", nsMessage);
		break;
	case Logger::LogLevel::Warning:
		NSLog(@"[Veyon WARN] %@", nsMessage);
		break;
	default:
		NSLog(@"[Veyon] %@", nsMessage);
		break;
	}
}

StandardInputReader* MacCoreFunctions::createStandardInputReader(QObject* parent)
{
	Q_UNUSED(parent)
	return nullptr;
}

void MacCoreFunctions::reboot()
{
	QProcess::startDetached(
		QStringLiteral("/usr/bin/osascript"),
		{QStringLiteral("-e"),
		 QStringLiteral("tell application \"System Events\" to restart")}
	);
}

void MacCoreFunctions::powerDown(bool installUpdates)
{
	Q_UNUSED(installUpdates)
	QProcess::startDetached(
		QStringLiteral("/usr/bin/osascript"),
		{QStringLiteral("-e"),
		 QStringLiteral("tell application \"System Events\" to shut down")}
	);
}

void MacCoreFunctions::raiseWindow(QWidget* widget, bool stayOnTop)
{
	if (!widget)
	{
		return;
	}

	if (stayOnTop)
	{
		widget->setWindowFlags(widget->windowFlags() | Qt::WindowStaysOnTopHint);
	}
	widget->show();
	widget->raise();
	widget->activateWindow();
}

void MacCoreFunctions::disableScreenSaver()
{
	if (m_screenSaverAssertionID == kIOPMNullAssertionID)
	{
		IOPMAssertionCreateWithName(
			kIOPMAssertPreventUserIdleDisplaySleep,
			kIOPMAssertionLevelOn,
			CFSTR("Veyon - Disable Screen Saver"),
			&m_screenSaverAssertionID
		);
	}
}

void MacCoreFunctions::restoreScreenSaverSettings()
{
	if (m_screenSaverAssertionID != kIOPMNullAssertionID)
	{
		IOPMAssertionRelease(m_screenSaverAssertionID);
		m_screenSaverAssertionID = kIOPMNullAssertionID;
	}
}

void MacCoreFunctions::setSystemUiState(bool enabled)
{
	Q_UNUSED(enabled)
}

QString MacCoreFunctions::activeDesktopName()
{
	return QStringLiteral("Aqua");
}

bool MacCoreFunctions::isRunningAsAdmin() const
{
	return geteuid() == 0;
}

bool MacCoreFunctions::runProgramAsAdmin(const QString& program, const QStringList& parameters)
{
	QString escapedScript = QStringLiteral("do shell script \"%1 %2\" with administrator privileges")
	                        .arg(program, parameters.join(QLatin1Char(' ')));

	return QProcess::execute(QStringLiteral("/usr/bin/osascript"),
	                         {QStringLiteral("-e"), escapedScript}) == 0;
}

bool MacCoreFunctions::runProgramAsUser(const QString& program,
                                       const QStringList& parameters,
                                       const QString& username,
                                       const QString& desktop,
                                       const QByteArray& stdInData)
{
	Q_UNUSED(desktop)

	QStringList args = {
		QStringLiteral("-"), username,
		QStringLiteral("-c"),
		program + QLatin1Char(' ') + parameters.join(QLatin1Char(' '))
	};

	QProcess proc;
	proc.start(QStringLiteral("/usr/bin/su"), args);

	if (!stdInData.isEmpty())
	{
		proc.write(stdInData);
		proc.closeWriteChannel();
	}

	return proc.waitForFinished(30000) && proc.exitCode() == 0;
}

QString MacCoreFunctions::genericUrlHandler() const
{
	return QStringLiteral("/usr/bin/open");
}

QString MacCoreFunctions::queryDisplayDeviceName(const QScreen& screen) const
{
	return screen.name();
}

QString MacCoreFunctions::getApplicationName(ProcessId processId) const
{
	@autoreleasepool {
		NSRunningApplication* app = [NSRunningApplication
			runningApplicationWithProcessIdentifier:static_cast<pid_t>(processId)];
		if (app)
		{
			return QString::fromNSString(app.localizedName ?: app.bundleIdentifier);
		}
	}
	return {};
}
