import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// Название продукта в интерфейсе. Единственное место, где оно задано (кроме подписи под иконкой: android/app/src/main/res/values*/strings.xml). Шапка выделяет часть после первого пробела.
  ///
  /// In ru, this message translates to:
  /// **'Эй, Helpy'**
  String get appName;

  /// Фраза голосовой активации, как её произносит пользователь
  ///
  /// In ru, this message translates to:
  /// **'Эй, Хелпи'**
  String get wakePhrase;

  /// No description provided for @appTagline.
  ///
  /// In ru, this message translates to:
  /// **'Заявки и контроль работ — в одно касание'**
  String get appTagline;

  /// No description provided for @commonCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get commonSave;

  /// No description provided for @commonRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get commonRetry;

  /// No description provided for @commonRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get commonRefresh;

  /// No description provided for @commonNotSpecified.
  ///
  /// In ru, this message translates to:
  /// **'Не указано'**
  String get commonNotSpecified;

  /// No description provided for @errorGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось. Проверьте интернет и попробуйте ещё раз.'**
  String get errorGeneric;

  /// No description provided for @misconfiguredTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не заданы ключи Supabase'**
  String get misconfiguredTitle;

  /// No description provided for @misconfiguredRunWith.
  ///
  /// In ru, this message translates to:
  /// **'Запустите приложение с параметрами:'**
  String get misconfiguredRunWith;

  /// No description provided for @misconfiguredSeeReadme.
  ///
  /// In ru, this message translates to:
  /// **'Подробности — в README.md'**
  String get misconfiguredSeeReadme;

  /// No description provided for @splashLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить профиль.\nПроверьте подключение к интернету.'**
  String get splashLoadFailed;

  /// No description provided for @splashSignOut.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта'**
  String get splashSignOut;

  /// No description provided for @loginName.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get loginName;

  /// No description provided for @loginEmail.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginEmailInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректный email'**
  String get loginEmailInvalid;

  /// No description provided for @loginPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get loginPassword;

  /// No description provided for @loginPasswordTooShort.
  ///
  /// In ru, this message translates to:
  /// **'Минимум 6 символов'**
  String get loginPasswordTooShort;

  /// No description provided for @loginSignIn.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get loginSignIn;

  /// No description provided for @loginSignUp.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрироваться'**
  String get loginSignUp;

  /// No description provided for @loginHaveAccount.
  ///
  /// In ru, this message translates to:
  /// **'Уже есть аккаунт? Войти'**
  String get loginHaveAccount;

  /// No description provided for @loginNoAccount.
  ///
  /// In ru, this message translates to:
  /// **'Нет аккаунта? Зарегистрироваться'**
  String get loginNoAccount;

  /// No description provided for @loginAccountCreated.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт создан. Если включено подтверждение почты — проверьте письмо.'**
  String get loginAccountCreated;

  /// No description provided for @loginErrorInvalidCredentials.
  ///
  /// In ru, this message translates to:
  /// **'Неверный email или пароль'**
  String get loginErrorInvalidCredentials;

  /// No description provided for @loginErrorAlreadyRegistered.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь с таким email уже зарегистрирован. Войдите.'**
  String get loginErrorAlreadyRegistered;

  /// No description provided for @loginErrorEmailNotConfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Почта не подтверждена. Откройте письмо и перейдите по ссылке.'**
  String get loginErrorEmailNotConfirmed;

  /// No description provided for @navHome.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get navHome;

  /// No description provided for @navHistory.
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get navHistory;

  /// No description provided for @navReports.
  ///
  /// In ru, this message translates to:
  /// **'Отчёты'**
  String get navReports;

  /// No description provided for @navProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get navProfile;

  /// No description provided for @tabRequests.
  ///
  /// In ru, this message translates to:
  /// **'Заявки'**
  String get tabRequests;

  /// Вкладка со списком подрядчиков
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель'**
  String get tabContractors;

  /// No description provided for @tabLocations.
  ///
  /// In ru, this message translates to:
  /// **'Локации'**
  String get tabLocations;

  /// Временно: выдуманные данные
  ///
  /// In ru, this message translates to:
  /// **'Выполнено за месяц: {count}'**
  String mockHistoryDoneThisMonth(int count);

  /// No description provided for @mockHistory1Title.
  ///
  /// In ru, this message translates to:
  /// **'Ремонт стула'**
  String get mockHistory1Title;

  /// No description provided for @mockHistory1Place.
  ///
  /// In ru, this message translates to:
  /// **'Астана · Кабинет 512'**
  String get mockHistory1Place;

  /// No description provided for @mockHistory1Meta.
  ///
  /// In ru, this message translates to:
  /// **'12 авг · 40 мин'**
  String get mockHistory1Meta;

  /// No description provided for @mockHistory2Title.
  ///
  /// In ru, this message translates to:
  /// **'Замена фильтров'**
  String get mockHistory2Title;

  /// No description provided for @mockHistory2Place.
  ///
  /// In ru, this message translates to:
  /// **'Москва · Серверная'**
  String get mockHistory2Place;

  /// No description provided for @mockHistory2Meta.
  ///
  /// In ru, this message translates to:
  /// **'11 авг · 1 ч 20 мин'**
  String get mockHistory2Meta;

  /// No description provided for @mockHistory3Title.
  ///
  /// In ru, this message translates to:
  /// **'Уборка холла'**
  String get mockHistory3Title;

  /// No description provided for @mockHistory3Place.
  ///
  /// In ru, this message translates to:
  /// **'Москва · 1 этаж'**
  String get mockHistory3Place;

  /// No description provided for @mockHistory3Meta.
  ///
  /// In ru, this message translates to:
  /// **'11 авг · 55 мин'**
  String get mockHistory3Meta;

  /// No description provided for @historyDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get historyDone;

  /// No description provided for @reportsKpiRequests.
  ///
  /// In ru, this message translates to:
  /// **'заявок за месяц'**
  String get reportsKpiRequests;

  /// No description provided for @reportsKpiOnTime.
  ///
  /// In ru, this message translates to:
  /// **'в срок'**
  String get reportsKpiOnTime;

  /// No description provided for @reportsKpiAvgTime.
  ///
  /// In ru, this message translates to:
  /// **'ср. время'**
  String get reportsKpiAvgTime;

  /// No description provided for @hoursShort.
  ///
  /// In ru, this message translates to:
  /// **'{value} ч'**
  String hoursShort(String value);

  /// No description provided for @reportsWeeklyChart.
  ///
  /// In ru, this message translates to:
  /// **'Заявки по неделям'**
  String get reportsWeeklyChart;

  /// No description provided for @reportsExportPdf.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт в PDF'**
  String get reportsExportPdf;

  /// No description provided for @reportsWebHint.
  ///
  /// In ru, this message translates to:
  /// **'Полные отчёты и фильтры — в web-версии'**
  String get reportsWebHint;

  /// No description provided for @profileDefaultName.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь'**
  String get profileDefaultName;

  /// No description provided for @profileMyCompany.
  ///
  /// In ru, this message translates to:
  /// **'Моя компания'**
  String get profileMyCompany;

  /// No description provided for @profileNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get profileNotifications;

  /// No description provided for @profileLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get profileLanguage;

  /// No description provided for @profileSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get profileSettings;

  /// No description provided for @profileSignOut.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get profileSignOut;

  /// No description provided for @profileLanguageNotSynced.
  ///
  /// In ru, this message translates to:
  /// **'Язык сохранён на этом телефоне, но не в профиле. Проверьте интернет.'**
  String get profileLanguageNotSynced;

  /// No description provided for @roleAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Администратор'**
  String get roleAdmin;

  /// No description provided for @roleManager.
  ///
  /// In ru, this message translates to:
  /// **'Менеджер'**
  String get roleManager;

  /// No description provided for @roleRequester.
  ///
  /// In ru, this message translates to:
  /// **'Заявитель'**
  String get roleRequester;

  /// No description provided for @roleContractor.
  ///
  /// In ru, this message translates to:
  /// **'Подрядчик'**
  String get roleContractor;

  /// No description provided for @roleExecutor.
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель'**
  String get roleExecutor;

  /// No description provided for @statusNew.
  ///
  /// In ru, this message translates to:
  /// **'Новая'**
  String get statusNew;

  /// No description provided for @statusAssigned.
  ///
  /// In ru, this message translates to:
  /// **'Назначена'**
  String get statusAssigned;

  /// No description provided for @statusInProgress.
  ///
  /// In ru, this message translates to:
  /// **'В работе'**
  String get statusInProgress;

  /// No description provided for @statusOnReview.
  ///
  /// In ru, this message translates to:
  /// **'На проверке'**
  String get statusOnReview;

  /// No description provided for @statusReturned.
  ///
  /// In ru, this message translates to:
  /// **'Возвращена'**
  String get statusReturned;

  /// No description provided for @statusDone.
  ///
  /// In ru, this message translates to:
  /// **'Принята'**
  String get statusDone;

  /// No description provided for @statusCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменена'**
  String get statusCancelled;

  /// No description provided for @statusOverdue.
  ///
  /// In ru, this message translates to:
  /// **'Просрочена'**
  String get statusOverdue;

  /// No description provided for @priorityLow.
  ///
  /// In ru, this message translates to:
  /// **'Низкий'**
  String get priorityLow;

  /// No description provided for @priorityNormal.
  ///
  /// In ru, this message translates to:
  /// **'Обычный'**
  String get priorityNormal;

  /// No description provided for @priorityHigh.
  ///
  /// In ru, this message translates to:
  /// **'Высокий'**
  String get priorityHigh;

  /// No description provided for @priorityCritical.
  ///
  /// In ru, this message translates to:
  /// **'Критический'**
  String get priorityCritical;

  /// No description provided for @requestsLoading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка…'**
  String get requestsLoading;

  /// No description provided for @requestsLoadErrorShort.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки'**
  String get requestsLoadErrorShort;

  /// No description provided for @requestsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Заявок нет} one{{count} заявка} few{{count} заявки} many{{count} заявок} other{{count} заявки}}'**
  String requestsCount(int count);

  /// No description provided for @requestsLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить заявки. Проверьте интернет и нажмите «Обновить».'**
  String get requestsLoadFailed;

  /// No description provided for @requestsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет заявок.\nНажмите «Создать заявку».'**
  String get requestsEmpty;

  /// No description provided for @requestsCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать заявку'**
  String get requestsCreate;

  /// No description provided for @requestsVoice.
  ///
  /// In ru, this message translates to:
  /// **'Нажми и говори'**
  String get requestsVoice;

  /// No description provided for @requestsCreated.
  ///
  /// In ru, this message translates to:
  /// **'Заявка создана'**
  String get requestsCreated;

  /// No description provided for @requestsNoCompany.
  ///
  /// In ru, this message translates to:
  /// **'Ваш профиль не привязан к компании. Обратитесь к администратору.'**
  String get requestsNoCompany;

  /// No description provided for @requestRecurringTag.
  ///
  /// In ru, this message translates to:
  /// **'регламент'**
  String get requestRecurringTag;

  /// No description provided for @objectNone.
  ///
  /// In ru, this message translates to:
  /// **'Без объекта'**
  String get objectNone;

  /// No description provided for @objectUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Объект'**
  String get objectUnknown;

  /// No description provided for @contractorNone.
  ///
  /// In ru, this message translates to:
  /// **'не назначен'**
  String get contractorNone;

  /// No description provided for @contractorUnknown.
  ///
  /// In ru, this message translates to:
  /// **'исполнитель'**
  String get contractorUnknown;

  /// No description provided for @detailTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заявка'**
  String get detailTitle;

  /// No description provided for @detailEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get detailEdit;

  /// No description provided for @detailLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть заявку. Проверьте интернет и попробуйте ещё раз.'**
  String get detailLoadFailed;

  /// No description provided for @fieldObject.
  ///
  /// In ru, this message translates to:
  /// **'Объект'**
  String get fieldObject;

  /// No description provided for @fieldContractor.
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель'**
  String get fieldContractor;

  /// No description provided for @fieldWorkType.
  ///
  /// In ru, this message translates to:
  /// **'Вид работ'**
  String get fieldWorkType;

  /// No description provided for @fieldPriority.
  ///
  /// In ru, this message translates to:
  /// **'Приоритет'**
  String get fieldPriority;

  /// No description provided for @fieldKind.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get fieldKind;

  /// No description provided for @kindRecurring.
  ///
  /// In ru, this message translates to:
  /// **'Регламентная'**
  String get kindRecurring;

  /// No description provided for @kindOneOff.
  ///
  /// In ru, this message translates to:
  /// **'Разовая'**
  String get kindOneOff;

  /// No description provided for @fieldPhotoProof.
  ///
  /// In ru, this message translates to:
  /// **'Фотоподтверждение'**
  String get fieldPhotoProof;

  /// No description provided for @photoRequired.
  ///
  /// In ru, this message translates to:
  /// **'Требуется'**
  String get photoRequired;

  /// No description provided for @photoNotRequired.
  ///
  /// In ru, this message translates to:
  /// **'Не требуется'**
  String get photoNotRequired;

  /// No description provided for @fieldCreated.
  ///
  /// In ru, this message translates to:
  /// **'Создана'**
  String get fieldCreated;

  /// No description provided for @createdByYou.
  ///
  /// In ru, this message translates to:
  /// **'{date} (вы)'**
  String createdByYou(String date);

  /// No description provided for @fieldDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get fieldDescription;

  /// No description provided for @noDescription.
  ///
  /// In ru, this message translates to:
  /// **'Без описания'**
  String get noDescription;

  /// No description provided for @returnedWithReason.
  ///
  /// In ru, this message translates to:
  /// **'Возвращено: {reason}'**
  String returnedWithReason(String reason);

  /// No description provided for @actionsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Действия'**
  String get actionsTitle;

  /// No description provided for @actionAssign.
  ///
  /// In ru, this message translates to:
  /// **'Назначить исполнителя'**
  String get actionAssign;

  /// No description provided for @actionReassign.
  ///
  /// In ru, this message translates to:
  /// **'Сменить исполнителя'**
  String get actionReassign;

  /// No description provided for @actionStart.
  ///
  /// In ru, this message translates to:
  /// **'Взять в работу'**
  String get actionStart;

  /// No description provided for @actionRestart.
  ///
  /// In ru, this message translates to:
  /// **'Взять на доработку'**
  String get actionRestart;

  /// No description provided for @actionSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Выполнено, на проверку'**
  String get actionSubmit;

  /// No description provided for @actionAccept.
  ///
  /// In ru, this message translates to:
  /// **'Принять работу'**
  String get actionAccept;

  /// No description provided for @actionReturn.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть на доработку'**
  String get actionReturn;

  /// No description provided for @actionCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get actionCancel;

  /// No description provided for @toastInProgress.
  ///
  /// In ru, this message translates to:
  /// **'Заявка в работе'**
  String get toastInProgress;

  /// No description provided for @toastSubmitted.
  ///
  /// In ru, this message translates to:
  /// **'Отправлено на проверку'**
  String get toastSubmitted;

  /// No description provided for @toastAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Работа принята'**
  String get toastAccepted;

  /// No description provided for @toastCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Заявка отменена'**
  String get toastCancelled;

  /// No description provided for @toastReturned.
  ///
  /// In ru, this message translates to:
  /// **'Возвращено исполнителю'**
  String get toastReturned;

  /// No description provided for @toastSaved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get toastSaved;

  /// No description provided for @toastAssigned.
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель назначен'**
  String get toastAssigned;

  /// No description provided for @assignNoContractors.
  ///
  /// In ru, this message translates to:
  /// **'Сначала добавьте подрядчика во вкладке «{tab}»'**
  String assignNoContractors(String tab);

  /// No description provided for @returnHint.
  ///
  /// In ru, this message translates to:
  /// **'Что нужно исправить?'**
  String get returnHint;

  /// No description provided for @returnConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть'**
  String get returnConfirm;

  /// No description provided for @returnReasonRequired.
  ///
  /// In ru, this message translates to:
  /// **'Напишите, что нужно исправить'**
  String get returnReasonRequired;

  /// No description provided for @errPhotoRequired.
  ///
  /// In ru, this message translates to:
  /// **'Нужно фото выполненной работы'**
  String get errPhotoRequired;

  /// No description provided for @errNotAllowed.
  ///
  /// In ru, this message translates to:
  /// **'Это действие недоступно для вашей роли или текущего статуса'**
  String get errNotAllowed;

  /// No description provided for @formNewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новая заявка'**
  String get formNewTitle;

  /// No description provided for @formEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать заявку'**
  String get formEditTitle;

  /// No description provided for @formWhat.
  ///
  /// In ru, this message translates to:
  /// **'Что случилось?'**
  String get formWhat;

  /// No description provided for @formWhatHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, протекает кран'**
  String get formWhatHint;

  /// No description provided for @formDetailsHint.
  ///
  /// In ru, this message translates to:
  /// **'Подробности'**
  String get formDetailsHint;

  /// No description provided for @formNoObjects.
  ///
  /// In ru, this message translates to:
  /// **'Нет объектов — добавьте во вкладке «{tab}»'**
  String formNoObjects(String tab);

  /// No description provided for @formChooseObject.
  ///
  /// In ru, this message translates to:
  /// **'Выберите объект'**
  String get formChooseObject;

  /// No description provided for @formRecurring.
  ///
  /// In ru, this message translates to:
  /// **'Регламентная (повторяющаяся)'**
  String get formRecurring;

  /// No description provided for @formWhatRequired.
  ///
  /// In ru, this message translates to:
  /// **'Напишите, что случилось'**
  String get formWhatRequired;

  /// No description provided for @formSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить заявку. Проверьте интернет и попробуйте ещё раз.'**
  String get formSaveFailed;

  /// No description provided for @formLayersFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить виды работ. Заявку можно отправить без него.'**
  String get formLayersFailed;

  /// No description provided for @voiceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Голосовая заявка'**
  String get voiceTitle;

  /// No description provided for @voiceStarting.
  ///
  /// In ru, this message translates to:
  /// **'Включаю микрофон…'**
  String get voiceStarting;

  /// No description provided for @voiceListening.
  ///
  /// In ru, this message translates to:
  /// **'Слушаю'**
  String get voiceListening;

  /// No description provided for @voiceProcessing.
  ///
  /// In ru, this message translates to:
  /// **'Распознаю…'**
  String get voiceProcessing;

  /// No description provided for @voiceFailedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось'**
  String get voiceFailedTitle;

  /// No description provided for @voicePrompt.
  ///
  /// In ru, this message translates to:
  /// **'Скажите, что случилось и где.\nНапример: «В переговорной на третьем этаже не работает кондиционер».'**
  String get voicePrompt;

  /// No description provided for @voiceTimer.
  ///
  /// In ru, this message translates to:
  /// **'{elapsed} · осталось {left} с'**
  String voiceTimer(String elapsed, int left);

  /// No description provided for @voiceProcessingHint.
  ///
  /// In ru, this message translates to:
  /// **'Это займёт несколько секунд'**
  String get voiceProcessingHint;

  /// No description provided for @voiceDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get voiceDone;

  /// No description provided for @voiceAgain.
  ///
  /// In ru, this message translates to:
  /// **'Ещё раз'**
  String get voiceAgain;

  /// No description provided for @voiceNoMicPermission.
  ///
  /// In ru, this message translates to:
  /// **'Нужен доступ к микрофону. Разрешите его в настройках телефона и попробуйте снова.'**
  String get voiceNoMicPermission;

  /// No description provided for @voiceMicFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось включить микрофон. Попробуйте ещё раз.'**
  String get voiceMicFailed;

  /// No description provided for @voiceTooShort.
  ///
  /// In ru, this message translates to:
  /// **'Слишком коротко. Нажмите «Ещё раз» и опишите проблему.'**
  String get voiceTooShort;

  /// No description provided for @voiceRecognizeFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось распознать запись. Проверьте интернет и попробуйте ещё раз.'**
  String get voiceRecognizeFailed;

  /// No description provided for @voiceConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте заявку'**
  String get voiceConfirmTitle;

  /// No description provided for @voiceYouSaid.
  ///
  /// In ru, this message translates to:
  /// **'Вы сказали'**
  String get voiceYouSaid;

  /// Цитата в кавычках, принятых в языке
  ///
  /// In ru, this message translates to:
  /// **'«{text}»'**
  String quoted(String text);

  /// No description provided for @voicePickLayer.
  ///
  /// In ru, this message translates to:
  /// **'Выберите вид работ, чтобы заявка сразу ушла нужному подрядчику.'**
  String get voicePickLayer;

  /// No description provided for @voiceWhere.
  ///
  /// In ru, this message translates to:
  /// **'Где'**
  String get voiceWhere;

  /// No description provided for @voiceHeard.
  ///
  /// In ru, this message translates to:
  /// **'Услышали: «{hint}»'**
  String voiceHeard(String hint);

  /// No description provided for @voiceUrgency.
  ///
  /// In ru, this message translates to:
  /// **'Срочность'**
  String get voiceUrgency;

  /// No description provided for @voiceSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get voiceSend;

  /// No description provided for @voiceSendFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить заявку. Проверьте интернет и попробуйте ещё раз.'**
  String get voiceSendFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
