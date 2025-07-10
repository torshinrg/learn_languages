---
name: "Flutter Dart Mobile Application Development Guide"
description: "A comprehensive development guide for building modern mobile applications using Flutter, Dart, Provider, GetIt, and Appwrite with best practices and performance optimization"
category: "Mobile Framework"
author: "Agents.md Collection"
authorUrl: "https://github.com/gakeez/agents_md_collection"
tags:
  [
    "flutter",
    "dart",
    "mobile-development",
    "provider",
    "get_it",
    "appwrite",
    "state-management",
  ]
lastUpdated: "2025-06-16"
---

# Flutter Dart Mobile Application Development Guide

## Project Overview

This comprehensive guide outlines best practices for developing modern mobile applications using Flutter, Dart, Provider for state management, GetIt for dependency injection, and Appwrite for backend services. The guide emphasizes functional and declarative programming patterns, performance optimization, and maintainable code architecture.

## Tech Stack

- **Framework**: Flutter 3.16+
- **Language**: Dart 3.7+
- **State Management**: Provider 6+
- **Dependency Injection**: GetIt 8+
- **Local Storage**: Sqflite
- **Backend**: Appwrite (Database, Auth)
- **Navigation**: Navigator 2.0 or go_router
- **HTTP Client**: http
- **Notifications**: flutter_local_notifications
- **Voice Recognition**: speech_to_text
- **Testing**: flutter_test

## Development Environment Setup

### Installation Requirements

- Flutter SDK 3.16+
- Dart SDK 3.7+
- Android Studio / VS Code with Flutter extensions
- Xcode (for iOS development)
- Appwrite CLI (optional)

### Installation Steps

```bash
# Add core dependencies
flutter pub add provider get_it sqflite http
flutter pub add flutter_local_notifications timezone permission_handler
flutter pub add record dart_levenshtein whisper_ggml receive_sharing_intent
flutter pub add speech_to_text auto_size_text uuid appwrite

# Development dependencies
flutter pub add --dev flutter_test

# Generate localization and other files if needed
flutter pub run build_runner build --delete-conflicting-outputs
```

## Project Structure

```
learn_languages/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── core/                        # Core utilities
│   │   ├── services/                # External services like Appwrite
│   │   └── utils/                   # Shared utilities
│   ├── features/                    # Feature modules
│   └── data/                        # Data layer
├── test/                            # Test files
├── assets/                          # Static assets
├── pubspec.yaml
└── analysis_options.yaml
```

## Key Principles and Guidelines

### Core Development Philosophy

- Write concise, technical Dart code with accurate examples
- Use functional and declarative programming patterns where appropriate
- Prefer composition over inheritance
- Use descriptive variable names with auxiliary verbs (isLoading, hasError)
- Structure files: exported widget, subwidgets, helpers, static content, types

### Naming Conventions and Code Style

```dart
// Use descriptive variable names with auxiliary verbs
bool isLoading = false;
bool hasError = false;
bool canSubmit = true;

// Use const constructors for immutable widgets
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.onPressed,
    required this.text,
  });

  final VoidCallback onPressed;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(text),
    );
  }
}

// Use arrow syntax for simple functions
String get fullName => '$firstName $lastName';
bool get isValid => email.isNotEmpty && password.length >= 6;

// Use trailing commas for better formatting
Widget buildCard() {
  return Card(
    elevation: 4,
    margin: const EdgeInsets.all(16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Title'),
          const SizedBox(height: 8),
          Text('Content'),
        ],
      ),
    ),
  );
}
```

### File Structure Convention

```dart
// user_profile_screen.dart - Proper file structure

// 1. Exported widget
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const _ProfileContent(),
    );
  }
}

// 2. Subwidgets (private)
class _ProfileContent extends StatelessWidget {
  const _ProfileContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Profile data here'),
    );
  }
}

// 3. Helpers and utilities
extension UserProfileHelpers on User {
  String get displayName => name.isEmpty ? email : name;
}

// 4. Static content and constants
class _Constants {
  static const double profileImageSize = 120;
  static const EdgeInsets contentPadding = EdgeInsets.all(16);
}
```

## Core Feature Implementation

### Provider State Management

```dart
// Example of a ChangeNotifier with Provider
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._service);

  final AppwriteService _service;

  User? _user;
  bool get isLoggedIn => _user != null;

  Future<void> login(String email, String password) async {
    _user = await _service.login(email: email, password: password);
    notifyListeners();
  }
}
```

### Error Handling and Validation

```dart
class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Error: ${error.toString()}',
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}
```

### Appwrite Integration

```dart
// services/appwrite_service.dart - Appwrite integration
class AppwriteService {
  AppwriteService(this.client);

  final Client client;
  late final Account account = Account(client);

  Future<User?> login({required String email, required String password}) async {
    try {
      final session = await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      return account.get();
    } on AppwriteException {
      return null;
    }
  }
}
```

## Best Practices Summary

### Code Quality Guidelines

- **Use const constructors** for immutable widgets to optimize rebuilds
- **Prefer composition over inheritance** for better code reusability
- **Use descriptive variable names** with auxiliary verbs (isLoading, hasError)
- **Structure files properly** with exported widgets, subwidgets, helpers, and types
- **Implement proper error handling** using dedicated widgets for error display
- **Keep lines no longer than 80 characters** with trailing commas

### Provider and GetIt

- **Use Provider** for reactive state management
- **Use GetIt** for dependency injection
- **Avoid tight coupling** between UI and business logic

### Performance Optimization

- **Use const widgets** where possible to optimize rebuilds
- **Implement ListView.builder** for large lists instead of ListView with children
- **Use CachedNetworkImage or similar** for remote images if needed
- **Implement proper error handling** for Appwrite operations, including network errors
- **Use RefreshIndicator** for pull-to-refresh functionality

### Development Workflow

- **Run build_runner** when using code generation
- **Use log instead of print** for debugging
- **Follow official documentation** for Flutter, Provider, and Appwrite best practices
```
