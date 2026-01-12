/// API Configuration for EMR Backend Service
/// 
/// This module provides the production backend URL configuration.
/// The backend URL can be overridden using the EMR_BASE_URL environment variable
/// during build time for different deployment environments.
/// 
/// Production backend: https://localhost:7287

/// Resolves the EMR base URL for API connections.
/// 
/// Priority:
/// 1. EMR_BASE_URL environment variable (if set during build)
/// 2. Production backend URL: https://localhost:7287
/// 
/// Returns the base URL string for the EMR API service.
String resolveEmrBaseUrl() {
  const String defined = String.fromEnvironment('EMR_BASE_URL', defaultValue: '');
  if (defined.isNotEmpty) {
    return defined;
  }

  // Production backend service URL
  return 'https://localhost:7287';
}


