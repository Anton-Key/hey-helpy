# Скриншоты веб-версии

Снято: 2026-10-14, команда `/screens` (`tools/screens/screens.mjs`), рабочая база (миграции 0001–0022). Шаг 25.

⚠️ Снято в три приёма: в первом полном прогоне браузер в контейнере упал после менеджера 1920 и 1280 (`browser.newContext: Target … has been closed`, нехватка памяти) — эти снимки сохранены, но сводка прогона не записалась (строки ниже без названий экранов — по именам файлов). Затем `--width=412` (менеджер, исполнитель, заявитель — 102 снимка, проблем 0) и `--width=360` (44 снимка). На 360 «Выбор подрядчика» ❌ — как и в шаге 24 (в видимой части списка нет демо-заявки «Новая / Назначена / Возвращена», зависит от данных); два «Сообщения» упали вслед за ним и при повторе отдельно (`--only=message,message-gone`) ✅.

| Роль | Ширина | Экран | Итог | Файл | Примечание |
|---|---|---|---|---|---|
| Менеджер | 1280 | asset-card | ✅ | [manager-1280-asset-card.png](manager-1280-asset-card.png) 82 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | camera-card | ✅ | [manager-1280-camera-card.png](manager-1280-camera-card.png) 136 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | camera-live | ✅ | [manager-1280-camera-live.png](manager-1280-camera-live.png) 117 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | confirm-scroll | ✅ | [manager-1280-confirm-scroll.png](manager-1280-confirm-scroll.png) 70 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | contractor-card | ✅ | [manager-1280-contractor-card.png](manager-1280-contractor-card.png) 76 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | contractors | ✅ | [manager-1280-contractors.png](manager-1280-contractors.png) 87 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | equipment | ✅ | [manager-1280-equipment.png](manager-1280-equipment.png) 84 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | filter-empty | ✅ | [manager-1280-filter-empty.png](manager-1280-filter-empty.png) 70 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | filter-object-city | ✅ | [manager-1280-filter-object-city.png](manager-1280-filter-object-city.png) 125 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | filter-object | ✅ | [manager-1280-filter-object.png](manager-1280-filter-object.png) 152 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | filter-period | ✅ | [manager-1280-filter-period.png](manager-1280-filter-period.png) 114 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | filter-picker | ✅ | [manager-1280-filter-picker.png](manager-1280-filter-picker.png) 144 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | filter-sort | ✅ | [manager-1280-filter-sort.png](manager-1280-filter-sort.png) 134 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | filters-active | ✅ | [manager-1280-filters-active.png](manager-1280-filters-active.png) 123 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | filters-panel | ✅ | [manager-1280-filters-panel.png](manager-1280-filters-panel.png) 142 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | history | ✅ | [manager-1280-history.png](manager-1280-history.png) 106 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | locations-regions | ✅ | [manager-1280-locations-regions.png](manager-1280-locations-regions.png) 96 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | locations | ✅ | [manager-1280-locations.png](manager-1280-locations.png) 96 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | map-area | ✅ | [manager-1280-map-area.jpg](manager-1280-map-area.jpg) 149 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | map-city | ✅ | [manager-1280-map-city.jpg](manager-1280-map-city.jpg) 152 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | map-nearby | ✅ | [manager-1280-map-nearby.jpg](manager-1280-map-nearby.jpg) 137 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | map-orders | ✅ | [manager-1280-map-orders.png](manager-1280-map-orders.png) 131 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | map-place | ✅ | [manager-1280-map-place.jpg](manager-1280-map-place.jpg) 135 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | map-selected | ✅ | [manager-1280-map-selected.jpg](manager-1280-map-selected.jpg) 152 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | map | ✅ | [manager-1280-map.jpg](manager-1280-map.jpg) 110 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | message-gone | ✅ | [manager-1280-message-gone.png](manager-1280-message-gone.png) 87 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | message | ✅ | [manager-1280-message.png](manager-1280-message.png) 92 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | notifications | ✅ | [manager-1280-notifications.png](manager-1280-notifications.png) 124 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | object-picker | ✅ | [manager-1280-object-picker.png](manager-1280-object-picker.png) 149 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | order-delete | ✅ | [manager-1280-order-delete.png](manager-1280-order-delete.png) 95 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | order-photos | ✅ | [manager-1280-order-photos.png](manager-1280-order-photos.png) 87 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | order | ✅ | [manager-1280-order.png](manager-1280-order.png) 91 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | photo-order | ✅ | [manager-1280-photo-order.png](manager-1280-photo-order.png) 76 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | photo-result | ✅ | [manager-1280-photo-result.png](manager-1280-photo-result.png) 90 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | photo-start | ✅ | [manager-1280-photo-start.png](manager-1280-photo-start.png) 49 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | picker | ✅ | [manager-1280-picker.png](manager-1280-picker.png) 103 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | plan-edit | ✅ | [manager-1280-plan-edit.png](manager-1280-plan-edit.png) 145 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | plan-from-order | ✅ | [manager-1280-plan-from-order.png](manager-1280-plan-from-order.png) 163 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | plan-info | ✅ | [manager-1280-plan-info.png](manager-1280-plan-info.png) 157 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | plan-marker | ✅ | [manager-1280-plan-marker.png](manager-1280-plan-marker.png) 149 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | plan-object | ✅ | [manager-1280-plan-object.png](manager-1280-plan-object.png) 83 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | plan-order | ✅ | [manager-1280-plan-order.png](manager-1280-plan-order.png) 91 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | plan-overdue | ✅ | [manager-1280-plan-overdue.png](manager-1280-plan-overdue.png) 147 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | plan-unplaced | ✅ | [manager-1280-plan-unplaced.png](manager-1280-plan-unplaced.png) 139 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | plan-upload-done | ✅ | [manager-1280-plan-upload-done.png](manager-1280-plan-upload-done.png) 139 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | plan-upload-edit | ✅ | [manager-1280-plan-upload-edit.png](manager-1280-plan-upload-edit.png) 161 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | plan-upload-empty | ✅ | [manager-1280-plan-upload-empty.png](manager-1280-plan-upload-empty.png) 138 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | plan | ✅ | [manager-1280-plan.png](manager-1280-plan.png) 146 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | ppr-card | ✅ | [manager-1280-ppr-card.png](manager-1280-ppr-card.png) 86 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | ppr-list | ✅ | [manager-1280-ppr-list.png](manager-1280-ppr-list.png) 120 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | ppr-task | ✅ | [manager-1280-ppr-task.png](manager-1280-ppr-task.png) 86 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | profile | ✅ | [manager-1280-profile.png](manager-1280-profile.png) 56 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | reports-regions | ✅ | [manager-1280-reports-regions.png](manager-1280-reports-regions.png) 114 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | reports | ✅ | [manager-1280-reports.png](manager-1280-reports.png) 114 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | requests-collapsed | ✅ | [manager-1280-requests-collapsed.png](manager-1280-requests-collapsed.png) 132 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | requests-end | ✅ | [manager-1280-requests-end.png](manager-1280-requests-end.png) 135 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | requests | ✅ | [manager-1280-requests.png](manager-1280-requests.png) 121 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | systems | ✅ | [manager-1280-systems.png](manager-1280-systems.png) 88 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | voice-confirm-low | ✅ | [manager-1280-voice-confirm-low.png](manager-1280-voice-confirm-low.png) 91 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | voice-confirm | ✅ | [manager-1280-voice-confirm.png](manager-1280-voice-confirm.png) 91 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | voice-type | ✅ | [manager-1280-voice-type.png](manager-1280-voice-type.png) 48 КБ | первый прогон (до падения браузера) |
| Менеджер | 1280 | voice | ✅ | [manager-1280-voice.png](manager-1280-voice.png) 66 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | asset-card | ✅ | [manager-1920-asset-card.png](manager-1920-asset-card.png) 85 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | audit | ✅ | [manager-1920-audit.png](manager-1920-audit.png) 44 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | camera-card | ✅ | [manager-1920-camera-card.png](manager-1920-camera-card.png) 179 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | camera-live | ✅ | [manager-1920-camera-live.png](manager-1920-camera-live.png) 159 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | confirm-scroll | ✅ | [manager-1920-confirm-scroll.png](manager-1920-confirm-scroll.png) 73 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | contractor-card | ✅ | [manager-1920-contractor-card.png](manager-1920-contractor-card.png) 82 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | contractors | ✅ | [manager-1920-contractors.png](manager-1920-contractors.png) 92 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | crew-zone | ✅ | [manager-1920-crew-zone.png](manager-1920-crew-zone.png) 61 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | crews | ✅ | [manager-1920-crews.png](manager-1920-crews.png) 79 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | equipment | ✅ | [manager-1920-equipment.png](manager-1920-equipment.png) 88 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | filter-empty | ✅ | [manager-1920-filter-empty.png](manager-1920-filter-empty.png) 76 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | filter-object-city | ✅ | [manager-1920-filter-object-city.png](manager-1920-filter-object-city.png) 167 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | filter-object-error | ✅ | [manager-1920-filter-object-error.png](manager-1920-filter-object-error.png) 166 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | filter-period | ✅ | [manager-1920-filter-period.png](manager-1920-filter-period.png) 151 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | filter-picker | ✅ | [manager-1920-filter-picker.png](manager-1920-filter-picker.png) 181 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | filter-sort | ✅ | [manager-1920-filter-sort.png](manager-1920-filter-sort.png) 174 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | filters-active | ✅ | [manager-1920-filters-active.png](manager-1920-filters-active.png) 168 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | filters-panel | ✅ | [manager-1920-filters-panel.png](manager-1920-filters-panel.png) 204 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | history | ✅ | [manager-1920-history.png](manager-1920-history.png) 111 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | locations-regions | ✅ | [manager-1920-locations-regions.png](manager-1920-locations-regions.png) 100 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | locations | ✅ | [manager-1920-locations.png](manager-1920-locations.png) 101 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | map-area | ✅ | [manager-1920-map-area.jpg](manager-1920-map-area.jpg) 212 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | map-city | ✅ | [manager-1920-map-city.jpg](manager-1920-map-city.jpg) 254 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | map-nearby | ✅ | [manager-1920-map-nearby.jpg](manager-1920-map-nearby.jpg) 201 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | map-orders | ✅ | [manager-1920-map-orders.png](manager-1920-map-orders.png) 137 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | map-place | ✅ | [manager-1920-map-place.jpg](manager-1920-map-place.jpg) 199 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | map-selected | ✅ | [manager-1920-map-selected.jpg](manager-1920-map-selected.jpg) 269 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | map | ✅ | [manager-1920-map.jpg](manager-1920-map.jpg) 129 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | message-gone | ✅ | [manager-1920-message-gone.png](manager-1920-message-gone.png) 92 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | message | ✅ | [manager-1920-message.png](manager-1920-message.png) 97 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | notifications | ✅ | [manager-1920-notifications.png](manager-1920-notifications.png) 38 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | object-picker | ✅ | [manager-1920-object-picker.png](manager-1920-object-picker.png) 154 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | order-delete | ✅ | [manager-1920-order-delete.png](manager-1920-order-delete.png) 123 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | order-photos | ✅ | [manager-1920-order-photos.png](manager-1920-order-photos.png) 90 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | order | ✅ | [manager-1920-order.png](manager-1920-order.png) 117 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | photo-order | ✅ | [manager-1920-photo-order.png](manager-1920-photo-order.png) 79 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | photo-result | ✅ | [manager-1920-photo-result.png](manager-1920-photo-result.png) 94 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | photo-start | ✅ | [manager-1920-photo-start.png](manager-1920-photo-start.png) 52 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | picker | ✅ | [manager-1920-picker.png](manager-1920-picker.png) 142 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | plan-areas | ✅ | [manager-1920-plan-areas.png](manager-1920-plan-areas.png) 157 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | plan-edit | ✅ | [manager-1920-plan-edit.png](manager-1920-plan-edit.png) 150 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | plan-from-order | ✅ | [manager-1920-plan-from-order.png](manager-1920-plan-from-order.png) 166 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | plan-info | ✅ | [manager-1920-plan-info.png](manager-1920-plan-info.png) 168 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | plan-marker | ✅ | [manager-1920-plan-marker.png](manager-1920-plan-marker.png) 160 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | plan-object | ✅ | [manager-1920-plan-object.png](manager-1920-plan-object.png) 87 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | plan-order | ✅ | [manager-1920-plan-order.png](manager-1920-plan-order.png) 96 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | plan-overdue | ✅ | [manager-1920-plan-overdue.png](manager-1920-plan-overdue.png) 157 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | plan-unplaced | ✅ | [manager-1920-plan-unplaced.png](manager-1920-plan-unplaced.png) 149 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | plan-upload-done | ✅ | [manager-1920-plan-upload-done.png](manager-1920-plan-upload-done.png) 149 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | plan-upload-edit | ✅ | [manager-1920-plan-upload-edit.png](manager-1920-plan-upload-edit.png) 167 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | plan-upload-empty | ✅ | [manager-1920-plan-upload-empty.png](manager-1920-plan-upload-empty.png) 140 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | plan | ✅ | [manager-1920-plan.png](manager-1920-plan.png) 157 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | ppr-card | ✅ | [manager-1920-ppr-card.png](manager-1920-ppr-card.png) 90 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | ppr-list | ✅ | [manager-1920-ppr-list.png](manager-1920-ppr-list.png) 124 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | ppr-task | ✅ | [manager-1920-ppr-task.png](manager-1920-ppr-task.png) 90 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | profile | ✅ | [manager-1920-profile.png](manager-1920-profile.png) 61 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | reports-regions | ✅ | [manager-1920-reports-regions.png](manager-1920-reports-regions.png) 118 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | reports | ✅ | [manager-1920-reports.png](manager-1920-reports.png) 119 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | requests-collapsed | ✅ | [manager-1920-requests-collapsed.png](manager-1920-requests-collapsed.png) 177 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | requests-end | ✅ | [manager-1920-requests-end.png](manager-1920-requests-end.png) 182 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | requests | ✅ | [manager-1920-requests.png](manager-1920-requests.png) 158 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | systems | ✅ | [manager-1920-systems.png](manager-1920-systems.png) 91 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | voice-confirm-low | ✅ | [manager-1920-voice-confirm-low.png](manager-1920-voice-confirm-low.png) 96 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | voice-confirm | ✅ | [manager-1920-voice-confirm.png](manager-1920-voice-confirm.png) 98 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | voice-type | ✅ | [manager-1920-voice-type.png](manager-1920-voice-type.png) 51 КБ | первый прогон (до падения браузера) |
| Менеджер | 1920 | voice | ✅ | [manager-1920-voice.png](manager-1920-voice.png) 75 КБ | первый прогон (до падения браузера) |
| Менеджер | 412 | Список заявок | ✅ | [manager-412-requests.png](manager-412-requests.png) 87 КБ |  |
| Менеджер | 412 | Список заявок — конец списка | ✅ | [manager-412-requests-end.png](manager-412-requests-end.png) 83 КБ |  |
| Менеджер | 412 | Заявки — свёрнутая шапка при прокрутке | ✅ | [manager-412-requests-collapsed.png](manager-412-requests-collapsed.png) 93 КБ | поиск и фильтры закреплены сверху, сегменты спрятаны |
| Менеджер | 412 | Заявки — применённые фильтры по ссылке (таблетки «×», «Сбросить всё») | ✅ | [manager-412-filters-active.png](manager-412-filters-active.png) 94 КБ | ссылка #/?pri=critical,high&st=overdue,new,assigned,in_progress&period=30d&sort=priority |
| Менеджер | 412 | Окно «Фильтры» с «Показать N заявок» | ✅ | [manager-412-filters-panel.png](manager-412-filters-panel.png) 46 КБ | шторка на весь экран; число считает сервер |
| Менеджер | 412 | Окно фильтра «Статус» | ✅ | [manager-412-filter-picker.png](manager-412-filter-picker.png) 41 КБ | шторка поверх окна «Фильтры»; отмечены «Просрочено» и «Новая», закрыто без применения |
| Менеджер | 412 | Фильтр «Период» → «Свой период…» (календарь) | ✅ | [manager-412-filter-period.png](manager-412-filter-period.png) 36 КБ | окно «Период» (по дате создания / по сроку, пресеты) и календарь «с — по»; закрыто без выбора |
| Менеджер | 412 | Сортировка списка заявок | ✅ | [manager-412-filter-sort.png](manager-412-filter-sort.png) 59 КБ | 6 вариантов, галочка у текущей; выбор сразу применяется (здесь закрыто без выбора) |
| Менеджер | 412 | Заявки — «Ничего не найдено» и «Сбросить фильтры» | ✅ | [manager-412-filter-empty.png](manager-412-filter-empty.png) 50 КБ | ссылка #/?rec=recurring&pri=critical |
| Менеджер | 412 | Фильтр «Объект»: секции по городам, «Весь город» (Москва) | ✅ | [manager-412-filter-object.png](manager-412-filter-object.png) 41 КБ | отмечен «Весь город» у Москвы — «Применить (5)»; закрыто без применения |
| Менеджер | 412 | Заявки с фильтром «Москва (5)», строки «Москва · Офис N» | ✅ | [manager-412-filter-object-city.png](manager-412-filter-object-city.png) 91 КБ | ссылка #/?obj=<5 объектов Москвы> |
| Менеджер | 412 | Карточка подрядчика «ЭлектроСити» (2 объекта из 5 в Москве) | ✅ | [manager-412-contractor-card.png](manager-412-contractor-card.png) 49 КБ | виды работ; объекты по городам: МОСКВА · 2 |
| Менеджер | 412 | Карточка заявки «Шумит вентилятор в переговорной» | ✅ | [manager-412-order.png](manager-412-order.png) 65 КБ |  |
| Менеджер | 412 | Карточка заявки — меню «⋯» и диалог удаления | ✅ | [manager-412-order-delete.png](manager-412-order-delete.png) 62 КБ | меню «⋯» в шапке: «Отменить», «Удалить»; диалог закрыт кнопкой «Отмена» |
| Менеджер | 412 | Выбор подрядчика | ✅ | [manager-412-picker.png](manager-412-picker.png) 71 КБ | заявка «Душно в торговой галерее» |
| Менеджер | 412 | Голосовая заявка — распознавание | ✅ | [manager-412-voice.png](manager-412-voice.png) 37 КБ |  |
| Менеджер | 412 | Голосовая заявка — подтверждение | ✅ | [manager-412-voice-confirm.png](manager-412-voice-confirm.png) 63 КБ |  |
| Менеджер | 412 | Голосовая заявка — подтверждение, низкое окно | ✅ | [manager-412-voice-confirm-low.png](manager-412-voice-confirm-low.png) 52 КБ | окно 412×700, «Отправить» видна (низ кнопки — 690 px) |
| Менеджер | 412 | Проверьте заявку — прокрутка колесом и PageDown | ✅ | [manager-412-confirm-scroll.png](manager-412-confirm-scroll.png) 49 КБ | окно 412×700: колесо 716→545 px, Home 716, PageDown →545 px |
| Менеджер | 412 | «Слушаю» → «Ввести текстом» с одного нажатия | ✅ | [manager-412-voice-type.png](manager-412-voice-type.png) 21 КБ | поле открылось с первого нажатия, курсор в поле |
| Менеджер | 412 | Сообщение «Напишите, что случилось» | ✅ | [manager-412-message.png](manager-412-message.png) 63 КБ | сверху (x 16, y 52 px), кнопка «Отправить» открыта |
| Менеджер | 412 | Сообщение исчезает само (~3 с) | ✅ | [manager-412-message-gone.png](manager-412-message-gone.png) 60 КБ | исчезло через 3.3 с |
| Менеджер | 412 | Отчёты (30 дней) | ✅ | [manager-412-reports.png](manager-412-reports.png) 61 КБ |  |
| Менеджер | 412 | История | ✅ | [manager-412-history.png](manager-412-history.png) 72 КБ |  |
| Менеджер | 412 | Подрядчики | ✅ | [manager-412-contractors.png](manager-412-contractors.png) 63 КБ |  |
| Менеджер | 412 | Локации | ✅ | [manager-412-locations.png](manager-412-locations.png) 69 КБ |  |
| Менеджер | 412 | Локации — карта, все объекты | ✅ | [manager-412-map.jpg](manager-412-map.jpg) 46 КБ | все объекты, маркер — число открытых заявок |
| Менеджер | 412 | Локации — карта, выбран регион «СНГ» (Москва) | ✅ | [manager-412-map-city.jpg](manager-412-map-city.jpg) 74 КБ | чип региона «СНГ» (в нём только Москва) — объекты города; список — секции по городам |
| Менеджер | 412 | Локации — карта, выбранный объект | ✅ | [manager-412-map-selected.jpg](manager-412-map-selected.jpg) 69 КБ | карточка объекта, круг геозоны |
| Менеджер | 412 | Локации — карта, выделенная область | ✅ | [manager-412-map-area.jpg](manager-412-map-area.jpg) 74 КБ | рамка протянута мышью, список — только объекты внутри |
| Менеджер | 412 | Локации — карта, «Объекты рядом» (правый клик) | ✅ | [manager-412-map-nearby.jpg](manager-412-map-nearby.jpg) 74 КБ | радиус 3 км, список — по удалённости |
| Менеджер | 412 | Локации — карта, «Изменить место на карте» | ✅ | [manager-412-map-place.jpg](manager-412-map-place.jpg) 65 КБ | перекрестие по центру; закрыто кнопкой «Отмена», место не сохранено |
| Менеджер | 412 | Карта → «Заявки» объекта (фильтр) | ✅ | [manager-412-map-orders.png](manager-412-map-orders.png) 89 КБ | фильтр «Объект» = БЦ «Демо» (та же таблетка, что в строке фильтров), снимается крестиком |
| Менеджер | 412 | Карточка объекта — «Этажи · N» и помещения с этажами | ✅ | [manager-412-plan-object.png](manager-412-plan-object.png) 65 КБ | у менеджера — «+ Этаж», «+» и «⋯» у этажа |
| Менеджер | 412 | План этажа «3 этаж» (открыт по ссылке) | ✅ | [manager-412-plan.png](manager-412-plan.png) 62 КБ | ссылка #/objects/…/floors/…; маркеры помещений и оборудования, фильтр, список |
| Менеджер | 412 | План — шторка маркера «Кондиционер серверной» | ✅ | [manager-412-plan-marker.png](manager-412-plan-marker.png) 69 КБ | подзаголовок без повтора этажа («… · Серверная, 3 этаж»), открытая просроченная заявка, «Создать заявку здесь» |
| Менеджер | 412 | План — оборудование с просроченной заявкой (красное, «дышит») | ✅ | [manager-412-plan-overdue.png](manager-412-plan-overdue.png) 61 КБ | план целиком: квадраты оборудования — цвет статуса и бейдж числа заявок, «Кондиционер серверной» (просрочено) — красный ореол «дышит»; подписи помещений скрыты (они на картинке) |
| Менеджер | 412 | План — режим расстановки | ✅ | [manager-412-plan-edit.png](manager-412-plan-edit.png) 77 КБ | плашка «Режим расстановки · Готово»; маркеры перетаскиваются (здесь ничего не меняется) |
| Менеджер | 412 | План без картинки — «Загрузить план» (менеджер) | ✅ | [manager-412-plan-upload-empty.png](manager-412-plan-upload-empty.png) 61 КБ | ответ сервера в браузере — этаж без plan_path; база не меняется |
| Менеджер | 412 | План сразу после загрузки (без перезахода) | ✅ | [manager-412-plan-upload-done.png](manager-412-plan-upload-done.png) 58 КБ | файл подставлен Playwright; загрузка и запись этажа перехвачены в браузере |
| Менеджер | 412 | «Редактировать» — режим расстановки и перетаскивание | ✅ | [manager-412-plan-upload-edit.png](manager-412-plan-upload-edit.png) 85 КБ | плашка режима, контур маркеров; перенос «Кафе» перехвачен (3 записей не ушли в базу) |
| Менеджер | 412 | План — список «На плане / Не размещены» | ✅ | [manager-412-plan-unplaced.png](manager-412-plan-unplaced.png) 71 КБ | «Open space, 2 этаж» — без этажа, в «Не размещены» |
| Менеджер | 412 | Подсказка ⓘ «Что значат маркеры» | ✅ | [manager-412-plan-info.png](manager-412-plan-info.png) 77 КБ |  |
| Менеджер | 412 | Карточка заявки — «Показать на плане» | ✅ | [manager-412-plan-order.png](manager-412-plan-order.png) 65 КБ | превью плана, «3 этаж · N открытых заявок рядом» |
| Менеджер | 412 | План, открытый из заявки (маркер подсвечен) | ✅ | [manager-412-plan-from-order.png](manager-412-plan-from-order.png) 72 КБ | план центрирован на «Кондиционер серверной»: красные волны (просрочено), маркер ×1,25, подпись полужирная |
| Менеджер | 412 | Профиль | ✅ | [manager-412-profile.png](manager-412-profile.png) 31 КБ |  |
| Менеджер | 412 | Уведомления | ✅ | [manager-412-notifications.png](manager-412-notifications.png) 93 КБ |  |
| Менеджер | 412 | ППР — список планов, сводка «Октябрь: выполнено N из 8» | ✅ | [manager-412-ppr-list.png](manager-412-ppr-list.png) 75 КБ | сводка — Октябрь: выполнено 1 из 8 |
| Менеджер | 412 | ППР — карточка плана «ТО кондиционеров» (история периодов) | ✅ | [manager-412-ppr-card.png](manager-412-ppr-card.png) 64 КБ |  |
| Менеджер | 412 | Задача периода — карточка заявки «ППР · октябрь 2026 · до 31 окт.» | ✅ | [manager-412-ppr-task.png](manager-412-ppr-task.png) 60 КБ |  |
| Менеджер | 412 | Локации по регионам → страна → город | ✅ | [manager-412-locations-regions.png](manager-412-locations-regions.png) 69 КБ |  |
| Менеджер | 412 | Окно выбора объектов: «Весь регион», «Вся страна», «Весь город» | ✅ | [manager-412-object-picker.png](manager-412-object-picker.png) 38 КБ | закрыто без применения |
| Менеджер | 412 | Отчёты: блок «По регионам» | ✅ | [manager-412-reports-regions.png](manager-412-reports-regions.png) 61 КБ |  |
| Менеджер | 412 | Карточка объекта: «Оборудование · N» по системам | ✅ | [manager-412-equipment.png](manager-412-equipment.png) 63 КБ |  |
| Менеджер | 412 | Карточка оборудования «Кондиционер серверной»: паспорт, план, ППР, заявки | ✅ | [manager-412-asset-card.png](manager-412-asset-card.png) 60 КБ |  |
| Менеджер | 412 | «Узнать по фото» — «Где я» и «Сфотографировать» | ✅ | [manager-412-photo-start.png](manager-412-photo-start.png) 23 КБ | Где я: БЦ «Демо» · 3 этаж · 301; ответ — заглушка (ПРЕДПРОСМОТР) |
| Менеджер | 412 | «Узнать по фото» — вид, система, «Скорее всего» и «Это он» | ✅ | [manager-412-photo-result.png](manager-412-photo-result.png) 68 КБ | нарисованный кондиционер; ответ — заглушка VOICE_MOCK (ПРЕДПРОСМОТР) |
| Менеджер | 412 | «Это он» → новая заявка: объект, помещение, оборудование, система, снимок | ✅ | [manager-412-photo-order.png](manager-412-photo-order.png) 51 КБ | «Создать» не нажимали |
| Менеджер | 412 | «Камера-помощник»: живое видео, «Где я», рамка-прицел, «Что это?» | ✅ | [manager-412-camera-live.png](manager-412-camera-live.png) 46 КБ | камера — заглушка: нарисованный кадр (ПРЕДПРОСМОТР) |
| Менеджер | 412 | «Камера-помощник»: стоп-кадр, «КД-301 · 91 %», карточка поверх кадра | ✅ | [manager-412-camera-card.png](manager-412-camera-card.png) 58 КБ | нарисованный кадр; ответ ИИ — заглушка VOICE_MOCK; заявки и ТО — рабочая база |
| Менеджер | 412 | «Моя компания» → «Системы»: значки, цвета, оборудование, заявки, подрядчики | ✅ | [manager-412-systems.png](manager-412-systems.png) 61 КБ |  |
| Менеджер | 412 | Заявка «КлиматСервис» 111: «Фото · 2» — «До» и «После», документы | ✅ | [manager-412-order-photos.png](manager-412-order-photos.png) 66 КБ |  |
| Менеджер | 412 | План этажа «3 этаж»: области и номера помещений | ✅ | [manager-412-plan-areas.png](manager-412-plan-areas.png) 62 КБ |  |
| Менеджер | 412 | «Моя компания» → «Журнал изменений доступа» | ✅ | [manager-412-audit.png](manager-412-audit.png) 17 КБ |  |
| Менеджер | 412 | Карточка подрядчика Huaxin FM → «Бригады» | ✅ | [manager-412-crews.png](manager-412-crews.png) 54 КБ |  |
| Менеджер | 412 | Бригада «Пекин» у Huaxin FM: исполнители и зона (как «Зона доступа») | ✅ | [manager-412-crew-zone.png](manager-412-crew-zone.png) 31 КБ | закрыто без сохранения |
| Исполнитель | 412 | Список заявок | ✅ | [executor-412-requests.png](executor-412-requests.png) 82 КБ |  |
| Исполнитель | 412 | Список заявок — конец списка | ✅ | [executor-412-requests-end.png](executor-412-requests-end.png) 83 КБ |  |
| Исполнитель | 412 | Заявки — свёрнутая шапка при прокрутке | ✅ | [executor-412-requests-collapsed.png](executor-412-requests-collapsed.png) 93 КБ | поиск и фильтры закреплены сверху, сегменты спрятаны |
| Исполнитель | 412 | Заявки — применённые фильтры по ссылке (таблетки «×», «Сбросить всё») | ✅ | [executor-412-filters-active.png](executor-412-filters-active.png) 73 КБ | ссылка #/?pri=critical,high&st=overdue,new,assigned,in_progress&period=30d&sort=priority |
| Исполнитель | 412 | Окно «Фильтры» с «Показать N заявок» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Окно фильтра «Статус» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Фильтр «Период» → «Свой период…» (календарь) | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Сортировка списка заявок | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Заявки — «Ничего не найдено» и «Сбросить фильтры» | ✅ | [executor-412-filter-empty.png](executor-412-filter-empty.png) 49 КБ | ссылка #/?rec=recurring&pri=critical |
| Исполнитель | 412 | Фильтр «Объект»: секции по городам, «Весь город» (Москва) | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Заявки с фильтром «Москва (5)», строки «Москва · Офис N» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Карточка подрядчика «ЭлектроСити» (2 объекта из 5 в Москве) | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Карточка заявки «Шумит вентилятор в переговорной» | ✅ | [executor-412-order.png](executor-412-order.png) 66 КБ |  |
| Исполнитель | 412 | Карточка заявки — меню «⋯» и диалог удаления | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Выбор подрядчика | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Голосовая заявка — распознавание | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Голосовая заявка — подтверждение | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Голосовая заявка — подтверждение, низкое окно | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Проверьте заявку — прокрутка колесом и PageDown | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | «Слушаю» → «Ввести текстом» с одного нажатия | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Сообщение «Напишите, что случилось» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Сообщение исчезает само (~3 с) | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Отчёты (30 дней) | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | История | ✅ | [executor-412-history.png](executor-412-history.png) 75 КБ |  |
| Исполнитель | 412 | Подрядчики | ✅ | [executor-412-contractors.png](executor-412-contractors.png) 63 КБ |  |
| Исполнитель | 412 | Локации | ✅ | [executor-412-locations.png](executor-412-locations.png) 69 КБ |  |
| Исполнитель | 412 | Локации — карта, все объекты | ✅ | [executor-412-map.jpg](executor-412-map.jpg) 44 КБ | все объекты, маркер — число открытых заявок |
| Исполнитель | 412 | Локации — карта, выбран регион «СНГ» (Москва) | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Локации — карта, выбранный объект | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Локации — карта, выделенная область | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Локации — карта, «Объекты рядом» (правый клик) | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Локации — карта, «Изменить место на карте» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Карта → «Заявки» объекта (фильтр) | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Карточка объекта — «Этажи · N» и помещения с этажами | ✅ | [executor-412-plan-object.png](executor-412-plan-object.png) 70 КБ | только чтение: без «+» и «⋯» |
| Исполнитель | 412 | План этажа «3 этаж» (открыт по ссылке) | ✅ | [executor-412-plan.png](executor-412-plan.png) 61 КБ | только чтение: нет «Редактировать» |
| Исполнитель | 412 | План — шторка маркера «Кондиционер серверной» | ✅ | [executor-412-plan-marker.png](executor-412-plan-marker.png) 69 КБ | подзаголовок без повтора этажа («… · Серверная, 3 этаж»), открытая просроченная заявка, «Создать заявку здесь» |
| Исполнитель | 412 | План — оборудование с просроченной заявкой (красное, «дышит») | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | План — режим расстановки | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | План без картинки — «Загрузить план» (менеджер) | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | План сразу после загрузки (без перезахода) | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | «Редактировать» — режим расстановки и перетаскивание | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | План — список «На плане / Не размещены» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Подсказка ⓘ «Что значат маркеры» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Карточка заявки — «Показать на плане» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | План, открытый из заявки (маркер подсвечен) | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Профиль | ✅ | [executor-412-profile.png](executor-412-profile.png) 31 КБ |  |
| Исполнитель | 412 | Уведомления | ✅ | [executor-412-notifications.png](executor-412-notifications.png) 72 КБ |  |
| Исполнитель | 412 | ППР — список планов, сводка «Октябрь: выполнено N из 8» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | ППР — карточка плана «ТО кондиционеров» (история периодов) | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Задача периода — карточка заявки «ППР · октябрь 2026 · до 31 окт.» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Локации по регионам → страна → город | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Окно выбора объектов: «Весь регион», «Вся страна», «Весь город» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Отчёты: блок «По регионам» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Карточка объекта: «Оборудование · N» по системам | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Карточка оборудования «Кондиционер серверной»: паспорт, план, ППР, заявки | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | «Узнать по фото» — «Где я» и «Сфотографировать» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | «Узнать по фото» — вид, система, «Скорее всего» и «Это он» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | «Это он» → новая заявка: объект, помещение, оборудование, система, снимок | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | «Камера-помощник»: живое видео, «Где я», рамка-прицел, «Что это?» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | «Камера-помощник»: стоп-кадр, «КД-301 · 91 %», карточка поверх кадра | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | «Моя компания» → «Системы»: значки, цвета, оборудование, заявки, подрядчики | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Заявка «КлиматСервис» 111: «Фото · 2» — «До» и «После», документы | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | План этажа «3 этаж»: области и номера помещений | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | «Моя компания» → «Журнал изменений доступа» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Карточка подрядчика Huaxin FM → «Бригады» | — |  | Нет у этой роли (так задумано) |
| Исполнитель | 412 | Бригада «Пекин» у Huaxin FM: исполнители и зона (как «Зона доступа») | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Список заявок | ✅ | [requester-412-requests.png](requester-412-requests.png) 87 КБ |  |
| Заявитель | 412 | Список заявок — конец списка | ✅ | [requester-412-requests-end.png](requester-412-requests-end.png) 83 КБ |  |
| Заявитель | 412 | Заявки — свёрнутая шапка при прокрутке | ✅ | [requester-412-requests-collapsed.png](requester-412-requests-collapsed.png) 94 КБ | поиск и фильтры закреплены сверху, сегменты спрятаны |
| Заявитель | 412 | Заявки — применённые фильтры по ссылке (таблетки «×», «Сбросить всё») | ✅ | [requester-412-filters-active.png](requester-412-filters-active.png) 90 КБ | ссылка #/?pri=critical,high&st=overdue,new,assigned,in_progress&period=30d&sort=priority |
| Заявитель | 412 | Окно «Фильтры» с «Показать N заявок» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Окно фильтра «Статус» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Фильтр «Период» → «Свой период…» (календарь) | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Сортировка списка заявок | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Заявки — «Ничего не найдено» и «Сбросить фильтры» | ✅ | [requester-412-filter-empty.png](requester-412-filter-empty.png) 49 КБ | ссылка #/?rec=recurring&pri=critical |
| Заявитель | 412 | Фильтр «Объект»: секции по городам, «Весь город» (Москва) | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Заявки с фильтром «Москва (5)», строки «Москва · Офис N» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Карточка подрядчика «ЭлектроСити» (2 объекта из 5 в Москве) | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Карточка заявки «Шумит вентилятор в переговорной» | ✅ | [requester-412-order.png](requester-412-order.png) 63 КБ |  |
| Заявитель | 412 | Карточка заявки — меню «⋯» и диалог удаления | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Выбор подрядчика | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Голосовая заявка — распознавание | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Голосовая заявка — подтверждение | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Голосовая заявка — подтверждение, низкое окно | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Проверьте заявку — прокрутка колесом и PageDown | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | «Слушаю» → «Ввести текстом» с одного нажатия | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Сообщение «Напишите, что случилось» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Сообщение исчезает само (~3 с) | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Отчёты (30 дней) | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | История | ✅ | [requester-412-history.png](requester-412-history.png) 73 КБ |  |
| Заявитель | 412 | Подрядчики | ✅ | [requester-412-contractors.png](requester-412-contractors.png) 63 КБ |  |
| Заявитель | 412 | Локации | ✅ | [requester-412-locations.png](requester-412-locations.png) 69 КБ |  |
| Заявитель | 412 | Локации — карта, все объекты | ✅ | [requester-412-map.jpg](requester-412-map.jpg) 45 КБ | все объекты, маркер — число открытых заявок |
| Заявитель | 412 | Локации — карта, выбран регион «СНГ» (Москва) | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Локации — карта, выбранный объект | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Локации — карта, выделенная область | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Локации — карта, «Объекты рядом» (правый клик) | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Локации — карта, «Изменить место на карте» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Карта → «Заявки» объекта (фильтр) | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Карточка объекта — «Этажи · N» и помещения с этажами | ✅ | [requester-412-plan-object.png](requester-412-plan-object.png) 70 КБ | только чтение: без «+» и «⋯» |
| Заявитель | 412 | План этажа «3 этаж» (открыт по ссылке) | ✅ | [requester-412-plan.png](requester-412-plan.png) 61 КБ | только чтение: нет «Редактировать» |
| Заявитель | 412 | План — шторка маркера «Кондиционер серверной» | ✅ | [requester-412-plan-marker.png](requester-412-plan-marker.png) 69 КБ | подзаголовок без повтора этажа («… · Серверная, 3 этаж»), открытая просроченная заявка, «Создать заявку здесь» |
| Заявитель | 412 | План — оборудование с просроченной заявкой (красное, «дышит») | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | План — режим расстановки | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | План без картинки — «Загрузить план» (менеджер) | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | План сразу после загрузки (без перезахода) | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | «Редактировать» — режим расстановки и перетаскивание | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | План — список «На плане / Не размещены» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Подсказка ⓘ «Что значат маркеры» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Карточка заявки — «Показать на плане» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | План, открытый из заявки (маркер подсвечен) | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Профиль | ✅ | [requester-412-profile.png](requester-412-profile.png) 31 КБ |  |
| Заявитель | 412 | Уведомления | ✅ | [requester-412-notifications.png](requester-412-notifications.png) 91 КБ |  |
| Заявитель | 412 | ППР — список планов, сводка «Октябрь: выполнено N из 8» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | ППР — карточка плана «ТО кондиционеров» (история периодов) | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Задача периода — карточка заявки «ППР · октябрь 2026 · до 31 окт.» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Локации по регионам → страна → город | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Окно выбора объектов: «Весь регион», «Вся страна», «Весь город» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Отчёты: блок «По регионам» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Карточка объекта: «Оборудование · N» по системам | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Карточка оборудования «Кондиционер серверной»: паспорт, план, ППР, заявки | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | «Узнать по фото» — «Где я» и «Сфотографировать» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | «Узнать по фото» — вид, система, «Скорее всего» и «Это он» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | «Это он» → новая заявка: объект, помещение, оборудование, система, снимок | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | «Камера-помощник»: живое видео, «Где я», рамка-прицел, «Что это?» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | «Камера-помощник»: стоп-кадр, «КД-301 · 91 %», карточка поверх кадра | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | «Моя компания» → «Системы»: значки, цвета, оборудование, заявки, подрядчики | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Заявка «КлиматСервис» 111: «Фото · 2» — «До» и «После», документы | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | План этажа «3 этаж»: области и номера помещений | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | «Моя компания» → «Журнал изменений доступа» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Карточка подрядчика Huaxin FM → «Бригады» | — |  | Нет у этой роли (так задумано) |
| Заявитель | 412 | Бригада «Пекин» у Huaxin FM: исполнители и зона (как «Зона доступа») | — |  | Нет у этой роли (так задумано) |
| Менеджер (EN) | 412 | EN — Work orders | ✅ | [manager-412-en-requests.png](manager-412-en-requests.png) 89 КБ |  |
| Менеджер (EN) | 412 | EN — Preventive maintenance (Maintenance) | ✅ | [manager-412-en-ppr.png](manager-412-en-ppr.png) 75 КБ |  |
| Менеджер (EN) | 412 | EN — Locations by region | ✅ | [manager-412-en-locations.png](manager-412-en-locations.png) 70 КБ |  |
| Менеджер (EN) | 412 | EN — Reports | ✅ | [manager-412-en-reports.png](manager-412-en-reports.png) 63 КБ |  |
| Менеджер (EN) | 412 | EN — карточка заявки «Шумит вентилятор в переговорной» | ✅ | [manager-412-en-order.png](manager-412-en-order.png) 64 КБ |  |
| Менеджер (EN) | 412 | EN — план этажа | ✅ | [manager-412-en-plan.png](manager-412-en-plan.png) 61 КБ |  |
| Менеджер | 360 | Список заявок | ✅ | [manager-360-requests.png](manager-360-requests.png) 67 КБ |  |
| Менеджер | 360 | Список заявок — конец списка | ✅ | [manager-360-requests-end.png](manager-360-requests-end.png) 63 КБ |  |
| Менеджер | 360 | Заявки — свёрнутая шапка при прокрутке | ✅ | [manager-360-requests-collapsed.png](manager-360-requests-collapsed.png) 67 КБ | поиск и фильтры закреплены сверху, сегменты спрятаны |
| Менеджер | 360 | Заявки — применённые фильтры по ссылке (таблетки «×», «Сбросить всё») | ✅ | [manager-360-filters-active.png](manager-360-filters-active.png) 74 КБ | ссылка #/?pri=critical,high&st=overdue,new,assigned,in_progress&period=30d&sort=priority |
| Менеджер | 360 | Окно «Фильтры» с «Показать N заявок» | ✅ | [manager-360-filters-panel.png](manager-360-filters-panel.png) 38 КБ | шторка на весь экран; число считает сервер |
| Менеджер | 360 | Окно фильтра «Статус» | ✅ | [manager-360-filter-picker.png](manager-360-filter-picker.png) 34 КБ | шторка поверх окна «Фильтры»; отмечены «Просрочено» и «Новая», закрыто без применения |
| Менеджер | 360 | Фильтр «Период» → «Свой период…» (календарь) | ✅ | [manager-360-filter-period.png](manager-360-filter-period.png) 33 КБ | окно «Период» (по дате создания / по сроку, пресеты) и календарь «с — по»; закрыто без выбора |
| Менеджер | 360 | Сортировка списка заявок | ✅ | [manager-360-filter-sort.png](manager-360-filter-sort.png) 45 КБ | 6 вариантов, галочка у текущей; выбор сразу применяется (здесь закрыто без выбора) |
| Менеджер | 360 | Заявки — «Ничего не найдено» и «Сбросить фильтры» | ✅ | [manager-360-filter-empty.png](manager-360-filter-empty.png) 46 КБ | ссылка #/?rec=recurring&pri=critical |
| Менеджер | 360 | Фильтр «Объект»: секции по городам, «Весь город» (Москва) | ✅ | [manager-360-filter-object.png](manager-360-filter-object.png) 37 КБ | отмечен «Весь город» у Москвы — «Применить (5)»; закрыто без применения |
| Менеджер | 360 | Заявки с фильтром «Москва (5)», строки «Москва · Офис N» | ✅ | [manager-360-filter-object-city.png](manager-360-filter-object-city.png) 70 КБ | ссылка #/?obj=<5 объектов Москвы> |
| Менеджер | 360 | Карточка подрядчика «ЭлектроСити» (2 объекта из 5 в Москве) | ✅ | [manager-360-contractor-card.png](manager-360-contractor-card.png) 43 КБ | виды работ; объекты по городам: МОСКВА · 2 |
| Менеджер | 360 | Карточка заявки «Шумит вентилятор в переговорной» | ✅ | [manager-360-order.png](manager-360-order.png) 54 КБ |  |
| Менеджер | 360 | Карточка заявки — меню «⋯» и диалог удаления | ✅ | [manager-360-order-delete.png](manager-360-order-delete.png) 53 КБ | меню «⋯» в шапке: «Отменить», «Удалить»; диалог закрыт кнопкой «Отмена» |
| Менеджер | 360 | Выбор подрядчика | ❌ | [manager-360-picker-error.png](manager-360-picker-error.png) 67 КБ | В списке нет заявки из демо-истории со статусом «Новая», «Назначена» или «Возвращена» |
| Менеджер | 360 | Голосовая заявка — распознавание | ✅ | [manager-360-voice.png](manager-360-voice.png) 37 КБ |  |
| Менеджер | 360 | Голосовая заявка — подтверждение | ✅ | [manager-360-voice-confirm.png](manager-360-voice-confirm.png) 51 КБ |  |
| Менеджер | 360 | Голосовая заявка — подтверждение, низкое окно | ✅ | [manager-360-voice-confirm-low.png](manager-360-voice-confirm-low.png) 46 КБ | окно 360×700, «Отправить» видна (низ кнопки — 690 px) |
| Менеджер | 360 | Проверьте заявку — прокрутка колесом и PageDown | ✅ | [manager-360-confirm-scroll.png](manager-360-confirm-scroll.png) 43 КБ | окно 360×700: колесо 800→545 px, Home 800, PageDown →545 px |
| Менеджер | 360 | «Слушаю» → «Ввести текстом» с одного нажатия | ✅ | [manager-360-voice-type.png](manager-360-voice-type.png) 20 КБ | поле открылось с первого нажатия, курсор в поле |
| Менеджер | 360 | Отчёты (30 дней) | ✅ | [manager-360-reports.png](manager-360-reports.png) 61 КБ |  |
| Менеджер | 360 | История | ✅ | [manager-360-history.png](manager-360-history.png) 65 КБ |  |
| Менеджер | 360 | Подрядчики | ✅ | [manager-360-contractors.png](manager-360-contractors.png) 62 КБ |  |
| Менеджер | 360 | Локации | ✅ | [manager-360-locations.png](manager-360-locations.png) 67 КБ |  |
| Менеджер | 360 | Локации — карта, все объекты | ✅ | [manager-360-map.jpg](manager-360-map.jpg) 40 КБ | все объекты, маркер — число открытых заявок |
| Менеджер | 360 | Локации — карта, выбран регион «СНГ» (Москва) | ✅ | [manager-360-map-city.jpg](manager-360-map-city.jpg) 68 КБ | чип региона «СНГ» (в нём только Москва) — объекты города; список — секции по городам |
| Менеджер | 360 | Локации — карта, выбранный объект | ✅ | [manager-360-map-selected.jpg](manager-360-map-selected.jpg) 62 КБ | карточка объекта, круг геозоны |
| Менеджер | 360 | Локации — карта, выделенная область | ✅ | [manager-360-map-area.jpg](manager-360-map-area.jpg) 68 КБ | рамка протянута мышью, список — только объекты внутри |
| Менеджер | 360 | Локации — карта, «Объекты рядом» (правый клик) | ✅ | [manager-360-map-nearby.jpg](manager-360-map-nearby.jpg) 68 КБ | радиус 3 км, список — по удалённости |
| Менеджер | 360 | Локации — карта, «Изменить место на карте» | ✅ | [manager-360-map-place.jpg](manager-360-map-place.jpg) 57 КБ | перекрестие по центру; закрыто кнопкой «Отмена», место не сохранено |
| Менеджер | 360 | Карта → «Заявки» объекта (фильтр) | ✅ | [manager-360-map-orders.png](manager-360-map-orders.png) 77 КБ | фильтр «Объект» = БЦ «Демо» (та же таблетка, что в строке фильтров), снимается крестиком |
| Менеджер | 360 | Карточка объекта — «Этажи · N» и помещения с этажами | ✅ | [manager-360-plan-object.png](manager-360-plan-object.png) 59 КБ | у менеджера — «+ Этаж», «+» и «⋯» у этажа |
| Менеджер | 360 | План этажа «3 этаж» (открыт по ссылке) | ✅ | [manager-360-plan.png](manager-360-plan.png) 57 КБ | ссылка #/objects/…/floors/…; маркеры помещений и оборудования, фильтр, список |
| Менеджер | 360 | План — шторка маркера «Кондиционер серверной» | ✅ | [manager-360-plan-marker.png](manager-360-plan-marker.png) 67 КБ | подзаголовок без повтора этажа («… · Серверная, 3 этаж»), открытая просроченная заявка, «Создать заявку здесь» |
| Менеджер | 360 | План — оборудование с просроченной заявкой (красное, «дышит») | ✅ | [manager-360-plan-overdue.png](manager-360-plan-overdue.png) 57 КБ | план целиком: квадраты оборудования — цвет статуса и бейдж числа заявок, «Кондиционер серверной» (просрочено) — красный ореол «дышит»; подписи помещений скрыты (они на картинке) |
| Менеджер | 360 | План — режим расстановки | ✅ | [manager-360-plan-edit.png](manager-360-plan-edit.png) 72 КБ | плашка «Режим расстановки · Готово»; маркеры перетаскиваются (здесь ничего не меняется) |
| Менеджер | 360 | План без картинки — «Загрузить план» (менеджер) | ✅ | [manager-360-plan-upload-empty.png](manager-360-plan-upload-empty.png) 58 КБ | ответ сервера в браузере — этаж без plan_path; база не меняется |
| Менеджер | 360 | План сразу после загрузки (без перезахода) | ✅ | [manager-360-plan-upload-done.png](manager-360-plan-upload-done.png) 54 КБ | файл подставлен Playwright; загрузка и запись этажа перехвачены в браузере |
| Менеджер | 360 | «Редактировать» — режим расстановки и перетаскивание | ✅ | [manager-360-plan-upload-edit.png](manager-360-plan-upload-edit.png) 79 КБ | плашка режима, контур маркеров; перенос «Кафе» перехвачен (3 записей не ушли в базу) |
| Менеджер | 360 | План — список «На плане / Не размещены» | ✅ | [manager-360-plan-unplaced.png](manager-360-plan-unplaced.png) 67 КБ | «Open space, 2 этаж» — без этажа, в «Не размещены» |
| Менеджер | 360 | Подсказка ⓘ «Что значат маркеры» | ✅ | [manager-360-plan-info.png](manager-360-plan-info.png) 73 КБ |  |
| Менеджер | 360 | Карточка заявки — «Показать на плане» | ✅ | [manager-360-plan-order.png](manager-360-plan-order.png) 63 КБ | превью плана, «3 этаж · N открытых заявок рядом» |
| Менеджер | 360 | План, открытый из заявки (маркер подсвечен) | ✅ | [manager-360-plan-from-order.png](manager-360-plan-from-order.png) 66 КБ | план центрирован на «Кондиционер серверной»: красные волны (просрочено), маркер ×1,25, подпись полужирная |
| Менеджер | 360 | Профиль | ✅ | [manager-360-profile.png](manager-360-profile.png) 31 КБ |  |
| Менеджер | 360 | Уведомления | ✅ | [manager-360-notifications.png](manager-360-notifications.png) 78 КБ |  |
| Менеджер | 360 | Сообщение «Напишите, что случилось» | ✅ | [manager-360-message.png](manager-360-message.png) 52 КБ | сверху (x 16, y 52 px), кнопка «Отправить» открыта |
| Менеджер | 360 | Сообщение исчезает само (~3 с) | ✅ | [manager-360-message-gone.png](manager-360-message-gone.png) 49 КБ | исчезло через 3.3 с |
