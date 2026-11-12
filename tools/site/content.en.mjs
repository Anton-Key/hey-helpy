// Site copy — English (address «/en/»). Same facts as content.ru.mjs; terms as in the app
// (CLAUDE.md, «Языки»): Work order, Contractor, Preventive maintenance, Floor plan, Access zone, System, Contractor act.

import { ROI_SHOW_PRICES } from './config.mjs';
import { REGIONS, fmtMoney } from './roi.mjs';
import { roiBody, exampleRoi } from './roi_page.mjs';

export const ui = {
  lang: 'en',
  locale: 'en_US',
  skip: 'Skip to content',
  menu: 'Menu',
  login: 'Sign in',
  demo: 'Apply for a pilot',
  howCta: 'See how it works',
  legend: 'Dokazio (doh-KAH-zee-oh) — from “dokaz”, Serbian for “proof”.',
  home: 'Home',
  otherLang: 'Русский',
  otherLangShort: 'RU',
  footerNote: 'Dokazio — Contractor Control. Send the job. See it done. The product is at the MVP stage.',
  footerAi: 'For AI assistants',
  shotNote: 'App screen, demo data',
  illNote: 'Illustration',
  demoFrame: 'Demo frame — not measured accuracy',
  roiCta: 'Estimate your ROI',
  roiLink: 'Open the ROI calculator',
  videoNote: 'The video is in English with on-screen captions, 2 min 17 s, no sound. Demo data; AI responses in the recording are simulated.',
};

export const llmsIntro = 'Dokazio — Contractor Control (pronounced doh-KAH-zee-oh, from “dokaz”, Serbian for “proof”; tagline: “Send the job. See it done.”) is an AI service for property maintenance (CMMS / facility management) and contractor control for business and shopping centres, chains and retail, property management and FM companies, and public-sector customers: work orders by text, camera or voice, in the app or via Telegram, automatic contractor assignment, proof of completion (an “after” photo with a stamp, a geofenced visit, a checklist) and a contractor act where only proven work is payable. Web and Android. Stage: MVP; ' + (ROI_SHOW_PRICES ? `subscription per site from ${fmtMoney(REGIONS.US.prices.S, 'US', 'en')} per month by site area, contractors pay nothing` : 'pricing on request') + '; pilots available.';

// Калькулятор окупаемости (шаг 35). Тексты — из docs/site/roi-calculator-brief.md (разделы 2–9),
// цифры подставляет roi_page.mjs из tools/site/roi.mjs.
const SOURCES = [
  ['Salary.com — Facilities Coordinator salary (US)', 'https://www.salary.com/research/salary/listing/facilities-coordinator-salary'],
  ['U.S. Bureau of Labor Statistics — Administrative Services and Facilities Managers', 'https://www.bls.gov/ooh/management/administrative-services-managers.htm'],
  ['Payscale UK — Facilities Coordinator salary', 'https://www.payscale.com/research/UK/Job=Facilities_Coordinator/Salary'],
  ['StepStone DE — Facility Manager salary', 'https://stepstone.de/gehalt/Facility-Manager-in.html'],
  ['Payscale UAE — Facilities Coordinator salary', 'https://www.payscale.com/research/AE/Job=Facilities_Coordinator/Salary'],
  ['Oxmaint — facility management cost per sq ft benchmarks 2026 (IFMA 2025 / BOMA 2024 median)', 'https://oxmaint.com/industries/facility-management/facility-management-cost-per-sqft-benchmarks-2026'],
  ['Vixxo — the hidden cost of overcharges (vendor estimate)', 'https://www.vixxo.com/facilities-management-news/the-hidden-cost-of-overcharges-how-vixxo-verify-found-2.6m-in-savings'],
  ['ServiceChannel — Ovation Brands case study', 'https://servicechannel.com/case-study/ovation-brands/'],
];

export const roi = {
  h1: 'How much would proven work save you?',
  lead: 'A one-minute estimate for your portfolio: the staff time Dokazio takes over (sending work orders, collecting photos and acts, reconciling the monthly statement) plus the contractor overbilling you stop paying for, because work without proof is not paid. We use cautious defaults: 3% overbilling, adjustable from 3% to 10%.',
  noJs: 'The interactive calculator needs JavaScript. Below are reference examples, prices and how we calculate — the same formulas the calculator uses.',
  demo: 'Apply for a pilot',
  honest: 'This is an estimate based on industry data and our assumptions, not a promise. A pilot on your sites will show real numbers.',
  priceOnRequest: 'Pricing on request',
  custom: 'custom',
  regionShort: { US: 'United States', EU: 'UK / EU', GCC: 'Gulf' },
  regionLong: { US: 'United States (USD)', EU: 'UK / Europe (EUR)', GCC: 'Gulf — UAE, Saudi Arabia (AED)' },
  tierName: { S: 'Site S', M: 'Site M', L: 'Site L', custom: 'Over 30,000 m²' },
  tierArea: { S: 'up to {s} m²', M: '{s}–{m} m²', L: '{m}–{l} m²', custom: '—' },
  ex: {
    title: 'Reference examples',
    text: 'One site of 5,000 m² (Site M), default hours, monthly billing, no payout fee. Amounts per month, in the currency of the region.',
    caption: '1 site, 5,000 m², per month',
    metric: 'Per month',
    spend: 'Contractor spend',
    time: 'Staff time',
    over: 'Cut overbilling at {p}',
    value: 'Benefit at {p}',
    price: 'Dokazio price',
    net: 'Net benefit at {p}',
    roi: 'Return at {p}',
    gulfNote: 'In the Gulf, at 3% the return is about ×1.0 — we show it as it is. Staff time costs less there, so the main benefit is control of overbilling and records for civil defence inspections.',
  },
  prices: {
    title: 'Prices',
    caption: 'Subscription per site, per month',
    tier: 'Tier',
    area: 'Site area',
    notes: [
      '<strong>Contractors use it free and pay nothing.</strong> Only the customer pays.',
      '{d} off when paying a year in advance.',
      'No percentage of your contractor spend — the price depends only on the site area.',
      'Optional, from 2028: paying contractors through Dokazio via a partner bank — {us} / {eu} / {gcc} per payout, paid by the customer, regardless of the invoice amount. Off by default in the calculator.',
      'Paid pilot: 90 days at 50% of the price, credited towards an annual contract (not included in the calculation).',
    ],
    free: 'Contractors use it free and pay nothing.',
  },
  kind: { fact: 'fact', assumption: 'assumption', calc: 'calculated', estimate: 'estimate' },
  how: {
    title: 'How we calculate',
    steps: [
      '<strong>Staff time.</strong> Hours saved per site per month (by default 15 coordinator hours and 5 facility manager hours) × the cost of an hour. The cost of an hour = annual salary × 1.25 (taxes and social contributions) / 2,080 working hours.',
      '<strong>Cut overbilling.</strong> Contractor spend per site per month × the overbilling share. By default, contractor spend = site area × repair and maintenance cost per m² per year × 70% (the share that goes to contractors) / 12. You can enter your own figure.',
      '<strong>Benefit</strong> = staff time + cut overbilling, multiplied by the number of sites.',
      '<strong>Dokazio cost</strong> = subscription for the site’s area tier (−15% for annual payment) + the optional payout fee, multiplied by the number of sites.',
      '<strong>Net benefit</strong> = benefit − cost; per year = × 12. <strong>Return</strong> = benefit / cost, shown as “×2.6”. The range is the same calculation at 3% and at 10% overbilling.',
      'Money is rounded to whole units of currency, the return to one decimal place. Sites over 30,000 m² have custom pricing — we do not estimate them.',
    ],
    tableCaption: 'Default assumptions by region',
    param: 'Parameter',
    type: 'Type',
    coordSalary: 'Facilities coordinator salary, per year',
    fmSalary: 'Facility manager salary, per year',
    burden: 'Taxes and social contributions multiplier',
    hoursYear: 'Working hours per year (40 h × 52 weeks)',
    coordHour: 'Coordinator, cost per hour',
    fmHour: 'Facility manager, cost per hour',
    repair: 'Repair and maintenance cost per m² per year',
    share: 'Share of that cost paid to contractors',
    hours: 'Hours saved per site per month',
    hoursValue: '{c} coordinator + {f} FM',
    overbilling: 'Overbilling in contractor invoices',
    overbillingValue: '{p} ({min}–{max})',
    notes: 'US repair cost: ${sqft} per sq ft per year (IFMA 2025 / BOMA 2024 median via Oxmaint); 1 m² = {m2} sq ft. UK / EU = {eu} of the US figure, Gulf = {gcc} (our assumptions). Fixed exchange rates: 1 EUR = {eur} USD, 1 USD = {aed} AED. UK / EU salaries: coordinator — Payscale UK (£28,044) converted to euros, facility manager — StepStone DE. Gulf salaries are based on small samples. Hours saved come from the founder’s experience and will be checked in pilots.',
    sourcesTitle: 'Sources',
    sources: SOURCES,
    vendorNote: 'Overbilling of 10–15% is an estimate by Vixxo, a vendor with an interest in the topic, so we use it only as the upper bound, never as the default. The ServiceChannel case (Ovation Brands) reports an 11.8% lower average invoice; ACFE 2024 describes billing fraud in general. Dokazio has no paying customers yet: none of these numbers are our customers’ results.',
  },
  form: {
    submit: 'Calculate',
    title: 'Your sites',
    region: 'Region',
    sites: 'Number of sites',
    sitesHint: 'From 1 to {max}.',
    area: 'Average site area',
    unit: 'Unit of area',
    m2: 'm²',
    sqft: 'sq ft',
    areaHint: 'Site S — up to {s} m², M — up to {m} m², L — up to {l} m².',
    spend: 'Contractor spend per site, per month',
    over: 'Overbilling in contractor invoices',
    overHint: '3% is a cautious estimate. Move the slider up to 10%.',
    annual: 'Pay annually ({d} off)',
    more: 'Advanced: hours and contractor payouts',
    hc: 'Coordinator hours saved per site, per month',
    hf: 'Facility manager hours saved per site, per month',
    hoursHint: 'From 0 to 744.',
    payouts: 'Pay contractors through Dokazio (from 2028)',
    payoutsHint: '{us} / {eu} / {gcc} per payout, paid by you — not a percentage of the invoice.',
    k: 'Payouts per site, per month',
    kHint: 'About 10 by default.',
  },
  out: {
    title: 'Your estimate',
    roi: 'Return on cost',
    net: 'Net benefit',
    value: 'Benefit',
    perMonth: '/ month',
    perYear: '/ year',
    cost: 'Dokazio cost',
    free: 'Contractors use it free and pay nothing.',
    time: 'Staff time',
    over: 'Cut overbilling',
    fix: 'Check the highlighted fields — then the estimate will appear.',
    custom: 'Sites over 30,000 m² (about 322,900 sq ft) have custom pricing, so we do not show an estimate for them. Apply for a pilot — we will calculate it together for your portfolio.',
    gulf: 'In the Gulf, the main benefit is control of overbilling and records for civil defence inspections, not staff time.',
  },
  js: {
    spendHint: 'Calculated from the area: {v} per month. Leave empty or enter your own figure.',
    spendHintEmpty: 'Leave empty to calculate it from the area, or enter your own figure.',
    costValue: '{m} per month (Site {tier}, {site} per site)',
    range: 'Net benefit from {low} (3%) to {high} (10%) per month; return from {roiLow} to {roiHigh}.',
    rangeNoPrice: 'Benefit from {low} (3%) to {high} (10%) per month.',
    perMonthYear: '{m} per month · {y} per year',
    overLabel: 'Cut overbilling ({p})',
    priceOnRequest: 'Pricing on request',
    err: {
      any: 'Enter a number.',
      sites: { required: 'Enter the number of sites.', number: 'Use digits only, for example 12.', any: 'Enter a whole number from 1 to 500.' },
      areaM2: { required: 'Enter the average site area.', number: 'Use digits only, for example 5000.', min: 'The area must be greater than 0.', max: 'That is too large — enter up to 1,000,000 m².' },
      contractorSpend: { number: 'Use digits only, or leave empty.', any: 'Enter 0 or more, or leave empty.' },
      hoursCoord: { number: 'Use digits only, for example 15.', any: 'Enter from 0 to 744 hours.' },
      hoursFm: { number: 'Use digits only, for example 5.', any: 'Enter from 0 to 744 hours.' },
      overbilling: { any: 'Choose from 3% to 10%.' },
      payoutsPerSite: { number: 'Use digits only, for example 10.', any: 'Enter a whole number from 0 to 1,000.' },
    },
  },
  cta: {
    title: 'Check it on your own sites',
    text: 'A pilot shows real numbers instead of estimates: your sites, your contractors, payment only for proven work.',
    faq: 'Questions and answers',
  },
};

export const pages = {
  home: {
    slug: '',
    nav: 'Home',
    title: 'Dokazio — Contractor Control: send the job, see it done',
    description: 'For business and shopping centres, chains and retail, property management and FM companies, public sector: work orders by text, camera or voice; only proven work gets paid.',
    h1: 'Send the job. See it done.',
    body: (h) => `
<section class="hero">
  <div class="hero-text">
    <p class="kicker">Dokazio — Contractor Control for business and shopping centres, chains and retail, property management and FM companies, public-sector customers</p>
    <h1>Send the job. See it done.</h1>
    <p class="lead">Dispatch work to any contractor in one tap. Dokazio shows proof the work was done at the exact equipment, so you pay only for verified work.</p>
    <p class="actions">${h.cta('primary')} <a class="btn ghost" href="#how">${ui.howCta}</a></p>
    <p class="legend">${ui.legend}</p>
    <p>${h.link('roi', ui.roiCta + ' →')} · <a href="#video">Watch the two-minute video</a></p>
  </div>
  ${h.ill('hotel_ac', 'Hotel room: an AR label above the air conditioner with diagnostics and an open work order', { eager: true })}
</section>

<section aria-labelledby="problem">
  <h2 id="problem">How many people does it take to fix one lock?</h2>
  <p>An employee posts in a group chat. The receptionist calls the dispatcher. The dispatcher looks up which contractor handles doors at this site. The manager sends reminders. The contractor shows up when they can and sends an invoice. Accounting pays — on trust.</p>
  <p>Everyone does their part, yet in the end nobody can show <strong>that the work was done, where, when and by whom</strong>. Requests get lost in chats, overdue work only surfaces through complaints, and whatever is on the invoice gets paid.</p>
</section>

<section aria-labelledby="how">
  <h2 id="how">How it works</h2>
  <ol class="steps">
    <li><h3>Intake</h3><p>Say it: “Hey, Dokazio, water is dripping from the air conditioner in the third-floor meeting room.” Or point the camera at the equipment. Or message the Telegram bot — requesters need no app, just the QR code at the site.</p></li>
    <li><h3>AI parses it</h3><p>An AI model works out what happened, in which room, which building system it is and how urgent. From a photo, the service suggests matching equipment from the site’s asset register — a person confirms which unit it is.</p></li>
    <li><h3>Contractor</h3><p>The work order goes straight to the contractor assigned to that system at that site. The technician gets a notification and takes it with one tap.</p></li>
    <li><h3>Proof</h3><p>The “after” photo can only be taken with the app’s live camera and carries a stamp: date · site · room · inside geofence. The visit is checked against the site’s geofence, the checklist item by item. No “after” photo — no hand-over.</p></li>
    <li><h3>Contractor act</h3><p>At month-end the contractor act is built automatically: only accepted work with proof is payable, disputed items go to a manager’s decision, the rest show why they are not payable.</p></li>
  </ol>
  ${h.ill('phone', 'A hand holds a phone pointed at an office air conditioner: a label above it shows work orders and maintenance', { cls: 'tall' })}
</section>

<section aria-labelledby="any-unit">
  <h2 id="any-unit">Any unit, same flow</h2>
  <p>A fridge, a faucet, a light or a lobby camera — the technician points the camera, the service suggests matching equipment from the site’s register, the technician confirms it and sees its work orders and preventive maintenance. A new work order takes one tap, with the place and equipment already filled in.</p>
  <div class="ills">
    <div>${h.ill('fridge', 'Office fridge with an AR card and a maintenance checklist')}<h3>Office fridge</h3><p>The preventive maintenance checklist right at the unit.</p></div>
    <div>${h.ill('faucet', 'Leaking faucet with a plumbing AR label')}<h3>Leaking faucet</h3><p>A work order with a “before” photo goes to the contractor assigned to plumbing at the site.</p></div>
    <div>${h.ill('led', 'Faulty LED ceiling panel with an AR label')}<h3>Light fixture</h3><p>The fault is visible in the shot; due date and contractor are in the work order.</p></div>
    <div>${h.ill('cctv', 'Lobby security camera with an AR card')}<h3>Lobby camera</h3><p>Security systems have their own contractor, equipment and history.</p></div>
  </div>
</section>

<section aria-labelledby="features">
  <h2 id="features">Highlights</h2>
  <div class="cards">
    ${h.card('camera', 'Camera assistant', 'Point the camera at an air conditioner — the service suggests which unit from the site’s register it may be, you confirm it and see its open work orders, preventive maintenance and last job.', 'Camera assistant: air conditioner AC-301 labelled 91 % in a demo frame, card with an open work order, maintenance and last job', h.demoFrame)}
    ${h.card('telegram', 'Work orders from Telegram', 'A requester reports a fault in Telegram via the site’s QR code — no app needed. The contractor’s technician gets a notification from the bot and handles the work order in the app.', 'Technician chat with the bot: a new work order notification (mock-up with the bot’s texts)')}
    ${h.card('photos', '“Before” and “after” photos', 'The work order holds all the proof: photos before and after, time, place, documents.', 'Work order card: “before” and “after” photos and a maintenance document')}
  </div>
  ${h.figure('act', 'Contractor acts: 5 work orders payable, 4 without proof, 56 % of work proven', 'Contractor act: only proven work is payable')}
  <p>${h.link('features', 'All features →')}</p>
</section>

<section aria-labelledby="spatial">
  <h2 id="spatial">Dokazio Spatial — work orders on the plan and in space</h2>
  <p>Rooms and equipment are pinned on the floor plan, and anything overdue stands out. On ARCore phones, a person places AR labels with work orders and maintenance right above the equipment. The illustration shows where we are taking this: the whole floor, with every work order tied to its place.</p>
  ${h.ill('iso', 'Isometric office floor: rooms, equipment and work order markers')}
</section>

<section aria-labelledby="proof-home">
  <h2 id="proof-home">Proof of completion</h2>
  <p>The “after” photo comes only from the app’s live camera, with a stamp: date, site, room, “inside geofence”. The visit is checked against the site’s geofence, the checklist item by item. Only proven work goes into the contractor act as payable.</p>
  ${h.ill('pipe', 'Pipes in a plant room with an inspection AR label')}
</section>

<section aria-labelledby="video">
  <h2 id="video">Two-minute demo</h2>
  <p>The full story of one fault: spoken request → camera → work order with a photo → proof → contractor act.</p>
  ${h.video('Dokazio demo: voice work order, camera assistant, “after” photo and contractor act')}
</section>

<section aria-labelledby="who">
  <h2 id="who">Who it is for</h2>
  <ul class="ticks">
    <li>Business centres and shopping centres</li>
    <li>Chains and retail: many sites across cities and countries</li>
    <li>Property management and FM companies working with contractors</li>
    <li>Public-sector clients and restricted-access sites</li>
  </ul>
  <p>${h.link('industries', 'More about each scenario →')}</p>
</section>

${h.ctaBlock()}
`,
  },

  features: {
    slug: 'features/',
    nav: 'Features',
    title: 'Features — Dokazio',
    description: 'Work orders by text, camera or voice and from Telegram, AR labels, proof-based contractor payment, roles, offline work, preventive maintenance, floor plans, reports.',
    h1: 'Features',
    body: (h) => `
<h1>Features</h1>
<p class="lead">The four stages of maintenance — intake, dispatch, execution, control — in one service. Below is what already works in the product.</p>
<nav class="toc" aria-label="On this page"><ul>
  <li><a href="#voice">Voice work orders</a></li><li><a href="#photo">Photo and camera</a></li><li><a href="#ar">AR labels</a></li><li><a href="#telegram">Telegram</a></li>
  <li><a href="#proof">Proof-based payment</a></li><li><a href="#roles">Roles</a></li><li><a href="#offline">Offline</a></li>
  <li><a href="#ppr">Preventive maintenance</a></li><li><a href="#plans">Floor plans</a></li><li><a href="#docs">Documents</a></li>
  <li><a href="#reports">Reports</a></li><li><a href="#zones">Regions and access zones</a></li>
</ul></nav>

<section aria-labelledby="voice">
  <h2 id="voice">Voice work orders</h2>
  <div class="split">
    <div>
      <p>Tap “Dokazio” and speak. The text appears as you talk; speech recognition is done by the browser (Chrome, Edge) or by Android.</p>
      <ul>
        <li>An AI model turns the phrase into work order fields: title, description, system (HVAC, electrical, plumbing…), room and priority.</li>
        <li>If the AI does not answer in time, a built-in dictionary parses the request; the screen shows which one did: “Parsed by AI” or “Parsed by dictionary”.</li>
        <li>Before sending, a person checks and can edit any field. Typing is always an option.</li>
        <li>The contractor is assigned automatically by system and site.</li>
      </ul>
    </div>
    ${h.img('voice', 'Voice work order check: parsed by AI, system HVAC, room 301 meeting room, priority high', { cls: 'phone' })}
  </div>
</section>

<section aria-labelledby="photo">
  <h2 id="photo">Photo and the camera assistant</h2>
  <div class="split">
    <div>
      <p>A technician or employee points the phone camera at the equipment and taps “What is this?”.</p>
      <ul>
        <li>A multimodal model describes the shot: equipment type (from a catalogue of 22 types), system, readable nameplate, visible defect.</li>
        <li>The service suggests units from the site’s register that may match — by serial number, model, type, room and floor: up to three candidates with reasons. A person confirms the right one (“This is it”) or picks another.</li>
        <li>Equipment card: open work orders, next preventive maintenance, last completed job.</li>
        <li>“Create work order” — site, room, equipment and system are pre-filled, the shot is attached as the “before” photo.</li>
        <li>If there is no equipment in the frame, the service says so. The recognition shot is neither stored nor logged.</li>
      </ul>
    </div>
    ${h.img('camera', 'Camera assistant: frozen frame labelled “AC-301 · 91 %” and the air conditioner card', { cls: 'phone', caption: h.demoFrame })}
  </div>
</section>

<section aria-labelledby="ar">
  <h2 id="ar">AR labels</h2>
  <p>Point the camera at the equipment and confirm which unit from the register it is — a label with open work orders and preventive maintenance is placed above it, for example “AC-301 · 1 open work order · maintenance by 31.10”. The label stays in place while you walk around the room. In the first version labels are placed by a person.</p>
  <ul>
    <li>Tap the label to open the equipment card or create a work order with the site, room and equipment already filled in.</li>
    <li>The service suggests candidates from the register, as in the camera assistant, and a person chooses; the shot is neither stored nor logged.</li>
    <li>The phone’s position in the room is calculated on the phone itself. No data goes to third-party AR services: Google’s cloud anchors and geospatial positioning are switched off.</li>
    <li>Works in the Android app on phones that support ARCore. Other devices get the regular camera assistant.</li>
    <li>Labels are not yet kept between sessions: after the screen is closed, labels have to be placed again. An internet connection is required — suggestions come from the server.</li>
  </ul>
</section>

<section aria-labelledby="telegram">
  <h2 id="telegram">Work orders and notifications in Telegram</h2>
  <div class="split">
    <div>
      <ul>
        <li><strong>Guests via QR code.</strong> An A4 poster with a QR code hangs at the site. Anyone, without an account, messages the bot with text, a voice note or a photo — a work order is created for that site. Guests see only the site of their link; the number of requests is limited.</li>
        <li><strong>Team groups.</strong> A Telegram group is linked to a site with a code from the app; the bot reads only messages addressed to it.</li>
        <li><strong>Employees</strong> link their account with a code and create work orders with the same permissions as in the app.</li>
        <li><strong>The requester</strong> receives “in progress” and “done ✅” — with the “after” photo. Notifications can be turned off.</li>
        <li><strong>The contractor’s technician</strong> only gets a Telegram notification about a new work order; the work order itself is received and handled in the app.</li>
      </ul>
    </div>
    ${h.img('telegram', 'Technician chat with the bot: a new work order notification (mock-up with the bot’s texts)', { cls: 'phone' })}
  </div>
</section>

<section aria-labelledby="proof">
  <h2 id="proof">Proof-based payment</h2>
  <p>The monthly contractor act is built automatically and splits work orders into three groups:</p>
  <ol>
    <li><strong>Payable</strong> — accepted by a manager, with an “after” photo (if required), a visit inside the site’s geofence (if the site has coordinates) and a fully completed checklist.</li>
    <li><strong>Needs a manager’s decision</strong> — for example, the time of an offline photo is not verified, the photo was uploaded from a file rather than taken with the camera, or it arrived after the work order was cancelled. The manager approves it for payment (a comment is required) or rejects it — the decision is recorded.</li>
    <li><strong>No proof</strong> — with the reason: no “after” photo, visit outside the geofence, no visit, work not accepted.</li>
  </ol>
  <p>Amounts are calculated from the contractor’s rates “per work order” and “per maintenance visit”. The act gets a number like АКТ-2026-001 and exports to PDF and Excel; a re-issued act gets a new number and the previous one is marked “replaced”.</p>
  ${h.figure('act', 'Contractor acts screen: “Payable” and “No proof” groups with reasons', 'Contractor act: what is payable, what is not, and why')}
  <h3>What counts as proof</h3>
  <ul>
    <li><strong>“After” photo</strong> — live app camera only, no gallery. A stamp is burnt into the image: date and time, site, room, “inside geofence”. A photo from a file (possible only in a browser without a camera) is labelled and does not count as proof in the act.</li>
    <li><strong>Geofenced visit</strong> — the time, distance to the site and whether it is inside the radius (150 m by default) are computed by the database, not the phone.</li>
    <li><strong>Checklist</strong> — who ticked each item and when is recorded by the database.</li>
  </ul>
</section>

<section aria-labelledby="roles">
  <h2 id="roles">Roles and segregation of duties</h2>
  <p>Who can do what with a work order is enforced by the <strong>database</strong> (access policies and triggers), not just the interface. Going around the app does not get around the rules.</p>
  <div class="table-wrap"><table>
    <caption>Who does what with a work order</caption>
    <thead><tr><th scope="col">Action</th><th scope="col">Who</th></tr></thead>
    <tbody>
      <tr><td>Create a work order</td><td>Employee (requester), manager, Telegram guest via the site link</td></tr>
      <tr><td>Assign contractor, due date, priority</td><td>Manager with rights to the site and system, administrator</td></tr>
      <tr><td>Start work, check in, tick the checklist, take the “after” photo, submit for review</td><td>Only a technician of the assigned contractor</td></tr>
      <tr><td>Accept or return the work</td><td>Manager or administrator — but not the person who submitted it</td></tr>
      <tr><td>Cancel</td><td>Manager; the author — until work has started</td></tr>
    </tbody>
  </table></div>
  <p><strong>A manager cannot close work on a contractor’s behalf.</strong> If a company has its own maintenance team, it is set up as a contractor, and another manager or the administrator accepts the work.</p>
</section>

<section aria-labelledby="offline">
  <h2 id="offline">Working offline</h2>
  <p>Basements, roofs and plant rooms often have no signal. The Android app keeps working without it:</p>
  <ul>
    <li>create a new work order — by text, with a “before” photo from the live camera; site, room and type of work are picked from reference data saved on the phone; the work order is sent automatically once the connection is back and is marked “Created offline”;</li>
    <li>their work orders with checklists, rooms, floor plans and “before” photos are saved on the phone in advance;</li>
    <li>start, check in, tick the checklist, take the “after” photo, submit — actions are queued and sent automatically once the connection is back;</li>
    <li><strong>trusted time</strong>: the time of each action is counted from the last server contact using a clock that cannot be changed, or from GPS; if the phone clock is off by more than 5 minutes, the time is marked “not verified”;</li>
    <li><strong>photo fingerprint</strong> (SHA-256) is taken on the phone and verified on the server — a swapped file is detected;</li>
    <li>disputed cases (time not verified, work order cancelled while offline) land in the act under “Needs a manager’s decision”.</li>
  </ul>
  <p>The creation time of a work order, like the time of the technician’s actions, is trusted time. Signing out deletes everything stored on the phone. The web version does not work offline.</p>
</section>

<section aria-labelledby="ppr">
  <h2 id="ppr">Preventive maintenance</h2>
  <div class="split">
    <div>
      <ul>
        <li>A maintenance plan: system, site or a specific piece of equipment, frequency — month, quarter, half-year, year or every N days, checklist.</li>
        <li>Tasks for each period are created automatically, without duplicates, and go to the assigned contractor.</li>
        <li>See how much is done this month, what has not started and what is overdue; each plan keeps 12 periods of history.</li>
        <li>Maintenance visits are paid at their own rate in the contractor act.</li>
      </ul>
    </div>
    ${h.img('ppr', 'Preventive maintenance: monthly tasks grouped into “Not started”, “In progress”, “Done”', { cls: 'wide' })}
  </div>
</section>

<section aria-labelledby="plans">
  <h2 id="plans">Floor plans and equipment</h2>
  <ul>
    <li>Floor plans are uploaded as images (PNG, JPEG, WebP); rooms and equipment are placed on the plan as points.</li>
    <li>Markers are coloured by the most urgent work order, equipment shows the number of open work orders; “Show on plan” from a work order.</li>
    <li>Asset register: type, system, manufacturer, model, serial number, installation date, work order history and maintenance plans. Import from Excel and CSV using a template.</li>
    <li>Sites on a map, clustered by city; grouped region → country → city.</li>
  </ul>
  ${h.figure('plan', 'Floor plan on desktop: room and equipment markers; the server room air conditioner with an overdue work order is highlighted in red', 'Floor plan: overdue work stands out (drawn demo plan)')}
</section>

<section aria-labelledby="docs">
  <h2 id="docs">Documents</h2>
  <p>Documents can be attached to a work order: PDF, DOC(X), XLS(X), JPG, PNG, TXT — up to 20 MB. Files are private: they open via a temporary link and only for those who can see the work order.</p>
  ${h.img('photos', 'Work order card: “before” and “after” photos and the Documents section', { cls: 'phone center' })}
</section>

<section aria-labelledby="reports">
  <h2 id="reports">Reports</h2>
  <ul>
    <li>Per contractor for a period: geofenced visits, time on site, share of work done on time, first-time acceptance, returns.</li>
    <li>Breakdowns by region and work order type, photo recognition statistics.</li>
    <li>Report as PDF in one tap; contractor act as PDF and Excel.</li>
    <li>History of accepted and cancelled work orders for a period.</li>
  </ul>
  ${h.figure('reports', 'Contractor report for 30 days: visits, time, on-time share, first-time acceptance', 'Contractor control in numbers (demo data)')}
</section>

<section aria-labelledby="zones">
  <h2 id="zones">Regions and access zones</h2>
  <ul>
    <li>A portfolio of sites across cities and countries: regions, countries, cities.</li>
    <li>A manager’s access zone is “systems × places”, e.g. “HVAC · Dubai”: the manager sees and changes only their part.</li>
    <li>Contractor crews: a technician sees only the work orders in their crew’s zone.</li>
    <li>Access change log (roles, zones, crews) — administrator only, read-only.</li>
    <li>Interface in English and Russian.</li>
  </ul>
</section>

${h.ctaBlock()}
`,
  },

  industries: {
    slug: 'industries/',
    nav: 'Who it’s for',
    title: 'Who it’s for — Dokazio',
    description: 'Dokazio for business and shopping centres, chains and retail, property management and FM companies, public-sector and restricted-access sites.',
    h1: 'Who it’s for',
    body: (h) => `
<h1>Who it’s for</h1>
<p class="lead">Dokazio fits wherever buildings are serviced by contractors and you want to pay only for work actually done — in the United States, Europe and the Middle East.</p>

<section aria-labelledby="bc">
  <h2 id="bc">Business centres and shopping centres</h2>
  <ul>
    <li>Tenants and staff report faults by voice, photo or via a QR code in Telegram — no calls to reception.</li>
    <li>Each work order is tied to a room and a point on the floor plan; overdue work stands out.</li>
    <li>Each system (HVAC, electrical, plumbing, cleaning, security) has its own contractors and equipment.</li>
    <li>Scheduled preventive maintenance without spreadsheets: monthly tasks are created automatically.</li>
  </ul>
</section>

<section aria-labelledby="retail">
  <h2 id="retail">Chains and retail</h2>
  <ul>
    <li>Many sites in different cities and countries — on one map, by region.</li>
    <li>A regional manager sees only their zone: their cities and systems.</li>
    <li>Contractors are assigned to systems and sites; work orders reach the right one automatically.</li>
    <li>A report for each contractor: visits, time on site, on-time work.</li>
  </ul>
</section>

<section aria-labelledby="fm">
  <h2 id="fm">Property management and FM companies</h2>
  <ul>
    <li>A contractor act where only proven work is payable — stamped “after” photo, geofenced visit, checklist.</li>
    <li>Segregation of duties: the technician submits, someone else accepts.</li>
    <li>A PDF report for the owner in one tap.</li>
    <li>Contractor technicians receive and handle work orders in the Android app, including offline; Telegram sends them notifications.</li>
  </ul>
</section>

<section aria-labelledby="gov">
  <h2 id="gov">Public-sector and restricted-access sites</h2>
  <ul>
    <li>Every action on a work order is checked by the database; history and the access change log are kept.</li>
    <li>Proof of completion — time, place and photo that are hard to fake, even with no signal on site.</li>
    <li>Cloud in the region of the customer’s choice (US, EU, UAE), a dedicated cloud or installation on the customer’s own servers — terms are discussed during a pilot. ${h.link('security', 'More on security and deployment')}.</li>
  </ul>
  <p class="note">The product has no public-sector certifications yet.</p>
</section>

${h.ctaBlock()}
`,
  },

  security: {
    slug: 'security/',
    nav: 'Security',
    title: 'Security and deployment — Dokazio',
    description: 'Company isolation at the database level (RLS), roles and segregation of duties, private file storage, access change log, hosting options.',
    h1: 'Security and deployment',
    body: (h) => `
<h1>Security and deployment</h1>
<p class="lead">In Dokazio permissions are enforced by the database. The interface only shows what is allowed.</p>

<section aria-labelledby="isolation">
  <h2 id="isolation">Company isolation</h2>
  <ul>
    <li>Company data is separated by PostgreSQL row-level security policies — on every table.</li>
    <li>Companies and managers of different sites are isolated — everyone sees only their own information.</li>
    <li>A new user without an invitation sees nothing: people join a company with an invitation code (valid for 7 days).</li>
  </ul>
</section>

<section aria-labelledby="roles">
  <h2 id="roles">Roles and segregation of duties</h2>
  <ul>
    <li>Roles: administrator, manager (whole company or an access zone), contractor technician, requester.</li>
    <li>A role or company can only be changed through checked database functions, not by editing a profile.</li>
    <li>Only a technician of the assigned contractor starts and submits work; someone else accepts it. ${h.link('features', 'Roles table', '#roles')}.</li>
    <li>An internal permissions review (October 2026) found several issues within a company; fixes have been released and applied.</li>
  </ul>
</section>

<section aria-labelledby="files">
  <h2 id="files">Files, log, AI</h2>
  <ul>
    <li>Photos, documents, floor plans and acts are kept in private storage; no public links, only temporary links for those with access.</li>
    <li>Work order history and action times are written by the database. The log of role, zone and crew changes is visible to the administrator and cannot be edited.</li>
    <li>AI keys live only on the server. Models are called with the user’s permissions; model output is checked against the company’s reference data.</li>
    <li>Server logs never contain work order texts, model answers or recognition shots — only technical data (time, size, error code).</li>
    <li>The Telegram bot does not expose chat IDs to the app; employees’ phone numbers are visible only to the person and managers.</li>
  </ul>
</section>

<section aria-labelledby="deploy">
  <h2 id="deploy">Where it runs and deployment options</h2>
  <div class="table-wrap"><table>
    <caption>Hosting options</caption>
    <thead><tr><th scope="col">Option</th><th scope="col">Status</th></tr></thead>
    <tbody>
      <tr><td>Cloud (SaaS): PostgreSQL on Supabase, EU region; AI models via a standard API, provider configurable</td><td>Available now</td></tr>
      <tr><td>Cloud in the region of the customer’s choice: US, EU, UAE</td><td>For a pilot: the same stack in the required region</td></tr>
      <tr><td>Customer’s dedicated cloud, installation on the customer’s own servers, isolated network</td><td>Discussed during a pilot: the stack is open (PostgreSQL, Supabase), no packaged delivery yet</td></tr>
    </tbody>
  </table></div>
  <p>Clients: web version in the browser and the Android app.</p>
</section>

${h.ctaBlock()}
`,
  },

  faq: {
    slug: 'faq/',
    nav: 'FAQ',
    title: 'FAQ — Dokazio',
    description: 'What happens with no signal in the basement, how Dokazio differs from spreadsheets and messengers, can you use it without the app, where data is stored and how much it costs.',
    h1: 'Frequently asked questions',
    faq: [
      ['What is Dokazio?', 'An AI service for property maintenance and contractor control. Work orders come in by voice, by photo and via Telegram, the contractor is assigned automatically, and only work with proof — a stamped “after” photo, a visit inside the site geofence and a completed checklist — is payable in the contractor act.'],
      ['How is it different from a spreadsheet or a group chat?', 'In a chat requests get lost; a spreadsheet has to be filled in by hand. In Dokazio you just say or photograph the problem — AI fills in the place, system and priority, the contractor is assigned automatically, overdue work is visible at once. The key difference is proof: time, place and the “after” photo are captured automatically, and the act shows what to pay for and what not.'],
      ['What if there is no signal in the basement?', 'The Android app works offline: a new work order can be created without a connection, and the technician’s work orders are saved on the phone in advance, actions and “after” photos are queued and sent automatically when the connection returns. Time is verified by a clock that cannot be changed or by GPS, and the photo fingerprint is checked on the server. If the time cannot be verified, the work order goes to a manager’s decision in the act.'],
      ['Can someone report a fault without the app?', 'Yes. A QR code at the site lets anyone message the Telegram bot with text, a voice note or a photo — no sign-up. A team Telegram group can also be linked to a site. The author gets “in progress” and “done” notifications with a photo.'],
      ['Does the contractor need to install anything?', 'Yes, the contractor’s technician receives and handles work orders in the app — on Android or in a browser: starts work, checks in, ticks the checklist, takes the “after” photo. Telegram only sends them notifications about new work orders.'],
      ['Can a manager close a work order on the contractor’s behalf?', 'No. Only a technician of the assigned contractor can start the work, take the “after” photo and submit it, and only a manager who did not submit it can accept it. This is enforced by the database, not just the interface.'],
      ['How does the AI know what broke and where?', 'An AI model parses the phrase into a work order: system, room and priority — only from your company’s reference data. From a photo the model describes the equipment, and the service suggests matching units from the register by serial number, model, type and room — a person confirms the right one. If AI is unavailable, a dictionary parser or manual selection takes over.'],
      ['Where is the data stored?', 'Currently in a cloud PostgreSQL database (Supabase) in the EU region; company data is isolated by database access policies. Cloud in the region of the customer’s choice (US, EU, UAE), a dedicated cloud and installation on the customer’s own servers are discussed during a pilot.'],
      ['Which devices does it run on?', 'In a browser on desktop and mobile (voice input in Chrome and Edge) and in the Android app. There is no iPhone app yet.'],
      ['Which languages does the interface support?', 'English (default) and Russian; the language is switched in settings.'],
      ['How much does it cost?', ROI_SHOW_PRICES
        ? `A subscription per site per month, by site area: from ${fmtMoney(REGIONS.US.prices.S, 'US', 'en')} / ${fmtMoney(REGIONS.EU.prices.S, 'EU', 'en')} / ${fmtMoney(REGIONS.GCC.prices.S, 'GCC', 'en')} (Site S, up to 3,000 m²); 15% off when paying annually; sites over 30,000 m² — custom pricing. Contractors use it free and pay nothing. There is no percentage of your contractor spend. A paid pilot is available: 90 days at 50% of the price, credited towards an annual contract. Prices and the calculation are on the ROI calculator page.`
        : 'Pricing is on request and depends on the number of sites. The product is at the MVP stage, and we offer a pilot at your sites. To apply for a pilot, use the “Apply for a pilot” button: it opens our Telegram bot.', 'roi'],
      ['Will Dokazio pay for itself?', 'Estimate it for your portfolio in the ROI calculator. It counts the staff time Dokazio takes over and the contractor overbilling you stop paying for, with a cautious 3% by default (3–10%). ' + (ROI_SHOW_PRICES ? `For one 5,000 m² site in the US the estimate is about ${exampleRoi('US', 'en')} at 3%; in the Gulf it is about ${exampleRoi('GCC', 'en')}, and we show that as it is. ` : '') + 'This is an estimate, not a promise — a pilot shows real numbers.', 'roi'],
    ],
    body: (h, page) => `
<h1>Frequently asked questions</h1>
<div class="faq">
${page.faq.map(([q, a, link], i) => `  <section aria-labelledby="q${i + 1}"><h2 id="q${i + 1}">${q}</h2><p>${a}${link ? ` ${h.link(link, ui.roiLink)}.` : ''}</p></section>`).join('\n')}
</div>
${h.ctaBlock()}
`,
  },

  contact: {
    slug: 'contact/',
    nav: 'Contact',
    title: 'Apply for a pilot — Dokazio',
    description: 'Apply for a Dokazio pilot at your sites or ask for a demo: voice and photo work orders, contractor control and proof-based payment.',
    h1: 'Apply for a pilot',
    body: (h) => `
<h1>Apply for a pilot</h1>
<p class="lead">We will show the service on demo data and discuss a pilot at your sites.</p>
${h.contact()}
<section aria-labelledby="what">
  <h2 id="what">What to include in your message</h2>
  <ul>
    <li>Type and number of sites (offices, shopping centres, warehouses, hotels…) and cities.</li>
    <li>How many contractors and for which systems.</li>
    <li>How work orders are received today and how completion is confirmed.</li>
  </ul>
  <p>Already have access? ${h.appLink('Sign in to the app')}.</p>
</section>
`,
  },

  roi: {
    slug: 'roi/',
    nav: 'ROI',
    title: 'ROI calculator — Dokazio',
    description: 'Estimate what paying contractors only for proven work could save across your sites: staff time and cut overbilling, 3% by default (3–10%). US, UK/EU, Gulf.',
    h1: roi.h1,
    body: (h) => roiBody(h, roi, 'en'),
  },

  privacy: {
    slug: 'privacy/',
    nav: 'Privacy',
    title: 'Website privacy policy — Dokazio',
    description: 'The Dokazio website uses no cookies or analytics; demo requests are accepted only via Telegram — what we store and why.',
    h1: 'Website privacy policy',
    body: (h) => `
<h1>Website privacy policy</h1>
<p>Version of 23 October 2026. Applies to this website; the app is covered in the last section.</p>
<section aria-labelledby="collect"><h2 id="collect">What the website collects</h2>
  <ul>
    <li>The website uses no cookies, visit counters, advertising or analytics services.</li>
    <li>There are no forms that send data to a server. The “Apply for a pilot” button opens Telegram — you decide what to write.</li>
    <li>Fonts, images and video are loaded from the same address as the website, with no third-party services.</li>
  </ul>
</section>
<section aria-labelledby="hosting"><h2 id="hosting">Hosting</h2>
  <p>The website is hosted on GitHub Pages. Like any web server, the host may keep technical request logs (e.g. IP address) under GitHub’s terms.</p>
</section>
<section aria-labelledby="letters"><h2 id="letters">Demo requests in Telegram</h2>
  <p>If you message our bot @HeyHelpy_bot via the “Apply for a pilot” link, we store your message text, your Telegram name and username, language and chat ID — only to reply and discuss a demo or pilot. Only the Dokazio team can see this data, and we do not share it with third parties. To have it deleted, send a request the same way — via the “Apply for a pilot” link.</p>
</section>
<section aria-labelledby="app"><h2 id="app">The app</h2>
  <p>Data processing in the ${h.appLink('Dokazio')} app (work orders, photos, location when checking in) is governed by the contract with the customer company. App data is stored in the cloud; the storage region (US, EU or UAE) is chosen in the contract with the customer, currently the EU. How data access works is described on the ${h.link('security', 'Security')} page.</p>
  <p>The “AR labels” feature in the Android app uses “Google Play Services for AR” (ARCore) — a Google app on the phone, governed by the <a href="https://policies.google.com/privacy">Google Privacy Policy</a>. ARCore calculates the phone’s position on the phone itself; our code does not call Google services, and Google’s cloud anchors and geospatial positioning are switched off. The shot used to recognise equipment goes to our server and is not stored.</p>
</section>
`,
  },
};

export const notFound = {
  title: 'Page not found — Dokazio',
  h1: 'Page not found',
  text: 'This page does not exist. The address may have changed.',
};

