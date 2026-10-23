// Site copy — English (address «/en/»). Same facts as content.ru.mjs; terms as in the app
// (CLAUDE.md, «Языки»): Work order, Contractor, Preventive maintenance, Floor plan, Access zone, System, Contractor act.

export const ui = {
  lang: 'en',
  locale: 'en_US',
  skip: 'Skip to content',
  menu: 'Menu',
  login: 'Sign in',
  demo: 'Request a demo',
  home: 'Home',
  otherLang: 'Русский',
  otherLangShort: 'RU',
  footerNote: 'AI service for property maintenance and contractor control. The product is at the MVP stage.',
  footerAi: 'For AI assistants',
  shotNote: 'App screen, demo data',
  videoNote: 'The video is in Russian with on-screen captions, 2 min 9 s, no sound.',
};

export const llmsIntro = 'Hey Helpy (Russian: «Эй, Helpy») is an AI service for property maintenance (CMMS / facility management) and contractor control for business and shopping centres, chains and retail, property management and FM companies, and public-sector customers: work orders by text, camera or voice, in the app or via Telegram, automatic contractor assignment, proof of completion (an “after” photo with a stamp, a geofenced visit, a checklist) and a contractor act where only proven work is payable. Web and Android. Stage: MVP; pricing on request; pilots available.';

export const pages = {
  home: {
    slug: 'en/',
    nav: 'Home',
    title: 'Hey Helpy — AI service for property maintenance and contractor control',
    description: 'For business and shopping centres, chains and retail, property management and FM companies, public sector: work orders by text, camera or voice; only proven work gets paid.',
    h1: 'AI service for property maintenance and contractor control',
    body: (h) => `
<section class="hero">
  <div class="hero-text">
    <p class="kicker">Hey Helpy — for business and shopping centres, chains and retail, property management and FM companies, public-sector customers</p>
    <h1>AI service for property maintenance and contractor control</h1>
    <p class="lead"><strong>Pay contractors only for proven work.</strong> A work order is created by text, camera or voice — in the app or via Telegram, with nothing to install. The service figures out what broke and where, sends it to the right contractor and collects proof of completion.</p>
    <p class="actions">${h.cta('primary')} <a class="btn ghost" href="#video">Watch the video</a></p>
  </div>
  ${h.img('voice', 'The “Check the work order” screen: a spoken request about a broken air conditioner in a meeting room parsed by AI into system, room and priority (app in Russian)', { eager: true, cls: 'phone' })}
</section>

<section aria-labelledby="problem">
  <h2 id="problem">How many people does it take to fix one lock?</h2>
  <p>An employee posts in a group chat. The receptionist calls the dispatcher. The dispatcher looks up which contractor handles doors at this site. The manager sends reminders. The contractor shows up when they can and sends an invoice. Accounting pays — on trust.</p>
  <p>Everyone does their part, yet in the end nobody can show <strong>that the work was done, where, when and by whom</strong>. Requests get lost in chats, overdue work only surfaces through complaints, and whatever is on the invoice gets paid.</p>
</section>

<section aria-labelledby="how">
  <h2 id="how">How it works</h2>
  <ol class="steps">
    <li><h3>Intake</h3><p>Say it: “Hey, Helpy, water is dripping from the air conditioner in the third-floor meeting room.” Or point the camera at the equipment. Or message the Telegram bot — requesters need no app, just the QR code at the site.</p></li>
    <li><h3>AI parses it</h3><p>YandexGPT works out what happened, in which room, which building system it is and how urgent. From a photo, the service finds the exact piece of equipment in the asset register. A person just confirms.</p></li>
    <li><h3>Contractor</h3><p>The work order goes straight to the contractor assigned to that system at that site. The technician gets a notification and takes it with one tap.</p></li>
    <li><h3>Proof</h3><p>The “after” photo can only be taken with the app’s live camera and carries a stamp: date · site · room · inside geofence. The visit is checked against the site’s geofence, the checklist item by item. No “after” photo — no hand-over.</p></li>
    <li><h3>Contractor act</h3><p>At month-end the contractor act is built automatically: only accepted work with proof is payable, disputed items go to a manager’s decision, the rest show why they are not payable.</p></li>
  </ol>
</section>

<section aria-labelledby="features">
  <h2 id="features">Highlights</h2>
  <div class="cards">
    ${h.card('camera', 'Camera assistant', 'Point the camera at an air conditioner — the service recognises which unit from the register it is and shows its open work orders, preventive maintenance and last job.', 'Camera assistant: air conditioner KD-301 recognised at 91 %, card with an open work order, maintenance and last job (app in Russian)')}
    ${h.card('telegram', 'Work orders from Telegram', 'A requester reports a fault in Telegram via the site’s QR code — no app needed. The contractor’s technician gets a notification from the bot and handles the work order in the app.', 'Technician chat with the bot: a new work order notification (mock-up with the bot’s texts, in Russian)')}
    ${h.card('photos', '“Before” and “after” photos', 'The work order holds all the proof: photos before and after, time, place, documents.', 'Work order card: “before” and “after” photos and a maintenance document (app in Russian)')}
  </div>
  ${h.figure('act', 'Contractor acts: 5 work orders payable (22,500 ₽), 4 without proof, 56 % of work proven (app in Russian)', 'Contractor act: only proven work is payable')}
  <p>${h.link('features', 'All features →')}</p>
</section>

<section aria-labelledby="video">
  <h2 id="video">Two-minute demo</h2>
  <p>The full story of one fault: spoken request → camera → work order with a photo → proof → contractor act.</p>
  ${h.video('Hey Helpy demo: voice work order, camera assistant, “after” photo and contractor act')}
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
    slug: 'en/features/',
    nav: 'Features',
    title: 'Features — Hey Helpy',
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
      <p>Tap “Hey Helpy” and speak. The text appears as you talk; speech recognition is done by the browser (Chrome, Edge) or by Android.</p>
      <ul>
        <li>AI (YandexGPT) turns the phrase into work order fields: title, description, system (HVAC, electrical, plumbing…), room and priority.</li>
        <li>If the AI does not answer in time, a built-in dictionary parses the request; the screen shows which one did: “Parsed by AI” or “Parsed by dictionary”.</li>
        <li>Before sending, a person checks and can edit any field. Typing is always an option.</li>
        <li>The contractor is assigned automatically by system and site.</li>
      </ul>
    </div>
    ${h.img('voice', 'Voice work order check: parsed by AI, system HVAC, room 301 meeting room, priority high (app in Russian)', { cls: 'phone' })}
  </div>
</section>

<section aria-labelledby="photo">
  <h2 id="photo">Photo and the camera assistant</h2>
  <div class="split">
    <div>
      <p>A technician or employee points the phone camera at the equipment and taps “What is this?”.</p>
      <ul>
        <li>A multimodal model describes the shot: equipment type (from a catalogue of 22 types), system, readable nameplate, visible defect.</li>
        <li>Which exact unit from the register it is, the service decides itself — by serial number, model, type, room and floor. Up to three candidates with reasons.</li>
        <li>Equipment card: open work orders, next preventive maintenance, last completed job.</li>
        <li>“Create work order” — site, room, equipment and system are pre-filled, the shot is attached as the “before” photo.</li>
        <li>If there is no equipment in the frame, the service says so. The recognition shot is neither stored nor logged.</li>
      </ul>
    </div>
    ${h.img('camera', 'Camera assistant: frozen frame labelled “KD-301 · 91 %” and the air conditioner card (app in Russian)', { cls: 'phone' })}
  </div>
</section>

<section aria-labelledby="ar">
  <h2 id="ar">AR labels</h2>
  <p>Point the camera — a label with open work orders and preventive maintenance appears above the equipment, for example “KD-301 · 1 open work order · maintenance by 31.10”. The label stays in place while you walk around the room.</p>
  <ul>
    <li>Tap the label to open the equipment card or create a work order with the site, room and equipment already filled in.</li>
    <li>The equipment is recognised by the same service as in the camera assistant; the shot is neither stored nor logged.</li>
    <li>The phone’s position in the room is calculated on the phone itself. No data goes to third-party AR services: Google’s cloud anchors and geospatial positioning are switched off.</li>
    <li>Works in the Android app on phones that support ARCore. Other devices get the regular camera assistant.</li>
    <li>Labels are not yet kept between sessions: after the screen is closed, equipment has to be recognised again. An internet connection is required — recognition runs on the server.</li>
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
    ${h.img('telegram', 'Technician chat with the bot: a new work order notification (mock-up with the bot’s texts, in Russian)', { cls: 'phone' })}
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
  ${h.figure('act', 'Contractor acts screen: “Payable” and “No proof” groups with reasons (app in Russian)', 'Contractor act: what is payable, what is not, and why')}
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
  <p>Basements, roofs and plant rooms often have no signal. In the Android app the technician keeps working without it:</p>
  <ul>
    <li>their work orders with checklists, rooms, floor plans and “before” photos are saved on the phone in advance;</li>
    <li>start, check in, tick the checklist, take the “after” photo, submit — actions are queued and sent automatically once the connection is back;</li>
    <li><strong>trusted time</strong>: the time of each action is counted from the last server contact using a clock that cannot be changed, or from GPS; if the phone clock is off by more than 5 minutes, the time is marked “not verified”;</li>
    <li><strong>photo fingerprint</strong> (SHA-256) is taken on the phone and verified on the server — a swapped file is detected;</li>
    <li>disputed cases (time not verified, work order cancelled while offline) land in the act under “Needs a manager’s decision”.</li>
  </ul>
  <p>Signing out deletes everything stored on the phone. The web version does not work offline.</p>
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
    ${h.img('ppr', 'Preventive maintenance: monthly tasks grouped into “Not started”, “In progress”, “Done” (app in Russian)', { cls: 'wide' })}
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
  ${h.img('photos', 'Work order card: “before” and “after” photos and the Documents section (app in Russian)', { cls: 'phone center' })}
</section>

<section aria-labelledby="reports">
  <h2 id="reports">Reports</h2>
  <ul>
    <li>Per contractor for a period: geofenced visits, time on site, share of work done on time, first-time acceptance, returns.</li>
    <li>Breakdowns by region and work order type, photo recognition statistics.</li>
    <li>Report as PDF in one tap; contractor act as PDF and Excel.</li>
    <li>History of accepted and cancelled work orders for a period.</li>
  </ul>
  ${h.figure('reports', 'Contractor report for 30 days: visits, time, on-time share, first-time acceptance (app in Russian)', 'Contractor control in numbers (demo data)')}
</section>

<section aria-labelledby="zones">
  <h2 id="zones">Regions and access zones</h2>
  <ul>
    <li>A portfolio of sites across cities and countries: regions, countries, cities.</li>
    <li>A manager’s access zone is “systems × places”, e.g. “HVAC · Moscow”: the manager sees and changes only their part.</li>
    <li>Contractor crews: a technician sees only the work orders in their crew’s zone.</li>
    <li>Access change log (roles, zones, crews) — administrator only, read-only.</li>
    <li>Interface in Russian and English.</li>
  </ul>
</section>

${h.ctaBlock()}
`,
  },

  industries: {
    slug: 'en/industries/',
    nav: 'Who it’s for',
    title: 'Who it’s for — Hey Helpy',
    description: 'Hey Helpy for business and shopping centres, chains and retail, property management and FM companies, public-sector and restricted-access sites.',
    h1: 'Who it’s for',
    body: (h) => `
<h1>Who it’s for</h1>
<p class="lead">Hey Helpy fits wherever buildings are serviced by contractors and you want to pay only for work actually done.</p>

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
    <li>Hosting data in Russia (Yandex Cloud) and dedicated deployment options are planned; terms are discussed during a pilot. ${h.link('security', 'More on security and deployment')}.</li>
  </ul>
  <p class="note">The product currently has no certification for government information systems.</p>
</section>

${h.ctaBlock()}
`,
  },

  security: {
    slug: 'en/security/',
    nav: 'Security',
    title: 'Security and deployment — Hey Helpy',
    description: 'Company isolation at the database level (RLS), roles and segregation of duties, private file storage, access change log, hosting options.',
    h1: 'Security and deployment',
    body: (h) => `
<h1>Security and deployment</h1>
<p class="lead">In Hey Helpy permissions are enforced by the database. The interface only shows what is allowed.</p>

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
      <tr><td>Cloud service (SaaS): PostgreSQL on Supabase, servers in the EU; AI — YandexGPT (Yandex Cloud)</td><td>Available now</td></tr>
      <tr><td>Hosting in Russia: self-hosted Supabase in Yandex Cloud, Yandex SpeechKit speech recognition</td><td>Planned</td></tr>
      <tr><td>Customer’s dedicated cloud, on-premise, isolated network</td><td>Discussed during a pilot: the stack is open (PostgreSQL, Supabase), no packaged delivery yet</td></tr>
    </tbody>
  </table></div>
  <p>Clients: web version in the browser and the Android app.</p>
</section>

${h.ctaBlock()}
`,
  },

  faq: {
    slug: 'en/faq/',
    nav: 'FAQ',
    title: 'FAQ — Hey Helpy',
    description: 'What happens with no signal in the basement, how Hey Helpy differs from spreadsheets and messengers, can you use it without the app, where data is stored and how much it costs.',
    h1: 'Frequently asked questions',
    faq: [
      ['What is Hey Helpy?', 'An AI service for property maintenance and contractor control. Work orders come in by voice, by photo and via Telegram, the contractor is assigned automatically, and only work with proof — a stamped “after” photo, a visit inside the site geofence and a completed checklist — is payable in the contractor act.'],
      ['How is it different from a spreadsheet or a group chat?', 'In a chat requests get lost; a spreadsheet has to be filled in by hand. In Hey Helpy you just say or photograph the problem — AI fills in the place, system and priority, the contractor is assigned automatically, overdue work is visible at once. The key difference is proof: time, place and the “after” photo are captured automatically, and the act shows what to pay for and what not.'],
      ['What if there is no signal in the basement?', 'The technician’s Android app works offline: work orders are saved on the phone in advance, actions and “after” photos are queued and sent automatically when the connection returns. Time is verified by a clock that cannot be changed or by GPS, and the photo fingerprint is checked on the server. If the time cannot be verified, the work order goes to a manager’s decision in the act.'],
      ['Can someone report a fault without the app?', 'Yes. A QR code at the site lets anyone message the Telegram bot with text, a voice note or a photo — no sign-up. A team Telegram group can also be linked to a site. The author gets “in progress” and “done” notifications with a photo.'],
      ['Does the contractor need to install anything?', 'Yes, the contractor’s technician receives and handles work orders in the app — on Android or in a browser: starts work, checks in, ticks the checklist, takes the “after” photo. Telegram only sends them notifications about new work orders.'],
      ['Can a manager close a work order on the contractor’s behalf?', 'No. Only a technician of the assigned contractor can start the work, take the “after” photo and submit it, and only a manager who did not submit it can accept it. This is enforced by the database, not just the interface.'],
      ['How does the AI know what broke and where?', 'YandexGPT parses the phrase into a work order: system, room and priority — only from your company’s reference data. From a photo the model describes the equipment, and the service finds the exact unit in the register by serial number, model, type and room. If AI is unavailable, a dictionary parser or manual selection takes over.'],
      ['Where is the data stored?', 'Currently in a cloud PostgreSQL database (Supabase) on servers in the EU; company data is isolated by database access policies. Hosting in Russia on Yandex Cloud is planned. Dedicated cloud and on-premise options are discussed during a pilot.'],
      ['Which devices does it run on?', 'In a browser on desktop and mobile (voice input in Chrome and Edge) and in the Android app. There is no iPhone app yet.'],
      ['Which languages does the interface support?', 'Russian and English; the language is switched in settings.'],
      ['How much does it cost?', 'Pricing is on request and depends on the number of sites. The product is at the MVP stage, and we offer a pilot at your sites. To request a demo or pilot, use the “Request a demo” button: it opens our Telegram bot.'],
    ],
    body: (h, page) => `
<h1>Frequently asked questions</h1>
<div class="faq">
${page.faq.map(([q, a], i) => `  <section aria-labelledby="q${i + 1}"><h2 id="q${i + 1}">${q}</h2><p>${a}</p></section>`).join('\n')}
</div>
${h.ctaBlock()}
`,
  },

  contact: {
    slug: 'en/contact/',
    nav: 'Contact',
    title: 'Request a demo or pilot — Hey Helpy',
    description: 'Request a Hey Helpy demo or a pilot at your sites: voice and photo work orders, contractor control and proof-based payment.',
    h1: 'Request a demo or pilot',
    body: (h) => `
<h1>Request a demo or pilot</h1>
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

  privacy: {
    slug: 'en/privacy/',
    nav: 'Privacy',
    title: 'Website privacy policy — Hey Helpy',
    description: 'The Hey Helpy website uses no cookies or analytics; demo requests are accepted only via Telegram — what we store and why.',
    h1: 'Website privacy policy',
    body: (h) => `
<h1>Website privacy policy</h1>
<p>Version of 23 October 2026. Applies to this website; the app is covered in the last section.</p>
<section aria-labelledby="collect"><h2 id="collect">What the website collects</h2>
  <ul>
    <li>The website uses no cookies, visit counters, advertising or analytics services.</li>
    <li>There are no forms that send data to a server. The “Request a demo” button opens Telegram — you decide what to write.</li>
    <li>Fonts, images and video are loaded from the same address as the website, with no third-party services.</li>
  </ul>
</section>
<section aria-labelledby="hosting"><h2 id="hosting">Hosting</h2>
  <p>The website is hosted on GitHub Pages. Like any web server, the host may keep technical request logs (e.g. IP address) under GitHub’s terms.</p>
</section>
<section aria-labelledby="letters"><h2 id="letters">Demo requests in Telegram</h2>
  <p>If you message our bot @HeyHelpy_bot via the “Request a demo” link, we store your message text, your Telegram name and username, language and chat ID — only to reply and discuss a demo or pilot. Only the Hey Helpy team can see this data, and we do not share it with third parties. To have it deleted, send a request the same way — via the “Request a demo” link.</p>
</section>
<section aria-labelledby="app"><h2 id="app">The app</h2>
  <p>Data processing in the ${h.appLink('Hey Helpy')} app (work orders, photos, location when checking in) is governed by the contract with the customer company. How data access works is described on the ${h.link('security', 'Security')} page.</p>
  <p>The “AR labels” feature in the Android app uses “Google Play Services for AR” (ARCore) — a Google app on the phone, governed by the <a href="https://policies.google.com/privacy">Google Privacy Policy</a>. ARCore calculates the phone’s position on the phone itself; our code does not call Google services, and Google’s cloud anchors and geospatial positioning are switched off. The shot used to recognise equipment goes to our server and is not stored.</p>
</section>
`,
  },
};

export const notFound = {
  title: 'Page not found — Hey Helpy',
  h1: 'Page not found',
  text: 'This page does not exist. The address may have changed.',
};
