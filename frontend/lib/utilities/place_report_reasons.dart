/// System-defined fixed PLACE report reasons.
///
/// This is the ONE frontend definition — reasons are NOT admin-managed and
/// are NEVER fetched at runtime. It mirrors the authoritative backend list
/// in backend/Domain/Entities/PlaceSubmission.cs (PlaceReportReasons), and
/// the backend validates every submitted reason against that list, so the
/// two definitions must stay in sync when a reason is ever added.
class PlaceReportReasons {
  PlaceReportReasons._();

  static const String closed = 'CLOSED';
  static const String wrongInformation = 'WRONG_INFORMATION';
  static const String duplicate = 'DUPLICATE';
  static const String doesNotExist = 'DOES_NOT_EXIST';
  static const String other = 'OTHER';

  /// All codes the backend accepts for submission (PlaceReportReasons.All).
  static const List<String> all = [
    closed,
    wrongInformation,
    duplicate,
    doesNotExist,
    other,
  ];

  /// Codes offered in the Report Place sheet. OTHER is intentionally not
  /// offered (there is no free-text input; matches the previous UI behavior
  /// which stripped OTHER from the fetched list).
  static const List<String> uiSelectable = [
    closed,
    wrongInformation,
    duplicate,
    doesNotExist,
  ];

  /// User-friendly label for each reason code.
  static String friendlyLabel(String code) {
    switch (code) {
      case closed:
        return 'This place is permanently closed';
      case wrongInformation:
        return 'The information is incorrect';
      case duplicate:
        return 'Duplicate of another place';
      case doesNotExist:
        return 'This place does not exist';
      default:
        return code;
    }
  }
}
