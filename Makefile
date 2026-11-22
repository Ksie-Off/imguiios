ARCHS := arm64
TARGET := iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := imgui

imgui_USE_MODULES := 0

imgui_FILES += $(wildcard sources/*.mm sources/*.m)
imgui_FILES += $(wildcard sources/imgui/*.cpp)
imgui_FILES += $(wildcard sources/imgui/backends/*.mm)

imgui_CFLAGS += -fobjc-arc
imgui_CFLAGS += -std=c++14
imgui_CFLAGS += -Isources
imgui_CFLAGS += -Isources/imgui

imgui_FRAMEWORKS += Foundation UIKit CoreGraphics QuartzCore Metal MetalKit

include $(THEOS_MAKE_PATH)/application.mk

after-package::
	$(ECHO_NOTHING)mkdir -p packages $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)cp -rp $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Applications/imgui.app $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)cd $(THEOS_STAGING_DIR); zip -qr imgui.ipa Payload; cd -$(ECHO_END)
	$(ECHO_NOTHING)mv $(THEOS_STAGING_DIR)/imgui.ipa packages/imgui.ipa$(ECHO_END)
