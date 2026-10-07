// Daily Spins - synthesized sound effects (Web Audio API, no audio files needed)
const Sound = (() => {
    let ctx = null;
    let master = null;
    let enabled = true;

    try { enabled = localStorage.getItem('dailyspins:sound') !== 'off'; } catch (e) { /* storage unavailable */ }

    function audio() {
        if (!ctx) {
            const AC = window.AudioContext || window.webkitAudioContext;
            if (!AC) return null;
            ctx = new AC();
            master = ctx.createGain();
            master.gain.value = 0.55;
            const comp = ctx.createDynamicsCompressor();
            master.connect(comp);
            comp.connect(ctx.destination);
        }
        if (ctx.state === 'suspended') ctx.resume();
        return ctx;
    }

    // One oscillator voice with an attack/decay envelope and an optional pitch slide
    function tone({ freq, type = 'sine', at = 0, dur = 0.15, vol = 0.25, slide = null, attack = 0.005, filter = null }) {
        const ac = audio();
        if (!ac) return;
        const t = ac.currentTime + at;
        const osc = ac.createOscillator();
        const gain = ac.createGain();
        osc.type = type;
        osc.frequency.setValueAtTime(freq, t);
        if (slide) osc.frequency.exponentialRampToValueAtTime(slide, t + dur);
        gain.gain.setValueAtTime(0.0001, t);
        gain.gain.exponentialRampToValueAtTime(vol, t + attack);
        gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);
        let node = osc;
        if (filter) {
            const f = ac.createBiquadFilter();
            f.type = 'lowpass';
            f.frequency.value = filter;
            osc.connect(f);
            node = f;
        }
        node.connect(gain);
        gain.connect(master);
        osc.start(t);
        osc.stop(t + dur + 0.05);
    }

    // Filtered noise burst, used for clicks and the whoosh
    function noise({ at = 0, dur = 0.2, vol = 0.2, from = 800, to = null, q = 1, type = 'bandpass' }) {
        const ac = audio();
        if (!ac) return;
        const t = ac.currentTime + at;
        const length = Math.max(1, Math.floor(ac.sampleRate * dur));
        const buffer = ac.createBuffer(1, length, ac.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < length; i++) data[i] = Math.random() * 2 - 1;
        const src = ac.createBufferSource();
        src.buffer = buffer;
        const f = ac.createBiquadFilter();
        f.type = type;
        f.Q.value = q;
        f.frequency.setValueAtTime(from, t);
        if (to) f.frequency.exponentialRampToValueAtTime(to, t + dur);
        const gain = ac.createGain();
        gain.gain.setValueAtTime(0.0001, t);
        gain.gain.exponentialRampToValueAtTime(vol, t + dur * 0.3);
        gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);
        src.connect(f);
        f.connect(gain);
        gain.connect(master);
        src.start(t);
        src.stop(t + dur + 0.05);
    }

    const sounds = {
        tap() {
            tone({ freq: 520, type: 'sine', dur: 0.06, vol: 0.12, slide: 380 });
        },
        tick() {
            tone({ freq: 2100, type: 'square', dur: 0.025, vol: 0.05, filter: 3500 });
            noise({ dur: 0.03, vol: 0.12, from: 3000, q: 2 });
        },
        whoosh() {
            noise({ dur: 0.7, vol: 0.22, from: 300, to: 2600, q: 0.8 });
            tone({ freq: 140, type: 'sine', dur: 0.5, vol: 0.12, slide: 320 });
        },
        win() {
            const notes = [523.25, 659.25, 783.99, 1046.5];
            notes.forEach((f, i) => {
                tone({ freq: f, type: 'triangle', at: i * 0.09, dur: 0.35, vol: 0.22 });
                tone({ freq: f * 2, type: 'sine', at: i * 0.09, dur: 0.25, vol: 0.05 });
            });
            [1318.5, 1567.98, 2093].forEach((f, i) => tone({ freq: f, type: 'sine', at: 0.4 + i * 0.06, dur: 0.5, vol: 0.06 }));
        },
        jackpot() {
            const run = [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5];
            run.forEach((f, i) => tone({ freq: f, type: 'square', at: i * 0.08, dur: 0.18, vol: 0.07, filter: 2600 }));
            [523.25, 659.25, 783.99, 1046.5].forEach(f => tone({ freq: f, type: 'triangle', at: 0.6, dur: 1.4, vol: 0.14, attack: 0.02 }));
            for (let i = 0; i < 10; i++) {
                tone({ freq: 1800 + Math.random() * 1600, type: 'sine', at: 0.65 + i * 0.07, dur: 0.25, vol: 0.05 });
            }
            noise({ at: 0.6, dur: 1.1, vol: 0.05, from: 6000, q: 0.5, type: 'highpass' });
        },
        mission() {
            tone({ freq: 659.25, type: 'triangle', dur: 0.18, vol: 0.2 });
            tone({ freq: 987.77, type: 'triangle', at: 0.13, dur: 0.3, vol: 0.2 });
            tone({ freq: 1318.5, type: 'sine', at: 0.26, dur: 0.45, vol: 0.1 });
            [329.63, 493.88].forEach(f => tone({ freq: f, type: 'sine', at: 0.13, dur: 0.6, vol: 0.08, attack: 0.03 }));
        },
        lose() {
            tone({ freq: 392, type: 'sawtooth', dur: 0.28, vol: 0.09, filter: 1200, slide: 370 });
            tone({ freq: 349.23, type: 'sawtooth', at: 0.3, dur: 0.28, vol: 0.09, filter: 1100, slide: 330 });
            tone({ freq: 311.13, type: 'sawtooth', at: 0.6, dur: 0.7, vol: 0.1, filter: 900, slide: 233 });
        },
        success() {
            [783.99, 1046.5, 1318.5, 1567.98].forEach((f, i) => tone({ freq: f, type: 'sine', at: i * 0.07, dur: 0.4, vol: 0.14 }));
        },
        error() {
            tone({ freq: 220, type: 'square', dur: 0.1, vol: 0.06, filter: 900 });
            tone({ freq: 196, type: 'square', at: 0.12, dur: 0.14, vol: 0.06, filter: 900 });
        },
    };

    function play(name) {
        if (!enabled || !sounds[name]) return;
        try { sounds[name](); } catch (e) { /* audio not available */ }
    }

    function setEnabled(value) {
        enabled = value;
        try { localStorage.setItem('dailyspins:sound', value ? 'on' : 'off'); } catch (e) { /* storage unavailable */ }
    }

    return { play, setEnabled, isEnabled: () => enabled };
})();
