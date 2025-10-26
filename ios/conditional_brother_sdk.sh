#!/bin/bash

# Conditional Brother SDK Framework Linking Script
# This script conditionally links the Brother SDK framework based on the build target

set -e

echo "Conditional Brother SDK linking script started"
echo "PLATFORM_NAME: ${PLATFORM_NAME}"
echo "EFFECTIVE_PLATFORM_NAME: ${EFFECTIVE_PLATFORM_NAME}"
echo "ARCHS: ${ARCHS}"

# Check if building for simulator
if [[ "${EFFECTIVE_PLATFORM_NAME}" == "-iphonesimulator" ]]; then
    echo "Building for iOS Simulator - Brother SDK will be excluded"
    
    # Remove any existing Brother SDK framework references for simulator builds
    if [ -d "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/BRLMPrinterKit.framework" ]; then
        echo "Removing Brother SDK framework from simulator build"
        rm -rf "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/BRLMPrinterKit.framework"
    fi
    
    echo "Simulator build: Brother SDK excluded successfully"
    
elif [[ "${EFFECTIVE_PLATFORM_NAME}" == "-iphoneos" ]]; then
    echo "Building for iOS Device - Brother SDK will be included"
    
    # Path to the Brother SDK XCFramework
    BROTHER_XCFRAMEWORK_PATH="${SRCROOT}/Frameworks/BRLMPrinterKit.xcframework"
    
    if [ -d "${BROTHER_XCFRAMEWORK_PATH}" ]; then
        echo "Brother SDK XCFramework found at: ${BROTHER_XCFRAMEWORK_PATH}"
        
        # Extract the appropriate framework for the device architecture
        DEVICE_FRAMEWORK_PATH="${BROTHER_XCFRAMEWORK_PATH}/ios-arm64/BRLMPrinterKit.framework"
        
        if [ -d "${DEVICE_FRAMEWORK_PATH}" ]; then
            echo "Copying Brother SDK framework for device build"
            
            # Create frameworks directory if it doesn't exist
            mkdir -p "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
            
            # Copy the framework
            cp -R "${DEVICE_FRAMEWORK_PATH}" "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/"
            
            # Sign the framework if needed
            if [ "${CODE_SIGNING_REQUIRED}" == "YES" ]; then
                echo "Code signing Brother SDK framework"
                codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --preserve-metadata=identifier,entitlements --timestamp=none "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/BRLMPrinterKit.framework"
            fi
            
            echo "Device build: Brother SDK included successfully"
        else
            echo "Warning: Brother SDK device framework not found at ${DEVICE_FRAMEWORK_PATH}"
        fi
    else
        echo "Warning: Brother SDK XCFramework not found at ${BROTHER_XCFRAMEWORK_PATH}"
        echo "Please ensure BRLMPrinterKit.xcframework is installed in the Frameworks directory"
    fi
else
    echo "Unknown platform: ${EFFECTIVE_PLATFORM_NAME}"
fi

echo "Conditional Brother SDK linking script completed"