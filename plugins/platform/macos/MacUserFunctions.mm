/*
 * MacUserFunctions.mm - user management functions for macOS
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

#include "MacUserFunctions.h"
#include "PersistentLogonCredentials.h"
#include "Logger.h"

#import <OpenDirectory/OpenDirectory.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <pwd.h>
#include <grp.h>
#include <unistd.h>
#include <QProcess>

MacUserFunctions::MacUserFunctions()
{
}

QString MacUserFunctions::queryCurrentUserProperty(UserProperty property)
{
	switch (property)
	{
	case UserProperty::LoginName: return currentUserLoginName();
	case UserProperty::FullName: return currentUserFullName();
	case UserProperty::None: break;
	}
	return {};
}

QString MacUserFunctions::currentUserLoginName() const
{
	uid_t uid = 0;
	CFStringRef userName = SCDynamicStoreCopyConsoleUser(nullptr, &uid, nullptr);
	if (userName)
	{
		QString user = QString::fromCFString(userName);
		CFRelease(userName);
		if (!user.isEmpty() && user != QLatin1String("loginwindow"))
		{
			return user;
		}
	}

	const auto envUser = qgetenv("USER");
	if (!envUser.isEmpty())
	{
		return QString::fromUtf8(envUser);
	}

	struct passwd* pw = getpwuid(getuid());
	if (pw && pw->pw_name)
	{
		return QString::fromUtf8(pw->pw_name);
	}

	return {};
}

QString MacUserFunctions::currentUserFullName() const
{
	const auto username = currentUserLoginName();
	if (username.isEmpty())
	{
		return {};
	}

	@autoreleasepool {
		ODSession* session = [ODSession defaultSession];
		ODNode* node = [ODNode nodeWithSession:session
		                                  type:kODNodeTypeLocalNodes
		                                 error:nil];

		ODQuery* query = [ODQuery queryWithNode:node
		                         forRecordTypes:kODRecordTypeUsers
		                              attribute:kODAttributeTypeRecordName
		                              matchType:kODMatchEqualTo
		                            queryValues:username.toNSString()
		                       returnAttributes:kODAttributeTypeFullName
		                         maximumResults:1
		                                  error:nil];

		NSArray* results = [query resultsAllowingPartial:NO error:nil];
		if (results.count > 0)
		{
			ODRecord* record = results[0];
			NSArray* names = [record valuesForAttribute:kODAttributeTypeFullName error:nil];
			if (names.count > 0)
			{
				return QString::fromNSString(names[0]);
			}
		}
	}

	struct passwd* pw = getpwnam(username.toUtf8().constData());
	if (pw && pw->pw_gecos)
	{
		return QString::fromUtf8(pw->pw_gecos).split(QLatin1Char(',')).first();
	}

	return username;
}

QStringList MacUserFunctions::userGroups(bool queryDomainGroups)
{
	Q_UNUSED(queryDomainGroups)
	QStringList groups;

	@autoreleasepool {
		ODSession* session = [ODSession defaultSession];
		ODNode* node = [ODNode nodeWithSession:session
		                                  type:kODNodeTypeLocalNodes
		                                 error:nil];

		ODQuery* query = [ODQuery queryWithNode:node
		                         forRecordTypes:kODRecordTypeGroups
		                              attribute:nil
		                              matchType:kODMatchAny
		                            queryValues:nil
		                       returnAttributes:kODAttributeTypeRecordName
		                         maximumResults:0
		                                  error:nil];

		NSArray* results = [query resultsAllowingPartial:NO error:nil];
		for (ODRecord* record in results)
		{
			NSArray* names = [record valuesForAttribute:kODAttributeTypeRecordName error:nil];
			for (NSString* name in names)
			{
				QString groupName = QString::fromNSString(name);
				if (!groupName.startsWith(QLatin1Char('_')))
				{
					groups.append(groupName);
				}
			}
		}
	}

	return groups;
}

QStringList MacUserFunctions::groupsOfUser(const QString& username, bool queryDomainGroups)
{
	Q_UNUSED(queryDomainGroups)
	QStringList groups;

	@autoreleasepool {
		ODSession* session = [ODSession defaultSession];
		ODNode* node = [ODNode nodeWithSession:session
		                                  type:kODNodeTypeLocalNodes
		                                 error:nil];

		ODRecord* userRecord = [node recordWithRecordType:kODRecordTypeUsers
		                                             name:username.toNSString()
		                                       attributes:nil
		                                            error:nil];
		if (userRecord)
		{
			ODQuery* query = [ODQuery queryWithNode:node
			                         forRecordTypes:kODRecordTypeGroups
			                              attribute:nil
			                              matchType:kODMatchAny
			                            queryValues:nil
			                       returnAttributes:kODAttributeTypeRecordName
			                         maximumResults:0
			                                  error:nil];

			NSArray* groupRecords = [query resultsAllowingPartial:NO error:nil];
			for (ODRecord* grp in groupRecords)
			{
				if ([grp isMemberRecord:userRecord error:nil])
				{
					NSArray* names = [grp valuesForAttribute:kODAttributeTypeRecordName error:nil];
					if (names.count > 0)
					{
						groups.append(QString::fromNSString(names[0]));
					}
				}
			}
		}
	}

	return groups;
}

QString MacUserFunctions::userGroupSecurityIdentifier(const QString& groupName)
{
	@autoreleasepool {
		ODSession* session = [ODSession defaultSession];
		ODNode* node = [ODNode nodeWithSession:session
		                                  type:kODNodeTypeLocalNodes
		                                 error:nil];

		ODRecord* grp = [node recordWithRecordType:kODRecordTypeGroups
		                                      name:groupName.toNSString()
		                                attributes:nil
		                                     error:nil];
		if (grp)
		{
			NSArray* guid = [grp valuesForAttribute:kODAttributeTypeGUID error:nil];
			if (guid.count > 0)
			{
				return QString::fromNSString(guid[0]);
			}
		}
	}

	struct group* gr = getgrnam(groupName.toUtf8().constData());
	if (gr)
	{
		return QString::number(gr->gr_gid);
	}

	return {};
}

bool MacUserFunctions::isAnyUserLoggedOn()
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

bool MacUserFunctions::prepareLogon(const QString& username, const Password& password)
{
	return PersistentLogonCredentials::write(username, password);
}

bool MacUserFunctions::performLogon(const QString& username, const Password& password)
{
	Q_UNUSED(username)
	Q_UNUSED(password)
	return true;
}

void MacUserFunctions::logoff()
{
	QProcess::startDetached(QStringLiteral("/usr/bin/osascript"),
	                        {QStringLiteral("-e"),
	                         QStringLiteral("tell application \"System Events\" to log out")});
}

bool MacUserFunctions::authenticate(const QString& username, const Password& password)
{
	@autoreleasepool {
		ODSession* session = [ODSession defaultSession];
		ODNode* node = [ODNode nodeWithSession:session
		                                  type:kODNodeTypeLocalNodes
		                                 error:nil];

		ODRecord* userRecord = [node recordWithRecordType:kODRecordTypeUsers
		                                             name:username.toNSString()
		                                       attributes:nil
		                                            error:nil];
		if (userRecord)
		{
			NSError* error = nil;
			NSString* passStr = QString::fromUtf8(password.toByteArray()).toNSString();
			BOOL ok = [userRecord verifyPassword:passStr error:&error];
			if (ok)
			{
				vDebug() << "User authenticated successfully via OpenDirectory";
				return true;
			}
			else if (error)
			{
				vWarning() << "OpenDirectory authentication failed:"
				           << QString::fromNSString(error.localizedDescription);
			}
		}
	}

	return false;
}
