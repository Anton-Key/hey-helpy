// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Hey Helpy';

  @override
  String get wakePhrase => 'Hey, Helpy';

  @override
  String get appTagline => 'Work requests and job control in one tap';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonNotSpecified => 'Not specified';

  @override
  String get errorGeneric =>
      'Something went wrong. Check your connection and try again.';

  @override
  String get misconfiguredTitle => 'Supabase keys are not set';

  @override
  String get misconfiguredRunWith => 'Run the app with these parameters:';

  @override
  String get misconfiguredSeeReadme => 'See README.md for details';

  @override
  String get splashLoadFailed =>
      'Couldn\'t load your profile.\nCheck your internet connection.';

  @override
  String get splashSignOut => 'Sign out';

  @override
  String get loginName => 'Name';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginEmailInvalid => 'Enter a valid email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginPasswordTooShort => 'At least 6 characters';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get loginSignUp => 'Sign up';

  @override
  String get loginHaveAccount => 'Already have an account? Sign in';

  @override
  String get loginNoAccount => 'No account? Sign up';

  @override
  String get loginAccountCreated =>
      'Account created. If email confirmation is on, check your inbox.';

  @override
  String get loginErrorInvalidCredentials => 'Wrong email or password';

  @override
  String get loginErrorAlreadyRegistered =>
      'This email is already registered. Please sign in.';

  @override
  String get loginErrorEmailNotConfirmed =>
      'Email not confirmed. Open the email and follow the link.';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get navReports => 'Reports';

  @override
  String get navProfile => 'Profile';

  @override
  String get tabRequests => 'Requests';

  @override
  String get tabContractors => 'Contractors';

  @override
  String get tabLocations => 'Locations';

  @override
  String mockHistoryDoneThisMonth(int count) {
    return 'Completed this month: $count';
  }

  @override
  String get mockHistory1Title => 'Chair repair';

  @override
  String get mockHistory1Place => 'Astana · Office 512';

  @override
  String get mockHistory1Meta => 'Aug 12 · 40 min';

  @override
  String get mockHistory2Title => 'Filter replacement';

  @override
  String get mockHistory2Place => 'Moscow · Server room';

  @override
  String get mockHistory2Meta => 'Aug 11 · 1 h 20 min';

  @override
  String get mockHistory3Title => 'Lobby cleaning';

  @override
  String get mockHistory3Place => 'Moscow · 1st floor';

  @override
  String get mockHistory3Meta => 'Aug 11 · 55 min';

  @override
  String get historyDone => 'Done';

  @override
  String get reportsKpiRequests => 'requests this month';

  @override
  String get reportsKpiOnTime => 'on time';

  @override
  String get reportsKpiAvgTime => 'avg. time';

  @override
  String hoursShort(String value) {
    return '$value h';
  }

  @override
  String get reportsWeeklyChart => 'Requests by week';

  @override
  String get reportsExportPdf => 'Export to PDF';

  @override
  String get reportsWebHint =>
      'Full reports and filters are in the web version';

  @override
  String get profileDefaultName => 'User';

  @override
  String get profileMyCompany => 'My company';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileLanguageNotSynced =>
      'Language saved on this phone, but not in your profile. Check your connection.';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleRequester => 'Requester';

  @override
  String get roleContractor => 'Contractor';

  @override
  String get roleExecutor => 'Technician';

  @override
  String get statusNew => 'New';

  @override
  String get statusAssigned => 'Assigned';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusOnReview => 'In review';

  @override
  String get statusReturned => 'Returned';

  @override
  String get statusDone => 'Accepted';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusOverdue => 'Overdue';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityNormal => 'Normal';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityCritical => 'Critical';

  @override
  String get requestsLoading => 'Loading…';

  @override
  String get requestsLoadErrorShort => 'Loading error';

  @override
  String requestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests',
      one: '$count request',
      zero: 'No requests',
    );
    return '$_temp0';
  }

  @override
  String get requestsLoadFailed =>
      'Couldn\'t load requests. Check your connection and tap Refresh.';

  @override
  String get requestsEmpty => 'No requests yet.\nTap “New request”.';

  @override
  String get requestsCreate => 'New request';

  @override
  String get requestsVoice => 'Tap and speak';

  @override
  String get requestsCreated => 'Request created';

  @override
  String get requestsNoCompany =>
      'Your profile isn\'t linked to a company. Contact your administrator.';

  @override
  String get requestRecurringTag => 'scheduled';

  @override
  String get objectNone => 'No site';

  @override
  String get objectUnknown => 'Site';

  @override
  String get contractorNone => 'not assigned';

  @override
  String get contractorUnknown => 'contractor';

  @override
  String get detailTitle => 'Request';

  @override
  String get detailEdit => 'Edit';

  @override
  String get detailLoadFailed =>
      'Couldn\'t open the request. Check your connection and try again.';

  @override
  String get fieldObject => 'Site';

  @override
  String get fieldContractor => 'Contractor';

  @override
  String get fieldWorkType => 'Work type';

  @override
  String get fieldPriority => 'Priority';

  @override
  String get fieldKind => 'Type';

  @override
  String get kindRecurring => 'Scheduled';

  @override
  String get kindOneOff => 'One-off';

  @override
  String get fieldPhotoProof => 'Photo proof';

  @override
  String get photoRequired => 'Required';

  @override
  String get photoNotRequired => 'Not required';

  @override
  String get fieldCreated => 'Created';

  @override
  String createdByYou(String date) {
    return '$date (you)';
  }

  @override
  String get fieldDescription => 'Description';

  @override
  String get noDescription => 'No description';

  @override
  String returnedWithReason(String reason) {
    return 'Returned: $reason';
  }

  @override
  String get actionsTitle => 'Actions';

  @override
  String get actionAssign => 'Assign contractor';

  @override
  String get actionReassign => 'Change contractor';

  @override
  String get actionStart => 'Start work';

  @override
  String get actionRestart => 'Rework';

  @override
  String get actionSubmit => 'Done, send for review';

  @override
  String get actionAccept => 'Accept work';

  @override
  String get actionReturn => 'Return for rework';

  @override
  String get actionCancel => 'Cancel request';

  @override
  String get toastInProgress => 'Request in progress';

  @override
  String get toastSubmitted => 'Sent for review';

  @override
  String get toastAccepted => 'Work accepted';

  @override
  String get toastCancelled => 'Request cancelled';

  @override
  String get toastReturned => 'Returned to the contractor';

  @override
  String get toastSaved => 'Saved';

  @override
  String get toastAssigned => 'Contractor assigned';

  @override
  String assignNoContractors(String tab) {
    return 'Add a contractor in the “$tab” tab first';
  }

  @override
  String get returnHint => 'What needs fixing?';

  @override
  String get returnConfirm => 'Return';

  @override
  String get returnReasonRequired => 'Describe what needs fixing';

  @override
  String get errPhotoRequired => 'A photo of the finished work is required';

  @override
  String get errNotAllowed =>
      'This action isn\'t available for your role or the current status';

  @override
  String get formNewTitle => 'New request';

  @override
  String get formEditTitle => 'Edit request';

  @override
  String get formWhat => 'What happened?';

  @override
  String get formWhatHint => 'For example, a leaking tap';

  @override
  String get formDetailsHint => 'Details';

  @override
  String formNoObjects(String tab) {
    return 'No sites — add one in the “$tab” tab';
  }

  @override
  String get formChooseObject => 'Choose a site';

  @override
  String get formRecurring => 'Scheduled (recurring)';

  @override
  String get formWhatRequired => 'Describe what happened';

  @override
  String get formSaveFailed =>
      'Couldn\'t save the request. Check your connection and try again.';

  @override
  String get formLayersFailed =>
      'Couldn\'t load work types. You can send the request without one.';

  @override
  String get voiceTitle => 'Voice request';

  @override
  String get voiceStarting => 'Turning on the microphone…';

  @override
  String get voiceListening => 'Listening';

  @override
  String get voiceProcessing => 'Recognizing…';

  @override
  String get voiceFailedTitle => 'That didn\'t work';

  @override
  String get voicePrompt =>
      'Say what happened and where.\nFor example: “The air conditioning in the third-floor meeting room isn\'t working.”';

  @override
  String voiceTimer(String elapsed, int left) {
    return '$elapsed · $left s left';
  }

  @override
  String get voiceProcessingHint => 'This takes a few seconds';

  @override
  String get voiceDone => 'Done';

  @override
  String get voiceAgain => 'Try again';

  @override
  String get voiceNoMicPermission =>
      'Microphone access is needed. Allow it in your phone settings and try again.';

  @override
  String get voiceMicFailed =>
      'Couldn\'t turn on the microphone. Please try again.';

  @override
  String get voiceTooShort =>
      'Too short. Tap “Try again” and describe the problem.';

  @override
  String get voiceRecognizeFailed =>
      'Couldn\'t recognize the recording. Check your connection and try again.';

  @override
  String get voiceConfirmTitle => 'Check your request';

  @override
  String get voiceYouSaid => 'You said';

  @override
  String quoted(String text) {
    return '“$text”';
  }

  @override
  String get voicePickLayer =>
      'Choose a work type so the request goes straight to the right contractor.';

  @override
  String get voiceWhere => 'Where';

  @override
  String voiceHeard(String hint) {
    return 'We heard: “$hint”';
  }

  @override
  String get voiceUrgency => 'Urgency';

  @override
  String get voiceSend => 'Send';

  @override
  String get voiceSendFailed =>
      'Couldn\'t send the request. Check your connection and try again.';

  @override
  String get objectTypeOffice => 'Office';

  @override
  String get objectTypeHotel => 'Hotel';

  @override
  String get objectTypeApartments => 'Apartments';

  @override
  String get objectTypeWarehouse => 'Warehouse';

  @override
  String get objectTypeOther => 'Other';

  @override
  String get commonAdd => 'Add';

  @override
  String get objectsLoadFailed =>
      'Couldn\'t load sites. Check your connection and try again.';

  @override
  String get objectsEmpty => 'No sites yet.\nTap “Add”.';

  @override
  String get objectFormTitle => 'New location';

  @override
  String get objectFormName => 'Location name';

  @override
  String get objectFormNameHint => 'For example, North Tower business center';

  @override
  String get objectFormAddress => 'Address';

  @override
  String get objectFormAddressHint => 'City, street, building';

  @override
  String get objectFormType => 'Type';

  @override
  String get objectFormNameRequired => 'Enter a name';

  @override
  String get objectAdded => 'Location added';

  @override
  String get contractorsLoadFailed =>
      'Couldn\'t load contractors. Check your connection and try again.';

  @override
  String get contractorsEmpty => 'No contractors yet.\nTap “Add”.';

  @override
  String get contractorFormTitle => 'New contractor';

  @override
  String get contractorFormName => 'Company name';

  @override
  String get contractorFormNameHint => 'For example, BuildCo';

  @override
  String get contractorFormNameRequired => 'Enter the company name';

  @override
  String get contractorAdded => 'Contractor added';

  @override
  String get saveFailed =>
      'Couldn\'t save. Check your connection and try again.';

  @override
  String get onboardingTitle => 'Getting started';

  @override
  String onboardingChoose(String appName) {
    return 'Choose how you\'ll work in $appName';
  }

  @override
  String get onboardingCreateTitle => 'Create a company';

  @override
  String get onboardingCreateSubtitle =>
      'For property owners and managers. You\'ll become the administrator.';

  @override
  String get onboardingCompanyName => 'Company name';

  @override
  String get onboardingCreate => 'Create';

  @override
  String get onboardingInviteTitle => 'I have an invite code';

  @override
  String get onboardingInviteSubtitle =>
      'For technicians of contractor companies.';

  @override
  String get onboardingInviteCode => 'Invite code';

  @override
  String get onboardingJoin => 'Join';

  @override
  String get onboardingNoConnection =>
      'Can\'t reach the server. Please try again.';

  @override
  String get onbErrNotAuthenticated => 'Sign in to continue.';

  @override
  String get onbErrCompanyNameRequired => 'Enter the company name.';

  @override
  String get onbErrAlreadyInCompany => 'You already belong to a company.';

  @override
  String get onbErrInviteNotFound =>
      'Invite code not found. Check that you entered all of it.';

  @override
  String get onbErrInviteUsed => 'This invite code has already been used.';

  @override
  String get onbErrInviteExpired =>
      'This invite has expired. Ask for a new code.';

  @override
  String get onbErrOtherCompany =>
      'Your account is already linked to another company.';

  @override
  String get onbErrAdminOnly => 'Only an administrator can change roles.';

  @override
  String get onbErrOwnRole => 'You can\'t change your own role.';

  @override
  String get onbErrProfileNotFound => 'User not found in your company.';

  @override
  String get onbErrUnknown =>
      'Couldn\'t complete the action. Please try again.';

  @override
  String get adminTitle => 'Administration';

  @override
  String get adminObjects => 'Sites and geolocation';

  @override
  String get adminDepartments => 'Departments';

  @override
  String get adminAssets => 'Equipment and assets';

  @override
  String get adminContractors => 'Contractor companies';

  @override
  String get adminInvites => 'Invite links for technicians';

  @override
  String get adminUsers => 'Users and roles';

  @override
  String get adminComingSoon => 'Coming in Phase 1';

  @override
  String get reportsComingTitle => 'Reports are coming in Phase 1';

  @override
  String get reportsComingBody =>
      'Filters: site, work type, contractor, period, time.\nExport: CSV / XLSX / PDF / email.';

  @override
  String get photosTitle => 'Photos';

  @override
  String get photosBefore => 'Before';

  @override
  String get photosAfter => 'After';

  @override
  String get photosNone => 'No photos';

  @override
  String get photoTakeResult => 'Photograph the result';

  @override
  String get photoTakeMore => 'Add photo';

  @override
  String get photoAddBefore => 'Add a “before” photo';

  @override
  String get photoUploading => 'Uploading photo…';

  @override
  String get photoUploaded => 'Photo added';

  @override
  String get photoUploadFailed =>
      'Couldn\'t upload the photo. Check your connection and try again.';

  @override
  String get photoCameraDenied =>
      'Camera access is needed. Allow it in your phone settings and try again.';

  @override
  String get photoCameraFailed =>
      'Couldn\'t open the camera. Please try again.';

  @override
  String get photoLoadFailed => 'Couldn\'t load photos';

  @override
  String get photoNeededHint =>
      'Photograph the result: you can\'t send for review without an “after” photo.';

  @override
  String photoTakenAt(String date) {
    return 'Taken $date';
  }

  @override
  String get photoNoLocation => 'No location';

  @override
  String get photoWithLocation => 'With location';

  @override
  String get photoMockLocation => 'Location may be spoofed';

  @override
  String get visitsTitle => 'Visits';

  @override
  String visitOnSiteRange(String from, String to) {
    return 'On site $from–$to';
  }

  @override
  String visitOnSiteSince(String from) {
    return 'On site since $from';
  }

  @override
  String get visitInGeofence => 'inside geofence ✓';

  @override
  String get visitOutsideGeofence => 'outside geofence ⚠';

  @override
  String get visitGeofenceUnknown => 'geofence not checked';

  @override
  String visitDistance(String meters) {
    return '$meters m from the site';
  }

  @override
  String get visitMockLocation => 'Possible GPS spoofing';

  @override
  String get visitOutsideWarning =>
      'The executor checked in outside the site geofence or with spoofed GPS. Please check they were on site.';

  @override
  String get visitsLoadFailed => 'Couldn\'t load visits';

  @override
  String get visitNotRecorded =>
      'Work started, but the visit wasn\'t recorded. Check your internet connection.';

  @override
  String get visitNoLocation =>
      'Work started without location. Turn it on so the visit can be checked against the geofence.';
}
