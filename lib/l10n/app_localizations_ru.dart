// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Эй, Helpy';

  @override
  String get wakePhrase => 'Эй, Хелпи';

  @override
  String get appTagline => 'Заявки и контроль работ — в одно касание';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonRefresh => 'Обновить';

  @override
  String get commonNotSpecified => 'Не указано';

  @override
  String get errorGeneric =>
      'Не получилось. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get misconfiguredTitle => 'Не заданы ключи Supabase';

  @override
  String get misconfiguredRunWith => 'Запустите приложение с параметрами:';

  @override
  String get misconfiguredSeeReadme => 'Подробности — в README.md';

  @override
  String get splashLoadFailed =>
      'Не удалось загрузить профиль.\nПроверьте подключение к интернету.';

  @override
  String get splashSignOut => 'Выйти из аккаунта';

  @override
  String get loginName => 'Имя';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginEmailInvalid => 'Введите корректный email';

  @override
  String get loginPassword => 'Пароль';

  @override
  String get loginPasswordTooShort => 'Минимум 6 символов';

  @override
  String get loginSignIn => 'Войти';

  @override
  String get loginSignUp => 'Зарегистрироваться';

  @override
  String get loginHaveAccount => 'Уже есть аккаунт? Войти';

  @override
  String get loginNoAccount => 'Нет аккаунта? Зарегистрироваться';

  @override
  String get loginAccountCreated =>
      'Аккаунт создан. Если включено подтверждение почты — проверьте письмо.';

  @override
  String get loginErrorInvalidCredentials => 'Неверный email или пароль';

  @override
  String get loginErrorAlreadyRegistered =>
      'Пользователь с таким email уже зарегистрирован. Войдите.';

  @override
  String get loginErrorEmailNotConfirmed =>
      'Почта не подтверждена. Откройте письмо и перейдите по ссылке.';

  @override
  String get navHome => 'Главная';

  @override
  String get navHistory => 'История';

  @override
  String get navReports => 'Отчёты';

  @override
  String get navProfile => 'Профиль';

  @override
  String get tabRequests => 'Заявки';

  @override
  String get tabContractors => 'Исполнитель';

  @override
  String get tabLocations => 'Локации';

  @override
  String mockHistoryDoneThisMonth(int count) {
    return 'Выполнено за месяц: $count';
  }

  @override
  String get mockHistory1Title => 'Ремонт стула';

  @override
  String get mockHistory1Place => 'Астана · Кабинет 512';

  @override
  String get mockHistory1Meta => '12 авг · 40 мин';

  @override
  String get mockHistory2Title => 'Замена фильтров';

  @override
  String get mockHistory2Place => 'Москва · Серверная';

  @override
  String get mockHistory2Meta => '11 авг · 1 ч 20 мин';

  @override
  String get mockHistory3Title => 'Уборка холла';

  @override
  String get mockHistory3Place => 'Москва · 1 этаж';

  @override
  String get mockHistory3Meta => '11 авг · 55 мин';

  @override
  String get historyDone => 'Готово';

  @override
  String get reportsKpiRequests => 'заявок за месяц';

  @override
  String get reportsKpiOnTime => 'в срок';

  @override
  String get reportsKpiAvgTime => 'ср. время';

  @override
  String hoursShort(String value) {
    return '$value ч';
  }

  @override
  String get reportsWeeklyChart => 'Заявки по неделям';

  @override
  String get reportsExportPdf => 'Экспорт в PDF';

  @override
  String get reportsWebHint => 'Полные отчёты и фильтры — в web-версии';

  @override
  String get profileDefaultName => 'Пользователь';

  @override
  String get profileMyCompany => 'Моя компания';

  @override
  String get profileNotifications => 'Уведомления';

  @override
  String get profileLanguage => 'Язык';

  @override
  String get profileSettings => 'Настройки';

  @override
  String get profileSignOut => 'Выйти';

  @override
  String get profileLanguageNotSynced =>
      'Язык сохранён на этом телефоне, но не в профиле. Проверьте интернет.';

  @override
  String get roleAdmin => 'Администратор';

  @override
  String get roleManager => 'Менеджер';

  @override
  String get roleRequester => 'Заявитель';

  @override
  String get roleContractor => 'Подрядчик';

  @override
  String get roleExecutor => 'Исполнитель';

  @override
  String get statusNew => 'Новая';

  @override
  String get statusAssigned => 'Назначена';

  @override
  String get statusInProgress => 'В работе';

  @override
  String get statusOnReview => 'На проверке';

  @override
  String get statusReturned => 'Возвращена';

  @override
  String get statusDone => 'Принята';

  @override
  String get statusCancelled => 'Отменена';

  @override
  String get statusOverdue => 'Просрочена';

  @override
  String get priorityLow => 'Низкий';

  @override
  String get priorityNormal => 'Обычный';

  @override
  String get priorityHigh => 'Высокий';

  @override
  String get priorityCritical => 'Критический';

  @override
  String get requestsLoading => 'Загрузка…';

  @override
  String get requestsLoadErrorShort => 'Ошибка загрузки';

  @override
  String requestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count заявки',
      many: '$count заявок',
      few: '$count заявки',
      one: '$count заявка',
      zero: 'Заявок нет',
    );
    return '$_temp0';
  }

  @override
  String get requestsLoadFailed =>
      'Не удалось загрузить заявки. Проверьте интернет и нажмите «Обновить».';

  @override
  String get requestsEmpty => 'Пока нет заявок.\nНажмите «Создать заявку».';

  @override
  String get requestsCreate => 'Создать заявку';

  @override
  String get requestsVoice => 'Нажми и говори';

  @override
  String get requestsCreated => 'Заявка создана';

  @override
  String get requestsNoCompany =>
      'Ваш профиль не привязан к компании. Обратитесь к администратору.';

  @override
  String get requestRecurringTag => 'регламент';

  @override
  String get objectNone => 'Без объекта';

  @override
  String get objectUnknown => 'Объект';

  @override
  String get contractorNone => 'не назначен';

  @override
  String get contractorUnknown => 'исполнитель';

  @override
  String get detailTitle => 'Заявка';

  @override
  String get detailEdit => 'Редактировать';

  @override
  String get detailLoadFailed =>
      'Не удалось открыть заявку. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get fieldObject => 'Объект';

  @override
  String get fieldContractor => 'Исполнитель';

  @override
  String get fieldWorkType => 'Вид работ';

  @override
  String get fieldPriority => 'Приоритет';

  @override
  String get fieldKind => 'Тип';

  @override
  String get kindRecurring => 'Регламентная';

  @override
  String get kindOneOff => 'Разовая';

  @override
  String get fieldPhotoProof => 'Фотоподтверждение';

  @override
  String get photoRequired => 'Требуется';

  @override
  String get photoNotRequired => 'Не требуется';

  @override
  String get fieldCreated => 'Создана';

  @override
  String createdByYou(String date) {
    return '$date (вы)';
  }

  @override
  String get fieldDescription => 'Описание';

  @override
  String get noDescription => 'Без описания';

  @override
  String returnedWithReason(String reason) {
    return 'Возвращено: $reason';
  }

  @override
  String get actionsTitle => 'Действия';

  @override
  String get actionAssign => 'Назначить исполнителя';

  @override
  String get actionReassign => 'Сменить исполнителя';

  @override
  String get actionStart => 'Взять в работу';

  @override
  String get actionRestart => 'Взять на доработку';

  @override
  String get actionSubmit => 'Выполнено, на проверку';

  @override
  String get actionAccept => 'Принять работу';

  @override
  String get actionReturn => 'Вернуть на доработку';

  @override
  String get actionCancel => 'Отменить';

  @override
  String get toastInProgress => 'Заявка в работе';

  @override
  String get toastSubmitted => 'Отправлено на проверку';

  @override
  String get toastAccepted => 'Работа принята';

  @override
  String get toastCancelled => 'Заявка отменена';

  @override
  String get toastReturned => 'Возвращено исполнителю';

  @override
  String get toastSaved => 'Сохранено';

  @override
  String get toastAssigned => 'Исполнитель назначен';

  @override
  String assignNoContractors(String tab) {
    return 'Сначала добавьте подрядчика во вкладке «$tab»';
  }

  @override
  String get returnHint => 'Что нужно исправить?';

  @override
  String get returnConfirm => 'Вернуть';

  @override
  String get returnReasonRequired => 'Напишите, что нужно исправить';

  @override
  String get errPhotoRequired => 'Нужно фото выполненной работы';

  @override
  String get errNotAllowed =>
      'Это действие недоступно для вашей роли или текущего статуса';

  @override
  String get formNewTitle => 'Новая заявка';

  @override
  String get formEditTitle => 'Редактировать заявку';

  @override
  String get formWhat => 'Что случилось?';

  @override
  String get formWhatHint => 'Например, протекает кран';

  @override
  String get formDetailsHint => 'Подробности';

  @override
  String formNoObjects(String tab) {
    return 'Нет объектов — добавьте во вкладке «$tab»';
  }

  @override
  String get formChooseObject => 'Выберите объект';

  @override
  String get formRecurring => 'Регламентная (повторяющаяся)';

  @override
  String get formWhatRequired => 'Напишите, что случилось';

  @override
  String get formSaveFailed =>
      'Не удалось сохранить заявку. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get formLayersFailed =>
      'Не удалось загрузить виды работ. Заявку можно отправить без него.';

  @override
  String get voiceTitle => 'Голосовая заявка';

  @override
  String get voiceStarting => 'Включаю микрофон…';

  @override
  String get voiceListening => 'Слушаю';

  @override
  String get voiceProcessing => 'Распознаю…';

  @override
  String get voiceFailedTitle => 'Не получилось';

  @override
  String get voicePrompt =>
      'Скажите, что случилось и где.\nНапример: «В переговорной на третьем этаже не работает кондиционер».';

  @override
  String voiceTimer(String elapsed, int left) {
    return '$elapsed · осталось $left с';
  }

  @override
  String get voiceProcessingHint => 'Это займёт несколько секунд';

  @override
  String get voiceDone => 'Готово';

  @override
  String get voiceAgain => 'Ещё раз';

  @override
  String get voiceNoMicPermission =>
      'Нужен доступ к микрофону. Разрешите его в настройках телефона и попробуйте снова.';

  @override
  String get voiceMicFailed =>
      'Не удалось включить микрофон. Попробуйте ещё раз.';

  @override
  String get voiceTooShort =>
      'Слишком коротко. Нажмите «Ещё раз» и опишите проблему.';

  @override
  String get voiceRecognizeFailed =>
      'Не получилось распознать запись. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get voiceConfirmTitle => 'Проверьте заявку';

  @override
  String get voiceYouSaid => 'Вы сказали';

  @override
  String quoted(String text) {
    return '«$text»';
  }

  @override
  String get voicePickLayer =>
      'Выберите вид работ, чтобы заявка сразу ушла нужному подрядчику.';

  @override
  String get voiceWhere => 'Где';

  @override
  String voiceHeard(String hint) {
    return 'Услышали: «$hint»';
  }

  @override
  String get voiceUrgency => 'Срочность';

  @override
  String get voiceSend => 'Отправить';

  @override
  String get voiceSendFailed =>
      'Не удалось отправить заявку. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get objectTypeOffice => 'Офис';

  @override
  String get objectTypeHotel => 'Гостиница';

  @override
  String get objectTypeApartments => 'Апартаменты';

  @override
  String get objectTypeWarehouse => 'Склад';

  @override
  String get objectTypeOther => 'Другое';

  @override
  String get commonAdd => 'Добавить';

  @override
  String get objectsLoadFailed =>
      'Не удалось загрузить объекты. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get objectsEmpty => 'Пока нет объектов.\nНажмите «Добавить».';

  @override
  String get objectFormTitle => 'Новая локация';

  @override
  String get objectFormName => 'Наименование локации';

  @override
  String get objectFormNameHint => 'Например, БЦ «Северная башня»';

  @override
  String get objectFormAddress => 'Адрес';

  @override
  String get objectFormAddressHint => 'Город, улица, дом';

  @override
  String get objectFormType => 'Тип';

  @override
  String get objectFormNameRequired => 'Напишите название';

  @override
  String get objectAdded => 'Локация добавлена';

  @override
  String get contractorsLoadFailed =>
      'Не удалось загрузить подрядчиков. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get contractorsEmpty => 'Пока нет подрядчиков.\nНажмите «Добавить».';

  @override
  String get contractorFormTitle => 'Новый исполнитель';

  @override
  String get contractorFormName => 'Наименование организации';

  @override
  String get contractorFormNameHint => 'Например, СтройКом';

  @override
  String get contractorFormNameRequired => 'Напишите название организации';

  @override
  String get contractorAdded => 'Исполнитель добавлен';

  @override
  String get saveFailed =>
      'Не удалось сохранить. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get onboardingTitle => 'Начало работы';

  @override
  String onboardingChoose(String appName) {
    return 'Выберите, как вы будете работать в $appName';
  }

  @override
  String get onboardingCreateTitle => 'Создать компанию';

  @override
  String get onboardingCreateSubtitle =>
      'Для владельцев и управляющих объектами. Вы станете администратором.';

  @override
  String get onboardingCompanyName => 'Название компании';

  @override
  String get onboardingCreate => 'Создать';

  @override
  String get onboardingInviteTitle => 'У меня есть код приглашения';

  @override
  String get onboardingInviteSubtitle =>
      'Для исполнителей подрядных организаций.';

  @override
  String get onboardingInviteCode => 'Код приглашения';

  @override
  String get onboardingJoin => 'Вступить';

  @override
  String get onboardingNoConnection =>
      'Нет связи с сервером. Попробуйте ещё раз.';

  @override
  String get onbErrNotAuthenticated => 'Войдите в аккаунт, чтобы продолжить.';

  @override
  String get onbErrCompanyNameRequired => 'Укажите название компании.';

  @override
  String get onbErrAlreadyInCompany => 'Вы уже состоите в компании.';

  @override
  String get onbErrInviteNotFound =>
      'Код приглашения не найден. Проверьте, что он введён полностью.';

  @override
  String get onbErrInviteUsed => 'Этот код приглашения уже использован.';

  @override
  String get onbErrInviteExpired =>
      'Срок действия приглашения истёк. Попросите новый код.';

  @override
  String get onbErrOtherCompany =>
      'Ваш аккаунт уже привязан к другой компании.';

  @override
  String get onbErrAdminOnly => 'Менять роли может только администратор.';

  @override
  String get onbErrOwnRole => 'Нельзя изменить собственную роль.';

  @override
  String get onbErrProfileNotFound =>
      'Пользователь не найден в вашей компании.';

  @override
  String get onbErrUnknown =>
      'Не удалось выполнить действие. Попробуйте ещё раз.';

  @override
  String get adminTitle => 'Администрирование';

  @override
  String get adminObjects => 'Объекты и геолокация';

  @override
  String get adminDepartments => 'Направления / департаменты';

  @override
  String get adminAssets => 'Оборудование и активы';

  @override
  String get adminContractors => 'Подрядные организации';

  @override
  String get adminInvites => 'Инвайт-ссылки исполнителям';

  @override
  String get adminUsers => 'Пользователи и роли';

  @override
  String get adminComingSoon => 'Появится в Фазе 1';

  @override
  String get reportsComingTitle => 'Отчёты появятся в Фазе 1';

  @override
  String get reportsComingBody =>
      'Фильтры: объект, тип работ, исполнитель, период, время.\nЭкспорт: CSV / XLSX / PDF / отправка на почту.';
}
