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
