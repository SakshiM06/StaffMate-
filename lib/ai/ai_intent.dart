/// AI Intent definitions for StaffMate IPD AI Assistant
/// This file controls WHAT action the user wants to perform
/// Example: View Prescription, Investigation, Charges, etc.

enum AIIntent {
  viewPrescription,
  viewInvestigation,
  viewCharges,
  viewSummary,
}

/// Extension to provide UI-friendly labels
extension AIIntentLabel on AIIntent {
  String get label {
    switch (this) {
      case AIIntent.viewPrescription:
        return "View Prescription";
      case AIIntent.viewInvestigation:
        return "View Investigation";
      case AIIntent.viewCharges:
        return "View Charges";
      case AIIntent.viewSummary:
        return "View Patient Summary";
    }
  }
}

/// Extension to map intent to backend-understood key
extension AIIntentApiKey on AIIntent {
  String get apiKey {
    switch (this) {
      case AIIntent.viewPrescription:
        return "PRESCRIPTION";
      case AIIntent.viewInvestigation:
        return "INVESTIGATION";
      case AIIntent.viewCharges:
        return "CHARGES";
      case AIIntent.viewSummary:
        return "SUMMARY";
    }
  }
}

/// Helper to get all supported intents (used in UI dropdown / buttons)
List<AIIntent> getAllAIIntents() {
  return AIIntent.values;
}
