/*
 * MacServiceFunctions.mm - service management functions for macOS
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

#include "MacServiceFunctions.h"
#include "MacServiceCore.h"
#include "Logger.h"

#include <QFile>
#include <QProcess>

QString MacServiceFunctions::veyonServiceName() const
{
	return QStringLiteral("io.veyon.service");
}

QString MacServiceFunctions::plistPath(const QString& name)
{
	return QStringLiteral("/Library/LaunchDaemons/%1.plist").arg(name);
}

bool MacServiceFunctions::isRegistered(const QString& name)
{
	return QFile::exists(plistPath(name));
}

bool MacServiceFunctions::isRunning(const QString& name)
{
	QProcess proc;
	proc.start(QStringLiteral("/bin/launchctl"), {QStringLiteral("list"), name});
	proc.waitForFinished(5000);
	return proc.exitCode() == 0;
}

bool MacServiceFunctions::start(const QString& name)
{
	const auto plist = plistPath(name);
	if (!QFile::exists(plist))
	{
		return false;
	}

	// Try bootstrap first (macOS 10.11+ modern launchctl)
	int res = QProcess::execute(QStringLiteral("/bin/launchctl"),
	                            {QStringLiteral("bootstrap"), QStringLiteral("system"), plist});
	if (res != 0)
	{
		// Fallback to legacy load
		res = QProcess::execute(QStringLiteral("/bin/launchctl"),
		                        {QStringLiteral("load"), QStringLiteral("-w"), plist});
	}

	return res == 0;
}

bool MacServiceFunctions::stop(const QString& name)
{
	const auto plist = plistPath(name);

	// Try bootout first (modern launchctl)
	int res = QProcess::execute(QStringLiteral("/bin/launchctl"),
	                            {QStringLiteral("bootout"), QStringLiteral("system"), plist});
	if (res != 0)
	{
		// Fallback to legacy unload
		res = QProcess::execute(QStringLiteral("/bin/launchctl"),
		                        {QStringLiteral("unload"), plist});
	}

	return res == 0;
}

bool MacServiceFunctions::install(const QString& name, const QString& filePath,
                                  StartMode startMode, const QString& displayName)
{
	Q_UNUSED(displayName)

	const auto targetPlist = plistPath(name);

	QFile templateFile(QStringLiteral(":/macos/io.veyon.service.plist.in"));
	if (!templateFile.open(QFile::ReadOnly))
	{
		vCritical() << "Failed to open plist template resource";
		return false;
	}

	QString plistContent = QString::fromUtf8(templateFile.readAll());
	plistContent.replace(QStringLiteral("@CMAKE_INSTALL_PREFIX@/bin/veyon-service"), filePath);

	QFile outFile(targetPlist);
	if (!outFile.open(QFile::WriteOnly | QFile::Truncate))
	{
		vCritical() << "Failed to write launchd plist to" << targetPlist;
		return false;
	}
	outFile.write(plistContent.toUtf8());
	outFile.close();

	QProcess::execute(QStringLiteral("/usr/sbin/chown"), {QStringLiteral("root:wheel"), targetPlist});
	QProcess::execute(QStringLiteral("/bin/chmod"), {QStringLiteral("644"), targetPlist});

	if (startMode == StartMode::Auto)
	{
		return start(name);
	}

	return true;
}

bool MacServiceFunctions::uninstall(const QString& name)
{
	stop(name);
	return QFile::remove(plistPath(name));
}

bool MacServiceFunctions::setStartMode(const QString& name, StartMode startMode)
{
	if (startMode == StartMode::Auto)
	{
		return start(name);
	}
	else
	{
		return stop(name);
	}
}

bool MacServiceFunctions::runAsService(const QString& name, const ServiceEntryPoint& serviceEntryPoint)
{
	Q_UNUSED(name)
	serviceEntryPoint();
	return true;
}

void MacServiceFunctions::manageServerInstances()
{
	MacServiceCore serviceCore;
	serviceCore.run();
}
