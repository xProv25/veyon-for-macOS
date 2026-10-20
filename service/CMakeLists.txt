include(BuildVeyonApplication)

build_veyon_application(veyon-service
	NAME Service
	SOURCES
	src/main.cpp)

if(VEYON_BUILD_LINUX)
	configure_file(${CMAKE_CURRENT_SOURCE_DIR}/veyon.service.in ${CMAKE_CURRENT_BINARY_DIR}/veyon.service @ONLY)
	if(NOT SYSTEMD_SERVICE_INSTALL_DIR)
		set(SYSTEMD_SERVICE_INSTALL_DIR /lib/systemd/system)
	endif()
	install(FILES ${CMAKE_CURRENT_BINARY_DIR}/veyon.service DESTINATION ${SYSTEMD_SERVICE_INSTALL_DIR})
endif()

if(VEYON_BUILD_APPLE)
	configure_file(${CMAKE_SOURCE_DIR}/plugins/platform/macos/io.veyon.service.plist.in ${CMAKE_CURRENT_BINARY_DIR}/io.veyon.service.plist @ONLY)
	if(NOT LAUNCHD_DAEMON_INSTALL_DIR)
		set(LAUNCHD_DAEMON_INSTALL_DIR /Library/LaunchDaemons)
	endif()
	install(FILES ${CMAKE_CURRENT_BINARY_DIR}/io.veyon.service.plist DESTINATION ${LAUNCHD_DAEMON_INSTALL_DIR})
endif()
