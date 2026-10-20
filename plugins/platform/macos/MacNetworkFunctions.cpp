/*
 * MacNetworkFunctions.cpp - network functions for macOS
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

#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>

#include <QProcess>
#include <QRegularExpression>

#include "MacNetworkFunctions.h"
#include "Logger.h"

PlatformNetworkFunctions::PingResult MacNetworkFunctions::ping(const QString& hostAddress)
{
	QProcess pingProcess;
	pingProcess.start(QStringLiteral("/sbin/ping"),
	                  {QStringLiteral("-c"), QStringLiteral("1"),
	                   QStringLiteral("-t"), QString::number(PingTimeout / 1000),
	                   hostAddress});

	if (pingProcess.waitForFinished(PingProcessTimeout))
	{
		switch (pingProcess.exitCode())
		{
		case 0: return PingResult::ReplyReceived;
		case 1: return PingResult::TimedOut;
		case 2: return PingResult::NameResolutionFailed;
		default:
			break;
		}
	}

	return PingResult::Unknown;
}

bool MacNetworkFunctions::configureFirewallException(const QString& applicationPath, const QString& description, bool enabled)
{
	Q_UNUSED(description)

	QStringList args;
	if (enabled)
	{
		args << QStringLiteral("--add") << applicationPath
		     << QStringLiteral("--unblockapp") << applicationPath;
	}
	else
	{
		args << QStringLiteral("--blockapp") << applicationPath;
	}

	return QProcess::execute(QStringLiteral("/usr/libexec/ApplicationFirewall/socketfilterfw"), args) == 0;
}

bool MacNetworkFunctions::configureSocketKeepalive(Socket socket, bool enabled, int idleTime, int interval, int probes)
{
	int optval = enabled ? 1 : 0;
	socklen_t optlen = sizeof(optval);
	auto fd = static_cast<int>(socket);

	if (setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &optval, optlen) < 0)
	{
		vWarning() << "could not set SO_KEEPALIVE";
		return false;
	}

#if defined(TCP_KEEPALIVE)
	optval = std::max<int>(1, idleTime / 1000);
	if (setsockopt(fd, IPPROTO_TCP, TCP_KEEPALIVE, &optval, optlen) < 0)
	{
		vWarning() << "could not set TCP_KEEPALIVE";
		return false;
	}
#elif defined(TCP_KEEPIDLE)
	optval = std::max<int>(1, idleTime / 1000);
	if (setsockopt(fd, IPPROTO_TCP, TCP_KEEPIDLE, &optval, optlen) < 0)
	{
		vWarning() << "could not set TCP_KEEPIDLE";
		return false;
	}
#endif

#if defined(TCP_KEEPINTVL)
	optval = std::max<int>(1, interval / 1000);
	if (setsockopt(fd, IPPROTO_TCP, TCP_KEEPINTVL, &optval, optlen) < 0)
	{
		vWarning() << "could not set TCP_KEEPINTVL";
		return false;
	}
#endif

#if defined(TCP_KEEPCNT)
	optval = probes;
	if (setsockopt(fd, IPPROTO_TCP, TCP_KEEPCNT, &optval, optlen) < 0)
	{
		vWarning() << "could not set TCP_KEEPCNT";
		return false;
	}
#endif

	return true;
}

QNetworkInterface MacNetworkFunctions::defaultRouteNetworkInterface()
{
	QProcess proc;
	proc.start(QStringLiteral("/sbin/route"), {QStringLiteral("-n"), QStringLiteral("get"), QStringLiteral("default")});
	if (proc.waitForFinished(3000) && proc.exitCode() == 0)
	{
		const auto output = QString::fromUtf8(proc.readAllStandardOutput());
		static const QRegularExpression rx(QStringLiteral("interface:\\s*(\\S+)"));
		const auto match = rx.match(output);
		if (match.hasMatch())
		{
			return QNetworkInterface::interfaceFromName(match.captured(1).trimmed());
		}
	}

	return {};
}

int MacNetworkFunctions::networkInterfaceSpeedInMBitPerSecond(const QNetworkInterface& networkInterface)
{
	if (networkInterface.isValid())
	{
		// Default to 1 Gbps on modern macOS network adapters
		return 1000;
	}

	return 0;
}
