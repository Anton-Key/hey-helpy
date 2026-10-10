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
  String get fieldContractor => 'Подрядчик';

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
  String get actionAssign => 'Назначить подрядчика';

  @override
  String get actionReassign => 'Сменить подрядчика';

  @override
  String get actionStart => 'Начать работу';

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
  String get toastAssigned => 'Подрядчик назначен';

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
  String get voiceProcessing => 'Разбираю заявку…';

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
  String get voiceDone => 'Готово';

  @override
  String get voiceAgain => 'Ещё раз';

  @override
  String get voiceMicFailed =>
      'Не удалось включить микрофон. Попробуйте ещё раз.';

  @override
  String get voiceRecognizeFailed =>
      'Не получилось распознать речь. Попробуйте ещё раз или введите заявку текстом.';

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
  String get voiceAutoStop => 'После паузы в 3 секунды закончу сам';

  @override
  String get voiceNoMicPermissionWeb =>
      'Браузер не дал доступ к микрофону. Нажмите на значок замка или микрофона в адресной строке → «Микрофон» → «Разрешить» и нажмите «Ещё раз». На iPhone: Настройки → Safari → Микрофон → «Разрешить»; ещё должна быть включена диктовка (Настройки → Основные → Клавиатура).';

  @override
  String voiceNoMicPermissionApp(String app) {
    return 'Нужен доступ к микрофону: Настройки телефона → Приложения → $app → Разрешения → Микрофон → «Разрешить». Затем нажмите «Ещё раз».';
  }

  @override
  String get voiceUnsupportedWeb =>
      'В этом браузере нет распознавания речи (например, в Firefox). Откройте приложение в Chrome, Edge или Safari — или введите заявку текстом.';

  @override
  String get voiceUnsupportedApp =>
      'На телефоне не найден сервис распознавания речи (обычно это приложение Google). Введите заявку текстом.';

  @override
  String get voiceNetwork =>
      'Нет связи с сервисом распознавания речи. Проверьте интернет или введите заявку текстом.';

  @override
  String get voiceNothingHeard =>
      'Ничего не услышал. Нажмите «Ещё раз» и скажите, что случилось, — или введите текстом.';

  @override
  String get voiceTypeInstead => 'Ввести текстом';

  @override
  String get voiceTypeTitle => 'Опишите заявку';

  @override
  String get voiceTypeHint =>
      'Что случилось и где? Например: «В переговорной на третьем этаже не работает кондиционер»';

  @override
  String get voiceNext => 'Далее';

  @override
  String get voiceYouWrote => 'Вы написали';

  @override
  String get voiceEditHint =>
      'Заголовок и описание можно поправить перед отправкой.';

  @override
  String get voiceParsedByAi => 'Разобрано ИИ';

  @override
  String get voiceParsedByDictionary => 'Разобрано по словарю';

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
  String get reportsPeriodCustom => 'Свой';

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
      'В срок — доля заявок, принятых не позже дедлайна, среди всех заявок с дедлайном: не в срок — принятые после дедлайна и не закрытые, у которых дедлайн прошёл; отменённые не считаются. С первого раза — принятые без возврата на доработку. Реакция — от создания заявки до «В работе», выполнение — от «В работе» до «На проверке». Норма визитов пересчитана на длину периода и округлена до целого (меньше 1 — до десятых).';

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

  @override
  String get reportsPeriod30 => '30 дней';

  @override
  String get companyNameLabel => 'Компания';

  @override
  String get companyRenameTitle => 'Название компании';

  @override
  String get companyRenamed => 'Название сохранено';

  @override
  String get companyRenameUnavailable =>
      'Название пока нельзя изменить: нужно обновить базу. Сообщите администратору.';

  @override
  String get companyLoadFailed =>
      'Не удалось загрузить данные компании. Проверьте интернет.';

  @override
  String companyMembers(int count) {
    return 'Сотрудники: $count';
  }

  @override
  String companyMemberYou(String name) {
    return '$name (вы)';
  }

  @override
  String get companyNoPhone => 'Телефон не указан';

  @override
  String get companyRoleChange => 'Изменить роль';

  @override
  String companyRoleTitle(String name) {
    return 'Роль: $name';
  }

  @override
  String get companyRoleExecutorHint =>
      'Чтобы исполнитель видел заявки, его нужно привязать к подрядчику — через приглашение.';

  @override
  String get companyRoleChanged => 'Роль изменена';

  @override
  String get companyInvites => 'Приглашения';

  @override
  String get companyInvite => 'Пригласить';

  @override
  String get companyNoInvites => 'Активных приглашений нет.';

  @override
  String companyInviteRow(String contractor, String date) {
    return '$contractor · до $date';
  }

  @override
  String get companyDirectory => 'Справочники';

  @override
  String get inviteTitle => 'Пригласить исполнителя';

  @override
  String get inviteContractor => 'Подрядчик';

  @override
  String get inviteRoleInfo =>
      'Роль: исполнитель этого подрядчика. Он увидит заявки подрядчика и сможет их выполнять. Другую роль можно назначить потом в списке сотрудников.';

  @override
  String get inviteValidity => 'Срок действия';

  @override
  String inviteDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String get inviteCreate => 'Создать';

  @override
  String get inviteFailed =>
      'Не удалось создать приглашение. Попробуйте ещё раз.';

  @override
  String get inviteNoContractors =>
      'Сначала добавьте подрядчика на вкладке «Подрядчики».';

  @override
  String inviteReadyTitle(String contractor) {
    return 'Приглашение в «$contractor»';
  }

  @override
  String inviteValidUntil(String date) {
    return 'Действует до $date, один раз';
  }

  @override
  String get inviteCodeLabel => 'Код';

  @override
  String get inviteLinkLabel => 'Ссылка (веб-версия)';

  @override
  String get inviteHowTo =>
      'Новый сотрудник регистрируется в приложении и вводит код в блоке «У меня есть код приглашения». По ссылке на сайте код подставится сам.';

  @override
  String get inviteCopyMessage => 'Скопировать приглашение';

  @override
  String get inviteCopyCode => 'Скопировать код';

  @override
  String get inviteCopied =>
      'Приглашение скопировано — отправьте его в мессенджере';

  @override
  String get inviteCodeCopied => 'Код скопирован';

  @override
  String get inviteRevoke => 'Отозвать приглашение';

  @override
  String get inviteRevoked => 'Приглашение отозвано';

  @override
  String inviteMessage(
      String app, String contractor, String link, String code, String date) {
    return 'Вас приглашают в $app как исполнителя «$contractor».\nОткройте ссылку: $link\nили установите приложение и введите код: $code\nДействует до $date.';
  }

  @override
  String get settingsProfile => 'Профиль';

  @override
  String get settingsName => 'Имя и фамилия';

  @override
  String get settingsPhone => 'Телефон';

  @override
  String get settingsPhoneHint => '+7 900 000-00-00';

  @override
  String get settingsSaved => 'Сохранено';

  @override
  String get settingsSaveFailed =>
      'Не удалось сохранить. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get settingsPassword => 'Пароль';

  @override
  String get settingsNewPassword => 'Новый пароль';

  @override
  String get settingsRepeatPassword => 'Повторите пароль';

  @override
  String get settingsChangePassword => 'Сменить пароль';

  @override
  String settingsPasswordShort(int count) {
    return 'Пароль — не короче $count символов';
  }

  @override
  String get settingsPasswordMismatch => 'Пароли не совпадают';

  @override
  String get settingsPasswordChanged => 'Пароль изменён';

  @override
  String get settingsPasswordFailed =>
      'Не удалось сменить пароль. Возможно, он совпадает со старым или слишком простой.';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String settingsAboutApp(String app) {
    return 'О приложении $app';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'Версия $version (сборка $build)';
  }

  @override
  String settingsAboutText(String app) {
    return '$app — сервис эксплуатации зданий: приём заявок текстом, голосом и с фото, отправка подрядчику, контроль визитов и приёмка работ.';
  }

  @override
  String notifPeriod(int days) {
    return 'За последние $days дней';
  }

  @override
  String get notifEmpty => 'Новых событий нет';

  @override
  String get notifLoadFailed =>
      'Не удалось загрузить уведомления. Проверьте интернет.';

  @override
  String get notifAssigned => 'Новая заявка для вашего подрядчика';

  @override
  String get notifReturned => 'Работу вернули на доработку';

  @override
  String get notifOnReview => 'Работа ждёт приёмки';

  @override
  String get notifOverdue => 'Срок прошёл, заявка не закрыта';

  @override
  String get notifVisitOutside => 'Визит вне геозоны';

  @override
  String notifVisitOutsideM(String meters) {
    return 'Визит вне геозоны: $meters м от объекта';
  }

  @override
  String get notifVisitMock => 'Визит с подменой GPS';

  @override
  String get notifInProgress => 'Вашу заявку взяли в работу';

  @override
  String get notifAccepted => 'Работа по вашей заявке принята';

  @override
  String notifBellTooltip(int count) {
    return 'Уведомления: новых $count';
  }

  @override
  String get assignSearch => 'Поиск подрядчика';

  @override
  String get assignBound => 'Закреплены за этим видом работ';

  @override
  String get assignOthers => 'Другие подрядчики';

  @override
  String get assignAll => 'Подрядчики';

  @override
  String assignNobodyBound(String layer) {
    return 'За «$layer» никто не закреплён — выберите вручную или закрепите в карточке подрядчика';
  }

  @override
  String get assignNoLayer =>
      'Вид работ не указан — выберите подрядчика вручную';

  @override
  String get assignNothingFound => 'Ничего не найдено';

  @override
  String get assignBindingsFailed =>
      'Не удалось загрузить закрепления — список без подсказок.';

  @override
  String assignExecutors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count исполнителей',
      few: '$count исполнителя',
      one: '$count исполнитель',
      zero: 'Исполнителей нет',
    );
    return '$_temp0';
  }

  @override
  String assignNorm(int count) {
    return 'норма $count в мес.';
  }

  @override
  String get assignAllObjects => 'все объекты';

  @override
  String get assignCurrent => 'Назначен сейчас';

  @override
  String get assignInline => 'Назначить';

  @override
  String get assignChangeInline => 'Изменить';

  @override
  String toastAssignedTo(String name) {
    return 'Назначено: $name';
  }

  @override
  String get fieldExecutor => 'Исполнитель';

  @override
  String get voiceNetworkWeb =>
      'Нет связи с сервисом распознавания речи браузера. Проверьте интернет и нажмите «Ещё раз» — или введите заявку текстом.';

  @override
  String get voiceMicFailedWeb =>
      'Браузер не получает звук с микрофона. Проверьте, какой микрофон выбран: chrome://settings/content/microphone (в Edge — edge://settings/content/microphone), и нажмите «Ещё раз».';

  @override
  String voiceErrorCode(String code) {
    return 'код: $code';
  }

  @override
  String get voiceMicSilent =>
      'Микрофон не слышит звук — проверьте, какой микрофон выбран';

  @override
  String get voiceBrowserHint =>
      'Для голосового ввода лучше открыть в Google Chrome или Microsoft Edge';

  @override
  String get detailMore => 'Ещё';

  @override
  String get actionDelete => 'Удалить';

  @override
  String get deleteOrderConfirm =>
      'Удалить заявку безвозвратно? История, фото и отчёты по ней исчезнут. Если работа просто не нужна — лучше «Отменить».';

  @override
  String get toastDeleted => 'Заявка удалена';

  @override
  String get deleteOrderDenied =>
      'Удалять заявки может только менеджер. Заявка не удалена.';

  @override
  String get deleteOrderFailed =>
      'Не удалось удалить заявку. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get mapViewList => 'Список';

  @override
  String get mapViewMap => 'Карта';

  @override
  String get mapZoomIn => 'Приблизить';

  @override
  String get mapZoomOut => 'Отдалить';

  @override
  String get mapFitAll => 'Показать все объекты';

  @override
  String get mapMyLocation => 'Где я';

  @override
  String get mapMyLocationFailed =>
      'Не удалось определить, где вы. Включите геолокацию и разрешите её приложению.';

  @override
  String get mapSelectArea => 'Выделить область';

  @override
  String get mapSelectAreaHint => 'Протяните рамку по карте';

  @override
  String get mapSearchHere => 'Искать в этой области';

  @override
  String mapInArea(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count объекта',
      many: '$count объектов',
      few: '$count объекта',
      one: '$count объект',
      zero: 'нет объектов',
    );
    return 'В области: $_temp0';
  }

  @override
  String mapInRect(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count объекта',
      many: '$count объектов',
      few: '$count объекта',
      one: '$count объект',
      zero: 'нет объектов',
    );
    return 'В выделенной области: $_temp0';
  }

  @override
  String mapNearby(int count, String radius) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count объекта',
      many: '$count объектов',
      few: '$count объекта',
      one: '$count объект',
      zero: 'нет объектов',
    );
    return 'Рядом, до $radius: $_temp0';
  }

  @override
  String get mapReset => 'сбросить';

  @override
  String get mapNearbyTitle => 'Объекты рядом';

  @override
  String mapKm(String value) {
    return '$value км';
  }

  @override
  String get mapNearbyHelp =>
      'Правый клик или долгое нажатие на карте — объекты рядом. Shift + перетаскивание — выделить область.';

  @override
  String mapNoCoordinates(int count) {
    return 'Без места на карте ($count)';
  }

  @override
  String get mapSetOnMap => 'Указать на карте';

  @override
  String get mapMoveOnMap => 'Изменить место на карте';

  @override
  String mapPlaceHint(String name) {
    return 'Передвиньте карту: перекрестие — на «$name»';
  }

  @override
  String get mapSaveHere => 'Сохранить здесь';

  @override
  String get mapPlaceSaved => 'Место на карте сохранено';

  @override
  String get mapOpenObject => 'Открыть объект';

  @override
  String get mapOrders => 'Заявки';

  @override
  String get mapCreateHere => 'Создать заявку здесь';

  @override
  String get mapCountNew => 'Новые';

  @override
  String get mapCountInWork => 'В работе';

  @override
  String get mapCountOnReview => 'На проверке';

  @override
  String get mapCountOverdue => 'Просрочено';

  @override
  String mapOpenOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count открытой заявки',
      many: '$count открытых заявок',
      few: '$count открытые заявки',
      one: '$count открытая заявка',
      zero: 'Открытых заявок нет',
    );
    return '$_temp0';
  }

  @override
  String get mapSearchHint => 'Поиск по названию и адресу';

  @override
  String get mapNothingFound => 'Ничего не найдено';

  @override
  String mapListTitle(int count) {
    return 'Объекты на карте ($count)';
  }

  @override
  String get mapOrdersFailed =>
      'Не удалось загрузить заявки — числа на маркерах могут быть неточными.';

  @override
  String get mapClose => 'Закрыть';

  @override
  String mapCluster(int count) {
    return 'Объектов: $count. Нажмите, чтобы приблизить';
  }

  @override
  String requestsFilterObject(String name) {
    return 'Объект: $name';
  }

  @override
  String get requestsFilterClear => 'Снять фильтр';

  @override
  String get reqSearchHint => 'Поиск по заявкам';

  @override
  String reqSegAll(int count) {
    return 'Все · $count';
  }

  @override
  String reqSegOpen(int count) {
    return 'Открытые · $count';
  }

  @override
  String reqSegOverdue(int count) {
    return 'Просрочено · $count';
  }

  @override
  String get reqGroupToday => 'Сегодня';

  @override
  String get reqGroupEarlier => 'Ранее';

  @override
  String get reqNothingFound => 'Ничего не найдено';

  @override
  String get reqFieldPlace => 'Помещение';

  @override
  String get reqFieldDue => 'Срок';

  @override
  String get reqViaVoice => 'голосом';

  @override
  String get reqViaText => 'текстом';

  @override
  String get filterPeriod => 'Период';

  @override
  String get filterObject => 'Объект';

  @override
  String get filterRoom => 'Помещение';

  @override
  String get filterContractor => 'Подрядчик';

  @override
  String get filterPriority => 'Срочность';

  @override
  String get filterStatus => 'Статус';

  @override
  String get filterWorkType => 'Вид работ';

  @override
  String get filterMore => 'Ещё';

  @override
  String get filterSort => 'Сортировка';

  @override
  String get filterPeriodToday => 'Сегодня';

  @override
  String get filterPeriod7 => '7 дней';

  @override
  String get filterPeriod30 => '30 дней';

  @override
  String get filterPeriodThisMonth => 'Этот месяц';

  @override
  String get filterPeriodLastMonth => 'Прошлый месяц';

  @override
  String get filterPeriodCustom => 'Свой период…';

  @override
  String get filterByCreated => 'По дате создания';

  @override
  String get filterByDue => 'По сроку';

  @override
  String filterDueLabel(String period) {
    return 'Срок: $period';
  }

  @override
  String get filterNoContractor => 'Без подрядчика';

  @override
  String get filterOverdue => 'Просрочено';

  @override
  String get filterType => 'Тип';

  @override
  String get filterOnce => 'Разовая';

  @override
  String get filterRecurring => 'Повторяющаяся';

  @override
  String get filterSource => 'Источник';

  @override
  String get filterChannelVoice => 'Голос';

  @override
  String get filterChannelText => 'Текст';

  @override
  String get filterChannelButton => 'Вручную';

  @override
  String get filterOptions => 'Условия';

  @override
  String get filterNeedsPhoto => 'Нужно фото';

  @override
  String get filterReturned => 'Возвращались на доработку';

  @override
  String get filterCreatedByMe => 'Создал я';

  @override
  String get filterAssignedToMe => 'Назначено мне';

  @override
  String filterMoreCount(int count) {
    return 'Ещё · $count';
  }

  @override
  String filterPlus(String label, int count) {
    return '$label +$count';
  }

  @override
  String get sortNewest => 'Сначала новые';

  @override
  String get sortOldest => 'Сначала старые';

  @override
  String get sortDue => 'По сроку';

  @override
  String get sortPriority => 'По срочности';

  @override
  String get sortStatus => 'По статусу';

  @override
  String get sortObject => 'По объекту';

  @override
  String get filterReset => 'Сбросить';

  @override
  String get filterApply => 'Применить';

  @override
  String filterApplyCount(int count) {
    return 'Применить ($count)';
  }

  @override
  String get filterResetAll => 'Сбросить всё';

  @override
  String filterFound(int shown, int total) {
    return 'Найдено $shown из $total';
  }

  @override
  String get filterResetFilters => 'Сбросить фильтры';

  @override
  String get filterSearchHint => 'Поиск по списку';

  @override
  String filterClearOne(String name) {
    return 'Убрать фильтр «$name»';
  }

  @override
  String filterRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get filterPickDates => 'Выберите даты';

  @override
  String get cityNone => 'Без города';

  @override
  String cityCount(String city, int count) {
    return '$city · $count';
  }

  @override
  String get cityAll => 'Все';

  @override
  String get filterCityAll => 'Весь город';

  @override
  String filterCityWhole(String city, int count) {
    return '$city ($count)';
  }

  @override
  String objectsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count объекта',
      many: '$count объектов',
      few: '$count объекта',
      one: '$count объект',
    );
    return '$_temp0';
  }

  @override
  String contractorCoverage(String cities, String objects) {
    return '$cities · $objects';
  }

  @override
  String get cardWorkTypes => 'Виды работ';

  @override
  String get cardObjectsByCity => 'Объекты';

  @override
  String mapCityZoom(String city) {
    return 'Показать город $city';
  }

  @override
  String get filterAll => 'Фильтры';

  @override
  String filterAllCount(int count) {
    return 'Фильтры · $count';
  }

  @override
  String get filterAllWide => 'Все фильтры';

  @override
  String filterAllWideCount(int count) {
    return 'Все фильтры · $count';
  }

  @override
  String get filterAny => 'Все';

  @override
  String get filterShow => 'Показать';

  @override
  String filterShowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Показать $count заявок',
      few: 'Показать $count заявки',
      one: 'Показать $count заявку',
      zero: 'Нет заявок',
    );
    return '$_temp0';
  }

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonGotIt => 'Понятно';

  @override
  String get infoFiltersTitle => 'Как работают фильтры';

  @override
  String get infoFilters1 =>
      'Выберите условия — на кнопке внизу сразу видно, сколько заявок подойдёт.';

  @override
  String get infoFilters2 =>
      '«Показать» применяет фильтры, «×» на таблетке над списком снимает один фильтр.';

  @override
  String get infoFilters3 =>
      'Фильтры запоминаются на этом устройстве, а в браузере — ещё и в адресе страницы: ссылку можно отправить коллеге.';

  @override
  String infoShowHint(String title) {
    return 'Подсказка: $title';
  }

  @override
  String get sortShortNewest => 'Новые';

  @override
  String get sortShortOldest => 'Старые';

  @override
  String get sortShortDue => 'Срок';

  @override
  String get sortShortPriority => 'Срочность';

  @override
  String get sortShortStatus => 'Статус';

  @override
  String get sortShortObject => 'Объект';

  @override
  String get floorsHeader => 'Этажи';

  @override
  String floorsTitle(int count) {
    return 'Этажи · $count';
  }

  @override
  String get floorsEmpty => 'Этажей пока нет';

  @override
  String get floorsEmptyManager =>
      'Добавьте этаж и загрузите план — на нём можно будет отметить помещения и оборудование.';

  @override
  String get floorAdd => 'Этаж';

  @override
  String get floorAddLong => 'Добавить этаж';

  @override
  String floorPlacesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count помещений',
      few: '$count помещения',
      one: '$count помещение',
    );
    return '$_temp0';
  }

  @override
  String floorOpenOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count открытых заявок',
      few: '$count открытые заявки',
      one: '$count открытая заявка',
      zero: 'нет открытых заявок',
    );
    return '$_temp0';
  }

  @override
  String get floorNoPlan => 'Без плана';

  @override
  String get floorFormNew => 'Новый этаж';

  @override
  String get floorFormEdit => 'Этаж';

  @override
  String get floorName => 'Название';

  @override
  String get floorNameHint => 'Например, 3 этаж или Парковка';

  @override
  String get floorLevel => 'Номер этажа';

  @override
  String get floorLevelHint => '−1, −2 — подземные этажи';

  @override
  String get floorPlanImage => 'Картинка плана';

  @override
  String get floorPlanPick => 'Выбрать файл';

  @override
  String get floorPlanOptional => 'Необязательно — план можно загрузить позже.';

  @override
  String get floorNameEmpty => 'Введите название этажа';

  @override
  String get floorNameTooLong => 'Название — не длиннее 60 символов';

  @override
  String get floorNameTaken => 'Этаж с таким названием уже есть';

  @override
  String get floorLevelInvalid =>
      'Номер этажа — целое число, например 3 или −1';

  @override
  String get floorRename => 'Переименовать';

  @override
  String get floorUploadPlan => 'Загрузить план';

  @override
  String get floorReplacePlan => 'Заменить план';

  @override
  String get floorRemovePlan => 'Убрать план';

  @override
  String get floorMoveUp => 'Выше';

  @override
  String get floorMoveDown => 'Ниже';

  @override
  String get floorDelete => 'Удалить этаж';

  @override
  String floorDeleteConfirm(String name) {
    return 'Удалить этаж «$name»?';
  }

  @override
  String get floorDeleteHint =>
      'Помещения и оборудование останутся, но уйдут с плана.';

  @override
  String get floorDeleted => 'Этаж удалён';

  @override
  String floorAddPlace(String name) {
    return 'Добавить помещение на этаж «$name»';
  }

  @override
  String floorMenu(String name) {
    return 'Действия с этажом «$name»';
  }

  @override
  String get planTooBig =>
      'Файл больше 15 МБ. Уменьшите картинку или сохраните её в JPEG.';

  @override
  String get planPdf =>
      'PDF не подходит: сохраните нужную страницу как PNG или сделайте снимок экрана.';

  @override
  String get planBadType => 'Нужна картинка PNG, JPEG или WebP.';

  @override
  String get planUnreadable =>
      'Не удалось прочитать картинку. Попробуйте другой файл.';

  @override
  String get planNoRights =>
      'Менять этажи, планы и маркеры может только менеджер.';

  @override
  String get planUploadFailed =>
      'Не удалось загрузить план. Проверьте интернет и попробуйте ещё раз.';

  @override
  String planStorageDenied(String code) {
    return 'Хранилище отклонило загрузку (код $code). Попробуйте ещё раз или сообщите администратору.';
  }

  @override
  String planDbDenied(String code) {
    return 'База отклонила изменение (код $code). Попробуйте ещё раз или сообщите администратору.';
  }

  @override
  String get planUploaded => 'План загружен';

  @override
  String get planRemoved => 'План убран';

  @override
  String get placeNotOnPlan => 'не на плане';

  @override
  String get infoFloorsTitle => 'Этажи и планы';

  @override
  String get infoFloors1 =>
      'Этаж — часть объекта. У этажа может быть картинка плана.';

  @override
  String get infoFloors2 =>
      'На плане отмечают помещения и оборудование — исполнитель быстрее найдёт место.';

  @override
  String get infoFloors3 =>
      'Добавлять этажи, загружать планы и расставлять маркеры может менеджер. Остальные видят план только для чтения.';

  @override
  String get infoUploadTitle => 'Загрузка плана';

  @override
  String get infoUpload1 => 'Подходят картинки PNG, JPEG и WebP до 15 МБ.';

  @override
  String get infoUpload2 =>
      'PDF: сохраните нужную страницу как PNG или сделайте снимок экрана.';

  @override
  String get infoUpload3 => 'План видят только сотрудники вашей компании.';

  @override
  String get planTitle => 'План этажа';

  @override
  String get planEdit => 'Редактировать';

  @override
  String get planEditMode => 'Режим расстановки';

  @override
  String get planDone => 'Готово';

  @override
  String get planFilterAll => 'Всё';

  @override
  String get planFilterPlaces => 'Помещения';

  @override
  String get planFilterAssets => 'Оборудование';

  @override
  String get planFilterWithOrders => 'С заявками';

  @override
  String planOnPlan(int count) {
    return 'На плане · $count';
  }

  @override
  String planUnplaced(int count) {
    return 'Не размещены · $count';
  }

  @override
  String get planSearch => 'Поиск по помещениям и оборудованию';

  @override
  String get planNotLoaded => 'План не загружен';

  @override
  String get planFit => 'Вписать план';

  @override
  String get planList => 'Список';

  @override
  String get planOpenOrders => 'Открытые заявки';

  @override
  String get planNoOpenOrders => 'Открытых заявок нет';

  @override
  String get planCreateHere => 'Создать заявку здесь';

  @override
  String get planAllPlaceOrders => 'Все заявки помещения';

  @override
  String get planAssetInventory => 'Инвентарный номер';

  @override
  String get planAssetCategory => 'Категория';

  @override
  String get planAssetPlace => 'Помещение';

  @override
  String assetCategory(String code) {
    String _temp0 = intl.Intl.selectLogic(
      code,
      {
        'equipment': 'Оборудование',
        'furniture': 'Мебель',
        'infra': 'Инженерные сети',
        'other': 'Другое',
      },
    );
    return '$_temp0';
  }

  @override
  String get planNewPlaceHere => 'Новое помещение здесь';

  @override
  String get planNewAssetHere => 'Новое оборудование здесь';

  @override
  String get planPutHere => 'Поставить сюда…';

  @override
  String get planRename => 'Переименовать';

  @override
  String get planRemoveFromPlan => 'Убрать с плана';

  @override
  String get planDelete => 'Удалить';

  @override
  String planDeleteConfirm(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String planDeleteHasOrders(String name) {
    return 'У «$name» есть заявки — удалить нельзя. Можно убрать с плана.';
  }

  @override
  String get planSaved => 'Сохранено';

  @override
  String get planUndo => 'Отменить';

  @override
  String get planNewPlace => 'Новое помещение';

  @override
  String get planNewAsset => 'Новое оборудование';

  @override
  String get planNameLabel => 'Название';

  @override
  String get planNameRequired => 'Введите название';

  @override
  String get planInventoryLabel => 'Инвентарный номер (необязательно)';

  @override
  String get planPickUnplaced => 'Что поставить сюда';

  @override
  String get planNothingUnplaced => 'Всё уже на плане';

  @override
  String get planNotFound => 'Этаж не найден или нет доступа.';

  @override
  String get planNoPlaces => 'Сначала добавьте помещение на этот этаж';

  @override
  String get planFloorPicker => 'Этаж';

  @override
  String get planMarkerHint => 'Нажмите на маркер — заявки и действия';

  @override
  String get infoPlanTitle => 'Что значат маркеры';

  @override
  String get infoPlan1 =>
      'Кружок — помещение, число — его открытые заявки. Квадрат — оборудование.';

  @override
  String get infoPlan2 =>
      'Красный — есть просроченные или критические заявки, оранжевый — срочные или в работе.';

  @override
  String get infoPlan3 =>
      'Бирюзовый — есть открытые заявки, серый — открытых нет.';

  @override
  String get infoEditTitle => 'Режим расстановки';

  @override
  String get infoEdit1 =>
      'Перетащите маркер, чтобы передвинуть (на телефоне — долгое нажатие). Сохраняется сразу, можно «Отменить».';

  @override
  String get infoEdit2 =>
      'Нажмите на пустое место — добавьте помещение или оборудование или поставьте то, что ещё не размещено.';

  @override
  String get infoEdit3 =>
      'Нажмите на маркер — переименовать, убрать с плана или удалить.';

  @override
  String get orderShowOnPlan => 'Показать на плане';

  @override
  String planNearby(String floor, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count открытых заявок рядом',
      few: '$count открытые заявки рядом',
      one: '$count открытая заявка рядом',
      zero: 'открытых заявок рядом нет',
    );
    return '$floor · $_temp0';
  }

  @override
  String floorShort(int level) {
    return '$level эт.';
  }

  @override
  String get formPlace => 'Помещение';

  @override
  String get formChoosePlace => 'Без помещения';

  @override
  String get formAsset => 'Оборудование';
}
