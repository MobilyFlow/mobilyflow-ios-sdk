# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MobilyFlow is a SaaS platform for managing in-app purchases and subscriptions on iOS/Android. This is the **iOS native SDK** (Swift) that handles IAP operations, customer management, entitlements, and transaction syncing.

**Version:** 0.5.0 | **Min iOS:** 15.0 | **Swift:** 5.0+

## Build & Development Commands

### Build with Swift Package Manager
```bash
swift build
```

### Generate Objective-C Header (for bridging)
```bash
swiftc -emit-objc-header \
  -sdk $(xcrun --show-sdk-path --sdk iphoneos) \
  -target arm64-apple-ios15.0 \
  -framework UIKit -framework Foundation \
  -emit-objc-header-path Sources/MobilyflowSDK/MobilyflowSDK.h \
  -module-name MobilyflowSDK Sources/**/*
```

### Release to CocoaPods
```bash
./Scripts/upload-pod.sh <version>
```
This script updates version in `MobilyflowSDK.podspec` and `version.swift`, creates git tag, and publishes to CocoaPods trunk.

## Architecture

### Singleton Pattern
```
MobilyPurchaseSDK (Public Facade - static methods only)
    └── MobilyPurchaseSDKImpl (Core implementation)
        ├── MobilyPurchaseAPI (REST client → api.mobilyflow.com/v1/)
        ├── MobilyPurchaseSDKSyncer (Entitlement sync with 3600s cache)
        ├── MobilyPurchaseRegistry (StoreKit product cache, SKU → Product mapping)
        ├── MobilyPurchaseRefundRequestManager (Refund dialog UI)
        ├── MobilyPurchaseSDKDiagnostics (Monitoring/logging)
        └── AppLifecycleManager (App state + crash handling)
```

### Key Source Directories
- `Sources/MobilyflowSDK/` - All SDK code
- `MobilyPurchaseAPI/` - API communication layer
- `Models/` - Data structures (Customer, Product, Entitlement, Transaction, Event)
- `Enums/` - Type-safe constants (Environment, ProductType, TransactionStatus, etc.)
- `Errors/` - Error types (MobilyError, MobilyPurchaseError, MobilyInternalError)
- `SDKHelpers/` - Helper classes (Syncer, Registry, Waiter, Diagnostics)
- `Monitoring/` - File-based logging with rotation, crash handlers
- `Utils/` - DeviceInfo, StorekitUtils, serialization helpers

### Key Files
- `MobilyPurchaseSDK.swift` - Public API entry point (initialize, login, purchase, etc.)
- `MobilyPurchaseSDKImpl.swift` - Core implementation (599 lines)
- `MobilyPurchaseAPI.swift` - REST client (495 lines)
- `MobilyPurchaseSDKSyncer.swift` - Entitlement caching/sync
- `version.swift` - Version constant (updated by release script)

## Key Patterns

### Dual-Stack Product System
- **Mobily Models**: `MobilyProduct`, `MobilySubscription`, etc. (from API)
- **StoreKit Native**: `StoreKit.Product`, `StoreKit.Transaction` (from App Store)
- Registry bridges between them via SKU

### JSON Parsing
Models implement `static func parse()` with `Serializable` base class helpers.

### Async/Await
All I/O uses Swift concurrency. `AsyncDispatchQueue` provides serial execution for purchase operations.

### Caching
- Product cache: `[UUID: MobilyProduct]`
- Entitlement cache: 3600s TTL
- StoreKit registry: `[SKU: (Product, Offers)]`

## SDK Initialization
```swift
MobilyPurchaseSDK.initialize(
    appId: "...",
    apiKey: "...",
    environment: .STAGING,  // .development, .staging, .production
    options: MobilyPurchaseSDKOptions(locales: ["en"], debug: true)
)
```

## Related MobilyFlow Components (separate repositories)
- **SDKs**: Native (Swift for iOS, Kotlin for Android) and cross-platform (React Native, Flutter)
- **Webhook**: Sends standardized events about in-app purchases and subscriptions
- **API**: Automates communication with MobilyFlow
