include(BuildVeyonPlugin)

find_library(COCOA_FRAMEWORK Cocoa REQUIRED)
find_library(IOKIT_FRAMEWORK IOKit REQUIRED)
find_library(COREGRAPHICS_FRAMEWORK CoreGraphics REQUIRED)
find_library(SECURITY_FRAMEWORK Security REQUIRED)
find_library(SYSTEMCONFIGURATION_FRAMEWORK SystemConfiguration REQUIRED)
find_library(OPENDIRECTORY_FRAMEWORK OpenDirectory REQUIRED)
find_library(SERVICEMANAGEMENT_FRAMEWORK ServiceManagement REQUIRED)

set(macos_platform_SOURCES
	MacPlatformPlugin.h
	MacPlatformPlugin.mm
	MacPlatformConfiguration.h
	MacCoreFunctions.h
	MacCoreFunctions.mm
	MacFilesystemFunctions.h
	MacFilesystemFunctions.cpp
	MacInputDeviceFunctions.h
	MacInputDeviceFunctions.mm
	MacKeyboardShortcutTrapper.h
	MacKeyboardShortcutTrapper.mm
	MacNetworkFunctions.h
	MacNetworkFunctions.cpp
	MacServiceFunctions.h
	MacServiceFunctions.mm
	MacServiceCore.h
	MacServiceCore.mm
	MacSessionFunctions.h
	MacSessionFunctions.mm
	MacUserFunctions.h
	MacUserFunctions.mm
	MacPowerManager.h
	MacPowerManager.mm
	macos.qrc
	../common/LogonHelper.h
	../common/LogonHelper.cpp
	../common/PersistentLogonCredentials.h
	../common/PersistentLogonCredentials.cpp
	../common/PlatformSessionManager.h
	../common/PlatformSessionManager.cpp
	../common/ServiceDataManager.h
	../common/ServiceDataManager.cpp
)

build_veyon_plugin(macos-platform
	NAME MacPlatform
	SOURCES
	${macos_platform_SOURCES}
)

set_source_files_properties(MacCoreFunctions.mm PROPERTIES SKIP_UNITY_BUILD_INCLUSION TRUE)

target_include_directories(macos-platform PRIVATE
	${CMAKE_SOURCE_DIR}/plugins/platform/common
	${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(macos-platform PRIVATE
	Qt${QT_MAJOR_VERSION}::Network
	Qt${QT_MAJOR_VERSION}::Widgets
	${COCOA_FRAMEWORK}
	${IOKIT_FRAMEWORK}
	${COREGRAPHICS_FRAMEWORK}
	${SECURITY_FRAMEWORK}
	${SYSTEMCONFIGURATION_FRAMEWORK}
	${OPENDIRECTORY_FRAMEWORK}
	${SERVICEMANAGEMENT_FRAMEWORK}
)

target_compile_options(macos-platform PRIVATE "$<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>")
