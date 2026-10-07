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
  String get tabContractors => 'Подрядчики';

  @override
  String get tabLocations => 'Локации';

  @override
  String get reportsKpiRequests => 'заявок';

  @override
  String get reportsKpiOnTime => 'в срок';

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
  String get photosTitle => 'Фото';

  @override
  String get photosBefore => 'До';

  @override
  String get photosAfter => 'После';

  @override
  String get photosNone => 'Нет фото';

  @override
  String get photoTakeResult => 'Сфотографировать результат';

  @override
  String get photoTakeMore => 'Ещё фото';

  @override
  String get photoAddBefore => 'Добавить фото «до»';

  @override
  String get photoUploading => 'Загружаю фото…';

  @override
  String get photoUploaded => 'Фото добавлено';

  @override
  String get photoUploadFailed =>
      'Не удалось загрузить фото. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get photoCameraDenied =>
      'Нужен доступ к камере. Разрешите его в настройках телефона и попробуйте снова.';

  @override
  String get photoCameraFailed =>
      'Не удалось открыть камеру. Попробуйте ещё раз.';

  @override
  String get photoLoadFailed => 'Не удалось загрузить фото';

  @override
  String get photoNeededHint =>
      'Сфотографируйте результат: без фото «после» отправить на проверку нельзя.';

  @override
  String photoTakenAt(String date) {
    return 'Снято $date';
  }

  @override
  String get photoNoLocation => 'Без геометки';

  @override
  String get photoWithLocation => 'С геометкой';

  @override
  String get photoMockLocation => 'Координаты могли быть подменены';

  @override
  String get visitsTitle => 'Посещения';

  @override
  String visitOnSiteRange(String from, String to) {
    return 'На объекте $from–$to';
  }

  @override
  String visitOnSiteSince(String from) {
    return 'На объекте с $from';
  }

  @override
  String get visitInGeofence => 'в геозоне ✓';

  @override
  String get visitOutsideGeofence => 'вне геозоны ⚠';

  @override
  String get visitGeofenceUnknown => 'геозона не проверена';

  @override
  String visitDistance(String meters) {
    return '$meters м от объекта';
  }

  @override
  String get visitMockLocation => 'Подозрение на подмену GPS';

  @override
  String get visitOutsideWarning =>
      'Исполнитель отметился вне геозоны объекта или с подменой GPS. Проверьте, был ли он на месте.';

  @override
  String get visitsLoadFailed => 'Не удалось загрузить посещения';

  @override
  String get visitNotRecorded =>
      'Работа начата, но посещение не отмечено. Проверьте интернет.';

  @override
  String get visitNoLocation =>
      'Работа начата без геолокации. Включите её, чтобы посещение проверялось по геозоне.';

  @override
  String get reportsManagerOnly =>
      'Отчёты доступны менеджеру и администратору.';

  @override
  String get reportsPeriodWeek => 'Неделя';

  @override
  String get reportsPeriodMonth => 'Месяц';

  @override
  String get reportsPeriodCustom => 'Свой период';

  @override
  String reportsRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get reportsFilterObject => 'Объект';

  @override
  String get reportsFilterContractor => 'Подрядчик';

  @override
  String get reportsFilterLayer => 'Вид работ';

  @override
  String get reportsFilterAll => 'Все';

  @override
  String get reportsLoadFailed =>
      'Не удалось загрузить отчёт. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get reportsEmpty => 'За этот период заявок и посещений нет.';

  @override
  String get reportsKpiFirstPass => 'приняты с первого раза';

  @override
  String get reportsKpiGeofence => 'визитов в геозоне';

  @override
  String reportsKpiOf(int count) {
    return 'из $count';
  }

  @override
  String get reportsByContractor => 'По подрядчикам';

  @override
  String get reportsNoContractor => 'Без подрядчика';

  @override
  String get reportsOrders => 'Заявок';

  @override
  String get reportsAccepted => 'Принято';

  @override
  String get reportsReturned => 'Возвращено';

  @override
  String get reportsOverdue => 'Просрочено';

  @override
  String get reportsOnTime => 'В срок';

  @override
  String get reportsFirstPass => 'С первого раза';

  @override
  String get reportsReaction => 'Реакция';

  @override
  String get reportsExecution => 'Выполнение';

  @override
  String get reportsVisits => 'Визиты';

  @override
  String get reportsVisitsInZone => 'В геозоне';

  @override
  String get reportsVisitsSuspicious => 'Вне геозоны или подмена GPS';

  @override
  String get reportsOnSite => 'Время на объекте';

  @override
  String get reportsPhotos => 'С фото «до» и «после»';

  @override
  String get reportsVisitNorm => 'Визиты: факт / норма';

  @override
  String reportsFactNorm(String fact, String norm) {
    return '$fact / $norm';
  }

  @override
  String get reportsNoValue => '—';

  @override
  String get reportsNormsMissing =>
      'Норма посещений по договору появится после обновления базы.';

  @override
  String get reportsHelp =>
      'В срок — доля принятых до дедлайна среди заявок с дедлайном. С первого раза — принятые без возврата на доработку. Реакция — от создания заявки до «В работе», выполнение — от «В работе» до «На проверке». Норма визитов пересчитана на длину периода.';

  @override
  String get reportsOrdersEmpty => 'Заявок за период нет.';

  @override
  String reportsReturnedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'возвращали $count раза',
      many: 'возвращали $count раз',
      few: 'возвращали $count раза',
      one: 'возвращали $count раз',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(String minutes) {
    return '$minutes мин';
  }

  @override
  String durationHoursMinutes(String hours, String minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String durationDaysHours(String days, String hours) {
    return '$days д $hours ч';
  }

  @override
  String get visitAlreadyOpen =>
      'Посещение уже отмечено — вы на объекте. Продолжайте работу.';

  @override
  String get cardLoadFailed =>
      'Не удалось загрузить карточку. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get cardContractorOrders => 'Заявки подрядчика';

  @override
  String get cardContractorReport => 'Отчёт';

  @override
  String get cardBindingsTitle => 'Виды работ и объекты';

  @override
  String get cardBindingsEmpty => 'Закреплений пока нет.';

  @override
  String get cardAllObjects => 'Все объекты';

  @override
  String get cardNormHint => 'Нажмите на строку, чтобы изменить норму визитов.';

  @override
  String get cardNormNotSet => 'Норма визитов не задана';

  @override
  String cardNormPerMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Норма: $count визита в месяц',
      many: 'Норма: $count визитов в месяц',
      few: 'Норма: $count визита в месяц',
      one: 'Норма: $count визит в месяц',
    );
    return '$_temp0';
  }

  @override
  String get cardNormDialogTitle => 'Норма визитов в месяц';

  @override
  String get cardNormDialogHint => 'Например, 4. Пусто — без нормы';

  @override
  String get cardNormInvalid => 'Введите число от 0 до 1000';

  @override
  String get cardExecutorsTitle => 'Исполнители и контакты';

  @override
  String get cardExecutorsEmpty =>
      'Исполнителей пока нет. Пригласите их по коду приглашения.';

  @override
  String get cardCoordinates => 'Координаты';

  @override
  String get cardCoordinatesNotSet => 'не заданы';

  @override
  String get cardGeofenceRadius => 'Радиус геозоны';

  @override
  String cardMeters(String value) {
    return '$value м';
  }

  @override
  String get cardNoCoordinatesHint =>
      'Без координат визиты на этом объекте не проверяются по геозоне.';

  @override
  String get cardEditGeo => 'Адрес и геозона';

  @override
  String get cardLatitude => 'Широта';

  @override
  String get cardLongitude => 'Долгота';

  @override
  String get cardUseMyLocation => 'Взять мои координаты';

  @override
  String get cardLocationFailed =>
      'Не удалось определить местоположение. Включите геолокацию и разрешите её приложению.';

  @override
  String get cardGeofenceRadiusInput => 'Радиус геозоны, м (20–5000)';

  @override
  String get cardCoordinatesBoth =>
      'Укажите и широту, и долготу — или оставьте обе пустыми.';

  @override
  String get cardCoordinatesInvalid =>
      'Проверьте координаты: широта от −90 до 90, долгота от −180 до 180.';

  @override
  String get cardRadiusInvalid => 'Радиус — целое число от 20 до 5000 м.';

  @override
  String get cardPlacesTitle => 'Помещения';

  @override
  String get cardPlacesEmpty => 'Помещений пока нет.';

  @override
  String get cardObjectContractorsTitle => 'Подрядчики по видам работ';

  @override
  String get cardRecentOrders => 'Последние заявки';

  @override
  String get cardOrdersEmpty => 'Заявок пока нет.';

  @override
  String get cardAllObjectOrders => 'Все заявки по объекту';

  @override
  String get historyLoadFailed =>
      'Не удалось загрузить историю. Проверьте интернет и попробуйте ещё раз.';

  @override
  String historyDoneInPeriod(int count) {
    return 'Выполнено за период: $count';
  }

  @override
  String get historyEmpty => 'За этот период завершённых заявок нет.';

  @override
  String historyAcceptedAt(String date) {
    return 'Принята $date';
  }

  @override
  String historyCancelledAt(String date) {
    return 'Отменена $date';
  }

  @override
  String historyExecution(String time) {
    return 'Выполнение: $time';
  }

  @override
  String historyExecutor(String name) {
    return 'Исполнитель: $name';
  }

  @override
  String get historyVisitInGeofence => 'Визит в геозоне ✓';

  @override
  String get historyVisitOutside => 'Визит вне геозоны или с подменой GPS';
}
