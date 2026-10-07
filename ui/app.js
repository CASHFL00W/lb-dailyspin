// Daily Spins - phone app UI (works with lb-phone and phones that implement its custom app API)
(() => {
    'use strict';

    const IN_GAME = /^cfx-nui-/.test(location.hostname);
    const RESOURCE = IN_GAME ? location.hostname.replace(/^cfx-nui-/, '') : 'lb-dailyspin';
    const PARAMS = new URLSearchParams(location.search);

    // English fallback; the real strings come from locales/*.lua via the setLanguage callback
    const DEFAULT_STRINGS = {
        tab_spin: 'Spin', tab_mission: 'Mission', tab_history: 'History', subtitle: 'Your daily shot at luck',
        spin: 'SPIN', spinning: 'Good luck...', ready: 'Your spin is ready!', next_spin: 'Next spin in',
        locked_mission: 'Finish your mission to spin again', chances: 'Odds', chances_title: 'Odds per slice',
        close: 'Close', result_cash: 'You won', result_mission: 'New mission', result_empty: 'Not this time',
        result_empty_text: 'Better luck tomorrow!', result_jackpot: 'JACKPOT!', to_mission: 'Show mission',
        great: 'Awesome', reward: 'Reward', expires: 'Expires in', navigate: 'Navigate', cancel: 'Cancel',
        cancel_title: 'Cancel mission?', cancel_text: 'You will not get a new spin for it.',
        cancel_confirm: 'Cancel mission', keep: 'Keep', no_mission: 'No active mission',
        no_mission_text: 'Spin the wheel - with a little luck you get a job for today.', current_step: 'Current step',
        stats_spins: 'Spins', stats_earned: 'Earned', stats_missions: 'Missions', history_empty: 'Nothing here yet.',
        kind_cash: 'Cash prize', kind_mission: 'Mission received', kind_empty: 'No prize',
        kind_mission_done: 'Mission completed', kind_mission_failed: 'Mission failed',
        mission_done: 'Mission completed!', mission_failed: 'Mission ended', waypoint_set: 'Waypoint set',
        loading: 'Loading...', no_character: 'Load a character first.', sound_on: 'Sound on', sound_off: 'Sound off',
        just_now: 'just now', min_ago: '%d min ago', h_ago: '%d h ago', d_ago: '%d d ago',
    };

    const ICONS = {
        cash: '<rect x="2.5" y="6" width="19" height="12" rx="2.5"/><circle cx="12" cy="12" r="2.6"/><path d="M6 9.5v5M18 9.5v5"/>',
        taxi: '<path d="M5 11l1.6-4.2A2 2 0 0 1 8.5 5.5h7a2 2 0 0 1 1.9 1.3L19 11"/><rect x="3" y="11" width="18" height="6" rx="2"/><path d="M6.5 17v2M17.5 17v2M10 3h4"/><circle cx="7.5" cy="14" r=".6"/><circle cx="16.5" cy="14" r=".6"/>',
        package: '<path d="M21 8 12 3 3 8v8l9 5 9-5z"/><path d="m3 8 9 5 9-5M12 13v8M7.5 5.5l9 5"/>',
        mail: '<rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="m3.5 7 8.5 6 8.5-6"/>',
        empty: '<circle cx="12" cy="12" r="9"/><path d="m9 9 6 6M15 9l-6 6"/>',
        crown: '<path d="M3 8.5 7.5 12 12 5l4.5 7L21 8.5 19 18H5z"/><path d="M5 21h14"/>',
        clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
        nav: '<path d="M3 11 21 3l-8 18-2-8z"/>',
        check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
        x: '<path d="M6 6l12 12M18 6 6 18"/>',
        sound: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11"/>',
        mute: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="m16 9.5 5 5M21 9.5l-5 5"/>',
        info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
        lock: '<rect x="5" y="11" width="14" height="10" rx="2.5"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
        sparkle: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/><path d="M19 16l.8 2.2L22 19l-2.2.8L19 22l-.8-2.2L16 19l2.2-.8z"/>',
        flag: '<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>',
        wheel: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2"/><path d="M12 3v7M12 14v7M3 12h7M14 12h7"/>',
    };

    const MISSION_COLORS = {
        taxi: ['#ffb800', '#ff7a00'],
        package: ['#ff8a00', '#ff375f'],
        mail: ['#bf5af2', '#5e5ce6'],
    };

    const HISTORY_STYLE = {
        cash: { icon: 'cash', color: '#30d158' },
        mission: { icon: 'flag', color: '#0a84ff' },
        empty: { icon: 'empty', color: '#8e8e93' },
        mission_done: { icon: 'check', color: '#30d158' },
        mission_failed: { icon: 'x', color: '#ff453a' },
    };

    const S = {
        strings: { ...DEFAULT_STRINGS },
        lang: 'en',
        langRequested: undefined,
        state: null,
        offset: 0,
        tab: 'spin',
        spinning: false,
        rotation: 0,
        segmentsKey: '',
        ledMode: 'idle',
    };

    const $ = id => document.getElementById(id);
    const icon = (name, cls = 'svg-ico') => `<svg class="${cls}" viewBox="0 0 24 24">${ICONS[name] || ICONS.sparkle}</svg>`;
    const t = (key, ...args) => {
        let str = S.strings[key] ?? DEFAULT_STRINGS[key] ?? key;
        args.forEach(a => { str = str.replace(/%[sd]/, a); });
        return str;
    };
    const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = n => '$' + Number(n || 0).toLocaleString(S.lang === 'de' ? 'de-DE' : 'en-US');
    const serverNow = () => Date.now() + S.offset;

    // ---------------------------------------------------------------------------------------------
    // NUI bridge
    // ---------------------------------------------------------------------------------------------
    async function nui(event, data = {}) {
        if (!IN_GAME) return Demo.handle(event, data);
        try {
            const res = await fetch(`https://${RESOURCE}/${event}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data),
            });
            return await res.json();
        } catch (e) {
            return null;
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Toast / sheet
    // ---------------------------------------------------------------------------------------------
    let toastTimer;
    function toast(text, isError = false) {
        const el = $('toast');
        el.textContent = text;
        el.classList.toggle('error', isError);
        el.classList.add('show');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => el.classList.remove('show'), 2600);
    }

    function openSheet(html) {
        $('sheet').innerHTML = '<div class="sheet-grabber"></div>' + html;
        $('sheetBackdrop').classList.add('open');
    }

    function closeSheet() {
        $('sheetBackdrop').classList.remove('open');
    }

    $('sheetBackdrop').addEventListener('click', e => {
        if (e.target.id === 'sheetBackdrop') closeSheet();
    });

    // ---------------------------------------------------------------------------------------------
    // Confetti
    // ---------------------------------------------------------------------------------------------
    const Confetti = (() => {
        const canvas = $('confetti');
        const ctx = canvas.getContext('2d');
        let parts = [];
        let running = false;
        const colors = ['#ff375f', '#ff9f0a', '#ffd60a', '#30d158', '#64d2ff', '#bf5af2', '#ffffff'];

        function burst(count = 120) {
            if (PARAMS.has('still')) return;
            const rect = canvas.getBoundingClientRect();
            canvas.width = rect.width * devicePixelRatio;
            canvas.height = rect.height * devicePixelRatio;
            ctx.setTransform(devicePixelRatio, 0, 0, devicePixelRatio, 0, 0);
            for (let i = 0; i < count; i++) {
                const angle = -Math.PI / 2 + (Math.random() - 0.5) * 1.6;
                const speed = 6 + Math.random() * 9;
                parts.push({
                    x: rect.width / 2, y: rect.height * 0.42,
                    vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
                    w: 5 + Math.random() * 5, h: 8 + Math.random() * 6,
                    r: Math.random() * Math.PI, vr: (Math.random() - 0.5) * 0.4,
                    color: colors[(Math.random() * colors.length) | 0],
                    life: 0,
                });
            }
            if (!running) {
                running = true;
                requestAnimationFrame(frame);
            }
        }

        function frame() {
            const w = canvas.width / devicePixelRatio;
            const h = canvas.height / devicePixelRatio;
            ctx.clearRect(0, 0, w, h);
            parts = parts.filter(p => p.y < h + 20 && p.life < 260);
            for (const p of parts) {
                p.vy += 0.28;
                p.vx *= 0.985;
                p.x += p.vx;
                p.y += p.vy;
                p.r += p.vr;
                p.life++;
                ctx.save();
                ctx.translate(p.x, p.y);
                ctx.rotate(p.r);
                ctx.fillStyle = p.color;
                ctx.globalAlpha = Math.max(0, 1 - p.life / 260);
                ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h * Math.abs(Math.cos(p.r * 2)));
                ctx.restore();
            }
            if (parts.length) requestAnimationFrame(frame);
            else running = false;
        }

        return { burst };
    })();

    // ---------------------------------------------------------------------------------------------
    // Wheel
    // ---------------------------------------------------------------------------------------------
    const CX = 150, CY = 150, R = 134, LEDS = 24;

    function point(angle, radius) {
        const rad = angle * Math.PI / 180;
        return [CX + radius * Math.sin(rad), CY - radius * Math.cos(rad)];
    }

    function textColor(hex) {
        const n = parseInt(String(hex).replace('#', ''), 16);
        if (Number.isNaN(n)) return '#fff';
        const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.62 ? '#1c1c1e' : '#ffffff';
    }

    function buildWheel(segments) {
        const n = segments.length;
        const slice = 360 / n;
        let slices = '';
        let labels = '';
        let lines = '';

        segments.forEach((seg, i) => {
            const a0 = i * slice, a1 = (i + 1) * slice;
            const [x0, y0] = point(a0, R);
            const [x1, y1] = point(a1, R);
            const large = slice > 180 ? 1 : 0;
            slices += `<path d="M${CX} ${CY}L${x0.toFixed(2)} ${y0.toFixed(2)}A${R} ${R} 0 ${large} 1 ${x1.toFixed(2)} ${y1.toFixed(2)}Z" fill="${esc(seg.color)}"/>`;
            lines += `<line x1="${CX}" y1="${CY}" x2="${x0.toFixed(2)}" y2="${y0.toFixed(2)}"/>`;
            const fg = textColor(seg.color);
            labels += `<g transform="rotate(${(a0 + slice / 2).toFixed(2)} ${CX} ${CY})">
                <svg x="${CX - 12}" y="${CY - R + 16}" width="24" height="24" viewBox="0 0 24 24" class="svg-ico" style="color:${fg}">${ICONS[seg.icon] || ICONS.sparkle}</svg>
                <text class="slice-label" x="${CX}" y="${CY - R + 60}" text-anchor="middle" fill="${fg}">${esc(seg.label)}</text>
            </g>`;
        });

        let leds = '';
        for (let i = 0; i < LEDS; i++) {
            const [x, y] = point(i * (360 / LEDS), 142.5);
            leds += `<circle class="led" data-i="${i}" cx="${x.toFixed(2)}" cy="${y.toFixed(2)}" r="3.1"/>`;
        }

        $('wheel').innerHTML = `
            <defs>
                <radialGradient id="ds-shade" cx="50%" cy="50%" r="50%">
                    <stop offset="0%" stop-color="#fff" stop-opacity="0.18"/>
                    <stop offset="55%" stop-color="#fff" stop-opacity="0"/>
                    <stop offset="100%" stop-color="#000" stop-opacity="0.28"/>
                </radialGradient>
                <linearGradient id="ds-rim" x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0%" stop-color="#3a3a40"/>
                    <stop offset="50%" stop-color="#16161a"/>
                    <stop offset="100%" stop-color="#2c2c32"/>
                </linearGradient>
                <linearGradient id="ds-gold" x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0%" stop-color="#ffe08a"/>
                    <stop offset="50%" stop-color="#c8902a"/>
                    <stop offset="100%" stop-color="#ffd36b"/>
                </linearGradient>
            </defs>
            <circle cx="${CX}" cy="${CY}" r="149" fill="url(#ds-rim)"/>
            <circle cx="${CX}" cy="${CY}" r="137.5" fill="none" stroke="url(#ds-gold)" stroke-width="3"/>
            <g id="rotor" transform="rotate(${S.rotation} ${CX} ${CY})">
                ${slices}
                <g stroke="rgba(0,0,0,0.28)" stroke-width="1.5">${lines}</g>
                ${labels}
                <circle cx="${CX}" cy="${CY}" r="${R}" fill="url(#ds-shade)"/>
            </g>
            <g>${leds}</g>`;
    }

    function setRotation(deg) {
        S.rotation = deg;
        const rotor = $('rotor');
        if (rotor) rotor.setAttribute('transform', `rotate(${deg} ${CX} ${CY})`);
    }

    // LED patterns: idle (slow alternate), spin (chase), win (blink all)
    let ledStep = 0;
    setInterval(() => {
        ledStep++;
        const mode = S.ledMode;
        if (mode !== 'spin' && ledStep % 7 !== 0) return;
        document.querySelectorAll('.wheel .led').forEach(led => {
            const i = Number(led.dataset.i);
            let on;
            if (mode === 'spin') on = (i + ledStep) % 4 === 0;
            else if (mode === 'win') on = Math.floor(ledStep / 7) % 2 === 0;
            else on = (i + Math.floor(ledStep / 7)) % 2 === 0;
            led.classList.toggle('on', on);
            led.classList.toggle('off', !on);
        });
    }, 80);

    function flickPointer() {
        const p = $('pointer');
        p.classList.remove('flick');
        void p.offsetWidth;
        p.classList.add('flick');
    }

    function animateTo(index, duration) {
        const n = S.state.segments.length;
        const slice = 360 / n;
        const center = (index + 0.5) * slice;
        const jitter = (Math.random() - 0.5) * slice * 0.6;
        const targetMod = (((360 - center + jitter) % 360) + 360) % 360;
        const start = S.rotation;
        const current = ((start % 360) + 360) % 360;
        let delta = targetMod - current;
        if (delta < 0) delta += 360;
        const end = start + 360 * 6 + delta;

        return new Promise(resolve => {
            const t0 = performance.now();
            let lastSlice = Math.floor(start / slice);
            function frame(now) {
                const p = Math.min(1, (now - t0) / duration);
                const eased = 1 - Math.pow(1 - p, 4);
                setRotation(start + (end - start) * eased);
                const crossed = Math.floor(S.rotation / slice);
                if (crossed !== lastSlice) {
                    lastSlice = crossed;
                    Sound.play('tick');
                    flickPointer();
                }
                if (p < 1) requestAnimationFrame(frame);
                else resolve();
            }
            requestAnimationFrame(frame);
        });
    }

    // ---------------------------------------------------------------------------------------------
    // Rendering
    // ---------------------------------------------------------------------------------------------
    function renderTexts() {
        document.documentElement.lang = S.lang;
        document.querySelectorAll('[data-i18n]').forEach(el => { el.textContent = t(el.dataset.i18n); });
        document.querySelectorAll('[data-icon]').forEach(el => { el.innerHTML = icon(el.dataset.icon); });
        renderSoundBtn();
        render();
    }

    function renderSoundBtn() {
        const on = Sound.isEnabled();
        $('soundBtn').innerHTML = icon(on ? 'sound' : 'mute');
        $('soundBtn').setAttribute('aria-label', t(on ? 'sound_on' : 'sound_off'));
    }

    function canSpin() {
        const st = S.state;
        return !!(st && st.ready && !S.spinning && !st.mission && st.nextSpinAt * 1000 <= serverNow());
    }

    function formatDuration(ms) {
        const total = Math.max(0, Math.floor(ms / 1000));
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        const pad = v => String(v).padStart(2, '0');
        return h > 0 ? `${pad(h)}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
    }

    function renderStatus() {
        const st = S.state;
        const card = $('statusCard');
        const hub = $('spinBtn');
        card.classList.remove('is-ready', 'is-locked');

        if (!st || !st.ready) {
            $('statusIcon').innerHTML = icon('lock');
            $('statusCaption').textContent = '';
            $('statusValue').textContent = st ? t('no_character') : t('loading');
            card.classList.add('is-locked');
        } else if (S.spinning) {
            $('statusIcon').innerHTML = icon('sparkle');
            $('statusCaption').textContent = '';
            $('statusValue').textContent = t('spinning');
            card.classList.add('is-ready');
        } else if (st.mission) {
            $('statusIcon').innerHTML = icon(st.mission.icon);
            $('statusCaption').textContent = st.mission.label;
            $('statusValue').textContent = t('locked_mission');
            card.classList.add('is-locked');
        } else if (canSpin()) {
            $('statusIcon').innerHTML = icon('sparkle');
            $('statusCaption').textContent = '';
            $('statusValue').textContent = t('ready');
            card.classList.add('is-ready');
        } else {
            $('statusIcon').innerHTML = icon('clock');
            $('statusCaption').textContent = t('next_spin');
            $('statusValue').textContent = formatDuration(st.nextSpinAt * 1000 - serverNow());
        }

        const ready = canSpin();
        hub.disabled = !ready;
        hub.classList.toggle('ready', ready);
        $('hubLabel').innerHTML = ready || S.spinning ? esc(t('spin')) : icon(st && st.mission ? 'flag' : 'lock');
        $('chancesBtn').hidden = !(st && st.showChances);
    }

    function renderMission() {
        const st = S.state;
        const m = st && st.mission;
        document.body.classList.toggle('has-mission', !!m);
        const box = $('missionContent');

        if (!m) {
            box.innerHTML = `<div class="empty-state">
                <div class="empty-icon">${icon('wheel')}</div>
                <h3>${esc(t('no_mission'))}</h3>
                <p>${esc(t('no_mission_text'))}</p>
            </div>`;
            return;
        }

        const [c1, c2] = MISSION_COLORS[m.icon] || ['#ff375f', '#ff9f0a'];
        const steps = (m.steps || []).map((s, i) => {
            const current = i + 1 === m.step;
            const cls = s.done ? 'done' : current ? 'current' : '';
            const dot = s.done ? icon('check') : String(i + 1);
            return `<div class="step ${cls}"><div class="step-dot">${dot}</div><div class="step-label">${esc(s.label)}</div></div>`;
        }).join('');

        box.innerHTML = `
            <div class="mission-hero" style="--m1:${c1};--m2:${c2}">
                <div class="hero-icon">${icon(m.icon)}</div>
                <h2>${esc(m.label)}</h2>
                <p>${esc(m.description)}</p>
                <div class="hero-chips">
                    <span class="hero-chip">${icon('cash')}${money(m.reward)}</span>
                    <span class="hero-chip">${icon('clock')}<span id="missionExpire">${formatDuration(m.expiresAt * 1000 - serverNow())}</span></span>
                </div>
            </div>
            <div class="section-title">${esc(t('current_step'))}</div>
            <div class="card steps">${steps}</div>
            <div class="actions">
                <button class="btn btn-primary" id="navBtn">${icon('nav')}${esc(t('navigate'))}</button>
                <button class="btn btn-danger" id="cancelBtn">${esc(t('cancel'))}</button>
            </div>`;

        $('navBtn').onclick = async () => {
            Sound.play('tap');
            const res = await nui('setWaypoint');
            toast(t('waypoint_set'), !(res && res.ok));
        };
        $('cancelBtn').onclick = () => {
            Sound.play('tap');
            openSheet(`
                <h3>${esc(t('cancel_title'))}</h3>
                <p class="sheet-text">${esc(t('cancel_text'))}</p>
                <div class="actions">
                    <button class="btn btn-danger" id="confirmCancel">${esc(t('cancel_confirm'))}</button>
                    <button class="btn btn-plain" id="keepMission">${esc(t('keep'))}</button>
                </div>`);
            $('keepMission').onclick = closeSheet;
            $('confirmCancel').onclick = async () => {
                closeSheet();
                const res = await nui('cancelMission');
                if (res && res.error) toast(res.error, true);
                await loadState();
            };
        };
    }

    function relativeTime(unix) {
        const diff = Math.max(0, Math.floor((serverNow() / 1000 - unix) / 60));
        if (diff < 1) return t('just_now');
        if (diff < 60) return t('min_ago', diff);
        if (diff < 1440) return t('h_ago', Math.floor(diff / 60));
        return t('d_ago', Math.floor(diff / 1440));
    }

    function renderHistory() {
        const st = S.state;
        const stats = (st && st.stats) || {};
        $('statSpins').textContent = stats.spins || 0;
        $('statEarned').textContent = money(stats.earned);
        $('statMissions').textContent = stats.missions || 0;

        const history = (st && st.history) || [];
        if (!history.length) {
            $('historyList').innerHTML = `<div class="list-empty">${esc(t('history_empty'))}</div>`;
            return;
        }
        $('historyList').innerHTML = history.map(h => {
            const style = HISTORY_STYLE[h.kind] || HISTORY_STYLE.empty;
            const amount = h.amount > 0 ? `<span class="row-amount plus">+${money(h.amount)}</span>` : '';
            return `<div class="row">
                <div class="row-icon" style="background:${style.color}">${icon(style.icon)}</div>
                <div class="row-main">
                    <span class="row-title">${esc(h.label)}</span>
                    <span class="row-sub">${esc(t('kind_' + h.kind))} · ${esc(relativeTime(h.created_at))}</span>
                </div>
                ${amount}
            </div>`;
        }).join('');
    }

    function render() {
        const st = S.state;
        if (st && st.segments) {
            const key = JSON.stringify(st.segments);
            if (key !== S.segmentsKey) {
                S.segmentsKey = key;
                if (!S.spinning && S.rotation === 0) S.rotation = -180 / st.segments.length;
                buildWheel(st.segments);
            }
        }
        renderStatus();
        renderMission();
        renderHistory();
    }

    function setTab(tab) {
        S.tab = tab;
        const buttons = [...document.querySelectorAll('#tabs button')];
        const index = buttons.findIndex(b => b.dataset.tab === tab);
        buttons.forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
        document.querySelector('.seg-thumb').style.transform = `translateX(${index * 100}%)`;
        document.querySelectorAll('.view').forEach(v => v.classList.toggle('active', v.id === 'view-' + tab));
    }

    // ---------------------------------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------------------------------
    function applyState(state) {
        if (!state) return;
        S.state = state;
        if (state.now) S.offset = state.now * 1000 - Date.now();
        render();
    }

    async function loadState() {
        const state = await nui('getState');
        if (state) applyState(state);
        else if (!S.state) render();
    }

    // code = phone language, or null to let Lua keep its configured fallback
    async function setLanguage(code) {
        code = code || null;
        if (S.langRequested !== undefined && code === S.langRequested) return;
        S.langRequested = code;
        const res = await nui('setLanguage', { lang: code });
        if (res && res.strings) {
            S.strings = { ...DEFAULT_STRINGS, ...res.strings };
            S.lang = res.lang || 'en';
        }
        renderTexts();
    }

    function applySettings(settings) {
        if (!settings || typeof settings !== 'object') return Promise.resolve();
        const theme = (settings.display && settings.display.theme) || settings.theme;
        if (theme === 'light' || theme === 'dark') document.body.classList.toggle('dark', theme === 'dark');
        const lang = settings.locale || settings.language || settings.localeTag;
        return lang ? setLanguage(lang) : Promise.resolve();
    }

    // ---------------------------------------------------------------------------------------------
    // Spin
    // ---------------------------------------------------------------------------------------------
    function showResult(result) {
        const seg = S.state.segments.find(s => s.label === result.label) || {};
        const color = seg.color || '#ff375f';
        let caption, title, text = '', badgeIcon = result.icon || seg.icon || 'sparkle', titleCls = '';
        let buttons = `<button class="btn btn-primary" id="resultOk">${esc(t('great'))}</button>`;

        if (result.type === 'cash') {
            const jackpot = badgeIcon === 'crown';
            caption = t('result_cash');
            title = jackpot ? t('result_jackpot') : money(result.amount);
            text = jackpot ? money(result.amount) : '';
            titleCls = jackpot ? 'jackpot' : '';
            Sound.play(jackpot ? 'jackpot' : 'win');
            Confetti.burst(jackpot ? 260 : 120);
            if (jackpot) Confetti.burst(140);
        } else if (result.type === 'mission' && result.mission) {
            caption = t('result_mission');
            title = result.mission.label;
            text = result.mission.description;
            badgeIcon = result.mission.icon;
            buttons = `<button class="btn btn-primary" id="resultOk">${icon('flag')}${esc(t('to_mission'))}</button>`;
            Sound.play('mission');
            Confetti.burst(70);
        } else {
            caption = '';
            title = t('result_empty');
            text = t('result_empty_text');
            badgeIcon = 'empty';
            Sound.play('lose');
        }

        S.ledMode = result.type === 'empty' ? 'idle' : 'win';
        setTimeout(() => { S.ledMode = 'idle'; }, 3000);

        openSheet(`
            <div class="result">
                <div class="result-badge" style="--r1:${esc(color)};--r2:${esc(color)}cc">${icon(badgeIcon)}</div>
                ${caption ? `<div class="result-caption">${esc(caption)}</div>` : ''}
                <div class="result-title ${titleCls}">${esc(title)}</div>
                ${text ? `<p class="sheet-text">${esc(text)}</p>` : '<div style="height:20px"></div>'}
                <div class="actions">${buttons}</div>
            </div>`);
        $('resultOk').onclick = () => {
            Sound.play('tap');
            closeSheet();
            if (result.type === 'mission') setTab('mission');
        };
    }

    async function spin() {
        if (!canSpin()) return;
        S.spinning = true;
        Sound.play('tap');
        render();

        const res = await nui('spin');
        if (!res || !res.ok || !res.index) {
            S.spinning = false;
            Sound.play('error');
            toast((res && res.error) || t('loading'), true);
            if (res && res.state) applyState(res.state);
            else render();
            return;
        }

        $('wheelStage').classList.add('spinning');
        S.ledMode = 'spin';
        Sound.play('whoosh');
        await animateTo(res.index - 1, S.state.spinDuration || 6000);
        $('wheelStage').classList.remove('spinning');
        S.ledMode = 'idle';
        S.spinning = false;
        applyState(res.state);
        showResult(res.result);
    }

    function showChances() {
        Sound.play('tap');
        const rows = S.state.segments.map(seg => `
            <div class="row">
                <div class="row-icon" style="background:${esc(seg.color)};color:${textColor(seg.color)}">${icon(seg.icon)}</div>
                <div class="row-main">
                    <span class="row-title">${esc(seg.label)}</span>
                    <div class="odds-bar"><span style="width:${Math.min(100, (seg.chance || 0) * 3)}%;background:${esc(seg.color)}"></span></div>
                </div>
                <span class="row-amount">${(seg.chance || 0).toLocaleString(S.lang === 'de' ? 'de-DE' : 'en-US')}%</span>
            </div>`).join('');
        openSheet(`
            <h3>${esc(t('chances_title'))}</h3>
            <div class="card list odds">${rows}</div>
            <div class="actions"><button class="btn btn-plain" id="closeOdds">${esc(t('close'))}</button></div>`);
        $('closeOdds').onclick = closeSheet;
    }

    // ---------------------------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------------------------
    $('spinBtn').addEventListener('click', spin);
    $('chancesBtn').addEventListener('click', showChances);
    $('soundBtn').addEventListener('click', () => {
        Sound.setEnabled(!Sound.isEnabled());
        renderSoundBtn();
        Sound.play('tap');
        toast(t(Sound.isEnabled() ? 'sound_on' : 'sound_off'));
    });
    document.querySelectorAll('#tabs button').forEach(b => b.addEventListener('click', () => {
        if (b.dataset.tab === S.tab) return;
        Sound.play('tap');
        setTab(b.dataset.tab);
    }));

    // Messages from Lua (SendCustomAppMessage) and from the phone host
    window.addEventListener('message', e => {
        const msg = e.data;
        if (!msg || typeof msg !== 'object') return;

        if (msg.type === 'appOpen') loadState();
        if (msg.type === 'settingsUpdated' && msg.settings) applySettings(msg.settings).then(loadState);

        switch (msg.action) {
            case 'mission':
                if (S.state && !S.spinning) {
                    S.state.mission = msg.data;
                    render();
                }
                break;
            case 'missionEnd':
                if (msg.data && msg.data.success) {
                    Sound.play('success');
                    Confetti.burst(90);
                    toast(`${t('mission_done')} +${money(msg.data.reward)}`);
                } else if (msg.data) {
                    Sound.play('error');
                    toast(msg.data.reason || t('mission_failed'), true);
                }
                loadState();
                break;
            case 'refresh':
                loadState();
                break;
        }
    });

    document.addEventListener('visibilitychange', () => {
        if (!document.hidden) loadState();
    });

    // Countdown tick
    setInterval(() => {
        if (!S.state || S.spinning) return;
        renderStatus();
        const m = S.state.mission;
        const el = $('missionExpire');
        if (m && el) el.textContent = formatDuration(m.expiresAt * 1000 - serverNow());
    }, 1000);

    // Keep the cooldown honest if the app stays open for a long time
    setInterval(() => { if (!document.hidden && !S.spinning) loadState(); }, 60000);

    // ---------------------------------------------------------------------------------------------
    // Boot: wait for the phone SDK (injected after load on some phones), then read theme + language
    // ---------------------------------------------------------------------------------------------
    function waitForSdk(timeout = 1500) {
        return new Promise(resolve => {
            const ready = () => globalThis.componentsLoaded || typeof globalThis.getSettings === 'function';
            if (ready()) return resolve();
            const start = Date.now();
            const poll = setInterval(() => {
                if (ready() || Date.now() - start > timeout) {
                    clearInterval(poll);
                    resolve();
                }
            }, 50);
        });
    }

    async function readSettings() {
        try {
            const getter = globalThis.getSettings || globalThis.GetSettings;
            if (typeof getter === 'function') return await getter();
        } catch (e) { /* not available */ }
        return globalThis.settings || null;
    }

    async function boot() {
        renderTexts();
        setTab(S.tab);
        await waitForSdk();

        const settings = await readSettings();
        await applySettings(settings || {});
        if (S.langRequested === undefined) await setLanguage(PARAMS.get('lang'));

        const listen = globalThis.onSettingsChange || globalThis.OnSettingsChange;
        if (typeof listen === 'function') {
            try { listen(s => applySettings(s).then(loadState)); } catch (e) { /* not available */ }
        }

        await loadState();
        if (!IN_GAME) Demo.after();
    }

    // ---------------------------------------------------------------------------------------------
    // Demo mode (outside FiveM): sample data for previews and screenshots.
    // Params: ?view=spin|mission|history  &theme=light|dark  &result=jackpot|cash|mission|empty  &cooldown=1  &still=1
    // ---------------------------------------------------------------------------------------------
    const Demo = (() => {
        const now = () => Math.floor(Date.now() / 1000);
        const segments = [
            { type: 'cash', label: '$500', icon: 'cash', color: '#30d158', amount: 500, chance: 16.3 },
            { type: 'mission', label: 'Taxi', icon: 'taxi', color: '#ffd60a', chance: 14.3 },
            { type: 'empty', label: 'Nothing', icon: 'empty', color: '#48484a', chance: 18.4 },
            { type: 'cash', label: '$1,500', icon: 'cash', color: '#0a84ff', amount: 1500, chance: 8.2 },
            { type: 'mission', label: 'Courier', icon: 'package', color: '#ff9f0a', chance: 14.3 },
            { type: 'cash', label: '$1,000', icon: 'cash', color: '#64d2ff', amount: 1000, chance: 10.2 },
            { type: 'mission', label: 'Postman', icon: 'mail', color: '#bf5af2', chance: 14.3 },
            { type: 'cash', label: 'Jackpot', icon: 'crown', color: '#ff375f', amount: 7500, chance: 2 },
        ];
        const mission = () => ({
            id: 'demo', kind: 'taxi', label: 'Taxi Driver', icon: 'taxi',
            description: 'Pick up your passenger and drop them off safely at their destination.',
            reward: 1540, expiresAt: now() + 1421, step: 2,
            steps: [
                { label: 'Get your work vehicle (Downtown Cab Co.)', done: true },
                { label: 'Pick up the passenger', done: false },
                { label: 'Drive the passenger to the destination', done: false },
                { label: 'Return the vehicle to the depot', done: false },
            ],
        });
        let state = null;

        function build() {
            const view = PARAMS.get('view');
            return {
                ready: true,
                now: now(),
                nextSpinAt: PARAMS.get('cooldown') ? now() + 15 * 3600 + 42 * 60 + 17 : 0,
                spinDuration: 6000,
                showChances: true,
                segments,
                mission: view === 'mission' ? mission() : null,
                stats: { spins: 23, earned: 31450, missions: 9 },
                history: [
                    { kind: 'cash', label: '$1,500', amount: 1500, created_at: now() - 3600 * 20 },
                    { kind: 'mission_done', label: 'Postman', amount: 1720, created_at: now() - 3600 * 45 },
                    { kind: 'mission', label: 'Postman', amount: 0, created_at: now() - 3600 * 46 },
                    { kind: 'empty', label: 'Nothing', amount: 0, created_at: now() - 3600 * 70 },
                    { kind: 'cash', label: 'Jackpot', amount: 7500, created_at: now() - 3600 * 95 },
                    { kind: 'mission_done', label: 'Courier', amount: 1380, created_at: now() - 3600 * 120 },
                ],
            };
        }

        function handle(event) {
            if (event === 'setLanguage') return Promise.resolve({ lang: 'en', strings: DEFAULT_STRINGS });
            if (event === 'getState') {
                state = state || build();
                return Promise.resolve(JSON.parse(JSON.stringify(state)));
            }
            if (event === 'spin') {
                const index = Math.floor(Math.random() * segments.length);
                const seg = segments[index];
                const result = { type: seg.type, label: seg.label, amount: seg.amount, icon: seg.icon };
                state.nextSpinAt = now() + 86400;
                if (seg.type === 'mission') {
                    state.mission = mission();
                    state.mission.step = 1;
                    state.mission.steps[0].done = false;
                    result.mission = state.mission;
                }
                return Promise.resolve({ ok: true, index: index + 1, result, state: JSON.parse(JSON.stringify(state)) });
            }
            if (event === 'cancelMission') {
                state.mission = null;
                return Promise.resolve({ ok: true });
            }
            return Promise.resolve({ ok: true });
        }

        function after() {
            const theme = PARAMS.get('theme');
            if (theme) document.body.classList.toggle('dark', theme !== 'light');
            const view = PARAMS.get('view');
            if (view) setTab(view);
            const result = PARAMS.get('result');
            if (result) {
                const pick = { jackpot: 7, cash: 3, mission: 1, empty: 2 }[result] ?? 0;
                const seg = segments[pick];
                const slice = 360 / segments.length;
                setRotation(360 - (pick + 0.5) * slice);
                const res = { type: seg.type, label: seg.label, amount: seg.amount, icon: seg.icon };
                if (seg.type === 'mission') res.mission = { ...mission(), label: 'Taxi Driver' };
                showResult(res);
            }
        }

        return { handle, after };
    })();

    boot();
})();
