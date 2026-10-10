import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Единый набор значков — Lucide (ISC), тонкая линия (вес 300, штрих 1.55).
///
/// В экранах — только `AppIcons.*`: не `Icons.*` из Material и не другие
/// веса Lucide. Исключение — `*Active` для активной вкладки (штрих 2).
/// Нужен новый значок — добавить сюда (имена — lucide.dev/icons, суффикс 300).
class AppIcons {
  const AppIcons._();

  // Навигация
  static const home = LucideIcons.house300;
  static const history = LucideIcons.history300;
  static const reports = LucideIcons.chartColumn300;
  static const profile = LucideIcons.circleUserRound300;
  static const chevronRight = LucideIcons.chevronRight300;
  static const chevronLeft = LucideIcons.chevronLeft300;
  static const chevronDown = LucideIcons.chevronDown300;
  static const close = LucideIcons.x300;
  static const more = LucideIcons.ellipsis300;
  static const panelOpen = LucideIcons.panelLeftOpen300;
  static const panelClose = LucideIcons.panelLeftClose300;
  static const help = LucideIcons.circleQuestionMark300;

  // Действия
  static const add = LucideIcons.plus300;
  static const remove = LucideIcons.minus300;
  static const mic = LucideIcons.mic300;
  static const search = LucideIcons.search300;
  static const edit = LucideIcons.pencil300;
  static const delete = LucideIcons.trash2300;
  static const refresh = LucideIcons.rotateCw300;
  static const copy = LucideIcons.copy300;
  static const link = LucideIcons.link300;
  static const send = LucideIcons.sendHorizontal300;
  static const undo = LucideIcons.undo2300;
  static const play = LucideIcons.play300;
  static const swap = LucideIcons.arrowLeftRight300;
  static const filter = LucideIcons.funnel300;
  static const sort = LucideIcons.arrowUpDown300;
  static const repeat = LucideIcons.repeat300;
  static const keyboard = LucideIcons.keyboard300;
  static const camera = LucideIcons.camera300;
  static const signOut = LucideIcons.logOut300;
  static const check = LucideIcons.check300;

  // Состояния
  static const success = LucideIcons.circleCheck300;
  static const error = LucideIcons.circleAlert300;
  static const warning = LucideIcons.triangleAlert300;
  static const info = LucideIcons.info300;
  static const offline = LucideIcons.wifiOff300;
  static const imageBroken = LucideIcons.imageOff300;
  static const sparkles = LucideIcons.sparkles300;
  static const audio = LucideIcons.audioLines300;
  static const verified = LucideIcons.shieldCheck300;
  static const accepted = LucideIcons.clipboardCheck300;

  // Сущности
  static const bell = LucideIcons.bell300;
  static const building = LucideIcons.building2300;
  static const room = LucideIcons.doorOpen300;
  static const contractor = LucideIcons.handshake300;
  static const executor = LucideIcons.hardHat300;
  static const workType = LucideIcons.layers300;
  static const wrench = LucideIcons.wrench300;
  static const user = LucideIcons.user300;
  static const users = LucideIcons.users300;
  static const userAdd = LucideIcons.userPlus300;
  static const mail = LucideIcons.mail300;
  static const phone = LucideIcons.phone300;
  static const lock = LucideIcons.lock300;
  static const key = LucideIcons.key300;
  static const language = LucideIcons.globe300;
  static const settings = LucideIcons.settings300;
  static const calendar = LucideIcons.calendarDays300;
  static const clock = LucideIcons.clock300;
  static const checklist = LucideIcons.listChecks300;
  static const list = LucideIcons.list300;
  static const inbox = LucideIcons.inbox300;

  // Карта
  static const map = LucideIcons.map300;
  static const place = LucideIcons.mapPin300;
  static const placeEdit = LucideIcons.mapPinned300;
  static const placeOff = LucideIcons.mapPinOff300;
  static const locate = LucideIcons.locateFixed300;
  static const nearby = LucideIcons.radar300;
  static const area = LucideIcons.squareDashed300;
  static const searchArea = LucideIcons.scanSearch300;
  static const zoomIn = LucideIcons.zoomIn300;
  static const zoomOut = LucideIcons.zoomOut300;
  static const fit = LucideIcons.maximize300;

  // Планы этажей
  static const floors = LucideIcons.layers300;
  static const plan = LucideIcons.map300;
  static const imageAdd = LucideIcons.imagePlus300;
  static const image = LucideIcons.image300;
  static const imageOff = LucideIcons.imageOff300;
  static const moveUp = LucideIcons.arrowUp300;
  static const moveDown = LucideIcons.arrowDown300;
  static const move = LucideIcons.move300;
  static const list2 = LucideIcons.listFilter300;

  // Оборудование на плане (assets.meta.kind, иначе — по категории)
  static const eqAirCon = LucideIcons.airVent300;
  static const eqFan = LucideIcons.fan300;
  static const eqPanel = LucideIcons.zap300;
  static const eqLight = LucideIcons.lightbulb300;
  static const eqSmoke = LucideIcons.alarmSmoke300;
  static const eqUps = LucideIcons.batteryCharging300;
  static const eqSensor = LucideIcons.thermometer300;
  static const eqCamera = LucideIcons.cctv300;
  static const eqServer = LucideIcons.server300;
  static const eqWater = LucideIcons.droplets300;
  static const eqFurniture = LucideIcons.armchair300;
  static const eqInfra = LucideIcons.cable300;
  static const eqOther = LucideIcons.box300;

  // Активная вкладка нижнего меню — те же значки с линией толще (штрих 2):
  // Lucide не делает залитых значков, поэтому активную вкладку выделяют
  // толщина линии и цвет.
  static const homeActive = LucideIcons.house;
  static const historyActive = LucideIcons.history;
  static const reportsActive = LucideIcons.chartColumn;
  static const profileActive = LucideIcons.circleUserRound;
}
