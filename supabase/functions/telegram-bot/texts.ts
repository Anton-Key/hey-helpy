// Все тексты бота — RU и EN, в одном месте. Язык — по language_code из
// Telegram: ru… → русский, остальное → английский. Подстановки {name} —
// уже экранированные для HTML (см. esc в bot.ts).

export type Lang = "ru" | "en";

export function langOf(code: string | null | undefined): Lang {
  return (code ?? "").toLowerCase().startsWith("ru") ? "ru" : "en";
}

const RU = {
  // Вход и привязка
  startUnknown:
    "Это бот «Hey Helpy» — сообщить о неисправности на объекте текстом, голосом или фото.\n\n" +
    "Чтобы начать, нужна ссылка от работодателя:\n" +
    "• отсканируйте QR-код на плакате объекта или откройте ссылку компании из рабочего чата;\n" +
    "• если у вас есть аккаунт в приложении — «Профиль → Настройки → Telegram → Подключить Telegram».",
  linked: "Готово, {name}. Теперь можно писать заявки сюда — текстом, голосом или фото.",
  linkedNoName: "Готово. Теперь можно писать заявки сюда — текстом, голосом или фото.",
  badCode: "Код не подошёл или устарел (он действует 15 минут). Получите новый в приложении: «Профиль → Настройки → Telegram».",
  guestObject: "Вы в {object}. Опишите, что случилось, — текстом, голосом или фото.",
  guestCompany: "Вы подключены к «{company}». Опишите, что и где случилось, — текстом, голосом или фото.",
  badLink: "Ссылка не работает: её отключили или пересоздали. Попросите новую у администратора объекта.",
  linkOff: "Ссылка, по которой вы подключались, больше не работает. Попросите новую у администратора объекта или отсканируйте QR-код ещё раз.",
  otherCompany: "Ваш аккаунт относится к другой компании — эта ссылка вам не подходит.",
  userObject: "Объект: {object}. Опишите, что случилось.",
  // Помощь
  help:
    "Опишите, что случилось и где, — текстом, голосом (до 30 с) или фото. Я разберу заявку и попрошу подтвердить.\n\n" +
    "/where — сменить объект\n/cancel — отменить черновик\n/reset — отвязать этот чат\n/help — эта подсказка",
  helpGroup:
    "Упомяните меня в сообщении — например, «@{bot} течёт кран на 2 этаже» — или ответьте на моё сообщение. Остальную переписку я не читаю.",
  groupNotConnected:
    "Эта группа не подключена к объекту. Менеджер может подключить её в приложении: карточка объекта → «Группа Telegram».",
  groupConnected: "Группа подключена к объекту {object}. Упомяните меня (@{bot}) в сообщении о неисправности.",
  connectInPrivate: "Команду /connect отправляют в группе объекта, а не в личном чате.",
  reset: "Чат отвязан. Чтобы снова писать заявки, откройте ссылку или QR-код ещё раз.",
  resetNothing: "Этот чат ни к чему не привязан.",
  cancelled: "Отменено.",
  nothingToCancel: "Отменять нечего.",
  // Разбор
  heard: "Услышал: «{text}»",
  understood: "Понял так:",
  object: "Объект",
  place: "Место",
  wholeObject: "весь объект",
  managerWillClarify: "уточнит менеджер",
  system: "Система",
  equipment: "Оборудование",
  priority: "Срочность",
  photo: "Фото",
  photoAttached: "приложу к заявке",
  createQ: "Создать?",
  aiOff: "ИИ сейчас недоступен — заявка будет создана с текстом как есть.",
  // Кнопки
  bCreate: "✅ Создать",
  bPlace: "📍 Изменить место",
  bPriority: "⚡ Срочность",
  bCancel: "Отмена",
  bBack: "← Назад",
  bWhole: "Весь объект",
  bLocation: "📍 Отправить геопозицию",
  bOtherObject: "Другой объект",
  // Выбор объекта
  askObject: "На каком объекте? Выберите кнопкой или отправьте геопозицию — найду ближайший объект.",
  askPlace: "Где именно?",
  askPriority: "Насколько срочно?",
  noObjects: "Нет объектов, о которых можно сообщить.",
  objectChosen: "Объект: {object}.",
  nearestNotFound: "Рядом (300 м) нет объектов компании. Выберите объект кнопкой.",
  locationOnlyPrivate: "Геопозицию можно отправить только в личном чате.",
  // Итог
  created: "Заявка № {number} принята. Менеджер уже видит её.",
  // Уведомления о статусе (telegram-notify, шаг 24)
  notifyInProgress: "Заявка № {number} «{title}»: взята в работу 🔧",
  notifyDone: "Заявка № {number} «{title}»: выполнена ✅",
  notifyReturned: "Заявка № {number} «{title}»: возвращена исполнителю на доработку",
  notifyCancelled: "Заявка № {number} «{title}»: отклонена",
  notifyReason: "Причина: {reason}",
  bNotifyOff: "🔕 Не присылать уведомления",
  notifyOff: "Хорошо, уведомления о заявках больше не придут. Чтобы снова получать — /start или новая заявка.",
  // Исполнителю: новая заявка и «Взять в работу» (шаг 28)
  assignNew: "🆕 Новая заявка № {number}: {title}",
  assignPriority: "срочность {priority}",
  bTake: "▶️ Взять в работу",
  bOpen: "Открыть",
  bAssignOff: "🔕 Не присылать заявки",
  takeOk: "🔧 Заявка № {number} «{title}» — вы взяли её в работу. Фото «после» и сдача — в приложении.",
  takeAlready: "Заявка № {number} уже в работе.",
  takeNotExecutor: "Эту заявку берёт исполнитель назначенного подрядчика (в бригаде — своей зоны).",
  takeGone: "Заявка недоступна: её отменили, передали другому подрядчику или уже приняли.",
  takeNotLinked: "Этот чат не привязан к аккаунту. Подключите Telegram в приложении: «Настройки → Telegram».",
  openInApp: "Открыть в приложении",
  stale: "Этот черновик уже неактуален — опишите заявку заново.",
  rateLimited: "Слишком много заявок за последний час. Подождите немного или позвоните администратору объекта.",
  rateLimitedLink: "По этой ссылке сегодня уже очень много заявок. Попробуйте позже или позвоните администратору объекта.",
  notAllowed: "На этом объекте вы не можете создавать заявки.",
  failed: "Не получилось, попробуйте ещё раз или напишите текстом.",
  // Голос и фото
  voiceTooLong: "Слишком длинное голосовое — запишите короче (до 30 секунд) или напишите текстом.",
  voiceEmpty: "Не расслышал. Повторите голосом или напишите текстом.",
  photoTooBig: "Фото слишком большое. Отправьте его как обычное фото (не файлом).",
  photoSeen: "На фото: {kind}",
  photoDefect: "Видно: {defect}",
  photoNoAi: "Не получилось разобрать фото — опишите проблему текстом.",
  unsupported: "Я понимаю текст, голосовые и фото.",
  pr_low: "низкая",
  pr_normal: "обычная",
  pr_high: "высокая",
  pr_critical: "авария",
  // Заявка на демо с сайта (шаг 29, /start demo)
  demoAsk:
    "Здравствуйте! Это Hey Helpy. Расскажите в одном сообщении: компания, сколько объектов и в каких городах, что хотите посмотреть. Мы свяжемся с вами здесь, в Telegram.",
  demoThanks: "Спасибо! Мы получили заявку и напишем вам здесь.",
  demoTextOnly: "Напишите, пожалуйста, текстом — одним сообщением: компания, сколько объектов и в каких городах, что хотите посмотреть.",
  demoTooLong: "Слишком длинно — уложитесь, пожалуйста, в 2000 символов.",
  demoLimit: "Мы уже получили ваши заявки сегодня и скоро напишем. Новую можно отправить завтра.",
  demoFailed: "Не получилось сохранить заявку. Попробуйте ещё раз чуть позже: откройте ссылку «Запросить демо» на сайте.",
  demoNotice: "🆕 Заявка на демо: {who}\n\n{text}",
};

export type TextKey = keyof typeof RU;

const EN: Record<TextKey, string> = {
  startUnknown:
    "This is the Hey Helpy bot — report a problem at a site by text, voice or photo.\n\n" +
    "To start you need a link from your employer:\n" +
    "• scan the QR code on the site's poster or open the company link from your work chat;\n" +
    "• if you have an account in the app — “Profile → Settings → Telegram → Connect Telegram”.",
  linked: "Done, {name}. You can now send work orders here — by text, voice or photo.",
  linkedNoName: "Done. You can now send work orders here — by text, voice or photo.",
  badCode: "The code is wrong or expired (it lasts 15 minutes). Get a new one in the app: “Profile → Settings → Telegram”.",
  guestObject: "You are at {object}. Describe what happened — by text, voice or photo.",
  guestCompany: "You are connected to “{company}”. Describe what happened and where — by text, voice or photo.",
  badLink: "This link doesn't work: it was disabled or replaced. Ask the site administrator for a new one.",
  linkOff: "The link you joined with no longer works. Ask the site administrator for a new one or scan the QR code again.",
  otherCompany: "Your account belongs to another company — this link isn't for you.",
  userObject: "Site: {object}. Describe what happened.",
  help:
    "Describe what happened and where — by text, voice (up to 30 s) or photo. I'll draft a work order and ask you to confirm.\n\n" +
    "/where — change site\n/cancel — discard the draft\n/reset — unlink this chat\n/help — this help",
  helpGroup:
    "Mention me in a message — e.g. “@{bot} the tap is leaking on floor 2” — or reply to my message. I don't read the rest of the chat.",
  groupNotConnected:
    "This group isn't connected to a site. A manager can connect it in the app: site card → “Telegram group”.",
  groupConnected: "The group is connected to {object}. Mention me (@{bot}) in a message about a problem.",
  connectInPrivate: "Send /connect in the site's group, not in a private chat.",
  reset: "Chat unlinked. To send work orders again, open the link or QR code again.",
  resetNothing: "This chat isn't linked to anything.",
  cancelled: "Cancelled.",
  nothingToCancel: "Nothing to cancel.",
  heard: "Heard: “{text}”",
  understood: "Here's what I got:",
  object: "Site",
  place: "Place",
  wholeObject: "whole site",
  managerWillClarify: "manager will clarify",
  system: "System",
  equipment: "Equipment",
  priority: "Priority",
  photo: "Photo",
  photoAttached: "will be attached",
  createQ: "Create?",
  aiOff: "AI is unavailable right now — the work order will be created with your text as is.",
  bCreate: "✅ Create",
  bPlace: "📍 Change place",
  bPriority: "⚡ Priority",
  bCancel: "Cancel",
  bBack: "← Back",
  bWhole: "Whole site",
  bLocation: "📍 Send location",
  bOtherObject: "Another site",
  askObject: "Which site? Pick one or send your location — I'll find the nearest site.",
  askPlace: "Where exactly?",
  askPriority: "How urgent is it?",
  noObjects: "There are no sites you can report about.",
  objectChosen: "Site: {object}.",
  nearestNotFound: "No company sites within 300 m. Pick a site with a button.",
  locationOnlyPrivate: "Location can only be sent in a private chat.",
  created: "Work order #{number} received. The manager can already see it.",
  notifyInProgress: "Work order #{number} “{title}”: work started 🔧",
  notifyDone: "Work order #{number} “{title}”: completed ✅",
  notifyReturned: "Work order #{number} “{title}”: returned to the contractor for rework",
  notifyCancelled: "Work order #{number} “{title}”: rejected",
  notifyReason: "Reason: {reason}",
  bNotifyOff: "🔕 Stop notifications",
  notifyOff: "OK, you won't get work order updates any more. To get them again — /start or a new request.",
  // To the contractor's worker: new work order and "Start work" (step 28)
  assignNew: "🆕 New work order #{number}: {title}",
  assignPriority: "priority: {priority}",
  bTake: "▶️ Start work",
  bOpen: "Open",
  bAssignOff: "🔕 Stop work order alerts",
  takeOk: "🔧 Work order #{number} “{title}” — you started work on it. After-photos and handover — in the app.",
  takeAlready: "Work order #{number} is already in progress.",
  takeNotExecutor: "Only a worker of the assigned contractor (in a crew — within its zone) can start this work order.",
  takeGone: "This work order is no longer available: it was cancelled, reassigned or already accepted.",
  takeNotLinked: "This chat isn't linked to an account. Connect Telegram in the app: “Settings → Telegram”.",
  openInApp: "Open in the app",
  stale: "This draft is out of date — please describe the problem again.",
  rateLimited: "Too many work orders in the last hour. Please wait a bit or call the site administrator.",
  rateLimitedLink: "This link has received too many work orders today. Try later or call the site administrator.",
  notAllowed: "You can't create work orders at this site.",
  failed: "That didn't work — please try again or send it as text.",
  voiceTooLong: "The voice message is too long — keep it under 30 seconds or send text.",
  voiceEmpty: "I couldn't hear that. Please repeat or send text.",
  photoTooBig: "The photo is too large. Send it as a regular photo, not a file.",
  photoSeen: "In the photo: {kind}",
  photoDefect: "Visible: {defect}",
  photoNoAi: "I couldn't read the photo — please describe the problem in text.",
  unsupported: "I understand text, voice messages and photos.",
  pr_low: "low",
  pr_normal: "normal",
  pr_high: "high",
  pr_critical: "emergency",
  demoAsk:
    "Hello! This is Hey Helpy. In one message, tell us: your company, how many sites and in which cities, and what you would like to see. We will get back to you here in Telegram.",
  demoThanks: "Thank you! We have received your request and will message you here.",
  demoTextOnly: "Please write it as text, in one message: your company, how many sites and in which cities, and what you would like to see.",
  demoTooLong: "That's too long — please keep it under 2000 characters.",
  demoLimit: "We have already received your requests today and will be in touch soon. You can send a new one tomorrow.",
  demoFailed: "Couldn't save your request. Please try again a bit later: open the “Request a demo” link on the website.",
  demoNotice: "🆕 Demo request: {who}\n\n{text}",
};

export const TEXTS: Record<Lang, Record<TextKey, string>> = { ru: RU, en: EN };

/** Текст на языке [lang] с подстановками {ключ}. */
export function t(
  lang: Lang,
  key: TextKey,
  vars: Record<string, string> = {},
): string {
  return TEXTS[lang][key].replace(
    /\{(\w+)\}/g,
    (m, k) => (k in vars ? vars[k] : m),
  );
}

/** Команды бота для setMyCommands (workflow «Telegram webhook»). */
export const COMMANDS: Record<Lang, { command: string; description: string }[]> = {
  ru: [
    { command: "help", description: "Как сообщить о неисправности" },
    { command: "where", description: "Сменить объект" },
    { command: "cancel", description: "Отменить черновик" },
    { command: "reset", description: "Отвязать этот чат" },
    { command: "stop", description: "Не присылать уведомления о заявках" },
  ],
  en: [
    { command: "help", description: "How to report a problem" },
    { command: "where", description: "Change site" },
    { command: "cancel", description: "Discard the draft" },
    { command: "reset", description: "Unlink this chat" },
    { command: "stop", description: "Stop work order notifications" },
  ],
};
