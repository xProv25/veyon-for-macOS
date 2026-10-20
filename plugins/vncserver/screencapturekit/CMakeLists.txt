include(BuildVeyonPlugin)

find_library(COCOA_FRAMEWORK Cocoa REQUIRED)
find_library(COREGRAPHICS_FRAMEWORK CoreGraphics REQUIRED)
find_library(COREMEDIA_FRAMEWORK CoreMedia REQUIRED)
find_library(COREVIDEO_FRAMEWORK CoreVideo REQUIRED)
find_library(IOSURFACE_FRAMEWORK IOSurface REQUIRED)
find_library(SCREENCAPTUREKIT_FRAMEWORK ScreenCaptureKit)

build_veyon_plugin(screencapturekit-vnc-server
	NAME ScreenCaptureKitVncServer
	SOURCES
	ScreenCaptureKitVncServer.h
	ScreenCaptureKitVncServer.mm
	ScreenCaptureKitConfiguration.h
	MacScreenCapture.h
	MacScreenCapture.mm
)

target_link_libraries(screencapturekit-vnc-server PRIVATE
	${COCOA_FRAMEWORK}
	${COREGRAPHICS_FRAMEWORK}
	${COREMEDIA_FRAMEWORK}
	${COREVIDEO_FRAMEWORK}
	${IOSURFACE_FRAMEWORK}
)

if(SCREENCAPTUREKIT_FRAMEWORK)
	target_link_libraries(screencapturekit-vnc-server PRIVATE ${SCREENCAPTUREKIT_FRAMEWORK})
	target_compile_definitions(screencapturekit-vnc-server PRIVATE HAVE_SCREENCAPTUREKIT=1)
endif()

if(WITH_BUNDLED_LIBVNC)
	target_link_libraries(screencapturekit-vnc-server PRIVATE vncserver)
else()
	target_link_libraries(screencapturekit-vnc-server PRIVATE LibVNC::LibVNCServer)
endif()

target_compile_options(screencapturekit-vnc-server PRIVATE "$<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>")
