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
  /// **'Подрядчики'**
  String get tabContractors;

  /// No description provided for @tabLocations.
  ///
  /// In ru, this message translates to:
  /// **'Локации'**
  String get tabLocations;

  /// No description provided for @reportsKpiRequests.
  ///
  /// In ru, this message translates to:
  /// **'заявок'**
  String get reportsKpiRequests;

  /// No description provided for @reportsKpiOnTime.
  ///
  /// In ru, this message translates to:
  /// **'в срок'**
  String get reportsKpiOnTime;

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
  /// **'Подрядчик'**
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
  /// **'Назначить подрядчика'**
  String get actionAssign;

  /// No description provided for @actionReassign.
  ///
  /// In ru, this message translates to:
  /// **'Сменить подрядчика'**
  String get actionReassign;

  /// No description provided for @actionStart.
  ///
  /// In ru, this message translates to:
  /// **'Начать работу'**
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
  /// **'Подрядчик назначен'**
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
  /// **'Разбираю заявку…'**
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

  /// No description provided for @voiceMicFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось включить микрофон. Попробуйте ещё раз.'**
  String get voiceMicFailed;

  /// No description provided for @voiceRecognizeFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось распознать речь. Попробуйте ещё раз или введите заявку текстом.'**
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

  /// No description provided for @voiceAutoStop.
  ///
  /// In ru, this message translates to:
  /// **'После паузы в 3 секунды закончу сам'**
  String get voiceAutoStop;

  /// No description provided for @voiceNoMicPermissionWeb.
  ///
  /// In ru, this message translates to:
  /// **'Браузер не дал доступ к микрофону. Нажмите на значок замка или микрофона в адресной строке → «Микрофон» → «Разрешить» и нажмите «Ещё раз». На iPhone: Настройки → Safari → Микрофон → «Разрешить»; ещё должна быть включена диктовка (Настройки → Основные → Клавиатура).'**
  String get voiceNoMicPermissionWeb;

  /// No description provided for @voiceNoMicPermissionApp.
  ///
  /// In ru, this message translates to:
  /// **'Нужен доступ к микрофону: Настройки телефона → Приложения → {app} → Разрешения → Микрофон → «Разрешить». Затем нажмите «Ещё раз».'**
  String voiceNoMicPermissionApp(String app);

  /// No description provided for @voiceUnsupportedWeb.
  ///
  /// In ru, this message translates to:
  /// **'В этом браузере нет распознавания речи (например, в Firefox). Откройте приложение в Chrome, Edge или Safari — или введите заявку текстом.'**
  String get voiceUnsupportedWeb;

  /// No description provided for @voiceUnsupportedApp.
  ///
  /// In ru, this message translates to:
  /// **'На телефоне не найден сервис распознавания речи (обычно это приложение Google). Введите заявку текстом.'**
  String get voiceUnsupportedApp;

  /// No description provided for @voiceNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервисом распознавания речи. Проверьте интернет или введите заявку текстом.'**
  String get voiceNetwork;

  /// No description provided for @voiceNothingHeard.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не услышал. Нажмите «Ещё раз» и скажите, что случилось, — или введите текстом.'**
  String get voiceNothingHeard;

  /// No description provided for @voiceTypeInstead.
  ///
  /// In ru, this message translates to:
  /// **'Ввести текстом'**
  String get voiceTypeInstead;

  /// No description provided for @voiceTypeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Опишите заявку'**
  String get voiceTypeTitle;

  /// No description provided for @voiceTypeHint.
  ///
  /// In ru, this message translates to:
  /// **'Что случилось и где? Например: «В переговорной на третьем этаже не работает кондиционер»'**
  String get voiceTypeHint;

  /// No description provided for @voiceNext.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get voiceNext;

  /// No description provided for @voiceYouWrote.
  ///
  /// In ru, this message translates to:
  /// **'Вы написали'**
  String get voiceYouWrote;

  /// No description provided for @voiceEditHint.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок и описание можно поправить перед отправкой.'**
  String get voiceEditHint;

  /// No description provided for @voiceParsedByAi.
  ///
  /// In ru, this message translates to:
  /// **'Разобрано ИИ'**
  String get voiceParsedByAi;

  /// No description provided for @voiceParsedByDictionary.
  ///
  /// In ru, this message translates to:
  /// **'Разобрано по словарю'**
  String get voiceParsedByDictionary;

  /// No description provided for @objectTypeOffice.
  ///
  /// In ru, this message translates to:
  /// **'Офис'**
  String get objectTypeOffice;

  /// No description provided for @objectTypeHotel.
  ///
  /// In ru, this message translates to:
  /// **'Гостиница'**
  String get objectTypeHotel;

  /// No description provided for @objectTypeApartments.
  ///
  /// In ru, this message translates to:
  /// **'Апартаменты'**
  String get objectTypeApartments;

  /// No description provided for @objectTypeWarehouse.
  ///
  /// In ru, this message translates to:
  /// **'Склад'**
  String get objectTypeWarehouse;

  /// No description provided for @objectTypeOther.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get objectTypeOther;

  /// No description provided for @commonAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get commonAdd;

  /// No description provided for @objectsLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить объекты. Проверьте интернет и попробуйте ещё раз.'**
  String get objectsLoadFailed;

  /// No description provided for @objectsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет объектов.\nНажмите «Добавить».'**
  String get objectsEmpty;

  /// No description provided for @objectFormTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новая локация'**
  String get objectFormTitle;

  /// No description provided for @objectFormName.
  ///
  /// In ru, this message translates to:
  /// **'Наименование локации'**
  String get objectFormName;

  /// No description provided for @objectFormNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, БЦ «Северная башня»'**
  String get objectFormNameHint;

  /// No description provided for @objectFormAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get objectFormAddress;

  /// No description provided for @objectFormAddressHint.
  ///
  /// In ru, this message translates to:
  /// **'Город, улица, дом'**
  String get objectFormAddressHint;

  /// No description provided for @objectFormType.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get objectFormType;

  /// No description provided for @objectFormNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Напишите название'**
  String get objectFormNameRequired;

  /// No description provided for @objectAdded.
  ///
  /// In ru, this message translates to:
  /// **'Локация добавлена'**
  String get objectAdded;

  /// No description provided for @contractorsLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить подрядчиков. Проверьте интернет и попробуйте ещё раз.'**
  String get contractorsLoadFailed;

  /// No description provided for @contractorsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет подрядчиков.\nНажмите «Добавить».'**
  String get contractorsEmpty;

  /// No description provided for @contractorFormTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый исполнитель'**
  String get contractorFormTitle;

  /// No description provided for @contractorFormName.
  ///
  /// In ru, this message translates to:
  /// **'Наименование организации'**
  String get contractorFormName;

  /// No description provided for @contractorFormNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, СтройКом'**
  String get contractorFormNameHint;

  /// No description provided for @contractorFormNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Напишите название организации'**
  String get contractorFormNameRequired;

  /// No description provided for @contractorAdded.
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель добавлен'**
  String get contractorAdded;

  /// No description provided for @saveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить. Проверьте интернет и попробуйте ещё раз.'**
  String get saveFailed;

  /// No description provided for @onboardingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Начало работы'**
  String get onboardingTitle;

  /// No description provided for @onboardingChoose.
  ///
  /// In ru, this message translates to:
  /// **'Выберите, как вы будете работать в {appName}'**
  String onboardingChoose(String appName);

  /// No description provided for @onboardingCreateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Создать компанию'**
  String get onboardingCreateTitle;

  /// No description provided for @onboardingCreateSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Для владельцев и управляющих объектами. Вы станете администратором.'**
  String get onboardingCreateSubtitle;

  /// No description provided for @onboardingCompanyName.
  ///
  /// In ru, this message translates to:
  /// **'Название компании'**
  String get onboardingCompanyName;

  /// No description provided for @onboardingCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get onboardingCreate;

  /// No description provided for @onboardingInviteTitle.
  ///
  /// In ru, this message translates to:
  /// **'У меня есть код приглашения'**
  String get onboardingInviteTitle;

  /// No description provided for @onboardingInviteSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Для исполнителей подрядных организаций.'**
  String get onboardingInviteSubtitle;

  /// No description provided for @onboardingInviteCode.
  ///
  /// In ru, this message translates to:
  /// **'Код приглашения'**
  String get onboardingInviteCode;

  /// No description provided for @onboardingJoin.
  ///
  /// In ru, this message translates to:
  /// **'Вступить'**
  String get onboardingJoin;

  /// No description provided for @onboardingNoConnection.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером. Попробуйте ещё раз.'**
  String get onboardingNoConnection;

  /// No description provided for @onbErrNotAuthenticated.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в аккаунт, чтобы продолжить.'**
  String get onbErrNotAuthenticated;

  /// No description provided for @onbErrCompanyNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите название компании.'**
  String get onbErrCompanyNameRequired;

  /// No description provided for @onbErrAlreadyInCompany.
  ///
  /// In ru, this message translates to:
  /// **'Вы уже состоите в компании.'**
  String get onbErrAlreadyInCompany;

  /// No description provided for @onbErrInviteNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Код приглашения не найден. Проверьте, что он введён полностью.'**
  String get onbErrInviteNotFound;

  /// No description provided for @onbErrInviteUsed.
  ///
  /// In ru, this message translates to:
  /// **'Этот код приглашения уже использован.'**
  String get onbErrInviteUsed;

  /// No description provided for @onbErrInviteExpired.
  ///
  /// In ru, this message translates to:
  /// **'Срок действия приглашения истёк. Попросите новый код.'**
  String get onbErrInviteExpired;

  /// No description provided for @onbErrOtherCompany.
  ///
  /// In ru, this message translates to:
  /// **'Ваш аккаунт уже привязан к другой компании.'**
  String get onbErrOtherCompany;

  /// No description provided for @onbErrAdminOnly.
  ///
  /// In ru, this message translates to:
  /// **'Менять роли может только администратор.'**
  String get onbErrAdminOnly;

  /// No description provided for @onbErrOwnRole.
  ///
  /// In ru, this message translates to:
  /// **'Нельзя изменить собственную роль.'**
  String get onbErrOwnRole;

  /// No description provided for @onbErrProfileNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь не найден в вашей компании.'**
  String get onbErrProfileNotFound;

  /// No description provided for @onbErrUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить действие. Попробуйте ещё раз.'**
  String get onbErrUnknown;

  /// No description provided for @photosTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фото'**
  String get photosTitle;

  /// No description provided for @photosBefore.
  ///
  /// In ru, this message translates to:
  /// **'До'**
  String get photosBefore;

  /// No description provided for @photosAfter.
  ///
  /// In ru, this message translates to:
  /// **'После'**
  String get photosAfter;

  /// No description provided for @photosNone.
  ///
  /// In ru, this message translates to:
  /// **'Нет фото'**
  String get photosNone;

  /// No description provided for @photoTakeResult.
  ///
  /// In ru, this message translates to:
  /// **'Сфотографировать результат'**
  String get photoTakeResult;

  /// No description provided for @photoTakeMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё фото'**
  String get photoTakeMore;

  /// No description provided for @photoAddBefore.
  ///
  /// In ru, this message translates to:
  /// **'Добавить фото «до»'**
  String get photoAddBefore;

  /// No description provided for @photoUploading.
  ///
  /// In ru, this message translates to:
  /// **'Загружаю фото…'**
  String get photoUploading;

  /// No description provided for @photoUploaded.
  ///
  /// In ru, this message translates to:
  /// **'Фото добавлено'**
  String get photoUploaded;

  /// No description provided for @photoUploadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить фото. Проверьте интернет и попробуйте ещё раз.'**
  String get photoUploadFailed;

  /// No description provided for @photoCameraDenied.
  ///
  /// In ru, this message translates to:
  /// **'Нужен доступ к камере. Разрешите его в настройках телефона и попробуйте снова.'**
  String get photoCameraDenied;

  /// No description provided for @photoCameraFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть камеру. Попробуйте ещё раз.'**
  String get photoCameraFailed;

  /// No description provided for @photoLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить фото'**
  String get photoLoadFailed;

  /// No description provided for @photoNeededHint.
  ///
  /// In ru, this message translates to:
  /// **'Сфотографируйте результат: без фото «после» отправить на проверку нельзя.'**
  String get photoNeededHint;

  /// No description provided for @photoTakenAt.
  ///
  /// In ru, this message translates to:
  /// **'Снято {date}'**
  String photoTakenAt(String date);

  /// No description provided for @photoNoLocation.
  ///
  /// In ru, this message translates to:
  /// **'Без геометки'**
  String get photoNoLocation;

  /// No description provided for @photoWithLocation.
  ///
  /// In ru, this message translates to:
  /// **'С геометкой'**
  String get photoWithLocation;

  /// No description provided for @photoMockLocation.
  ///
  /// In ru, this message translates to:
  /// **'Координаты могли быть подменены'**
  String get photoMockLocation;

  /// No description provided for @visitsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Посещения'**
  String get visitsTitle;

  /// No description provided for @visitOnSiteRange.
  ///
  /// In ru, this message translates to:
  /// **'На объекте {from}–{to}'**
  String visitOnSiteRange(String from, String to);

  /// No description provided for @visitOnSiteSince.
  ///
  /// In ru, this message translates to:
  /// **'На объекте с {from}'**
  String visitOnSiteSince(String from);

  /// No description provided for @visitInGeofence.
  ///
  /// In ru, this message translates to:
  /// **'в геозоне ✓'**
  String get visitInGeofence;

  /// No description provided for @visitOutsideGeofence.
  ///
  /// In ru, this message translates to:
  /// **'вне геозоны ⚠'**
  String get visitOutsideGeofence;

  /// No description provided for @visitGeofenceUnknown.
  ///
  /// In ru, this message translates to:
  /// **'геозона не проверена'**
  String get visitGeofenceUnknown;

  /// No description provided for @visitDistance.
  ///
  /// In ru, this message translates to:
  /// **'{meters} м от объекта'**
  String visitDistance(String meters);

  /// No description provided for @visitMockLocation.
  ///
  /// In ru, this message translates to:
  /// **'Подозрение на подмену GPS'**
  String get visitMockLocation;

  /// No description provided for @visitOutsideWarning.
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель отметился вне геозоны объекта или с подменой GPS. Проверьте, был ли он на месте.'**
  String get visitOutsideWarning;

  /// No description provided for @visitsLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить посещения'**
  String get visitsLoadFailed;

  /// No description provided for @visitNotRecorded.
  ///
  /// In ru, this message translates to:
  /// **'Работа начата, но посещение не отмечено. Проверьте интернет.'**
  String get visitNotRecorded;

  /// No description provided for @visitNoLocation.
  ///
  /// In ru, this message translates to:
  /// **'Работа начата без геолокации. Включите её, чтобы посещение проверялось по геозоне.'**
  String get visitNoLocation;

  /// No description provided for @reportsManagerOnly.
  ///
  /// In ru, this message translates to:
  /// **'Отчёты доступны менеджеру и администратору.'**
  String get reportsManagerOnly;

  /// No description provided for @reportsPeriodWeek.
  ///
  /// In ru, this message translates to:
  /// **'Неделя'**
  String get reportsPeriodWeek;

  /// No description provided for @reportsPeriodMonth.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get reportsPeriodMonth;

  /// No description provided for @reportsPeriodCustom.
  ///
  /// In ru, this message translates to:
  /// **'Свой'**
  String get reportsPeriodCustom;

  /// No description provided for @reportsRange.
  ///
  /// In ru, this message translates to:
  /// **'{from} – {to}'**
  String reportsRange(String from, String to);

  /// No description provided for @reportsFilterObject.
  ///
  /// In ru, this message translates to:
  /// **'Объект'**
  String get reportsFilterObject;

  /// No description provided for @reportsFilterContractor.
  ///
  /// In ru, this message translates to:
  /// **'Подрядчик'**
  String get reportsFilterContractor;

  /// No description provided for @reportsFilterLayer.
  ///
  /// In ru, this message translates to:
  /// **'Вид работ'**
  String get reportsFilterLayer;

  /// No description provided for @reportsFilterAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get reportsFilterAll;

  /// No description provided for @reportsLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить отчёт. Проверьте интернет и попробуйте ещё раз.'**
  String get reportsLoadFailed;

  /// No description provided for @reportsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'За этот период заявок и посещений нет.'**
  String get reportsEmpty;

  /// No description provided for @reportsKpiFirstPass.
  ///
  /// In ru, this message translates to:
  /// **'приняты с первого раза'**
  String get reportsKpiFirstPass;

  /// No description provided for @reportsKpiGeofence.
  ///
  /// In ru, this message translates to:
  /// **'визитов в геозоне'**
  String get reportsKpiGeofence;

  /// No description provided for @reportsKpiOf.
  ///
  /// In ru, this message translates to:
  /// **'из {count}'**
  String reportsKpiOf(int count);

  /// No description provided for @reportsByContractor.
  ///
  /// In ru, this message translates to:
  /// **'По подрядчикам'**
  String get reportsByContractor;

  /// No description provided for @reportsNoContractor.
  ///
  /// In ru, this message translates to:
  /// **'Без подрядчика'**
  String get reportsNoContractor;

  /// No description provided for @reportsOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заявок'**
  String get reportsOrders;

  /// No description provided for @reportsAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Принято'**
  String get reportsAccepted;

  /// No description provided for @reportsReturned.
  ///
  /// In ru, this message translates to:
  /// **'Возвращено'**
  String get reportsReturned;

  /// No description provided for @reportsOverdue.
  ///
  /// In ru, this message translates to:
  /// **'Просрочено'**
  String get reportsOverdue;

  /// No description provided for @reportsOnTime.
  ///
  /// In ru, this message translates to:
  /// **'В срок'**
  String get reportsOnTime;

  /// No description provided for @reportsFirstPass.
  ///
  /// In ru, this message translates to:
  /// **'С первого раза'**
  String get reportsFirstPass;

  /// No description provided for @reportsReaction.
  ///
  /// In ru, this message translates to:
  /// **'Реакция'**
  String get reportsReaction;

  /// No description provided for @reportsExecution.
  ///
  /// In ru, this message translates to:
  /// **'Выполнение'**
  String get reportsExecution;

  /// No description provided for @reportsVisits.
  ///
  /// In ru, this message translates to:
  /// **'Визиты'**
  String get reportsVisits;

  /// No description provided for @reportsVisitsInZone.
  ///
  /// In ru, this message translates to:
  /// **'В геозоне'**
  String get reportsVisitsInZone;

  /// No description provided for @reportsVisitsSuspicious.
  ///
  /// In ru, this message translates to:
  /// **'Вне геозоны или подмена GPS'**
  String get reportsVisitsSuspicious;

  /// No description provided for @reportsOnSite.
  ///
  /// In ru, this message translates to:
  /// **'Время на объекте'**
  String get reportsOnSite;

  /// No description provided for @reportsPhotos.
  ///
  /// In ru, this message translates to:
  /// **'С фото «до» и «после»'**
  String get reportsPhotos;

  /// No description provided for @reportsVisitNorm.
  ///
  /// In ru, this message translates to:
  /// **'Визиты: факт / норма'**
  String get reportsVisitNorm;

  /// No description provided for @reportsFactNorm.
  ///
  /// In ru, this message translates to:
  /// **'{fact} / {norm}'**
  String reportsFactNorm(String fact, String norm);

  /// No description provided for @reportsNoValue.
  ///
  /// In ru, this message translates to:
  /// **'—'**
  String get reportsNoValue;

  /// No description provided for @reportsNormsMissing.
  ///
  /// In ru, this message translates to:
  /// **'Норма посещений по договору появится после обновления базы.'**
  String get reportsNormsMissing;

  /// No description provided for @reportsHelp.
  ///
  /// In ru, this message translates to:
  /// **'В срок — доля заявок, принятых не позже дедлайна, среди всех заявок с дедлайном: не в срок — принятые после дедлайна и не закрытые, у которых дедлайн прошёл; отменённые не считаются. С первого раза — принятые без возврата на доработку. Реакция — от создания заявки до «В работе», выполнение — от «В работе» до «На проверке». Норма визитов пересчитана на длину периода и округлена до целого (меньше 1 — до десятых).'**
  String get reportsHelp;

  /// No description provided for @reportsOrdersEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Заявок за период нет.'**
  String get reportsOrdersEmpty;

  /// No description provided for @reportsReturnedTimes.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{возвращали {count} раз} few{возвращали {count} раза} many{возвращали {count} раз} other{возвращали {count} раза}}'**
  String reportsReturnedTimes(int count);

  /// No description provided for @durationMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{minutes} мин'**
  String durationMinutes(String minutes);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч {minutes} мин'**
  String durationHoursMinutes(String hours, String minutes);

  /// No description provided for @durationDaysHours.
  ///
  /// In ru, this message translates to:
  /// **'{days} д {hours} ч'**
  String durationDaysHours(String days, String hours);

  /// No description provided for @visitAlreadyOpen.
  ///
  /// In ru, this message translates to:
  /// **'Посещение уже отмечено — вы на объекте. Продолжайте работу.'**
  String get visitAlreadyOpen;

  /// No description provided for @cardLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить карточку. Проверьте интернет и попробуйте ещё раз.'**
  String get cardLoadFailed;

  /// No description provided for @cardContractorOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заявки подрядчика'**
  String get cardContractorOrders;

  /// No description provided for @cardContractorReport.
  ///
  /// In ru, this message translates to:
  /// **'Отчёт'**
  String get cardContractorReport;

  /// No description provided for @cardBindingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Виды работ и объекты'**
  String get cardBindingsTitle;

  /// No description provided for @cardBindingsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Закреплений пока нет.'**
  String get cardBindingsEmpty;

  /// No description provided for @cardAllObjects.
  ///
  /// In ru, this message translates to:
  /// **'Все объекты'**
  String get cardAllObjects;

  /// No description provided for @cardNormHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на строку, чтобы изменить норму визитов.'**
  String get cardNormHint;

  /// No description provided for @cardNormNotSet.
  ///
  /// In ru, this message translates to:
  /// **'Норма визитов не задана'**
  String get cardNormNotSet;

  /// No description provided for @cardNormPerMonth.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Норма: {count} визит в месяц} few{Норма: {count} визита в месяц} many{Норма: {count} визитов в месяц} other{Норма: {count} визита в месяц}}'**
  String cardNormPerMonth(int count);

  /// No description provided for @cardNormDialogTitle.
  ///
  /// In ru, this message translates to:
  /// **'Норма визитов в месяц'**
  String get cardNormDialogTitle;

  /// No description provided for @cardNormDialogHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, 4. Пусто — без нормы'**
  String get cardNormDialogHint;

  /// No description provided for @cardNormInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Введите число от 0 до 1000'**
  String get cardNormInvalid;

  /// No description provided for @cardExecutorsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Исполнители и контакты'**
  String get cardExecutorsTitle;

  /// No description provided for @cardExecutorsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Исполнителей пока нет. Пригласите их по коду приглашения.'**
  String get cardExecutorsEmpty;

  /// No description provided for @cardCoordinates.
  ///
  /// In ru, this message translates to:
  /// **'Координаты'**
  String get cardCoordinates;

  /// No description provided for @cardCoordinatesNotSet.
  ///
  /// In ru, this message translates to:
  /// **'не заданы'**
  String get cardCoordinatesNotSet;

  /// No description provided for @cardGeofenceRadius.
  ///
  /// In ru, this message translates to:
  /// **'Радиус геозоны'**
  String get cardGeofenceRadius;

  /// No description provided for @cardMeters.
  ///
  /// In ru, this message translates to:
  /// **'{value} м'**
  String cardMeters(String value);

  /// No description provided for @cardNoCoordinatesHint.
  ///
  /// In ru, this message translates to:
  /// **'Без координат визиты на этом объекте не проверяются по геозоне.'**
  String get cardNoCoordinatesHint;

  /// No description provided for @cardEditGeo.
  ///
  /// In ru, this message translates to:
  /// **'Адрес и геозона'**
  String get cardEditGeo;

  /// No description provided for @cardLatitude.
  ///
  /// In ru, this message translates to:
  /// **'Широта'**
  String get cardLatitude;

  /// No description provided for @cardLongitude.
  ///
  /// In ru, this message translates to:
  /// **'Долгота'**
  String get cardLongitude;

  /// No description provided for @cardUseMyLocation.
  ///
  /// In ru, this message translates to:
  /// **'Взять мои координаты'**
  String get cardUseMyLocation;

  /// No description provided for @cardLocationFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить местоположение. Включите геолокацию и разрешите её приложению.'**
  String get cardLocationFailed;

  /// No description provided for @cardGeofenceRadiusInput.
  ///
  /// In ru, this message translates to:
  /// **'Радиус геозоны, м (20–5000)'**
  String get cardGeofenceRadiusInput;

  /// No description provided for @cardCoordinatesBoth.
  ///
  /// In ru, this message translates to:
  /// **'Укажите и широту, и долготу — или оставьте обе пустыми.'**
  String get cardCoordinatesBoth;

  /// No description provided for @cardCoordinatesInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте координаты: широта от −90 до 90, долгота от −180 до 180.'**
  String get cardCoordinatesInvalid;

  /// No description provided for @cardRadiusInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Радиус — целое число от 20 до 5000 м.'**
  String get cardRadiusInvalid;

  /// No description provided for @cardPlacesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Помещения'**
  String get cardPlacesTitle;

  /// No description provided for @cardPlacesEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Помещений пока нет.'**
  String get cardPlacesEmpty;

  /// No description provided for @cardObjectContractorsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подрядчики по видам работ'**
  String get cardObjectContractorsTitle;

  /// No description provided for @cardRecentOrders.
  ///
  /// In ru, this message translates to:
  /// **'Последние заявки'**
  String get cardRecentOrders;

  /// No description provided for @cardOrdersEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Заявок пока нет.'**
  String get cardOrdersEmpty;

  /// No description provided for @cardAllObjectOrders.
  ///
  /// In ru, this message translates to:
  /// **'Все заявки по объекту'**
  String get cardAllObjectOrders;

  /// No description provided for @historyLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить историю. Проверьте интернет и попробуйте ещё раз.'**
  String get historyLoadFailed;

  /// No description provided for @historyDoneInPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Выполнено за период: {count}'**
  String historyDoneInPeriod(int count);

  /// No description provided for @historyEmpty.
  ///
  /// In ru, this message translates to:
  /// **'За этот период завершённых заявок нет.'**
  String get historyEmpty;

  /// No description provided for @historyAcceptedAt.
  ///
  /// In ru, this message translates to:
  /// **'Принята {date}'**
  String historyAcceptedAt(String date);

  /// No description provided for @historyCancelledAt.
  ///
  /// In ru, this message translates to:
  /// **'Отменена {date}'**
  String historyCancelledAt(String date);

  /// No description provided for @historyExecution.
  ///
  /// In ru, this message translates to:
  /// **'Выполнение: {time}'**
  String historyExecution(String time);

  /// No description provided for @historyExecutor.
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель: {name}'**
  String historyExecutor(String name);

  /// No description provided for @historyVisitInGeofence.
  ///
  /// In ru, this message translates to:
  /// **'Визит в геозоне ✓'**
  String get historyVisitInGeofence;

  /// No description provided for @historyVisitOutside.
  ///
  /// In ru, this message translates to:
  /// **'Визит вне геозоны или с подменой GPS'**
  String get historyVisitOutside;

  /// No description provided for @reportsPeriod30.
  ///
  /// In ru, this message translates to:
  /// **'30 дней'**
  String get reportsPeriod30;

  /// No description provided for @companyNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Компания'**
  String get companyNameLabel;

  /// No description provided for @companyRenameTitle.
  ///
  /// In ru, this message translates to:
  /// **'Название компании'**
  String get companyRenameTitle;

  /// No description provided for @companyRenamed.
  ///
  /// In ru, this message translates to:
  /// **'Название сохранено'**
  String get companyRenamed;

  /// No description provided for @companyRenameUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Название пока нельзя изменить: нужно обновить базу. Сообщите администратору.'**
  String get companyRenameUnavailable;

  /// No description provided for @companyLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить данные компании. Проверьте интернет.'**
  String get companyLoadFailed;

  /// No description provided for @companyMembers.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудники: {count}'**
  String companyMembers(int count);

  /// No description provided for @companyMemberYou.
  ///
  /// In ru, this message translates to:
  /// **'{name} (вы)'**
  String companyMemberYou(String name);

  /// No description provided for @companyNoPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон не указан'**
  String get companyNoPhone;

  /// No description provided for @companyRoleChange.
  ///
  /// In ru, this message translates to:
  /// **'Изменить роль'**
  String get companyRoleChange;

  /// No description provided for @companyRoleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Роль: {name}'**
  String companyRoleTitle(String name);

  /// No description provided for @companyRoleExecutorHint.
  ///
  /// In ru, this message translates to:
  /// **'Чтобы исполнитель видел заявки, его нужно привязать к подрядчику — через приглашение.'**
  String get companyRoleExecutorHint;

  /// No description provided for @companyRoleChanged.
  ///
  /// In ru, this message translates to:
  /// **'Роль изменена'**
  String get companyRoleChanged;

  /// No description provided for @companyInvites.
  ///
  /// In ru, this message translates to:
  /// **'Приглашения'**
  String get companyInvites;

  /// No description provided for @companyInvite.
  ///
  /// In ru, this message translates to:
  /// **'Пригласить'**
  String get companyInvite;

  /// No description provided for @companyNoInvites.
  ///
  /// In ru, this message translates to:
  /// **'Активных приглашений нет.'**
  String get companyNoInvites;

  /// No description provided for @companyInviteRow.
  ///
  /// In ru, this message translates to:
  /// **'{contractor} · до {date}'**
  String companyInviteRow(String contractor, String date);

  /// No description provided for @companyDirectory.
  ///
  /// In ru, this message translates to:
  /// **'Справочники'**
  String get companyDirectory;

  /// No description provided for @inviteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пригласить исполнителя'**
  String get inviteTitle;

  /// No description provided for @inviteContractor.
  ///
  /// In ru, this message translates to:
  /// **'Подрядчик'**
  String get inviteContractor;

  /// No description provided for @inviteRoleInfo.
  ///
  /// In ru, this message translates to:
  /// **'Роль: исполнитель этого подрядчика. Он увидит заявки подрядчика и сможет их выполнять. Другую роль можно назначить потом в списке сотрудников.'**
  String get inviteRoleInfo;

  /// No description provided for @inviteValidity.
  ///
  /// In ru, this message translates to:
  /// **'Срок действия'**
  String get inviteValidity;

  /// No description provided for @inviteDays.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} день} few{{count} дня} other{{count} дней}}'**
  String inviteDays(int count);

  /// No description provided for @inviteCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get inviteCreate;

  /// No description provided for @inviteFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось создать приглашение. Попробуйте ещё раз.'**
  String get inviteFailed;

  /// No description provided for @inviteNoContractors.
  ///
  /// In ru, this message translates to:
  /// **'Сначала добавьте подрядчика на вкладке «Подрядчики».'**
  String get inviteNoContractors;

  /// No description provided for @inviteReadyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Приглашение в «{contractor}»'**
  String inviteReadyTitle(String contractor);

  /// No description provided for @inviteValidUntil.
  ///
  /// In ru, this message translates to:
  /// **'Действует до {date}, один раз'**
  String inviteValidUntil(String date);

  /// No description provided for @inviteCodeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код'**
  String get inviteCodeLabel;

  /// No description provided for @inviteLinkLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка (веб-версия)'**
  String get inviteLinkLabel;

  /// No description provided for @inviteHowTo.
  ///
  /// In ru, this message translates to:
  /// **'Новый сотрудник регистрируется в приложении и вводит код в блоке «У меня есть код приглашения». По ссылке на сайте код подставится сам.'**
  String get inviteHowTo;

  /// No description provided for @inviteCopyMessage.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать приглашение'**
  String get inviteCopyMessage;

  /// No description provided for @inviteCopyCode.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать код'**
  String get inviteCopyCode;

  /// No description provided for @inviteCopied.
  ///
  /// In ru, this message translates to:
  /// **'Приглашение скопировано — отправьте его в мессенджере'**
  String get inviteCopied;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In ru, this message translates to:
  /// **'Код скопирован'**
  String get inviteCodeCopied;

  /// No description provided for @inviteRevoke.
  ///
  /// In ru, this message translates to:
  /// **'Отозвать приглашение'**
  String get inviteRevoke;

  /// No description provided for @inviteRevoked.
  ///
  /// In ru, this message translates to:
  /// **'Приглашение отозвано'**
  String get inviteRevoked;

  /// No description provided for @inviteMessage.
  ///
  /// In ru, this message translates to:
  /// **'Вас приглашают в {app} как исполнителя «{contractor}».\nОткройте ссылку: {link}\nили установите приложение и введите код: {code}\nДействует до {date}.'**
  String inviteMessage(
      String app, String contractor, String link, String code, String date);

  /// No description provided for @settingsProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get settingsProfile;

  /// No description provided for @settingsName.
  ///
  /// In ru, this message translates to:
  /// **'Имя и фамилия'**
  String get settingsName;

  /// No description provided for @settingsPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get settingsPhone;

  /// No description provided for @settingsPhoneHint.
  ///
  /// In ru, this message translates to:
  /// **'+7 900 000-00-00'**
  String get settingsPhoneHint;

  /// No description provided for @settingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get settingsSaved;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить. Проверьте интернет и попробуйте ещё раз.'**
  String get settingsSaveFailed;

  /// No description provided for @settingsPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get settingsPassword;

  /// No description provided for @settingsNewPassword.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль'**
  String get settingsNewPassword;

  /// No description provided for @settingsRepeatPassword.
  ///
  /// In ru, this message translates to:
  /// **'Повторите пароль'**
  String get settingsRepeatPassword;

  /// No description provided for @settingsChangePassword.
  ///
  /// In ru, this message translates to:
  /// **'Сменить пароль'**
  String get settingsChangePassword;

  /// No description provided for @settingsPasswordShort.
  ///
  /// In ru, this message translates to:
  /// **'Пароль — не короче {count} символов'**
  String settingsPasswordShort(int count);

  /// No description provided for @settingsPasswordMismatch.
  ///
  /// In ru, this message translates to:
  /// **'Пароли не совпадают'**
  String get settingsPasswordMismatch;

  /// No description provided for @settingsPasswordChanged.
  ///
  /// In ru, this message translates to:
  /// **'Пароль изменён'**
  String get settingsPasswordChanged;

  /// No description provided for @settingsPasswordFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сменить пароль. Возможно, он совпадает со старым или слишком простой.'**
  String get settingsPasswordFailed;

  /// No description provided for @settingsAbout.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get settingsAbout;

  /// No description provided for @settingsAboutApp.
  ///
  /// In ru, this message translates to:
  /// **'О приложении {app}'**
  String settingsAboutApp(String app);

  /// No description provided for @settingsVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version} (сборка {build})'**
  String settingsVersion(String version, String build);

  /// No description provided for @settingsAboutText.
  ///
  /// In ru, this message translates to:
  /// **'{app} — сервис эксплуатации зданий: приём заявок текстом, голосом и с фото, отправка подрядчику, контроль визитов и приёмка работ.'**
  String settingsAboutText(String app);

  /// No description provided for @notifPeriod.
  ///
  /// In ru, this message translates to:
  /// **'За последние {days} дней'**
  String notifPeriod(int days);

  /// No description provided for @notifEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Новых событий нет'**
  String get notifEmpty;

  /// No description provided for @notifLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить уведомления. Проверьте интернет.'**
  String get notifLoadFailed;

  /// No description provided for @notifAssigned.
  ///
  /// In ru, this message translates to:
  /// **'Новая заявка для вашего подрядчика'**
  String get notifAssigned;

  /// No description provided for @notifReturned.
  ///
  /// In ru, this message translates to:
  /// **'Работу вернули на доработку'**
  String get notifReturned;

  /// No description provided for @notifOnReview.
  ///
  /// In ru, this message translates to:
  /// **'Работа ждёт приёмки'**
  String get notifOnReview;

  /// No description provided for @notifOverdue.
  ///
  /// In ru, this message translates to:
  /// **'Срок прошёл, заявка не закрыта'**
  String get notifOverdue;

  /// No description provided for @notifVisitOutside.
  ///
  /// In ru, this message translates to:
  /// **'Визит вне геозоны'**
  String get notifVisitOutside;

  /// No description provided for @notifVisitOutsideM.
  ///
  /// In ru, this message translates to:
  /// **'Визит вне геозоны: {meters} м от объекта'**
  String notifVisitOutsideM(String meters);

  /// No description provided for @notifVisitMock.
  ///
  /// In ru, this message translates to:
  /// **'Визит с подменой GPS'**
  String get notifVisitMock;

  /// No description provided for @notifInProgress.
  ///
  /// In ru, this message translates to:
  /// **'Вашу заявку взяли в работу'**
  String get notifInProgress;

  /// No description provided for @notifAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Работа по вашей заявке принята'**
  String get notifAccepted;

  /// No description provided for @notifBellTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления: новых {count}'**
  String notifBellTooltip(int count);

  /// No description provided for @assignSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск подрядчика'**
  String get assignSearch;

  /// No description provided for @assignBound.
  ///
  /// In ru, this message translates to:
  /// **'Закреплены за этим видом работ'**
  String get assignBound;

  /// No description provided for @assignOthers.
  ///
  /// In ru, this message translates to:
  /// **'Другие подрядчики'**
  String get assignOthers;

  /// No description provided for @assignAll.
  ///
  /// In ru, this message translates to:
  /// **'Подрядчики'**
  String get assignAll;

  /// No description provided for @assignNobodyBound.
  ///
  /// In ru, this message translates to:
  /// **'За «{layer}» никто не закреплён — выберите вручную или закрепите в карточке подрядчика'**
  String assignNobodyBound(String layer);

  /// No description provided for @assignNoLayer.
  ///
  /// In ru, this message translates to:
  /// **'Вид работ не указан — выберите подрядчика вручную'**
  String get assignNoLayer;

  /// No description provided for @assignNothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get assignNothingFound;

  /// No description provided for @assignBindingsFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить закрепления — список без подсказок.'**
  String get assignBindingsFailed;

  /// No description provided for @assignExecutors.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Исполнителей нет} one{{count} исполнитель} few{{count} исполнителя} other{{count} исполнителей}}'**
  String assignExecutors(int count);

  /// No description provided for @assignNorm.
  ///
  /// In ru, this message translates to:
  /// **'норма {count} в мес.'**
  String assignNorm(int count);

  /// No description provided for @assignAllObjects.
  ///
  /// In ru, this message translates to:
  /// **'все объекты'**
  String get assignAllObjects;

  /// No description provided for @assignCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Назначен сейчас'**
  String get assignCurrent;

  /// No description provided for @assignInline.
  ///
  /// In ru, this message translates to:
  /// **'Назначить'**
  String get assignInline;

  /// No description provided for @assignChangeInline.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get assignChangeInline;

  /// No description provided for @toastAssignedTo.
  ///
  /// In ru, this message translates to:
  /// **'Назначено: {name}'**
  String toastAssignedTo(String name);

  /// No description provided for @fieldExecutor.
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель'**
  String get fieldExecutor;

  /// No description provided for @voiceNetworkWeb.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервисом распознавания речи браузера. Проверьте интернет и нажмите «Ещё раз» — или введите заявку текстом.'**
  String get voiceNetworkWeb;

  /// No description provided for @voiceMicFailedWeb.
  ///
  /// In ru, this message translates to:
  /// **'Браузер не получает звук с микрофона. Проверьте, какой микрофон выбран: chrome://settings/content/microphone (в Edge — edge://settings/content/microphone), и нажмите «Ещё раз».'**
  String get voiceMicFailedWeb;

  /// No description provided for @voiceErrorCode.
  ///
  /// In ru, this message translates to:
  /// **'код: {code}'**
  String voiceErrorCode(String code);

  /// No description provided for @voiceMicSilent.
  ///
  /// In ru, this message translates to:
  /// **'Микрофон не слышит звук — проверьте, какой микрофон выбран'**
  String get voiceMicSilent;

  /// No description provided for @voiceBrowserHint.
  ///
  /// In ru, this message translates to:
  /// **'Для голосового ввода лучше открыть в Google Chrome или Microsoft Edge'**
  String get voiceBrowserHint;

  /// No description provided for @detailMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get detailMore;

  /// No description provided for @actionDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get actionDelete;

  /// No description provided for @deleteOrderConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить заявку безвозвратно? История, фото и отчёты по ней исчезнут. Если работа просто не нужна — лучше «Отменить».'**
  String get deleteOrderConfirm;

  /// No description provided for @toastDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Заявка удалена'**
  String get toastDeleted;

  /// No description provided for @deleteOrderDenied.
  ///
  /// In ru, this message translates to:
  /// **'Удалять заявки может только менеджер. Заявка не удалена.'**
  String get deleteOrderDenied;

  /// No description provided for @deleteOrderFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить заявку. Проверьте интернет и попробуйте ещё раз.'**
  String get deleteOrderFailed;

  /// No description provided for @mapViewList.
  ///
  /// In ru, this message translates to:
  /// **'Список'**
  String get mapViewList;

  /// No description provided for @mapViewMap.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get mapViewMap;

  /// No description provided for @mapZoomIn.
  ///
  /// In ru, this message translates to:
  /// **'Приблизить'**
  String get mapZoomIn;

  /// No description provided for @mapZoomOut.
  ///
  /// In ru, this message translates to:
  /// **'Отдалить'**
  String get mapZoomOut;

  /// No description provided for @mapFitAll.
  ///
  /// In ru, this message translates to:
  /// **'Показать все объекты'**
  String get mapFitAll;

  /// No description provided for @mapMyLocation.
  ///
  /// In ru, this message translates to:
  /// **'Где я'**
  String get mapMyLocation;

  /// No description provided for @mapMyLocationFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить, где вы. Включите геолокацию и разрешите её приложению.'**
  String get mapMyLocationFailed;

  /// No description provided for @mapSelectArea.
  ///
  /// In ru, this message translates to:
  /// **'Выделить область'**
  String get mapSelectArea;

  /// No description provided for @mapSelectAreaHint.
  ///
  /// In ru, this message translates to:
  /// **'Протяните рамку по карте'**
  String get mapSelectAreaHint;

  /// No description provided for @mapSearchHere.
  ///
  /// In ru, this message translates to:
  /// **'Искать в этой области'**
  String get mapSearchHere;

  /// No description provided for @mapInArea.
  ///
  /// In ru, this message translates to:
  /// **'В области: {count, plural, =0{нет объектов} one{{count} объект} few{{count} объекта} many{{count} объектов} other{{count} объекта}}'**
  String mapInArea(int count);

  /// No description provided for @mapInRect.
  ///
  /// In ru, this message translates to:
  /// **'В выделенной области: {count, plural, =0{нет объектов} one{{count} объект} few{{count} объекта} many{{count} объектов} other{{count} объекта}}'**
  String mapInRect(int count);

  /// No description provided for @mapNearby.
  ///
  /// In ru, this message translates to:
  /// **'Рядом, до {radius}: {count, plural, =0{нет объектов} one{{count} объект} few{{count} объекта} many{{count} объектов} other{{count} объекта}}'**
  String mapNearby(int count, String radius);

  /// No description provided for @mapReset.
  ///
  /// In ru, this message translates to:
  /// **'сбросить'**
  String get mapReset;

  /// No description provided for @mapNearbyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Объекты рядом'**
  String get mapNearbyTitle;

  /// No description provided for @mapKm.
  ///
  /// In ru, this message translates to:
  /// **'{value} км'**
  String mapKm(String value);

  /// No description provided for @mapNearbyHelp.
  ///
  /// In ru, this message translates to:
  /// **'Правый клик или долгое нажатие на карте — объекты рядом. Shift + перетаскивание — выделить область.'**
  String get mapNearbyHelp;

  /// No description provided for @mapNoCoordinates.
  ///
  /// In ru, this message translates to:
  /// **'Без места на карте ({count})'**
  String mapNoCoordinates(int count);

  /// No description provided for @mapSetOnMap.
  ///
  /// In ru, this message translates to:
  /// **'Указать на карте'**
  String get mapSetOnMap;

  /// No description provided for @mapMoveOnMap.
  ///
  /// In ru, this message translates to:
  /// **'Изменить место на карте'**
  String get mapMoveOnMap;

  /// No description provided for @mapPlaceHint.
  ///
  /// In ru, this message translates to:
  /// **'Передвиньте карту: перекрестие — на «{name}»'**
  String mapPlaceHint(String name);

  /// No description provided for @mapSaveHere.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить здесь'**
  String get mapSaveHere;

  /// No description provided for @mapPlaceSaved.
  ///
  /// In ru, this message translates to:
  /// **'Место на карте сохранено'**
  String get mapPlaceSaved;

  /// No description provided for @mapOpenObject.
  ///
  /// In ru, this message translates to:
  /// **'Открыть объект'**
  String get mapOpenObject;

  /// No description provided for @mapOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заявки'**
  String get mapOrders;

  /// No description provided for @mapCreateHere.
  ///
  /// In ru, this message translates to:
  /// **'Создать заявку здесь'**
  String get mapCreateHere;

  /// No description provided for @mapCountNew.
  ///
  /// In ru, this message translates to:
  /// **'Новые'**
  String get mapCountNew;

  /// No description provided for @mapCountInWork.
  ///
  /// In ru, this message translates to:
  /// **'В работе'**
  String get mapCountInWork;

  /// No description provided for @mapCountOnReview.
  ///
  /// In ru, this message translates to:
  /// **'На проверке'**
  String get mapCountOnReview;

  /// No description provided for @mapCountOverdue.
  ///
  /// In ru, this message translates to:
  /// **'Просрочено'**
  String get mapCountOverdue;

  /// No description provided for @mapOpenOrders.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Открытых заявок нет} one{{count} открытая заявка} few{{count} открытые заявки} many{{count} открытых заявок} other{{count} открытой заявки}}'**
  String mapOpenOrders(int count);

  /// No description provided for @mapSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по названию и адресу'**
  String get mapSearchHint;

  /// No description provided for @mapNothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get mapNothingFound;

  /// No description provided for @mapListTitle.
  ///
  /// In ru, this message translates to:
  /// **'Объекты на карте ({count})'**
  String mapListTitle(int count);

  /// No description provided for @mapOrdersFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить заявки — числа на маркерах могут быть неточными.'**
  String get mapOrdersFailed;

  /// No description provided for @mapClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get mapClose;

  /// No description provided for @mapCluster.
  ///
  /// In ru, this message translates to:
  /// **'Объектов: {count}. Нажмите, чтобы приблизить'**
  String mapCluster(int count);

  /// No description provided for @requestsFilterObject.
  ///
  /// In ru, this message translates to:
  /// **'Объект: {name}'**
  String requestsFilterObject(String name);

  /// No description provided for @requestsFilterClear.
  ///
  /// In ru, this message translates to:
  /// **'Снять фильтр'**
  String get requestsFilterClear;

  /// No description provided for @reqSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по заявкам'**
  String get reqSearchHint;

  /// No description provided for @reqSegAll.
  ///
  /// In ru, this message translates to:
  /// **'Все · {count}'**
  String reqSegAll(String count);

  /// No description provided for @reqSegOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открытые · {count}'**
  String reqSegOpen(String count);

  /// No description provided for @reqSegOverdue.
  ///
  /// In ru, this message translates to:
  /// **'Просрочено · {count}'**
  String reqSegOverdue(String count);

  /// No description provided for @reqSegOf.
  ///
  /// In ru, this message translates to:
  /// **'{shown} из {total}'**
  String reqSegOf(int shown, int total);

  /// No description provided for @reqSearchShort.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get reqSearchShort;

  /// No description provided for @reqGroupToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get reqGroupToday;

  /// No description provided for @reqGroupEarlier.
  ///
  /// In ru, this message translates to:
  /// **'Ранее'**
  String get reqGroupEarlier;

  /// No description provided for @reqNothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get reqNothingFound;

  /// No description provided for @reqFieldPlace.
  ///
  /// In ru, this message translates to:
  /// **'Помещение'**
  String get reqFieldPlace;

  /// No description provided for @reqFieldDue.
  ///
  /// In ru, this message translates to:
  /// **'Срок'**
  String get reqFieldDue;

  /// No description provided for @reqViaVoice.
  ///
  /// In ru, this message translates to:
  /// **'голосом'**
  String get reqViaVoice;

  /// No description provided for @reqViaText.
  ///
  /// In ru, this message translates to:
  /// **'текстом'**
  String get reqViaText;

  /// No description provided for @filterPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Период'**
  String get filterPeriod;

  /// No description provided for @filterObject.
  ///
  /// In ru, this message translates to:
  /// **'Объект'**
  String get filterObject;

  /// No description provided for @filterRoom.
  ///
  /// In ru, this message translates to:
  /// **'Помещение'**
  String get filterRoom;

  /// No description provided for @filterContractor.
  ///
  /// In ru, this message translates to:
  /// **'Подрядчик'**
  String get filterContractor;

  /// No description provided for @filterPriority.
  ///
  /// In ru, this message translates to:
  /// **'Срочность'**
  String get filterPriority;

  /// No description provided for @filterStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get filterStatus;

  /// No description provided for @filterWorkType.
  ///
  /// In ru, this message translates to:
  /// **'Вид работ'**
  String get filterWorkType;

  /// No description provided for @filterMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get filterMore;

  /// No description provided for @filterSort.
  ///
  /// In ru, this message translates to:
  /// **'Сортировка'**
  String get filterSort;

  /// No description provided for @filterPeriodToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get filterPeriodToday;

  /// No description provided for @filterPeriod7.
  ///
  /// In ru, this message translates to:
  /// **'7 дней'**
  String get filterPeriod7;

  /// No description provided for @filterPeriod30.
  ///
  /// In ru, this message translates to:
  /// **'30 дней'**
  String get filterPeriod30;

  /// No description provided for @filterPeriodThisMonth.
  ///
  /// In ru, this message translates to:
  /// **'Этот месяц'**
  String get filterPeriodThisMonth;

  /// No description provided for @filterPeriodLastMonth.
  ///
  /// In ru, this message translates to:
  /// **'Прошлый месяц'**
  String get filterPeriodLastMonth;

  /// No description provided for @filterPeriodCustom.
  ///
  /// In ru, this message translates to:
  /// **'Свой период…'**
  String get filterPeriodCustom;

  /// No description provided for @filterByCreated.
  ///
  /// In ru, this message translates to:
  /// **'По дате создания'**
  String get filterByCreated;

  /// No description provided for @filterByDue.
  ///
  /// In ru, this message translates to:
  /// **'По сроку'**
  String get filterByDue;

  /// No description provided for @filterDueLabel.
  ///
  /// In ru, this message translates to:
  /// **'Срок: {period}'**
  String filterDueLabel(String period);

  /// No description provided for @filterNoContractor.
  ///
  /// In ru, this message translates to:
  /// **'Без подрядчика'**
  String get filterNoContractor;

  /// No description provided for @filterOverdue.
  ///
  /// In ru, this message translates to:
  /// **'Просрочено'**
  String get filterOverdue;

  /// No description provided for @filterType.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get filterType;

  /// No description provided for @filterOnce.
  ///
  /// In ru, this message translates to:
  /// **'Разовая'**
  String get filterOnce;

  /// No description provided for @filterRecurring.
  ///
  /// In ru, this message translates to:
  /// **'Повторяющаяся'**
  String get filterRecurring;

  /// No description provided for @filterSource.
  ///
  /// In ru, this message translates to:
  /// **'Источник'**
  String get filterSource;

  /// No description provided for @filterChannelVoice.
  ///
  /// In ru, this message translates to:
  /// **'Голос'**
  String get filterChannelVoice;

  /// No description provided for @filterChannelText.
  ///
  /// In ru, this message translates to:
  /// **'Текст'**
  String get filterChannelText;

  /// No description provided for @filterChannelButton.
  ///
  /// In ru, this message translates to:
  /// **'Вручную'**
  String get filterChannelButton;

  /// No description provided for @filterOptions.
  ///
  /// In ru, this message translates to:
  /// **'Условия'**
  String get filterOptions;

  /// No description provided for @filterNeedsPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Нужно фото'**
  String get filterNeedsPhoto;

  /// No description provided for @filterReturned.
  ///
  /// In ru, this message translates to:
  /// **'Возвращались на доработку'**
  String get filterReturned;

  /// No description provided for @filterCreatedByMe.
  ///
  /// In ru, this message translates to:
  /// **'Создал я'**
  String get filterCreatedByMe;

  /// No description provided for @filterAssignedToMe.
  ///
  /// In ru, this message translates to:
  /// **'Назначено мне'**
  String get filterAssignedToMe;

  /// No description provided for @filterMoreCount.
  ///
  /// In ru, this message translates to:
  /// **'Ещё · {count}'**
  String filterMoreCount(int count);

  /// No description provided for @filterPlus.
  ///
  /// In ru, this message translates to:
  /// **'{label} +{count}'**
  String filterPlus(String label, int count);

  /// No description provided for @sortNewest.
  ///
  /// In ru, this message translates to:
  /// **'Сначала новые'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In ru, this message translates to:
  /// **'Сначала старые'**
  String get sortOldest;

  /// No description provided for @sortDue.
  ///
  /// In ru, this message translates to:
  /// **'По сроку'**
  String get sortDue;

  /// No description provided for @sortPriority.
  ///
  /// In ru, this message translates to:
  /// **'По срочности'**
  String get sortPriority;

  /// No description provided for @sortStatus.
  ///
  /// In ru, this message translates to:
  /// **'По статусу'**
  String get sortStatus;

  /// No description provided for @sortObject.
  ///
  /// In ru, this message translates to:
  /// **'По объекту'**
  String get sortObject;

  /// No description provided for @filterReset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get filterReset;

  /// No description provided for @filterApply.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get filterApply;

  /// No description provided for @filterApplyCount.
  ///
  /// In ru, this message translates to:
  /// **'Применить ({count})'**
  String filterApplyCount(int count);

  /// No description provided for @filterResetAll.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить всё'**
  String get filterResetAll;

  /// No description provided for @filterFound.
  ///
  /// In ru, this message translates to:
  /// **'Найдено {shown} из {total}'**
  String filterFound(int shown, int total);

  /// No description provided for @filterResetFilters.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить фильтры'**
  String get filterResetFilters;

  /// No description provided for @filterSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по списку'**
  String get filterSearchHint;

  /// No description provided for @filterClearOne.
  ///
  /// In ru, this message translates to:
  /// **'Убрать фильтр «{name}»'**
  String filterClearOne(String name);

  /// No description provided for @filterRange.
  ///
  /// In ru, this message translates to:
  /// **'{from} – {to}'**
  String filterRange(String from, String to);

  /// No description provided for @filterPickDates.
  ///
  /// In ru, this message translates to:
  /// **'Выберите даты'**
  String get filterPickDates;

  /// No description provided for @cityNone.
  ///
  /// In ru, this message translates to:
  /// **'Без города'**
  String get cityNone;

  /// No description provided for @cityCount.
  ///
  /// In ru, this message translates to:
  /// **'{city} · {count}'**
  String cityCount(String city, int count);

  /// No description provided for @cityAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get cityAll;

  /// No description provided for @filterCityAll.
  ///
  /// In ru, this message translates to:
  /// **'Весь город'**
  String get filterCityAll;

  /// No description provided for @filterCityWhole.
  ///
  /// In ru, this message translates to:
  /// **'{city} ({count})'**
  String filterCityWhole(String city, int count);

  /// No description provided for @objectsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} объект} few{{count} объекта} many{{count} объектов} other{{count} объекта}}'**
  String objectsCount(int count);

  /// No description provided for @contractorCoverage.
  ///
  /// In ru, this message translates to:
  /// **'{cities} · {objects}'**
  String contractorCoverage(String cities, String objects);

  /// No description provided for @cardWorkTypes.
  ///
  /// In ru, this message translates to:
  /// **'Виды работ'**
  String get cardWorkTypes;

  /// No description provided for @cardObjectsByCity.
  ///
  /// In ru, this message translates to:
  /// **'Объекты'**
  String get cardObjectsByCity;

  /// No description provided for @mapCityZoom.
  ///
  /// In ru, this message translates to:
  /// **'Показать город {city}'**
  String mapCityZoom(String city);

  /// No description provided for @filterAll.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get filterAll;

  /// No description provided for @filterAllCount.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры · {count}'**
  String filterAllCount(int count);

  /// No description provided for @filterAllWide.
  ///
  /// In ru, this message translates to:
  /// **'Все фильтры'**
  String get filterAllWide;

  /// No description provided for @filterAllWideCount.
  ///
  /// In ru, this message translates to:
  /// **'Все фильтры · {count}'**
  String filterAllWideCount(int count);

  /// No description provided for @filterAny.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get filterAny;

  /// No description provided for @filterShow.
  ///
  /// In ru, this message translates to:
  /// **'Показать'**
  String get filterShow;

  /// No description provided for @filterShowCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Нет заявок} one{Показать {count} заявку} few{Показать {count} заявки} other{Показать {count} заявок}}'**
  String filterShowCount(int count);

  /// No description provided for @commonClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get commonClose;

  /// No description provided for @commonGotIt.
  ///
  /// In ru, this message translates to:
  /// **'Понятно'**
  String get commonGotIt;

  /// No description provided for @infoFiltersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Как работают фильтры'**
  String get infoFiltersTitle;

  /// No description provided for @infoFilters1.
  ///
  /// In ru, this message translates to:
  /// **'Выберите условия — на кнопке внизу сразу видно, сколько заявок подойдёт.'**
  String get infoFilters1;

  /// No description provided for @infoFilters2.
  ///
  /// In ru, this message translates to:
  /// **'«Показать» применяет фильтры, «×» на таблетке над списком снимает один фильтр.'**
  String get infoFilters2;

  /// No description provided for @infoFilters3.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры запоминаются на этом устройстве, а в браузере — ещё и в адресе страницы: ссылку можно отправить коллеге.'**
  String get infoFilters3;

  /// No description provided for @infoShowHint.
  ///
  /// In ru, this message translates to:
  /// **'Подсказка: {title}'**
  String infoShowHint(String title);

  /// No description provided for @sortShortNewest.
  ///
  /// In ru, this message translates to:
  /// **'Новые'**
  String get sortShortNewest;

  /// No description provided for @sortShortOldest.
  ///
  /// In ru, this message translates to:
  /// **'Старые'**
  String get sortShortOldest;

  /// No description provided for @sortShortDue.
  ///
  /// In ru, this message translates to:
  /// **'Срок'**
  String get sortShortDue;

  /// No description provided for @sortShortPriority.
  ///
  /// In ru, this message translates to:
  /// **'Срочность'**
  String get sortShortPriority;

  /// No description provided for @sortShortStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get sortShortStatus;

  /// No description provided for @sortShortObject.
  ///
  /// In ru, this message translates to:
  /// **'Объект'**
  String get sortShortObject;

  /// No description provided for @floorsHeader.
  ///
  /// In ru, this message translates to:
  /// **'Этажи'**
  String get floorsHeader;

  /// No description provided for @floorsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Этажи · {count}'**
  String floorsTitle(int count);

  /// No description provided for @floorsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Этажей пока нет'**
  String get floorsEmpty;

  /// No description provided for @floorsEmptyManager.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте этаж и загрузите план — на нём можно будет отметить помещения и оборудование.'**
  String get floorsEmptyManager;

  /// No description provided for @floorAdd.
  ///
  /// In ru, this message translates to:
  /// **'Этаж'**
  String get floorAdd;

  /// No description provided for @floorAddLong.
  ///
  /// In ru, this message translates to:
  /// **'Добавить этаж'**
  String get floorAddLong;

  /// No description provided for @floorPlacesCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} помещение} few{{count} помещения} other{{count} помещений}}'**
  String floorPlacesCount(int count);

  /// No description provided for @floorOpenOrders.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{нет открытых заявок} one{{count} открытая заявка} few{{count} открытые заявки} other{{count} открытых заявок}}'**
  String floorOpenOrders(int count);

  /// No description provided for @floorNoPlan.
  ///
  /// In ru, this message translates to:
  /// **'Без плана'**
  String get floorNoPlan;

  /// No description provided for @floorFormNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый этаж'**
  String get floorFormNew;

  /// No description provided for @floorFormEdit.
  ///
  /// In ru, this message translates to:
  /// **'Этаж'**
  String get floorFormEdit;

  /// No description provided for @floorName.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get floorName;

  /// No description provided for @floorNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, 3 этаж или Парковка'**
  String get floorNameHint;

  /// No description provided for @floorLevel.
  ///
  /// In ru, this message translates to:
  /// **'Номер этажа'**
  String get floorLevel;

  /// No description provided for @floorLevelHint.
  ///
  /// In ru, this message translates to:
  /// **'−1, −2 — подземные этажи'**
  String get floorLevelHint;

  /// No description provided for @floorPlanImage.
  ///
  /// In ru, this message translates to:
  /// **'Картинка плана'**
  String get floorPlanImage;

  /// No description provided for @floorPlanPick.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать файл'**
  String get floorPlanPick;

  /// No description provided for @floorPlanOptional.
  ///
  /// In ru, this message translates to:
  /// **'Необязательно — план можно загрузить позже.'**
  String get floorPlanOptional;

  /// No description provided for @floorNameEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Введите название этажа'**
  String get floorNameEmpty;

  /// No description provided for @floorNameTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Название — не длиннее 60 символов'**
  String get floorNameTooLong;

  /// No description provided for @floorNameTaken.
  ///
  /// In ru, this message translates to:
  /// **'Этаж с таким названием уже есть'**
  String get floorNameTaken;

  /// No description provided for @floorLevelInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Номер этажа — целое число, например 3 или −1'**
  String get floorLevelInvalid;

  /// No description provided for @floorRename.
  ///
  /// In ru, this message translates to:
  /// **'Переименовать'**
  String get floorRename;

  /// No description provided for @floorUploadPlan.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить план'**
  String get floorUploadPlan;

  /// No description provided for @floorReplacePlan.
  ///
  /// In ru, this message translates to:
  /// **'Заменить план'**
  String get floorReplacePlan;

  /// No description provided for @floorRemovePlan.
  ///
  /// In ru, this message translates to:
  /// **'Убрать план'**
  String get floorRemovePlan;

  /// No description provided for @floorMoveUp.
  ///
  /// In ru, this message translates to:
  /// **'Выше'**
  String get floorMoveUp;

  /// No description provided for @floorMoveDown.
  ///
  /// In ru, this message translates to:
  /// **'Ниже'**
  String get floorMoveDown;

  /// No description provided for @floorDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить этаж'**
  String get floorDelete;

  /// No description provided for @floorDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить этаж «{name}»?'**
  String floorDeleteConfirm(String name);

  /// No description provided for @floorDeleteHint.
  ///
  /// In ru, this message translates to:
  /// **'Помещения и оборудование останутся, но уйдут с плана.'**
  String get floorDeleteHint;

  /// No description provided for @floorDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Этаж удалён'**
  String get floorDeleted;

  /// No description provided for @floorAddPlace.
  ///
  /// In ru, this message translates to:
  /// **'Добавить помещение на этаж «{name}»'**
  String floorAddPlace(String name);

  /// No description provided for @floorMenu.
  ///
  /// In ru, this message translates to:
  /// **'Действия с этажом «{name}»'**
  String floorMenu(String name);

  /// No description provided for @planTooBig.
  ///
  /// In ru, this message translates to:
  /// **'Файл больше 15 МБ. Уменьшите картинку или сохраните её в JPEG.'**
  String get planTooBig;

  /// No description provided for @planPdf.
  ///
  /// In ru, this message translates to:
  /// **'PDF не подходит: сохраните нужную страницу как PNG или сделайте снимок экрана.'**
  String get planPdf;

  /// No description provided for @planBadType.
  ///
  /// In ru, this message translates to:
  /// **'Нужна картинка PNG, JPEG или WebP.'**
  String get planBadType;

  /// No description provided for @planUnreadable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать картинку. Попробуйте другой файл.'**
  String get planUnreadable;

  /// No description provided for @planNoRights.
  ///
  /// In ru, this message translates to:
  /// **'Менять этажи, планы и маркеры может только менеджер.'**
  String get planNoRights;

  /// No description provided for @planUploadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить план. Проверьте интернет и попробуйте ещё раз.'**
  String get planUploadFailed;

  /// No description provided for @planStorageDenied.
  ///
  /// In ru, this message translates to:
  /// **'Хранилище отклонило загрузку (код {code}). Попробуйте ещё раз или сообщите администратору.'**
  String planStorageDenied(String code);

  /// No description provided for @planDbDenied.
  ///
  /// In ru, this message translates to:
  /// **'База отклонила изменение (код {code}). Попробуйте ещё раз или сообщите администратору.'**
  String planDbDenied(String code);

  /// No description provided for @planUploaded.
  ///
  /// In ru, this message translates to:
  /// **'План загружен'**
  String get planUploaded;

  /// No description provided for @planRemoved.
  ///
  /// In ru, this message translates to:
  /// **'План убран'**
  String get planRemoved;

  /// No description provided for @placeNotOnPlan.
  ///
  /// In ru, this message translates to:
  /// **'не на плане'**
  String get placeNotOnPlan;

  /// No description provided for @infoFloorsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Этажи и планы'**
  String get infoFloorsTitle;

  /// No description provided for @infoFloors1.
  ///
  /// In ru, this message translates to:
  /// **'Этаж — часть объекта. У этажа может быть картинка плана.'**
  String get infoFloors1;

  /// No description provided for @infoFloors2.
  ///
  /// In ru, this message translates to:
  /// **'На плане отмечают помещения и оборудование — исполнитель быстрее найдёт место.'**
  String get infoFloors2;

  /// No description provided for @infoFloors3.
  ///
  /// In ru, this message translates to:
  /// **'Добавлять этажи, загружать планы и расставлять маркеры может менеджер. Остальные видят план только для чтения.'**
  String get infoFloors3;

  /// No description provided for @infoUploadTitle.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка плана'**
  String get infoUploadTitle;

  /// No description provided for @infoUpload1.
  ///
  /// In ru, this message translates to:
  /// **'Подходят картинки PNG, JPEG и WebP до 15 МБ.'**
  String get infoUpload1;

  /// No description provided for @infoUpload2.
  ///
  /// In ru, this message translates to:
  /// **'PDF: сохраните нужную страницу как PNG или сделайте снимок экрана.'**
  String get infoUpload2;

  /// No description provided for @infoUpload3.
  ///
  /// In ru, this message translates to:
  /// **'План видят только сотрудники вашей компании.'**
  String get infoUpload3;

  /// No description provided for @planTitle.
  ///
  /// In ru, this message translates to:
  /// **'План этажа'**
  String get planTitle;

  /// No description provided for @planEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get planEdit;

  /// No description provided for @planEditMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим расстановки'**
  String get planEditMode;

  /// No description provided for @planEditHint.
  ///
  /// In ru, this message translates to:
  /// **'перетаскивайте маркеры, нажмите на пустое место, чтобы добавить'**
  String get planEditHint;

  /// No description provided for @planDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get planDone;

  /// No description provided for @planFilterAll.
  ///
  /// In ru, this message translates to:
  /// **'Всё'**
  String get planFilterAll;

  /// No description provided for @planFilterPlaces.
  ///
  /// In ru, this message translates to:
  /// **'Помещения'**
  String get planFilterPlaces;

  /// No description provided for @planFilterAssets.
  ///
  /// In ru, this message translates to:
  /// **'Оборудование'**
  String get planFilterAssets;

  /// No description provided for @planFilterWithOrders.
  ///
  /// In ru, this message translates to:
  /// **'С заявками'**
  String get planFilterWithOrders;

  /// No description provided for @planOnPlan.
  ///
  /// In ru, this message translates to:
  /// **'На плане · {count}'**
  String planOnPlan(int count);

  /// No description provided for @planUnplaced.
  ///
  /// In ru, this message translates to:
  /// **'Не размещены · {count}'**
  String planUnplaced(int count);

  /// No description provided for @planSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по помещениям и оборудованию'**
  String get planSearch;

  /// No description provided for @planNotLoaded.
  ///
  /// In ru, this message translates to:
  /// **'План не загружен'**
  String get planNotLoaded;

  /// No description provided for @planFit.
  ///
  /// In ru, this message translates to:
  /// **'Вписать план'**
  String get planFit;

  /// No description provided for @planList.
  ///
  /// In ru, this message translates to:
  /// **'Список'**
  String get planList;

  /// No description provided for @planOpenOrders.
  ///
  /// In ru, this message translates to:
  /// **'Открытые заявки'**
  String get planOpenOrders;

  /// No description provided for @planNoOpenOrders.
  ///
  /// In ru, this message translates to:
  /// **'Открытых заявок нет'**
  String get planNoOpenOrders;

  /// No description provided for @planCreateHere.
  ///
  /// In ru, this message translates to:
  /// **'Создать заявку здесь'**
  String get planCreateHere;

  /// No description provided for @planAllPlaceOrders.
  ///
  /// In ru, this message translates to:
  /// **'Все заявки помещения'**
  String get planAllPlaceOrders;

  /// No description provided for @planAssetInventory.
  ///
  /// In ru, this message translates to:
  /// **'Инвентарный номер'**
  String get planAssetInventory;

  /// No description provided for @planAssetCategory.
  ///
  /// In ru, this message translates to:
  /// **'Категория'**
  String get planAssetCategory;

  /// No description provided for @planAssetPlace.
  ///
  /// In ru, this message translates to:
  /// **'Помещение'**
  String get planAssetPlace;

  /// No description provided for @assetCategory.
  ///
  /// In ru, this message translates to:
  /// **'{code, select, equipment{Оборудование} furniture{Мебель} infra{Инженерные сети} other{Другое}}'**
  String assetCategory(String code);

  /// No description provided for @planNewPlaceHere.
  ///
  /// In ru, this message translates to:
  /// **'Новое помещение здесь'**
  String get planNewPlaceHere;

  /// No description provided for @planNewAssetHere.
  ///
  /// In ru, this message translates to:
  /// **'Новое оборудование здесь'**
  String get planNewAssetHere;

  /// No description provided for @planPutHere.
  ///
  /// In ru, this message translates to:
  /// **'Поставить сюда…'**
  String get planPutHere;

  /// No description provided for @planRename.
  ///
  /// In ru, this message translates to:
  /// **'Переименовать'**
  String get planRename;

  /// No description provided for @planRemoveFromPlan.
  ///
  /// In ru, this message translates to:
  /// **'Убрать с плана'**
  String get planRemoveFromPlan;

  /// No description provided for @planDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get planDelete;

  /// No description provided for @planDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить «{name}»?'**
  String planDeleteConfirm(String name);

  /// No description provided for @planDeleteHasOrders.
  ///
  /// In ru, this message translates to:
  /// **'У «{name}» есть заявки — удалить нельзя. Можно убрать с плана.'**
  String planDeleteHasOrders(String name);

  /// No description provided for @planSaved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get planSaved;

  /// No description provided for @planUndo.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get planUndo;

  /// No description provided for @planNewPlace.
  ///
  /// In ru, this message translates to:
  /// **'Новое помещение'**
  String get planNewPlace;

  /// No description provided for @planNewAsset.
  ///
  /// In ru, this message translates to:
  /// **'Новое оборудование'**
  String get planNewAsset;

  /// No description provided for @planNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get planNameLabel;

  /// No description provided for @planNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get planNameRequired;

  /// No description provided for @planInventoryLabel.
  ///
  /// In ru, this message translates to:
  /// **'Инвентарный номер (необязательно)'**
  String get planInventoryLabel;

  /// No description provided for @planPickUnplaced.
  ///
  /// In ru, this message translates to:
  /// **'Что поставить сюда'**
  String get planPickUnplaced;

  /// No description provided for @planNothingUnplaced.
  ///
  /// In ru, this message translates to:
  /// **'Всё уже на плане'**
  String get planNothingUnplaced;

  /// No description provided for @planNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Этаж не найден или нет доступа.'**
  String get planNotFound;

  /// No description provided for @planNoPlaces.
  ///
  /// In ru, this message translates to:
  /// **'Сначала добавьте помещение на этот этаж'**
  String get planNoPlaces;

  /// No description provided for @planFloorPicker.
  ///
  /// In ru, this message translates to:
  /// **'Этаж'**
  String get planFloorPicker;

  /// No description provided for @planMarkerHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на маркер — заявки и действия'**
  String get planMarkerHint;

  /// No description provided for @infoPlanTitle.
  ///
  /// In ru, this message translates to:
  /// **'Что значат маркеры'**
  String get infoPlanTitle;

  /// No description provided for @infoPlan1.
  ///
  /// In ru, this message translates to:
  /// **'Кружок — помещение, число — его открытые заявки. Квадрат — оборудование.'**
  String get infoPlan1;

  /// No description provided for @infoPlan2.
  ///
  /// In ru, this message translates to:
  /// **'Красный — есть просроченные или критические заявки, оранжевый — срочные или в работе.'**
  String get infoPlan2;

  /// No description provided for @infoPlan3.
  ///
  /// In ru, this message translates to:
  /// **'Бирюзовый — есть открытые заявки, серый — открытых нет.'**
  String get infoPlan3;

  /// No description provided for @infoPlan4.
  ///
  /// In ru, this message translates to:
  /// **'Мигает — у оборудования просроченная заявка. Волны и ореол — выбранный маркер, нажмите на пустое место, чтобы снять выбор.'**
  String get infoPlan4;

  /// No description provided for @infoEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Режим расстановки'**
  String get infoEditTitle;

  /// No description provided for @infoEdit1.
  ///
  /// In ru, this message translates to:
  /// **'Перетащите маркер, чтобы передвинуть (на телефоне — долгое нажатие). Сохраняется сразу, можно «Отменить».'**
  String get infoEdit1;

  /// No description provided for @infoEdit2.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на пустое место — добавьте помещение или оборудование или поставьте то, что ещё не размещено.'**
  String get infoEdit2;

  /// No description provided for @infoEdit3.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на маркер — переименовать, убрать с плана или удалить.'**
  String get infoEdit3;

  /// No description provided for @orderShowOnPlan.
  ///
  /// In ru, this message translates to:
  /// **'Показать на плане'**
  String get orderShowOnPlan;

  /// No description provided for @planNearby.
  ///
  /// In ru, this message translates to:
  /// **'{floor} · {count, plural, =0{открытых заявок рядом нет} one{{count} открытая заявка рядом} few{{count} открытые заявки рядом} other{{count} открытых заявок рядом}}'**
  String planNearby(String floor, int count);

  /// No description provided for @floorShort.
  ///
  /// In ru, this message translates to:
  /// **'{level} эт.'**
  String floorShort(int level);

  /// No description provided for @formPlace.
  ///
  /// In ru, this message translates to:
  /// **'Помещение'**
  String get formPlace;

  /// No description provided for @formChoosePlace.
  ///
  /// In ru, this message translates to:
  /// **'Без помещения'**
  String get formChoosePlace;

  /// No description provided for @formAsset.
  ///
  /// In ru, this message translates to:
  /// **'Оборудование'**
  String get formAsset;

  /// No description provided for @navAddOrder.
  ///
  /// In ru, this message translates to:
  /// **'Заявка'**
  String get navAddOrder;

  /// No description provided for @navCollapse.
  ///
  /// In ru, this message translates to:
  /// **'Свернуть меню'**
  String get navCollapse;

  /// No description provided for @navExpand.
  ///
  /// In ru, this message translates to:
  /// **'Развернуть меню'**
  String get navExpand;

  /// No description provided for @navLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык интерфейса: {lang}'**
  String navLanguage(String lang);

  /// No description provided for @navHelp.
  ///
  /// In ru, this message translates to:
  /// **'Справка и горячие клавиши'**
  String get navHelp;

  /// No description provided for @navAccount.
  ///
  /// In ru, this message translates to:
  /// **'Меню профиля'**
  String get navAccount;

  /// No description provided for @navCompanyRole.
  ///
  /// In ru, this message translates to:
  /// **'{company} · {role}'**
  String navCompanyRole(String company, String role);

  /// No description provided for @helpTitle.
  ///
  /// In ru, this message translates to:
  /// **'Справка'**
  String get helpTitle;

  /// No description provided for @helpTip1.
  ///
  /// In ru, this message translates to:
  /// **'«Эй, Helpy» — скажите, что случилось и где: заявка заполнится сама, останется проверить и отправить.'**
  String get helpTip1;

  /// No description provided for @helpTip2.
  ///
  /// In ru, this message translates to:
  /// **'Заявку нельзя закрыть без фото «после» и подтверждения автора или менеджера.'**
  String get helpTip2;

  /// No description provided for @helpTip3.
  ///
  /// In ru, this message translates to:
  /// **'«Локации» — объекты на карте и планы этажей с маркерами помещений и оборудования.'**
  String get helpTip3;

  /// No description provided for @helpHotkeys.
  ///
  /// In ru, this message translates to:
  /// **'Горячие клавиши'**
  String get helpHotkeys;

  /// No description provided for @hotkeyNew.
  ///
  /// In ru, this message translates to:
  /// **'Новая заявка'**
  String get hotkeyNew;

  /// No description provided for @hotkeyVoice.
  ///
  /// In ru, this message translates to:
  /// **'Голосовая заявка'**
  String get hotkeyVoice;

  /// No description provided for @hotkeySearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по заявкам'**
  String get hotkeySearch;

  /// No description provided for @hotkeyHelp.
  ///
  /// In ru, this message translates to:
  /// **'Эта справка'**
  String get hotkeyHelp;

  /// No description provided for @hotkeyNote.
  ///
  /// In ru, this message translates to:
  /// **'Не срабатывают, когда курсор в поле ввода.'**
  String get hotkeyNote;

  /// Экран нового раздела на базе без нужной миграции (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Нужна миграция {number}: раздел заработает, когда её применят в базе (Actions → «Apply migration»).'**
  String migrationNeeded(String number);

  /// Вкладка и пункт меню «ППР» — планово-предупредительные (регламентные) работы (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'ППР'**
  String get tabPpr;

  /// No description provided for @pprTitle.
  ///
  /// In ru, this message translates to:
  /// **'Регламентные работы'**
  String get pprTitle;

  /// No description provided for @pprSummary.
  ///
  /// In ru, this message translates to:
  /// **'{month}: выполнено {done} из {total}'**
  String pprSummary(String month, int done, int total);

  /// No description provided for @pprEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Планов ППР пока нет. Менеджер добавляет их кнопкой «+».'**
  String get pprEmpty;

  /// No description provided for @pprEmptyFiltered.
  ///
  /// In ru, this message translates to:
  /// **'Нет планов по выбранным фильтрам'**
  String get pprEmptyFiltered;

  /// No description provided for @pprLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить планы ППР. Проверьте интернет и попробуйте ещё раз.'**
  String get pprLoadFailed;

  /// No description provided for @pprStateDone.
  ///
  /// In ru, this message translates to:
  /// **'Выполнено'**
  String get pprStateDone;

  /// No description provided for @pprStateInProgress.
  ///
  /// In ru, this message translates to:
  /// **'В работе'**
  String get pprStateInProgress;

  /// No description provided for @pprStateNotStarted.
  ///
  /// In ru, this message translates to:
  /// **'Не начато'**
  String get pprStateNotStarted;

  /// No description provided for @pprStateOverdue.
  ///
  /// In ru, this message translates to:
  /// **'Просрочено'**
  String get pprStateOverdue;

  /// No description provided for @pprStatePaused.
  ///
  /// In ru, this message translates to:
  /// **'Приостановлен'**
  String get pprStatePaused;

  /// No description provided for @pprEveryMonth.
  ///
  /// In ru, this message translates to:
  /// **'каждый месяц'**
  String get pprEveryMonth;

  /// No description provided for @pprEveryQuarter.
  ///
  /// In ru, this message translates to:
  /// **'каждый квартал'**
  String get pprEveryQuarter;

  /// No description provided for @pprEveryHalfYear.
  ///
  /// In ru, this message translates to:
  /// **'каждые полгода'**
  String get pprEveryHalfYear;

  /// No description provided for @pprEveryYear.
  ///
  /// In ru, this message translates to:
  /// **'каждый год'**
  String get pprEveryYear;

  /// No description provided for @pprEveryDays.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{каждый {count} день} few{каждые {count} дня} other{каждые {count} дней}}'**
  String pprEveryDays(int count);

  /// No description provided for @pprKindMonth.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get pprKindMonth;

  /// No description provided for @pprKindQuarter.
  ///
  /// In ru, this message translates to:
  /// **'Квартал'**
  String get pprKindQuarter;

  /// No description provided for @pprKindHalfYear.
  ///
  /// In ru, this message translates to:
  /// **'Полгода'**
  String get pprKindHalfYear;

  /// No description provided for @pprKindYear.
  ///
  /// In ru, this message translates to:
  /// **'Год'**
  String get pprKindYear;

  /// No description provided for @pprKindDays.
  ///
  /// In ru, this message translates to:
  /// **'N дней'**
  String get pprKindDays;

  /// Квартал: по-русски q — римская цифра (IV), по-английски — число (4)
  ///
  /// In ru, this message translates to:
  /// **'{q} кв. {year}'**
  String pprQuarterLabel(String q, String year);

  /// Полугодие: по-русски h — римская цифра (II), по-английски — число (2)
  ///
  /// In ru, this message translates to:
  /// **'{h} полугодие {year}'**
  String pprHalfLabel(String h, String year);

  /// No description provided for @pprYearLabel.
  ///
  /// In ru, this message translates to:
  /// **'{year} год'**
  String pprYearLabel(String year);

  /// No description provided for @pprTaskLine.
  ///
  /// In ru, this message translates to:
  /// **'ППР · {period} · до {due}'**
  String pprTaskLine(String period, String due);

  /// No description provided for @pprDoWithin.
  ///
  /// In ru, this message translates to:
  /// **'Выполнить в течение периода'**
  String get pprDoWithin;

  /// No description provided for @pprPeriodRow.
  ///
  /// In ru, this message translates to:
  /// **'Период ППР'**
  String get pprPeriodRow;

  /// No description provided for @pprTag.
  ///
  /// In ru, this message translates to:
  /// **'ППР'**
  String get pprTag;

  /// No description provided for @pprKindOrder.
  ///
  /// In ru, this message translates to:
  /// **'ППР'**
  String get pprKindOrder;

  /// No description provided for @filterPpr.
  ///
  /// In ru, this message translates to:
  /// **'ППР'**
  String get filterPpr;

  /// No description provided for @pprFilters.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get pprFilters;

  /// No description provided for @pprFiltersCount.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры · {count}'**
  String pprFiltersCount(int count);

  /// No description provided for @pprFilterObject.
  ///
  /// In ru, this message translates to:
  /// **'Объект'**
  String get pprFilterObject;

  /// No description provided for @pprFilterSystem.
  ///
  /// In ru, this message translates to:
  /// **'Система'**
  String get pprFilterSystem;

  /// No description provided for @pprFilterContractor.
  ///
  /// In ru, this message translates to:
  /// **'Подрядчик'**
  String get pprFilterContractor;

  /// No description provided for @pprFilterState.
  ///
  /// In ru, this message translates to:
  /// **'Статус периода'**
  String get pprFilterState;

  /// No description provided for @pprFiltersShow.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Нет планов} one{Показать {count} план} few{Показать {count} плана} other{Показать {count} планов}}'**
  String pprFiltersShow(int count);

  /// No description provided for @pprCardPeriodicity.
  ///
  /// In ru, this message translates to:
  /// **'Периодичность'**
  String get pprCardPeriodicity;

  /// No description provided for @pprCardStarts.
  ///
  /// In ru, this message translates to:
  /// **'с {date}'**
  String pprCardStarts(String date);

  /// No description provided for @pprCardCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Текущий период'**
  String get pprCardCurrent;

  /// No description provided for @pprCardChecklist.
  ///
  /// In ru, this message translates to:
  /// **'Чек-лист'**
  String get pprCardChecklist;

  /// No description provided for @pprCardHistory.
  ///
  /// In ru, this message translates to:
  /// **'История периодов'**
  String get pprCardHistory;

  /// No description provided for @pprCardHistoryEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Задач по плану ещё не было'**
  String get pprCardHistoryEmpty;

  /// No description provided for @pprCardNoTask.
  ///
  /// In ru, this message translates to:
  /// **'Задача периода ещё не создана'**
  String get pprCardNoTask;

  /// No description provided for @pprAcceptedBy.
  ///
  /// In ru, this message translates to:
  /// **'Принято {date} · {name}'**
  String pprAcceptedBy(String date, String name);

  /// No description provided for @pprAcceptedAt.
  ///
  /// In ru, this message translates to:
  /// **'Принято {date}'**
  String pprAcceptedAt(String date);

  /// No description provided for @pprNoContractor.
  ///
  /// In ru, this message translates to:
  /// **'Не закреплён за системой на этом объекте'**
  String get pprNoContractor;

  /// No description provided for @pprAsset.
  ///
  /// In ru, this message translates to:
  /// **'Оборудование'**
  String get pprAsset;

  /// No description provided for @pprEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get pprEdit;

  /// No description provided for @pprPause.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить'**
  String get pprPause;

  /// No description provided for @pprResume.
  ///
  /// In ru, this message translates to:
  /// **'Возобновить'**
  String get pprResume;

  /// No description provided for @pprDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить план'**
  String get pprDelete;

  /// No description provided for @pprDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить план «{title}»? Это нельзя отменить.'**
  String pprDeleteConfirm(String title);

  /// No description provided for @pprDeleteHasTasks.
  ///
  /// In ru, this message translates to:
  /// **'У плана уже есть задачи — его можно только приостановить.'**
  String get pprDeleteHasTasks;

  /// No description provided for @pprPaused.
  ///
  /// In ru, this message translates to:
  /// **'План приостановлен'**
  String get pprPaused;

  /// No description provided for @pprResumed.
  ///
  /// In ru, this message translates to:
  /// **'План возобновлён'**
  String get pprResumed;

  /// No description provided for @pprDeleted.
  ///
  /// In ru, this message translates to:
  /// **'План удалён'**
  String get pprDeleted;

  /// No description provided for @pprSaved.
  ///
  /// In ru, this message translates to:
  /// **'План сохранён'**
  String get pprSaved;

  /// No description provided for @pprGenerated.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Создана {count} задача ППР} few{Созданы {count} задачи ППР} other{Создано {count} задач ППР}}'**
  String pprGenerated(int count);

  /// No description provided for @pprFormNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый план ППР'**
  String get pprFormNew;

  /// No description provided for @pprFormEdit.
  ///
  /// In ru, this message translates to:
  /// **'План ППР'**
  String get pprFormEdit;

  /// No description provided for @pprFormTitle.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get pprFormTitle;

  /// No description provided for @pprFormTitleHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: ТО кондиционеров'**
  String get pprFormTitleHint;

  /// No description provided for @pprFormDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get pprFormDescription;

  /// No description provided for @pprFormDescriptionHint.
  ///
  /// In ru, this message translates to:
  /// **'Что входит в работу'**
  String get pprFormDescriptionHint;

  /// No description provided for @pprFormObject.
  ///
  /// In ru, this message translates to:
  /// **'Объект'**
  String get pprFormObject;

  /// No description provided for @pprFormPlace.
  ///
  /// In ru, this message translates to:
  /// **'Помещение'**
  String get pprFormPlace;

  /// No description provided for @pprFormAsset.
  ///
  /// In ru, this message translates to:
  /// **'Оборудование'**
  String get pprFormAsset;

  /// No description provided for @pprFormNone.
  ///
  /// In ru, this message translates to:
  /// **'Не выбрано'**
  String get pprFormNone;

  /// No description provided for @pprFormSystem.
  ///
  /// In ru, this message translates to:
  /// **'Система'**
  String get pprFormSystem;

  /// No description provided for @pprFormPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Периодичность'**
  String get pprFormPeriod;

  /// No description provided for @pprFormDays.
  ///
  /// In ru, this message translates to:
  /// **'Дней в периоде'**
  String get pprFormDays;

  /// No description provided for @pprFormStarts.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get pprFormStarts;

  /// No description provided for @pprFormChecklist.
  ///
  /// In ru, this message translates to:
  /// **'Чек-лист'**
  String get pprFormChecklist;

  /// No description provided for @pprFormChecklistHint.
  ///
  /// In ru, this message translates to:
  /// **'По пункту в строке'**
  String get pprFormChecklistHint;

  /// No description provided for @pprFormPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Фото «после» обязательно'**
  String get pprFormPhoto;

  /// No description provided for @pprFormRequired.
  ///
  /// In ru, this message translates to:
  /// **'Заполните название, объект и систему'**
  String get pprFormRequired;

  /// No description provided for @pprFormDaysInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Число дней — от 1 до 3660'**
  String get pprFormDaysInvalid;

  /// No description provided for @pprDuplicate.
  ///
  /// In ru, this message translates to:
  /// **'План с таким названием на этом объекте уже есть'**
  String get pprDuplicate;

  /// No description provided for @pprChooseObject.
  ///
  /// In ru, this message translates to:
  /// **'Выберите объект'**
  String get pprChooseObject;

  /// No description provided for @pprInfoTitle.
  ///
  /// In ru, this message translates to:
  /// **'ППР — регламентные работы'**
  String get pprInfoTitle;

  /// No description provided for @pprInfo1.
  ///
  /// In ru, this message translates to:
  /// **'План — регулярная работа на объекте: ТО, осмотр, уборка. Период — месяц, квартал, полгода, год или N дней.'**
  String get pprInfo1;

  /// No description provided for @pprInfo2.
  ///
  /// In ru, this message translates to:
  /// **'Задача текущего периода создаётся сама, когда менеджер открывает приложение (не чаще раза в 10 минут) или нажимает «Обновить». Подрядчик назначается по системе и объекту.'**
  String get pprInfo2;

  /// No description provided for @pprInfo3.
  ///
  /// In ru, this message translates to:
  /// **'Срок задачи — последний день периода. Не принята к концу периода — просрочена.'**
  String get pprInfo3;

  /// No description provided for @pprInfo4.
  ///
  /// In ru, this message translates to:
  /// **'План с задачами нельзя удалить — его можно приостановить.'**
  String get pprInfo4;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Печать отчёта'**
  String get reportPrint;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Готовим PDF…'**
  String get reportPrintPreparing;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сформировать PDF. Попробуйте ещё раз.'**
  String get reportPrintFailed;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'PDF собирается по тем же фильтрам, что сейчас на экране: период, объекты, регион, подрядчик, вид работ и тип задачи.'**
  String get reportPrintInfo1;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'В браузере откроется окно печати — там же можно выбрать «Сохранить как PDF».'**
  String get reportPrintInfo2;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'На телефоне файл можно отправить в мессенджер или почту либо распечатать.'**
  String get reportPrintInfo3;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'В отчёте: показатели, таблицы «По регионам» и «По подрядчикам», список заявок с номерами страниц.'**
  String get reportPrintInfo4;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Регион'**
  String get reportFilterRegion;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get reportFilterKind;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Разовые'**
  String get reportKindOnce;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Повторяющиеся'**
  String get reportKindRecurring;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'ППР'**
  String get reportKindPpr;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Регионы'**
  String get reportRegionsGroup;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Страны'**
  String get reportCountriesGroup;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'По регионам'**
  String get reportByRegion;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'По городам'**
  String get reportByCity;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Без региона'**
  String get reportNoRegion;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Без города'**
  String get reportNoCity;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'ППР выполнено'**
  String get reportPprDone;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'{done} из {total}'**
  String reportPprOf(String done, String total);

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Отчёт по заявкам и подрядчикам'**
  String get pdfTitle;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Компания: {name}'**
  String pdfCompany(String name);

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Период: {period}'**
  String pdfPeriod(String period);

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Фильтры: {filters}'**
  String pdfFilters(String filters);

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'все объекты, подрядчики и виды работ'**
  String get pdfNoFilters;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Сформирован: {date}, {name}'**
  String pdfGenerated(String date, String name);

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'стр. {page} из {pages}'**
  String pdfPageOf(String page, String pages);

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Заявки'**
  String get pdfOrders;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'За период заявок нет.'**
  String get pdfOrdersEmpty;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'№'**
  String get pdfColNumber;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get pdfColDate;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Объект'**
  String get pdfColObject;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Помещение'**
  String get pdfColPlace;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Система'**
  String get pdfColLayer;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Подрядчик'**
  String get pdfColContractor;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get pdfColStatus;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Срок'**
  String get pdfColDue;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Регион'**
  String get pdfColRegion;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'Город'**
  String get pdfColCity;

  /// Шаг 16 (E): отчёты, PDF
  ///
  /// In ru, this message translates to:
  /// **'HeyHelpy_Отчёт_{period}.pdf'**
  String pdfFileName(String period);

  /// No description provided for @roomCode.
  ///
  /// In ru, this message translates to:
  /// **'Номер помещения'**
  String get roomCode;

  /// No description provided for @roomCodeHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, 305 или 12А'**
  String get roomCodeHint;

  /// No description provided for @roomCodeTaken.
  ///
  /// In ru, this message translates to:
  /// **'Такой номер уже есть в этом объекте'**
  String get roomCodeTaken;

  /// No description provided for @roomCodeNone.
  ///
  /// In ru, this message translates to:
  /// **'Без номера'**
  String get roomCodeNone;

  /// No description provided for @areaDraw.
  ///
  /// In ru, this message translates to:
  /// **'Обвести область'**
  String get areaDraw;

  /// No description provided for @areaEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить область'**
  String get areaEdit;

  /// No description provided for @areaDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить область'**
  String get areaDelete;

  /// No description provided for @areaDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Область удалена'**
  String get areaDeleted;

  /// Шапка режима рисования области помещения (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Область: {name}'**
  String areaTitle(String name);

  /// No description provided for @areaHintPolygon.
  ///
  /// In ru, this message translates to:
  /// **'Нажимайте по углам помещения. Точки можно двигать.'**
  String get areaHintPolygon;

  /// No description provided for @areaHintRect.
  ///
  /// In ru, this message translates to:
  /// **'Протяните прямоугольник по помещению. Точки можно двигать.'**
  String get areaHintRect;

  /// No description provided for @areaModePolygon.
  ///
  /// In ru, this message translates to:
  /// **'По углам'**
  String get areaModePolygon;

  /// No description provided for @areaModeRect.
  ///
  /// In ru, this message translates to:
  /// **'Прямоугольник'**
  String get areaModeRect;

  /// No description provided for @areaUndoPoint.
  ///
  /// In ru, this message translates to:
  /// **'Отменить точку'**
  String get areaUndoPoint;

  /// No description provided for @areaNeedPoints.
  ///
  /// In ru, this message translates to:
  /// **'Нужно хотя бы 3 точки'**
  String get areaNeedPoints;

  /// No description provided for @roomInfoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Номер и область помещения'**
  String get roomInfoTitle;

  /// No description provided for @roomInfo1.
  ///
  /// In ru, this message translates to:
  /// **'Номер помещения («305») виден в списках и на плане, по нему ищут и его понимает голосовая заявка: «течёт кран в 305-й».'**
  String get roomInfo1;

  /// No description provided for @roomInfo2.
  ///
  /// In ru, this message translates to:
  /// **'Номер уникален внутри объекта. Пустой номер — без номера.'**
  String get roomInfo2;

  /// No description provided for @roomInfo3.
  ///
  /// In ru, this message translates to:
  /// **'Область — контур помещения на плане. Режим расстановки → помещение → «Обвести область»: нажимайте по углам или протяните прямоугольник, потом «Готово».'**
  String get roomInfo3;

  /// No description provided for @roomInfo4.
  ///
  /// In ru, this message translates to:
  /// **'Область закрашена цветом заявок помещения; нажатие в любом месте области открывает помещение.'**
  String get roomInfo4;

  /// No description provided for @regionNone.
  ///
  /// In ru, this message translates to:
  /// **'Без региона'**
  String get regionNone;

  /// No description provided for @regionWhole.
  ///
  /// In ru, this message translates to:
  /// **'Весь регион'**
  String get regionWhole;

  /// No description provided for @countryNone.
  ///
  /// In ru, this message translates to:
  /// **'Страна не указана'**
  String get countryNone;

  /// No description provided for @geoWholeCity.
  ///
  /// In ru, this message translates to:
  /// **'Весь город: {city}'**
  String geoWholeCity(String city);

  /// No description provided for @geoWholeCountry.
  ///
  /// In ru, this message translates to:
  /// **'Вся страна: {country}'**
  String geoWholeCountry(String country);

  /// No description provided for @regionsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Регионы'**
  String get regionsTitle;

  /// No description provided for @regionsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Регионов пока нет. Добавьте первый — например, «Европа».'**
  String get regionsEmpty;

  /// No description provided for @regionsLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить регионы'**
  String get regionsLoadFailed;

  /// No description provided for @regionAdd.
  ///
  /// In ru, this message translates to:
  /// **'Новый регион'**
  String get regionAdd;

  /// No description provided for @regionAddRow.
  ///
  /// In ru, this message translates to:
  /// **'+ Новый регион'**
  String get regionAddRow;

  /// No description provided for @regionNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название региона'**
  String get regionNameLabel;

  /// No description provided for @regionNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, Европа'**
  String get regionNameHint;

  /// No description provided for @regionNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите название региона'**
  String get regionNameRequired;

  /// No description provided for @regionNameTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Не больше 60 символов'**
  String get regionNameTooLong;

  /// No description provided for @regionRename.
  ///
  /// In ru, this message translates to:
  /// **'Переименовать'**
  String get regionRename;

  /// No description provided for @regionMoveUp.
  ///
  /// In ru, this message translates to:
  /// **'Выше'**
  String get regionMoveUp;

  /// No description provided for @regionMoveDown.
  ///
  /// In ru, this message translates to:
  /// **'Ниже'**
  String get regionMoveDown;

  /// No description provided for @regionMerge.
  ///
  /// In ru, this message translates to:
  /// **'Объединить с…'**
  String get regionMerge;

  /// No description provided for @regionDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get regionDelete;

  /// No description provided for @regionActions.
  ///
  /// In ru, this message translates to:
  /// **'Действия с регионом «{name}»'**
  String regionActions(String name);

  /// No description provided for @regionSimilarTitle.
  ///
  /// In ru, this message translates to:
  /// **'Похожий регион уже есть'**
  String get regionSimilarTitle;

  /// No description provided for @regionSimilarText.
  ///
  /// In ru, this message translates to:
  /// **'Похоже, такой регион уже есть: «{name}» ({objects}). Использовать его?'**
  String regionSimilarText(String name, String objects);

  /// No description provided for @regionUseExisting.
  ///
  /// In ru, this message translates to:
  /// **'Использовать «{name}»'**
  String regionUseExisting(String name);

  /// No description provided for @regionCreateAnyway.
  ///
  /// In ru, this message translates to:
  /// **'Всё равно создать'**
  String get regionCreateAnyway;

  /// No description provided for @regionRenameAnyway.
  ///
  /// In ru, this message translates to:
  /// **'Всё равно переименовать'**
  String get regionRenameAnyway;

  /// No description provided for @regionDuplicate.
  ///
  /// In ru, this message translates to:
  /// **'Регион с таким названием уже есть — выберите его из списка'**
  String get regionDuplicate;

  /// No description provided for @regionCreated.
  ///
  /// In ru, this message translates to:
  /// **'Регион добавлен'**
  String get regionCreated;

  /// No description provided for @regionRenamed.
  ///
  /// In ru, this message translates to:
  /// **'Регион переименован'**
  String get regionRenamed;

  /// No description provided for @regionDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Регион удалён'**
  String get regionDeleted;

  /// No description provided for @regionMerged.
  ///
  /// In ru, this message translates to:
  /// **'Регионы объединены'**
  String get regionMerged;

  /// No description provided for @regionMergePick.
  ///
  /// In ru, this message translates to:
  /// **'Объединить «{name}» с…'**
  String regionMergePick(String name);

  /// No description provided for @regionMergeConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Объединить регионы?'**
  String get regionMergeConfirmTitle;

  /// No description provided for @regionMergeConfirm.
  ///
  /// In ru, this message translates to:
  /// **'{objects} перейдут в «{into}», регион «{from}» будет удалён.'**
  String regionMergeConfirm(String objects, String into, String from);

  /// No description provided for @regionMergeAction.
  ///
  /// In ru, this message translates to:
  /// **'Объединить'**
  String get regionMergeAction;

  /// No description provided for @regionMergeNoOther.
  ///
  /// In ru, this message translates to:
  /// **'Других регионов нет — объединять не с чем'**
  String get regionMergeNoOther;

  /// No description provided for @regionDeleteConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить регион «{name}»?'**
  String regionDeleteConfirmTitle(String name);

  /// No description provided for @regionDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'У объектов ({objects}) регион станет пустым.'**
  String regionDeleteConfirm(String objects);

  /// No description provided for @regionOnlyManager.
  ///
  /// In ru, this message translates to:
  /// **'Регионы меняет менеджер компании'**
  String get regionOnlyManager;

  /// No description provided for @regionInfo1.
  ///
  /// In ru, this message translates to:
  /// **'Один общий список регионов компании: в объекте регион выбирается из списка, а не вводится текстом.'**
  String get regionInfo1;

  /// No description provided for @regionInfo2.
  ///
  /// In ru, this message translates to:
  /// **'Похожие названия («Европа» и «Европпа») приложение замечает и предлагает выбрать уже существующий регион.'**
  String get regionInfo2;

  /// No description provided for @regionInfo3.
  ///
  /// In ru, this message translates to:
  /// **'Лишний регион можно объединить с нужным: его объекты перейдут, а он сам удалится.'**
  String get regionInfo3;

  /// No description provided for @regionInfo4.
  ///
  /// In ru, this message translates to:
  /// **'Переименование сразу видно во всех объектах, фильтрах и отчётах.'**
  String get regionInfo4;

  /// No description provided for @regionPickTitle.
  ///
  /// In ru, this message translates to:
  /// **'Регион'**
  String get regionPickTitle;

  /// No description provided for @regionNotSet.
  ///
  /// In ru, this message translates to:
  /// **'Не указан'**
  String get regionNotSet;

  /// No description provided for @regionManage.
  ///
  /// In ru, this message translates to:
  /// **'Регионы компании'**
  String get regionManage;

  /// No description provided for @countryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Страна'**
  String get countryTitle;

  /// No description provided for @countrySearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Название или код страны'**
  String get countrySearchHint;

  /// No description provided for @countryNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Страна не найдена'**
  String get countryNotFound;

  /// No description provided for @geoCity.
  ///
  /// In ru, this message translates to:
  /// **'Город'**
  String get geoCity;

  /// No description provided for @geoCityHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, Белград'**
  String get geoCityHint;

  /// No description provided for @geoCitySimilarTitle.
  ///
  /// In ru, this message translates to:
  /// **'Похожий город уже есть'**
  String get geoCitySimilarTitle;

  /// No description provided for @geoCitySimilar.
  ///
  /// In ru, this message translates to:
  /// **'В компании уже есть город «{name}». Использовать его?'**
  String geoCitySimilar(String name);

  /// No description provided for @geoCityKeep.
  ///
  /// In ru, this message translates to:
  /// **'Оставить «{name}»'**
  String geoCityKeep(String name);

  /// No description provided for @geoCitySuggestions.
  ///
  /// In ru, this message translates to:
  /// **'Города компании в этой стране'**
  String get geoCitySuggestions;

  /// No description provided for @geoEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Страна, город, регион'**
  String get geoEditTitle;

  /// No description provided for @geoEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить страну, город, регион'**
  String get geoEdit;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Оборудование · {count}'**
  String equipSectionTitle(int count);

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Название, номер, модель'**
  String get equipSearchHint;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Оборудования пока нет'**
  String get equipEmpty;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Добавить оборудование'**
  String get equipAdd;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Импорт из Excel / CSV'**
  String get equipImport;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Без системы'**
  String get equipNoSystem;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get equipNothingFound;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'{system} · {count}'**
  String equipGroupTitle(String system, int count);

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Новое оборудование'**
  String get assetFormNewTitle;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Оборудование'**
  String get assetFormEditTitle;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get assetFieldName;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Например, кондиционер переговорной'**
  String get assetFieldNameHint;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Система'**
  String get assetFieldSystem;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Помещение'**
  String get assetFieldRoom;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Выберите помещение'**
  String get assetChooseRoom;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Инвентарный номер'**
  String get assetFieldInventory;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Производитель'**
  String get assetFieldManufacturer;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Модель'**
  String get assetFieldModel;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Серийный номер'**
  String get assetFieldSerial;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Дата ввода'**
  String get assetFieldInstalled;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Укажите название'**
  String get assetNameRequired;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Выберите помещение'**
  String get assetRoomRequired;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Оборудование сохранено'**
  String get assetSaved;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить. Проверьте связь и попробуйте ещё раз.'**
  String get assetSaveFailed;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Сначала добавьте помещение в объект'**
  String get assetNoPlaces;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Паспорт'**
  String get assetCardPassport;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Где стоит'**
  String get assetCardWhere;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Объект'**
  String get assetCardObject;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Этаж'**
  String get assetCardFloor;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Планы ППР'**
  String get assetCardPlans;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Нет планов ППР'**
  String get assetCardPlansEmpty;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Заявки · {count}'**
  String assetCardOrders(int count);

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Заявок по этому оборудованию нет'**
  String get assetCardOrdersEmpty;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Создать заявку'**
  String get assetCreateOrder;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить оборудование'**
  String get assetLoadFailed;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get assetEdit;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'каждый месяц'**
  String get assetPeriodMonth;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'каждый квартал'**
  String get assetPeriodQuarter;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'раз в полгода'**
  String get assetPeriodHalfYear;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'раз в год'**
  String get assetPeriodYear;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'каждые {days} дн.'**
  String assetPeriodDays(int days);

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'приостановлен'**
  String get assetPlanPaused;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Импорт оборудования'**
  String get importTitle;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Скачать шаблон Excel'**
  String get importTemplateXlsx;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Скачать шаблон CSV'**
  String get importTemplateCsv;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Выбрать файл (.xlsx, .csv)'**
  String get importPickFile;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Первая строка — заголовки. Обязательны «Название» и «Помещение».'**
  String get importFooter;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Шаблон сохранён'**
  String get importTemplateSaved;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить шаблон'**
  String get importTemplateFailed;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать файл. Сохраните его как .xlsx или .csv (UTF-8) и попробуйте ещё раз.'**
  String get importReadFailed;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'В файле нет строк с оборудованием'**
  String get importEmpty;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'В файле нет колонок: {columns}. Скачайте шаблон и перенесите данные в него.'**
  String importMissingColumns(String columns);

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get importColName;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Помещение'**
  String get importColRoom;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Строк: {total} · готово: {ok} · с ошибками: {bad}'**
  String importSummary(int total, int ok, int bad);

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Создать недостающие помещения ({count})'**
  String importCreateRooms(int count);

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'С ошибками — не будут загружены'**
  String get importErrorsTitle;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Готово к импорту'**
  String get importReadyTitle;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Строка {line} · {name}'**
  String importRowTitle(int line, String name);

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'без названия'**
  String get importNoRowName;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'И ещё {count}'**
  String importMore(int count);

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'нет названия'**
  String get importIssueNoName;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'не указано помещение'**
  String get importIssueNoRoom;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'нет помещения «{room}»'**
  String importIssueRoomNotFound(String room);

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'нет системы «{system}»'**
  String importIssueUnknownSystem(String system);

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'инвентарный номер повторяется в файле'**
  String get importIssueDupFile;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'такой инвентарный номер уже есть'**
  String get importIssueDupDb;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'дата не распознана (нужно ГГГГ-ММ-ДД или ДД.ММ.ГГГГ)'**
  String get importIssueBadDate;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'слишком длинное значение (больше 120 символов)'**
  String get importIssueTooLong;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Импортировать {count} строку} few{Импортировать {count} строки} other{Импортировать {count} строк}}'**
  String importButton(int count);

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Импортировано: {count}'**
  String importDone(int count);

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Импорт не выполнен — ничего не загружено. Проверьте связь и попробуйте ещё раз.'**
  String get importFailed;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Импорт оборудования'**
  String get importInfoTitle;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Скачайте шаблон Excel или CSV: первая строка — заголовки, вторая — пример (её можно удалить).'**
  String get importInfo1;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Обязательны «Название» и «Помещение». Помещение — по номеру («305») или по названию, как в карточке объекта.'**
  String get importInfo2;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'«Система» — как в видах работ (Климат, Электрика…). Дата ввода — ГГГГ-ММ-ДД или ДД.ММ.ГГГГ.'**
  String get importInfo3;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Строки с ошибками не загружаются: исправьте их в файле и выберите файл ещё раз. Недостающие помещения можно создать при импорте.'**
  String get importInfo4;

  /// Имя файла шаблона импорта, без расширения (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'HeyHelpy_Оборудование_шаблон'**
  String get importTemplateFileName;

  /// Реестр оборудования (шаг 16)
  ///
  /// In ru, this message translates to:
  /// **'Например, КЛ-3-001'**
  String get assetFieldInventoryHint;
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
