//
// Wallpaper Manager
// SkyLightBridge.h
//
// Created on 21/2/25
//
// Copyright ©2025 DoorHinge Apps.
//


// SkyLightBridge.h
#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>

// Forward declarations for SkyLight private APIs
typedef int CGError;

// Example functions:
extern CFArrayRef CGSCopyManagedDisplaySpaces(uint32_t connection);
extern CGError CGSSetDesktopImageURL(uint32_t connection, int64_t spaceID, CFURLRef url, CFDictionaryRef options);
extern uint32_t CGSMainConnectionID(void);
