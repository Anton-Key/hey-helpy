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
  String get reportsKpiRequests => 'requests';

  @override
  String get reportsKpiOnTime => 'on time';

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
  String get voiceProcessing => 'Reading your request…';

  @override
  String get voiceFailedTitle => 'That didn\'t work';

  @override
  String get voicePrompt =>
      'Say what happened and where.\nFor example: “The air conditioner in the meeting room on the third floor isn\'t working.”';

  @override
  String voiceTimer(String elapsed, int left) {
    return '$elapsed · $left s left';
  }

  @override
  String get voiceDone => 'Done';

  @override
  String get voiceAgain => 'Try again';

  @override
  String get voiceMicFailed =>
      'Couldn\'t turn on the microphone. Please try again.';

  @override
  String get voiceRecognizeFailed =>
      'Couldn\'t recognize speech. Try again or type your request.';

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
  String get voiceAutoStop => 'I\'ll stop by myself after a 3-second pause';

  @override
  String get voiceNoMicPermissionWeb =>
      'The browser blocked the microphone. Click the lock or microphone icon in the address bar → “Microphone” → “Allow”, then tap “Try again”. On iPhone: Settings → Safari → Microphone → “Allow”; Dictation must also be on (Settings → General → Keyboard).';

  @override
  String voiceNoMicPermissionApp(String app) {
    return 'Microphone access is needed: phone Settings → Apps → $app → Permissions → Microphone → “Allow”. Then tap “Try again”.';
  }

  @override
  String get voiceUnsupportedWeb =>
      'This browser can\'t recognize speech (Firefox, for example). Open the app in Chrome, Edge or Safari — or type your request.';

  @override
  String get voiceUnsupportedApp =>
      'No speech recognition service was found on this phone (usually it\'s the Google app). Please type your request.';

  @override
  String get voiceNetwork =>
      'Can\'t reach the speech recognition service. Check your connection or type your request.';

  @override
  String get voiceNothingHeard =>
      'I didn\'t hear anything. Tap “Try again” and say what happened — or type it.';

  @override
  String get voiceTypeInstead => 'Type instead';

  @override
  String get voiceTypeTitle => 'Describe the request';

  @override
  String get voiceTypeHint =>
      'What happened and where? For example: “The air conditioner in the meeting room on the third floor isn\'t working”';

  @override
  String get voiceNext => 'Next';

  @override
  String get voiceYouWrote => 'You wrote';

  @override
  String get voiceEditHint =>
      'You can edit the title and description before sending.';

  @override
  String get voiceParsedByAi => 'Parsed by AI';

  @override
  String get voiceParsedByDictionary => 'Parsed by keywords';

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

  @override
  String get reportsManagerOnly =>
      'Reports are available to managers and admins.';

  @override
  String get reportsPeriodWeek => 'Week';

  @override
  String get reportsPeriodMonth => 'Month';

  @override
  String get reportsPeriodCustom => 'Custom';

  @override
  String reportsRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get reportsFilterObject => 'Site';

  @override
  String get reportsFilterContractor => 'Contractor';

  @override
  String get reportsFilterLayer => 'Work type';

  @override
  String get reportsFilterAll => 'All';

  @override
  String get reportsLoadFailed =>
      'Couldn\'t load the report. Check your connection and try again.';

  @override
  String get reportsEmpty => 'No requests or visits in this period.';

  @override
  String get reportsKpiFirstPass => 'accepted first time';

  @override
  String get reportsKpiGeofence => 'visits in geofence';

  @override
  String reportsKpiOf(int count) {
    return 'of $count';
  }

  @override
  String get reportsByContractor => 'By contractor';

  @override
  String get reportsNoContractor => 'No contractor';

  @override
  String get reportsOrders => 'Requests';

  @override
  String get reportsAccepted => 'Accepted';

  @override
  String get reportsReturned => 'Returned';

  @override
  String get reportsOverdue => 'Overdue';

  @override
  String get reportsOnTime => 'On time';

  @override
  String get reportsFirstPass => 'First time';

  @override
  String get reportsReaction => 'Response';

  @override
  String get reportsExecution => 'Execution';

  @override
  String get reportsVisits => 'Visits';

  @override
  String get reportsVisitsInZone => 'In geofence';

  @override
  String get reportsVisitsSuspicious => 'Outside geofence or spoofed GPS';

  @override
  String get reportsOnSite => 'Time on site';

  @override
  String get reportsPhotos => 'With before & after photos';

  @override
  String get reportsVisitNorm => 'Visits: actual / target';

  @override
  String reportsFactNorm(String fact, String norm) {
    return '$fact / $norm';
  }

  @override
  String get reportsNoValue => '—';

  @override
  String get reportsNormsMissing =>
      'Contract visit targets will appear after the database update.';

  @override
  String get reportsHelp =>
      'On time — share of requests accepted by the deadline, among all requests with a deadline: accepted after the deadline and still open past the deadline count as late; cancelled ones are not counted. First time — accepted without being returned. Response — from creation to “In progress”; execution — from “In progress” to “In review”. Visit targets are prorated to the period length and rounded to a whole number (below 1 — to one decimal).';

  @override
  String get reportsOrdersEmpty => 'No requests in this period.';

  @override
  String reportsReturnedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'returned $count times',
      one: 'returned once',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(String minutes) {
    return '$minutes min';
  }

  @override
  String durationHoursMinutes(String hours, String minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durationDaysHours(String days, String hours) {
    return '$days d $hours h';
  }

  @override
  String get visitAlreadyOpen =>
      'Your visit is already recorded — you\'re on site. Carry on with the work.';

  @override
  String get cardLoadFailed =>
      'Couldn\'t load this card. Check your connection and try again.';

  @override
  String get cardContractorOrders => 'Contractor requests';

  @override
  String get cardContractorReport => 'Report';

  @override
  String get cardBindingsTitle => 'Work types and sites';

  @override
  String get cardBindingsEmpty => 'No assignments yet.';

  @override
  String get cardAllObjects => 'All sites';

  @override
  String get cardNormHint => 'Tap a row to change the visit target.';

  @override
  String get cardNormNotSet => 'No visit target';

  @override
  String cardNormPerMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Target: $count visits a month',
      one: 'Target: 1 visit a month',
    );
    return '$_temp0';
  }

  @override
  String get cardNormDialogTitle => 'Visits per month';

  @override
  String get cardNormDialogHint => 'E.g. 4. Leave empty for no target';

  @override
  String get cardNormInvalid => 'Enter a number from 0 to 1000';

  @override
  String get cardExecutorsTitle => 'Workers and contacts';

  @override
  String get cardExecutorsEmpty =>
      'No workers yet. Invite them with an invite code.';

  @override
  String get cardCoordinates => 'Coordinates';

  @override
  String get cardCoordinatesNotSet => 'not set';

  @override
  String get cardGeofenceRadius => 'Geofence radius';

  @override
  String cardMeters(String value) {
    return '$value m';
  }

  @override
  String get cardNoCoordinatesHint =>
      'Without coordinates, visits to this site can\'t be checked against the geofence.';

  @override
  String get cardEditGeo => 'Address and geofence';

  @override
  String get cardLatitude => 'Latitude';

  @override
  String get cardLongitude => 'Longitude';

  @override
  String get cardUseMyLocation => 'Use my location';

  @override
  String get cardLocationFailed =>
      'Couldn\'t get your location. Turn on location and allow it for the app.';

  @override
  String get cardGeofenceRadiusInput => 'Geofence radius, m (20–5000)';

  @override
  String get cardCoordinatesBoth =>
      'Enter both latitude and longitude, or leave both empty.';

  @override
  String get cardCoordinatesInvalid =>
      'Check the coordinates: latitude −90 to 90, longitude −180 to 180.';

  @override
  String get cardRadiusInvalid =>
      'Radius must be a whole number from 20 to 5000 m.';

  @override
  String get cardPlacesTitle => 'Rooms';

  @override
  String get cardPlacesEmpty => 'No rooms yet.';

  @override
  String get cardObjectContractorsTitle => 'Contractors by work type';

  @override
  String get cardRecentOrders => 'Recent requests';

  @override
  String get cardOrdersEmpty => 'No requests yet.';

  @override
  String get cardAllObjectOrders => 'All site requests';

  @override
  String get historyLoadFailed =>
      'Couldn\'t load history. Check your connection and try again.';

  @override
  String historyDoneInPeriod(int count) {
    return 'Completed in period: $count';
  }

  @override
  String get historyEmpty => 'No completed requests in this period.';

  @override
  String historyAcceptedAt(String date) {
    return 'Accepted $date';
  }

  @override
  String historyCancelledAt(String date) {
    return 'Cancelled $date';
  }

  @override
  String historyExecution(String time) {
    return 'Execution: $time';
  }

  @override
  String historyExecutor(String name) {
    return 'Done by: $name';
  }

  @override
  String get historyVisitInGeofence => 'Visit in geofence ✓';

  @override
  String get historyVisitOutside =>
      'Visit outside geofence or with spoofed GPS';

  @override
  String get reportsPeriod30 => '30 days';

  @override
  String get companyNameLabel => 'Company';

  @override
  String get companyRenameTitle => 'Company name';

  @override
  String get companyRenamed => 'Name saved';

  @override
  String get companyRenameUnavailable =>
      'The name can\'t be changed yet: the database needs an update. Let your administrator know.';

  @override
  String get companyLoadFailed =>
      'Couldn\'t load company data. Check your connection.';

  @override
  String companyMembers(int count) {
    return 'People: $count';
  }

  @override
  String companyMemberYou(String name) {
    return '$name (you)';
  }

  @override
  String get companyNoPhone => 'No phone number';

  @override
  String get companyRoleChange => 'Change role';

  @override
  String companyRoleTitle(String name) {
    return 'Role: $name';
  }

  @override
  String get companyRoleExecutorHint =>
      'To see requests, a technician must be linked to a contractor — use an invitation.';

  @override
  String get companyRoleChanged => 'Role changed';

  @override
  String get companyInvites => 'Invitations';

  @override
  String get companyInvite => 'Invite';

  @override
  String get companyNoInvites => 'No active invitations.';

  @override
  String companyInviteRow(String contractor, String date) {
    return '$contractor · until $date';
  }

  @override
  String get companyDirectory => 'Directories';

  @override
  String get inviteTitle => 'Invite a technician';

  @override
  String get inviteContractor => 'Contractor';

  @override
  String get inviteRoleInfo =>
      'Role: technician of this contractor. They will see the contractor\'s requests and can work on them. You can assign a different role later in the people list.';

  @override
  String get inviteValidity => 'Valid for';

  @override
  String inviteDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String get inviteCreate => 'Create';

  @override
  String get inviteFailed =>
      'Couldn\'t create the invitation. Please try again.';

  @override
  String get inviteNoContractors =>
      'Add a contractor on the Contractors tab first.';

  @override
  String inviteReadyTitle(String contractor) {
    return 'Invitation to $contractor';
  }

  @override
  String inviteValidUntil(String date) {
    return 'Valid until $date, single use';
  }

  @override
  String get inviteCodeLabel => 'Code';

  @override
  String get inviteLinkLabel => 'Link (web app)';

  @override
  String get inviteHowTo =>
      'The new person signs up in the app and enters the code in the “I have an invite code” box. Opening the link on the website fills in the code automatically.';

  @override
  String get inviteCopyMessage => 'Copy invitation';

  @override
  String get inviteCopyCode => 'Copy code';

  @override
  String get inviteCopied => 'Invitation copied — send it in a messenger';

  @override
  String get inviteCodeCopied => 'Code copied';

  @override
  String get inviteRevoke => 'Revoke invitation';

  @override
  String get inviteRevoked => 'Invitation revoked';

  @override
  String inviteMessage(
      String app, String contractor, String link, String code, String date) {
    return 'You\'re invited to $app as a technician of $contractor.\nOpen the link: $link\nor install the app and enter the code: $code\nValid until $date.';
  }

  @override
  String get settingsProfile => 'Profile';

  @override
  String get settingsName => 'Full name';

  @override
  String get settingsPhone => 'Phone';

  @override
  String get settingsPhoneHint => '+1 555 000 0000';

  @override
  String get settingsSaved => 'Saved';

  @override
  String get settingsSaveFailed =>
      'Couldn\'t save. Check your connection and try again.';

  @override
  String get settingsPassword => 'Password';

  @override
  String get settingsNewPassword => 'New password';

  @override
  String get settingsRepeatPassword => 'Repeat password';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String settingsPasswordShort(int count) {
    return 'Password must be at least $count characters';
  }

  @override
  String get settingsPasswordMismatch => 'Passwords don\'t match';

  @override
  String get settingsPasswordChanged => 'Password changed';

  @override
  String get settingsPasswordFailed =>
      'Couldn\'t change the password. It may match the old one or be too simple.';

  @override
  String get settingsAbout => 'About';

  @override
  String settingsAboutApp(String app) {
    return 'About $app';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String settingsAboutText(String app) {
    return '$app is a building operations service: requests by text, voice or photo, routing to contractors, visit control and work acceptance.';
  }

  @override
  String notifPeriod(int days) {
    return 'Last $days days';
  }

  @override
  String get notifEmpty => 'Nothing new';

  @override
  String get notifLoadFailed =>
      'Couldn\'t load notifications. Check your connection.';

  @override
  String get notifAssigned => 'New request for your contractor';

  @override
  String get notifReturned => 'Work returned for rework';

  @override
  String get notifOnReview => 'Work awaits acceptance';

  @override
  String get notifOverdue => 'Deadline passed, request still open';

  @override
  String get notifVisitOutside => 'Visit outside the geofence';

  @override
  String notifVisitOutsideM(String meters) {
    return 'Visit outside the geofence: $meters m from the site';
  }

  @override
  String get notifVisitMock => 'Visit with spoofed GPS';

  @override
  String get notifInProgress => 'Your request is in progress';

  @override
  String get notifAccepted => 'Work on your request was accepted';

  @override
  String notifBellTooltip(int count) {
    return 'Notifications: $count new';
  }

  @override
  String get assignSearch => 'Search contractors';

  @override
  String get assignBound => 'Assigned to this work type';

  @override
  String get assignOthers => 'Other contractors';

  @override
  String get assignAll => 'Contractors';

  @override
  String assignNobodyBound(String layer) {
    return 'Nobody is assigned to “$layer” — choose manually or set it up in the contractor card';
  }

  @override
  String get assignNoLayer => 'No work type — choose a contractor manually';

  @override
  String get assignNothingFound => 'Nothing found';

  @override
  String get assignBindingsFailed =>
      'Couldn\'t load assignments — the list has no hints.';

  @override
  String assignExecutors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count technicians',
      one: '$count technician',
      zero: 'No technicians',
    );
    return '$_temp0';
  }

  @override
  String assignNorm(int count) {
    return 'target $count/mo';
  }

  @override
  String get assignAllObjects => 'all sites';

  @override
  String get assignCurrent => 'Currently assigned';

  @override
  String get assignInline => 'Assign';

  @override
  String get assignChangeInline => 'Change';

  @override
  String toastAssignedTo(String name) {
    return 'Assigned: $name';
  }

  @override
  String get fieldExecutor => 'Technician';

  @override
  String get voiceNetworkWeb =>
      'Can\'t reach the browser\'s speech recognition service. Check your connection and tap “Try again” — or type your request.';

  @override
  String get voiceMicFailedWeb =>
      'The browser isn\'t getting sound from the microphone. Check which microphone is selected: chrome://settings/content/microphone (in Edge — edge://settings/content/microphone), then tap “Try again”.';

  @override
  String voiceErrorCode(String code) {
    return 'code: $code';
  }

  @override
  String get voiceMicSilent =>
      'The microphone doesn\'t hear any sound — check which microphone is selected';

  @override
  String get voiceBrowserHint =>
      'For voice input, it\'s best to open this in Google Chrome or Microsoft Edge';

  @override
  String get detailMore => 'More';

  @override
  String get actionDelete => 'Delete';

  @override
  String get deleteOrderConfirm =>
      'Delete this request permanently? Its history, photos and reports will be gone. If the work just isn\'t needed, better “Cancel request”.';

  @override
  String get toastDeleted => 'Request deleted';

  @override
  String get deleteOrderDenied =>
      'Only a manager can delete requests. The request was not deleted.';

  @override
  String get deleteOrderFailed =>
      'Couldn\'t delete the request. Check your connection and try again.';

  @override
  String get mapViewList => 'List';

  @override
  String get mapViewMap => 'Map';

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get mapFitAll => 'Show all locations';

  @override
  String get mapMyLocation => 'My location';

  @override
  String get mapMyLocationFailed =>
      'Couldn\'t find your location. Turn on location services and allow the app to use them.';

  @override
  String get mapSelectArea => 'Select area';

  @override
  String get mapSelectAreaHint => 'Drag a box on the map';

  @override
  String get mapSearchHere => 'Search this area';

  @override
  String mapInArea(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count locations',
      one: '$count location',
      zero: 'no locations',
    );
    return 'In this area: $_temp0';
  }

  @override
  String mapInRect(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count locations',
      one: '$count location',
      zero: 'no locations',
    );
    return 'In the selected area: $_temp0';
  }

  @override
  String mapNearby(int count, String radius) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count locations',
      one: '$count location',
      zero: 'no locations',
    );
    return 'Within $radius: $_temp0';
  }

  @override
  String get mapReset => 'reset';

  @override
  String get mapNearbyTitle => 'Nearby locations';

  @override
  String mapKm(String value) {
    return '$value km';
  }

  @override
  String get mapNearbyHelp =>
      'Right-click or long-press the map to find nearby locations. Shift + drag selects an area.';

  @override
  String mapNoCoordinates(int count) {
    return 'Not on the map ($count)';
  }

  @override
  String get mapSetOnMap => 'Set on map';

  @override
  String get mapMoveOnMap => 'Move on map';

  @override
  String mapPlaceHint(String name) {
    return 'Move the map so the crosshair is on “$name”';
  }

  @override
  String get mapSaveHere => 'Save here';

  @override
  String get mapPlaceSaved => 'Map location saved';

  @override
  String get mapOpenObject => 'Open location';

  @override
  String get mapOrders => 'Requests';

  @override
  String get mapCreateHere => 'New request here';

  @override
  String get mapCountNew => 'New';

  @override
  String get mapCountInWork => 'In progress';

  @override
  String get mapCountOnReview => 'In review';

  @override
  String get mapCountOverdue => 'Overdue';

  @override
  String mapOpenOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open requests',
      one: '$count open request',
      zero: 'No open requests',
    );
    return '$_temp0';
  }

  @override
  String get mapSearchHint => 'Search by name or address';

  @override
  String get mapNothingFound => 'Nothing found';

  @override
  String mapListTitle(int count) {
    return 'Locations on the map ($count)';
  }

  @override
  String get mapOrdersFailed =>
      'Couldn\'t load requests — marker numbers may be inaccurate.';

  @override
  String get mapClose => 'Close';

  @override
  String mapCluster(int count) {
    return '$count locations. Tap to zoom in';
  }

  @override
  String requestsFilterObject(String name) {
    return 'Location: $name';
  }

  @override
  String get requestsFilterClear => 'Clear filter';

  @override
  String get reqSearchHint => 'Search requests';

  @override
  String reqSegAll(String count) {
    return 'All · $count';
  }

  @override
  String reqSegOpen(String count) {
    return 'Open · $count';
  }

  @override
  String reqSegOverdue(String count) {
    return 'Overdue · $count';
  }

  @override
  String reqSegOf(int shown, int total) {
    return '$shown of $total';
  }

  @override
  String get reqSearchShort => 'Search';

  @override
  String get reqGroupToday => 'Today';

  @override
  String get reqGroupEarlier => 'Earlier';

  @override
  String get reqNothingFound => 'Nothing found';

  @override
  String get reqFieldPlace => 'Room';

  @override
  String get reqFieldDue => 'Due';

  @override
  String get reqViaVoice => 'by voice';

  @override
  String get reqViaText => 'by text';

  @override
  String get filterPeriod => 'Period';

  @override
  String get filterObject => 'Site';

  @override
  String get filterRoom => 'Room';

  @override
  String get filterContractor => 'Contractor';

  @override
  String get filterPriority => 'Priority';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterWorkType => 'Work type';

  @override
  String get filterMore => 'More';

  @override
  String get filterSort => 'Sort';

  @override
  String get filterPeriodToday => 'Today';

  @override
  String get filterPeriod7 => '7 days';

  @override
  String get filterPeriod30 => '30 days';

  @override
  String get filterPeriodThisMonth => 'This month';

  @override
  String get filterPeriodLastMonth => 'Last month';

  @override
  String get filterPeriodCustom => 'Custom range…';

  @override
  String get filterByCreated => 'By created date';

  @override
  String get filterByDue => 'By due date';

  @override
  String filterDueLabel(String period) {
    return 'Due: $period';
  }

  @override
  String get filterNoContractor => 'No contractor';

  @override
  String get filterOverdue => 'Overdue';

  @override
  String get filterType => 'Type';

  @override
  String get filterOnce => 'One-off';

  @override
  String get filterRecurring => 'Recurring';

  @override
  String get filterSource => 'Source';

  @override
  String get filterChannelVoice => 'Voice';

  @override
  String get filterChannelText => 'Text';

  @override
  String get filterChannelButton => 'Manual';

  @override
  String get filterOptions => 'Conditions';

  @override
  String get filterNeedsPhoto => 'Photo required';

  @override
  String get filterReturned => 'Returned for rework';

  @override
  String get filterCreatedByMe => 'Created by me';

  @override
  String get filterAssignedToMe => 'Assigned to me';

  @override
  String filterMoreCount(int count) {
    return 'More · $count';
  }

  @override
  String filterPlus(String label, int count) {
    return '$label +$count';
  }

  @override
  String get sortNewest => 'Newest first';

  @override
  String get sortOldest => 'Oldest first';

  @override
  String get sortDue => 'By due date';

  @override
  String get sortPriority => 'By priority';

  @override
  String get sortStatus => 'By status';

  @override
  String get sortObject => 'By site';

  @override
  String get filterReset => 'Reset';

  @override
  String get filterApply => 'Apply';

  @override
  String filterApplyCount(int count) {
    return 'Apply ($count)';
  }

  @override
  String get filterResetAll => 'Reset all';

  @override
  String filterFound(int shown, int total) {
    return 'Showing $shown of $total';
  }

  @override
  String get filterResetFilters => 'Reset filters';

  @override
  String get filterSearchHint => 'Search the list';

  @override
  String filterClearOne(String name) {
    return 'Clear filter “$name”';
  }

  @override
  String filterRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get filterPickDates => 'Choose dates';

  @override
  String get cityNone => 'No city';

  @override
  String cityCount(String city, int count) {
    return '$city · $count';
  }

  @override
  String get cityAll => 'All';

  @override
  String get filterCityAll => 'Whole city';

  @override
  String filterCityWhole(String city, int count) {
    return '$city ($count)';
  }

  @override
  String objectsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sites',
      one: '$count site',
    );
    return '$_temp0';
  }

  @override
  String contractorCoverage(String cities, String objects) {
    return '$cities · $objects';
  }

  @override
  String get cardWorkTypes => 'Work types';

  @override
  String get cardObjectsByCity => 'Sites';

  @override
  String mapCityZoom(String city) {
    return 'Show $city';
  }

  @override
  String get filterAll => 'Filters';

  @override
  String filterAllCount(int count) {
    return 'Filters · $count';
  }

  @override
  String get filterAllWide => 'All filters';

  @override
  String filterAllWideCount(int count) {
    return 'All filters · $count';
  }

  @override
  String get filterAny => 'Any';

  @override
  String get filterShow => 'Show';

  @override
  String filterShowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count requests',
      one: 'Show $count request',
      zero: 'No requests',
    );
    return '$_temp0';
  }

  @override
  String get commonClose => 'Close';

  @override
  String get commonGotIt => 'Got it';

  @override
  String get infoFiltersTitle => 'How filters work';

  @override
  String get infoFilters1 =>
      'Pick conditions — the button below shows right away how many requests match.';

  @override
  String get infoFilters2 =>
      '“Show” applies the filters; the “×” on a chip above the list removes one filter.';

  @override
  String get infoFilters3 =>
      'Filters are remembered on this device, and in the browser also in the page address — you can send the link to a colleague.';

  @override
  String infoShowHint(String title) {
    return 'Tip: $title';
  }

  @override
  String get sortShortNewest => 'Newest';

  @override
  String get sortShortOldest => 'Oldest';

  @override
  String get sortShortDue => 'Due';

  @override
  String get sortShortPriority => 'Priority';

  @override
  String get sortShortStatus => 'Status';

  @override
  String get sortShortObject => 'Site';

  @override
  String get floorsHeader => 'Floors';

  @override
  String floorsTitle(int count) {
    return 'Floors · $count';
  }

  @override
  String get floorsEmpty => 'No floors yet';

  @override
  String get floorsEmptyManager =>
      'Add a floor and upload its plan — then mark rooms and equipment on it.';

  @override
  String get floorAdd => 'Floor';

  @override
  String get floorAddLong => 'Add floor';

  @override
  String floorPlacesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rooms',
      one: '$count room',
    );
    return '$_temp0';
  }

  @override
  String floorOpenOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open requests',
      one: '$count open request',
      zero: 'no open requests',
    );
    return '$_temp0';
  }

  @override
  String get floorNoPlan => 'No plan';

  @override
  String get floorFormNew => 'New floor';

  @override
  String get floorFormEdit => 'Floor';

  @override
  String get floorName => 'Name';

  @override
  String get floorNameHint => 'For example, Floor 3 or Parking';

  @override
  String get floorLevel => 'Floor number';

  @override
  String get floorLevelHint => '−1, −2 — underground levels';

  @override
  String get floorPlanImage => 'Plan image';

  @override
  String get floorPlanPick => 'Choose file';

  @override
  String get floorPlanOptional => 'Optional — you can upload the plan later.';

  @override
  String get floorNameEmpty => 'Enter the floor name';

  @override
  String get floorNameTooLong => 'Name must be 60 characters or fewer';

  @override
  String get floorNameTaken => 'A floor with this name already exists';

  @override
  String get floorLevelInvalid =>
      'Floor number must be a whole number, e.g. 3 or −1';

  @override
  String get floorRename => 'Rename';

  @override
  String get floorUploadPlan => 'Upload plan';

  @override
  String get floorReplacePlan => 'Replace plan';

  @override
  String get floorRemovePlan => 'Remove plan';

  @override
  String get floorMoveUp => 'Move up';

  @override
  String get floorMoveDown => 'Move down';

  @override
  String get floorDelete => 'Delete floor';

  @override
  String floorDeleteConfirm(String name) {
    return 'Delete floor “$name”?';
  }

  @override
  String get floorDeleteHint =>
      'Rooms and equipment will stay, but they will be removed from the plan.';

  @override
  String get floorDeleted => 'Floor deleted';

  @override
  String floorAddPlace(String name) {
    return 'Add a room to “$name”';
  }

  @override
  String floorMenu(String name) {
    return 'Actions for “$name”';
  }

  @override
  String get planTooBig =>
      'The file is larger than 15 MB. Make the image smaller or save it as JPEG.';

  @override
  String get planPdf =>
      'PDF isn’t supported: save the page you need as PNG or take a screenshot.';

  @override
  String get planBadType => 'Please choose a PNG, JPEG or WebP image.';

  @override
  String get planUnreadable => 'Couldn’t read the image. Try another file.';

  @override
  String get planNoRights =>
      'Only a manager can change floors, plans and markers.';

  @override
  String get planUploadFailed =>
      'Couldn’t upload the plan. Check your connection and try again.';

  @override
  String planStorageDenied(String code) {
    return 'Storage rejected the upload (code $code). Try again or contact your administrator.';
  }

  @override
  String planDbDenied(String code) {
    return 'The database rejected the change (code $code). Try again or contact your administrator.';
  }

  @override
  String get planUploaded => 'Plan uploaded';

  @override
  String get planRemoved => 'Plan removed';

  @override
  String get placeNotOnPlan => 'not on plan';

  @override
  String get infoFloorsTitle => 'Floors and plans';

  @override
  String get infoFloors1 =>
      'A floor is part of a site. A floor can have a plan image.';

  @override
  String get infoFloors2 =>
      'Rooms and equipment are marked on the plan, so technicians find the spot faster.';

  @override
  String get infoFloors3 =>
      'Managers add floors, upload plans and place markers. Everyone else sees the plan read-only.';

  @override
  String get infoUploadTitle => 'Uploading a plan';

  @override
  String get infoUpload1 => 'PNG, JPEG and WebP images up to 15 MB.';

  @override
  String get infoUpload2 =>
      'PDF: save the page you need as PNG or take a screenshot.';

  @override
  String get infoUpload3 => 'Only people in your company can see the plan.';

  @override
  String get planTitle => 'Floor plan';

  @override
  String get planEdit => 'Edit';

  @override
  String get planEditMode => 'Placement mode';

  @override
  String get planEditHint => 'drag markers, tap an empty spot to add one';

  @override
  String get planDone => 'Done';

  @override
  String get planFilterAll => 'All';

  @override
  String get planFilterPlaces => 'Rooms';

  @override
  String get planFilterAssets => 'Equipment';

  @override
  String get planFilterWithOrders => 'With requests';

  @override
  String planOnPlan(int count) {
    return 'On plan · $count';
  }

  @override
  String planUnplaced(int count) {
    return 'Not placed · $count';
  }

  @override
  String get planSearch => 'Search rooms and equipment';

  @override
  String get planNotLoaded => 'No plan uploaded';

  @override
  String get planFit => 'Fit plan';

  @override
  String get planList => 'List';

  @override
  String get planOpenOrders => 'Open requests';

  @override
  String get planNoOpenOrders => 'No open requests';

  @override
  String get planCreateHere => 'Create request here';

  @override
  String get planAllPlaceOrders => 'All requests for this room';

  @override
  String get planAssetInventory => 'Inventory no.';

  @override
  String get planAssetCategory => 'Category';

  @override
  String get planAssetPlace => 'Room';

  @override
  String assetCategory(String code) {
    String _temp0 = intl.Intl.selectLogic(
      code,
      {
        'equipment': 'Equipment',
        'furniture': 'Furniture',
        'infra': 'Utilities',
        'other': 'Other',
      },
    );
    return '$_temp0';
  }

  @override
  String get planNewPlaceHere => 'New room here';

  @override
  String get planNewAssetHere => 'New equipment here';

  @override
  String get planPutHere => 'Place here…';

  @override
  String get planRename => 'Rename';

  @override
  String get planRemoveFromPlan => 'Remove from plan';

  @override
  String get planDelete => 'Delete';

  @override
  String planDeleteConfirm(String name) {
    return 'Delete “$name”?';
  }

  @override
  String planDeleteHasOrders(String name) {
    return '“$name” has requests and can’t be deleted. You can remove it from the plan.';
  }

  @override
  String get planSaved => 'Saved';

  @override
  String get planUndo => 'Undo';

  @override
  String get planNewPlace => 'New room';

  @override
  String get planNewAsset => 'New equipment';

  @override
  String get planNameLabel => 'Name';

  @override
  String get planNameRequired => 'Enter a name';

  @override
  String get planInventoryLabel => 'Inventory no. (optional)';

  @override
  String get planPickUnplaced => 'What to place here';

  @override
  String get planNothingUnplaced => 'Everything is already on the plan';

  @override
  String get planNotFound => 'Floor not found or no access.';

  @override
  String get planNoPlaces => 'Add a room to this floor first';

  @override
  String get planFloorPicker => 'Floor';

  @override
  String get planMarkerHint => 'Tap a marker for requests and actions';

  @override
  String get infoPlanTitle => 'What markers mean';

  @override
  String get infoPlan1 =>
      'Circle — a room, the number is its open requests. Square — equipment.';

  @override
  String get infoPlan2 =>
      'Red — overdue or critical requests, orange — urgent or in progress.';

  @override
  String get infoPlan3 => 'Teal — there are open requests, grey — none open.';

  @override
  String get infoEditTitle => 'Placement mode';

  @override
  String get infoEdit1 =>
      'Drag a marker to move it (on a phone — long-press first). It saves right away, with Undo.';

  @override
  String get infoEdit2 =>
      'Tap an empty spot to add a room or equipment, or to place something not yet on the plan.';

  @override
  String get infoEdit3 =>
      'Tap a marker to rename it, remove it from the plan or delete it.';

  @override
  String get orderShowOnPlan => 'Show on plan';

  @override
  String planNearby(String floor, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open requests nearby',
      one: '$count open request nearby',
      zero: 'no open requests nearby',
    );
    return '$floor · $_temp0';
  }

  @override
  String floorShort(int level) {
    return 'fl. $level';
  }

  @override
  String get formPlace => 'Room';

  @override
  String get formChoosePlace => 'No room';

  @override
  String get formAsset => 'Equipment';

  @override
  String get navAddOrder => 'Request';

  @override
  String get navCollapse => 'Collapse menu';

  @override
  String get navExpand => 'Expand menu';

  @override
  String navLanguage(String lang) {
    return 'Interface language: $lang';
  }

  @override
  String get navHelp => 'Help and keyboard shortcuts';

  @override
  String get navAccount => 'Account menu';

  @override
  String navCompanyRole(String company, String role) {
    return '$company · $role';
  }

  @override
  String get helpTitle => 'Help';

  @override
  String get helpTip1 =>
      '“Hey Helpy” — say what happened and where: the request fills itself in, you just check and send it.';

  @override
  String get helpTip2 =>
      'A request can\'t be closed without an “after” photo and approval by its author or a manager.';

  @override
  String get helpTip3 =>
      '“Locations” — sites on the map and floor plans with room and equipment markers.';

  @override
  String get helpHotkeys => 'Keyboard shortcuts';

  @override
  String get hotkeyNew => 'New request';

  @override
  String get hotkeyVoice => 'Voice request';

  @override
  String get hotkeySearch => 'Search requests';

  @override
  String get hotkeyHelp => 'This help';

  @override
  String get hotkeyNote =>
      'They don\'t work while the cursor is in a text field.';
}
