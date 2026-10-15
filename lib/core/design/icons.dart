import 'package:flutter/widgets.dart';

/// Единый набор значков — Lucide (ISC), тонкая линия (вес 300, штрих 1.55).
///
/// В экранах — только `AppIcons.*`: не `Icons.*` из Material и не другие
/// веса Lucide. Исключение — `*Active` для активной вкладки (штрих 2).
/// Шрифты Lucide лежат в `assets/fonts/lucide/` (шаг 27): пакет
/// `lucide_icons_flutter` тянул в веб-сборку ещё 4 неиспользуемых веса
/// целиком (~870 КБ сжатыми до первого кадра). Нужен новый значок — имя на
/// lucide.dev/icons, код — в `lib/lucide_icons.dart` пакета
/// lucide_icons_flutter 3.1.20 (`<имя>300`); семейство `AppLucide300`,
/// в комментарии — имя.
class AppIcons {
  const AppIcons._();

  // Навигация
  static const home = IconData(0xe0f5, fontFamily: 'AppLucide300'); // house300
  static const history =
      IconData(0xe1f5, fontFamily: 'AppLucide300'); // history300
  static const reports =
      IconData(0xe2a3, fontFamily: 'AppLucide300'); // chartColumn300
  static const profile =
      IconData(0xe462, fontFamily: 'AppLucide300'); // circleUserRound300
  static const chevronRight =
      IconData(0xe06f, fontFamily: 'AppLucide300'); // chevronRight300
  static const chevronLeft =
      IconData(0xe06e, fontFamily: 'AppLucide300'); // chevronLeft300
  static const chevronDown =
      IconData(0xe06d, fontFamily: 'AppLucide300'); // chevronDown300
  static const close = IconData(0xe1b2, fontFamily: 'AppLucide300'); // x300
  static const more =
      IconData(0xe0b6, fontFamily: 'AppLucide300'); // ellipsis300
  static const panelOpen =
      IconData(0xe21d, fontFamily: 'AppLucide300'); // panelLeftOpen300
  static const panelClose =
      IconData(0xe21c, fontFamily: 'AppLucide300'); // panelLeftClose300
  static const help =
      IconData(0xe082, fontFamily: 'AppLucide300'); // circleQuestionMark300

  // Действия
  static const add = IconData(0xe13d, fontFamily: 'AppLucide300'); // plus300
  static const remove =
      IconData(0xe11c, fontFamily: 'AppLucide300'); // minus300
  static const mic = IconData(0xe118, fontFamily: 'AppLucide300'); // mic300
  static const search =
      IconData(0xe151, fontFamily: 'AppLucide300'); // search300
  static const edit = IconData(0xe1f9, fontFamily: 'AppLucide300'); // pencil300
  static const delete =
      IconData(0xe18e, fontFamily: 'AppLucide300'); // trash2300
  static const refresh =
      IconData(0xe149, fontFamily: 'AppLucide300'); // rotateCw300
  static const copy = IconData(0xe09e, fontFamily: 'AppLucide300'); // copy300
  static const link = IconData(0xe102, fontFamily: 'AppLucide300'); // link300
  static const send =
      IconData(0xe4f2, fontFamily: 'AppLucide300'); // sendHorizontal300
  /// Telegram (шаг 23): бренд-значков в Lucide нет — «бумажный самолётик».
  static const telegram =
      IconData(0xe152, fontFamily: 'AppLucide300'); // send300
  static const qr = IconData(0xe1df, fontFamily: 'AppLucide300'); // qrCode300
  static const chats =
      IconData(0xe40d, fontFamily: 'AppLucide300'); // messagesSquare300
  static const undo = IconData(0xe2a1, fontFamily: 'AppLucide300'); // undo2300
  static const play = IconData(0xe13c, fontFamily: 'AppLucide300'); // play300
  static const swap =
      IconData(0xe24a, fontFamily: 'AppLucide300'); // arrowLeftRight300
  static const filter =
      IconData(0xe0dc, fontFamily: 'AppLucide300'); // funnel300
  static const sort =
      IconData(0xe37d, fontFamily: 'AppLucide300'); // arrowUpDown300
  static const repeat =
      IconData(0xe146, fontFamily: 'AppLucide300'); // repeat300
  static const keyboard =
      IconData(0xe284, fontFamily: 'AppLucide300'); // keyboard300
  static const camera =
      IconData(0xe064, fontFamily: 'AppLucide300'); // camera300
  static const signOut =
      IconData(0xe10e, fontFamily: 'AppLucide300'); // logOut300
  static const check = IconData(0xe06c, fontFamily: 'AppLucide300'); // check300
  static const print =
      IconData(0xe141, fontFamily: 'AppLucide300'); // printer300
  static const download =
      IconData(0xe0b2, fontFamily: 'AppLucide300'); // download300
  static const fileSheet =
      IconData(0xe326, fontFamily: 'AppLucide300'); // fileSpreadsheet300

  // Состояния
  static const success =
      IconData(0xe226, fontFamily: 'AppLucide300'); // circleCheck300
  static const error =
      IconData(0xe077, fontFamily: 'AppLucide300'); // circleAlert300
  static const warning =
      IconData(0xe193, fontFamily: 'AppLucide300'); // triangleAlert300

  /// Критичная заявка — красный «!» (шаг 21), жирнее остальных значков.
  static const critical =
      IconData(0xe077, fontFamily: 'AppLucide600'); // circleAlert600
  static const info = IconData(0xe0f9, fontFamily: 'AppLucide300'); // info300
  static const offline =
      IconData(0xe1af, fontFamily: 'AppLucide300'); // wifiOff300
  static const imageBroken =
      IconData(0xe1c0, fontFamily: 'AppLucide300'); // imageOff300
  static const sparkles =
      IconData(0xe412, fontFamily: 'AppLucide300'); // sparkles300
  static const audio =
      IconData(0xe55a, fontFamily: 'AppLucide300'); // audioLines300
  static const verified =
      IconData(0xe1ff, fontFamily: 'AppLucide300'); // shieldCheck300
  static const accepted =
      IconData(0xe219, fontFamily: 'AppLucide300'); // clipboardCheck300

  // Сущности
  static const bell = IconData(0xe059, fontFamily: 'AppLucide300'); // bell300
  static const building =
      IconData(0xe290, fontFamily: 'AppLucide300'); // building2300
  static const room =
      IconData(0xe3d6, fontFamily: 'AppLucide300'); // doorOpen300
  static const contractor =
      IconData(0xe5c0, fontFamily: 'AppLucide300'); // handshake300
  static const executor =
      IconData(0xe0ee, fontFamily: 'AppLucide300'); // hardHat300
  static const workType =
      IconData(0xe529, fontFamily: 'AppLucide300'); // layers300
  static const wrench =
      IconData(0xe1b1, fontFamily: 'AppLucide300'); // wrench300
  static const user = IconData(0xe19f, fontFamily: 'AppLucide300'); // user300
  static const users = IconData(0xe1a4, fontFamily: 'AppLucide300'); // users300
  static const userAdd =
      IconData(0xe1a2, fontFamily: 'AppLucide300'); // userPlus300
  static const mail = IconData(0xe10f, fontFamily: 'AppLucide300'); // mail300
  static const phone = IconData(0xe133, fontFamily: 'AppLucide300'); // phone300
  static const lock = IconData(0xe10b, fontFamily: 'AppLucide300'); // lock300
  static const key = IconData(0xe0fd, fontFamily: 'AppLucide300'); // key300
  static const language =
      IconData(0xe0e8, fontFamily: 'AppLucide300'); // globe300
  static const settings =
      IconData(0xe154, fontFamily: 'AppLucide300'); // settings300
  static const calendar =
      IconData(0xe2b9, fontFamily: 'AppLucide300'); // calendarDays300
  static const clock = IconData(0xe087, fontFamily: 'AppLucide300'); // clock300
  static const checklist =
      IconData(0xe1d0, fontFamily: 'AppLucide300'); // listChecks300
  // Шаг 27: пункт чек-листа, «ждёт отправки».
  static const checkboxOff =
      IconData(0xe167, fontFamily: 'AppLucide300'); // square300
  static const checkboxOn =
      IconData(0xe559, fontFamily: 'AppLucide300'); // squareCheck300
  static const uploadPending =
      IconData(0xe091, fontFamily: 'AppLucide300'); // cloudUpload300
  static const list = IconData(0xe106, fontFamily: 'AppLucide300'); // list300
  static const inbox = IconData(0xe0f7, fontFamily: 'AppLucide300'); // inbox300

  // Карта
  static const map = IconData(0xe110, fontFamily: 'AppLucide300'); // map300
  static const place =
      IconData(0xe111, fontFamily: 'AppLucide300'); // mapPin300
  static const placeEdit =
      IconData(0xe53d, fontFamily: 'AppLucide300'); // mapPinned300
  static const placeOff =
      IconData(0xe2a6, fontFamily: 'AppLucide300'); // mapPinOff300
  static const locate =
      IconData(0xe1db, fontFamily: 'AppLucide300'); // locateFixed300
  static const nearby =
      IconData(0xe497, fontFamily: 'AppLucide300'); // radar300
  static const area =
      IconData(0xe1cb, fontFamily: 'AppLucide300'); // squareDashed300
  static const searchArea =
      IconData(0xe537, fontFamily: 'AppLucide300'); // scanSearch300
  static const zoomIn =
      IconData(0xe1b6, fontFamily: 'AppLucide300'); // zoomIn300
  static const zoomOut =
      IconData(0xe1b7, fontFamily: 'AppLucide300'); // zoomOut300
  static const fit =
      IconData(0xe112, fontFamily: 'AppLucide300'); // maximize300

  // Планы этажей
  static const floors =
      IconData(0xe529, fontFamily: 'AppLucide300'); // layers300
  static const plan = IconData(0xe110, fontFamily: 'AppLucide300'); // map300
  static const imageAdd =
      IconData(0xe1f7, fontFamily: 'AppLucide300'); // imagePlus300
  static const image = IconData(0xe0f6, fontFamily: 'AppLucide300'); // image300
  static const imageOff =
      IconData(0xe1c0, fontFamily: 'AppLucide300'); // imageOff300
  static const moveUp =
      IconData(0xe04a, fontFamily: 'AppLucide300'); // arrowUp300
  static const moveDown =
      IconData(0xe042, fontFamily: 'AppLucide300'); // arrowDown300
  static const move = IconData(0xe121, fontFamily: 'AppLucide300'); // move300
  static const list2 =
      IconData(0xe460, fontFamily: 'AppLucide300'); // listFilter300

  // Оборудование на плане (assets.meta.kind, иначе — по категории)
  static const eqAirCon =
      IconData(0xe34d, fontFamily: 'AppLucide300'); // airVent300
  static const eqFan = IconData(0xe379, fontFamily: 'AppLucide300'); // fan300
  static const eqPanel = IconData(0xe1b4, fontFamily: 'AppLucide300'); // zap300
  static const eqLight =
      IconData(0xe1c2, fontFamily: 'AppLucide300'); // lightbulb300
  static const eqSmoke =
      IconData(0xe57b, fontFamily: 'AppLucide300'); // alarmSmoke300
  static const eqUps =
      IconData(0xe054, fontFamily: 'AppLucide300'); // batteryCharging300
  static const eqSensor =
      IconData(0xe186, fontFamily: 'AppLucide300'); // thermometer300
  static const eqCamera =
      IconData(0xe57d, fontFamily: 'AppLucide300'); // cctv300
  static const eqServer =
      IconData(0xe153, fontFamily: 'AppLucide300'); // server300
  static const eqWater =
      IconData(0xe0b5, fontFamily: 'AppLucide300'); // droplets300
  static const eqFurniture =
      IconData(0xe2c0, fontFamily: 'AppLucide300'); // armchair300
  static const eqInfra =
      IconData(0xe4e3, fontFamily: 'AppLucide300'); // cable300
  static const eqOther = IconData(0xe061, fontFamily: 'AppLucide300'); // box300
  // Каталог видов оборудования (шаг 22, equipment_kinds.dart).
  static const eqAcOutdoor =
      IconData(0xe379, fontFamily: 'AppLucide300'); // fan300
  static const eqVent = IconData(0xe1b0, fontFamily: 'AppLucide300'); // wind300
  static const eqRadiator =
      IconData(0xe58e, fontFamily: 'AppLucide300'); // heater300
  static const eqSocket =
      IconData(0xe37f, fontFamily: 'AppLucide300'); // plug300
  static const eqExtinguisher =
      IconData(0xe57e, fontFamily: 'AppLucide300'); // fireExtinguisher300
  static const eqAccessReader =
      IconData(0xe617, fontFamily: 'AppLucide300'); // idCard300
  static const eqLock =
      IconData(0xe531, fontFamily: 'AppLucide300'); // lockKeyhole300
  static const eqFaucet =
      IconData(0xe37c, fontFamily: 'AppLucide300'); // showerHead300
  static const eqToilet =
      IconData(0xe635, fontFamily: 'AppLucide300'); // toilet300
  static const eqWaterHeater =
      IconData(0xe188, fontFamily: 'AppLucide300'); // thermometerSun300
  static const eqLift =
      IconData(0xe37d, fontFamily: 'AppLucide300'); // arrowUpDown300
  // «Узнать по фото» (шаг 22).
  static const scan =
      IconData(0xe537, fontFamily: 'AppLucide300'); // scanSearch300

  // Файлы, системы, акты (шаг 24)
  static const share =
      IconData(0xe156, fontFamily: 'AppLucide300'); // share2300
  static const attach =
      IconData(0xe12d, fontFamily: 'AppLucide300'); // paperclip300
  static const file = IconData(0xe0c0, fontFamily: 'AppLucide300'); // file300
  static const fileText =
      IconData(0xe0cc, fontFamily: 'AppLucide300'); // fileText300
  static const fileImage =
      IconData(0xe31c, fontFamily: 'AppLucide300'); // fileImage300
  static const fileCheck =
      IconData(0xe0c1, fontFamily: 'AppLucide300'); // fileCheck300
  static const externalLink =
      IconData(0xe0b9, fontFamily: 'AppLucide300'); // externalLink300
  static const archive =
      IconData(0xe041, fontFamily: 'AppLucide300'); // archive300
  static const unarchive =
      IconData(0xe2cd, fontFamily: 'AppLucide300'); // archiveRestore300
  static const systems =
      IconData(0xe529, fontFamily: 'AppLucide300'); // layers300
  static const palette =
      IconData(0xe1dd, fontFamily: 'AppLucide300'); // palette300
  static const chevronUp =
      IconData(0xe070, fontFamily: 'AppLucide300'); // chevronUp300
  static const act = IconData(0xe3d3, fontFamily: 'AppLucide300'); // receipt300
  static const money =
      IconData(0xe052, fontFamily: 'AppLucide300'); // banknote300

  // Активная вкладка нижнего меню — те же значки с линией толще (штрих 2):
  // Lucide не делает залитых значков, поэтому активную вкладку выделяют
  // толщина линии и цвет.
  static const homeActive = IconData(0xe0f5, fontFamily: 'AppLucide'); // house
  static const historyActive =
      IconData(0xe1f5, fontFamily: 'AppLucide'); // history
  static const reportsActive =
      IconData(0xe2a3, fontFamily: 'AppLucide'); // chartColumn
  static const profileActive =
      IconData(0xe462, fontFamily: 'AppLucide'); // circleUserRound
}
