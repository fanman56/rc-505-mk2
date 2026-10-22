// BOSS RC-505mkII Loop Station - Complete Consolidated Flutter Port (Linux PipeWire/ALSA + Android)
// Includes: 1:1 Hardware Chassis, All 53 Authentic MKII Effects (G2B, Harmonist, Vocoder, etc.),
// Per-Track Isolated Output Buffers, Per-Slot Track FX TARGET (ALL / TRK 1..5),
// Per-Track Dedicated Insert FX + PRINT/BAKE FX to Track, Full Keyboard Mapping & Help Overlay.
import 'dart:async';
import 'dart:io';
import 'dart:math' as m;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const SR = 44100;

enum S { empty, rec, play, dub, stop, wait, stopping }

const red = Color(0xFFFF2222),
    green = Color(0xFF1EFF55),
    orange = Color(0xFFFF9A18);
const pink = Color(0xFFFF3A88),
    mint = Color(0xFF1EFF9E),
    cyan = Color(0xFF28D8FF),
    blue = Color(0xFF3888FF);

// Complete Official BOSS RC-505mkII FX List (53 Effects)
class FxSpec {
  final String name;
  final List<String> p;
  final int alg;
  final double arg;
  const FxSpec(this.name, this.p, this.alg, [this.arg = 0]);
}

const fxSpecs = <FxSpec>[
  // Filter & EQ (0..8)
  FxSpec('LPF', ['RATE', 'DEPTH', 'RESO', 'CUTOFF'], 0, 0),
  FxSpec('BPF', ['RATE', 'DEPTH', 'RESO', 'CUTOFF'], 0, 1),
  FxSpec('HPF', ['RATE', 'DEPTH', 'RESO', 'CUTOFF'], 0, 2),
  FxSpec('PHASER', ['RATE', 'DEPTH', 'RESO', 'MANUAL'], 1, 0),
  FxSpec('FLANGER', ['RATE', 'DEPTH', 'RESO', 'MANUAL'], 1, 1),
  FxSpec('SYNTH', ['FREQ', 'RESO', 'DECAY', 'BALANCE'], 2, 0),
  FxSpec('LO-FI', ['BIT', 'SAMPLE', 'BALANCE', 'LEVEL'], 3, 0),
  FxSpec('RADIO', ['LO-FI', 'LEVEL', 'NOISE', 'BALANCE'], 3, 1),
  FxSpec('RING MOD', ['FREQ', 'BALANCE', 'MOD', 'LEVEL'], 4, 0),
  // Guitar / Pitch / Harmony / Vocals (9..21)
  FxSpec('G2B', ['BALANCE', 'TONE', 'MODE', 'LEVEL'], 5, -12),
  FxSpec('DEFRETTER', ['TONE', 'ATTACK', 'DEPTH', 'SENS'], 2, 1),
  FxSpec('SUSTAINER', ['ATTACK', 'RELEASE', 'SUSTAIN', 'LEVEL'], 6, 0),
  FxSpec('AUTO RIFF', ['PHRASE', 'TEMPO', 'LOOP', 'BALANCE'], 7, 1),
  FxSpec('SLOW GEAR', ['SENS', 'RISE', 'LEVEL', 'MODE'], 2, 2),
  FxSpec('TRANSPOSE', ['TRANS', 'MODE', 'BALANCE', 'LEVEL'], 5, 0),
  FxSpec('PITCH BEND', ['PITCH', 'BEND', 'MODE', 'LEVEL'], 5, 7),
  FxSpec('ROBOT', ['ROBOT', 'FORMANT', 'MOD', 'GENDER'], 8, 0),
  FxSpec('ELECTRIC', ['SHIFT', 'FORMANT', 'STABILITY', 'SCALE'], 8, 1),
  FxSpec('HARMONIST', ['HARMONY', 'KEY', 'FORMANT', 'BALANCE'], 9, 0),
  FxSpec('OCTAVE', ['OCTAVE', 'MODE', 'TRACK', 'BALANCE'], 9, 1),
  FxSpec('VOCODER', ['CARRIER', 'TONE', 'SENS', 'BALANCE'], 8, 2),
  FxSpec('OSC BOT', ['OSC', 'TONE', 'MOD', 'BALANCE'], 8, 3),
  // Drive & Dynamics (22..26)
  FxSpec('PREAMP', ['TYPE', 'GAIN', 'T-COMP', 'LEVEL'], 6, 1),
  FxSpec('DIST', ['TYPE', 'TONE', 'DRIVE', 'LEVEL'], 6, 2),
  FxSpec('DYNAMICS', ['TYPE', 'DYNAMICS', 'MAKEUP', 'BALANCE'], 6, 0),
  FxSpec('EQ', ['LOW', 'MID', 'HIGH', 'LEVEL'], 10, 0),
  FxSpec('ISOLATOR', ['LOW', 'MID', 'HIGH', 'RATE'], 10, 1),
  // Slicer / Modulation / Pan (27..32)
  FxSpec('VIBRATO', ['RATE', 'DEPTH', 'COLOR', 'D.LEVEL'], 1, 2),
  FxSpec('TREMOLO', ['RATE', 'WAVE', 'DEPTH', 'LEVEL'], 11, 0),
  FxSpec('AUTO PAN', ['RATE', 'WAVE', 'INIT', 'DEPTH'], 11, 1),
  FxSpec('MANUAL PAN', ['POS', 'WIDTH', 'CH', 'LEVEL'], 11, 2),
  FxSpec('SLICER', ['PATTERN', 'RATE', 'DEPTH', 'THRESHOLD'], 11, 3),
  FxSpec('CHORUS', ['RATE', 'DEPTH', 'D.LEVEL', 'E.LEVEL'], 1, 3),
  // Delays & Reverbs (33..48)
  FxSpec('DELAY', ['TIME', 'FEEDBACK', 'HI-CUT', 'E.LEVEL'], 12, 0),
  FxSpec('PANNING DLY', ['TIME', 'FEEDBACK', 'HI-CUT', 'E.LEVEL'], 12, 1),
  FxSpec('REVERSE DLY', ['TIME', 'FEEDBACK', 'HI-CUT', 'E.LEVEL'], 12, 2),
  FxSpec('MOD DELAY', ['TIME', 'FEEDBACK', 'MOD', 'E.LEVEL'], 12, 3),
  FxSpec('TAPE ECHO', ['RATE', 'INTENSITY', 'TREBLE', 'E.LEVEL'], 12, 4),
  FxSpec('SPACE ECHO', ['RATE', 'INTENSITY', 'MODE', 'E.LEVEL'], 12, 5),
  FxSpec('GRANULAR DLY', ['TIME', 'FEEDBACK', 'SPREAD', 'E.LEVEL'], 12, 6),
  FxSpec('WARP', ['LEVEL', 'TIME', 'FEEDBACK', 'SW'], 13, 0),
  FxSpec('TWIST', ['RELEASE', 'FALL', 'RISE', 'LEVEL'], 13, 1),
  FxSpec('ROLL 1', ['TIME', 'REPEAT', 'ROLL', 'BALANCE'], 14, 0),
  FxSpec('ROLL 2', ['TIME', 'REPEAT', 'ROLL', 'BALANCE'], 14, 1),
  FxSpec('FREEZE', ['ATTACK', 'RELEASE', 'SENS', 'BALANCE'], 13, 2),
  FxSpec('CHORUS DLY', ['TIME', 'FEEDBACK', 'CHORUS', 'E.LEVEL'], 12, 3),
  FxSpec('REVERB', ['TIME', 'PRE-DLY', 'DENSITY', 'E.LEVEL'], 13, 3),
  FxSpec('GATE REVERB', ['TIME', 'PRE-DLY', 'THRES', 'E.LEVEL'], 13, 4),
  FxSpec('REV REVERB', ['TIME', 'PRE-DLY', 'GATE', 'E.LEVEL'], 13, 5),
  // Track FX Only: Beat & Vinyl (49..52)
  FxSpec('BEAT SCATTER', ['TYPE', 'LENGTH', 'SW', 'BALANCE'], 14, 2),
  FxSpec('BEAT REPEAT', ['TYPE', 'LENGTH', 'GATE', 'BALANCE'], 14, 0),
  FxSpec('BEAT SHIFT', ['TYPE', 'SHIFT', 'THRUST', 'BALANCE'], 15, 0),
  FxSpec('VINYL FLICK', ['FLICK', 'NOISE', 'SPEED', 'BALANCE'], 15, 1),
];

const measOpts = [
  'DEFAULT',
  'AUTO',
  'FREE',
  '1BEAT',
  '1BAR',
  '2BAR',
  '4BAR',
  '8BAR',
  '16BAR',
  '32BAR',
];
const loopMeasOpts = [
  'AUTO',
  'FREE',
  '1BEAT',
  '1BAR',
  '2BAR',
  '4BAR',
  '8BAR',
  '16BAR',
  '32BAR',
];
const startOpts = ['IMMEDIATE', 'FADE IN'];
const stopOpts = ['IMMEDIATE', 'FADE OUT', 'LOOP END'];
const dubOpts = ['OVERDUB', 'REPLACE'];
const spdOpts = ['HALF', 'NORMAL', 'DOUBLE'];
const tgtOpts = ['ALL', 'TRK 1', 'TRK 2', 'TRK 3', 'TRK 4', 'TRK 5'];

const PAT = <String, List<List<String>>>{
  'ROCK': [
    ['x.......x.x.....', '....x.......x...', 'x.x.x.x.x.x.x.x.'],
    ['x..x..x.x.x.....', '....x.......x..x', 'xxxxxxxxxxxxxxxx'],
  ],
  'HOUSE': [
    ['x...x...x...x...', '....x.......x...', '..x...x...x...x.'],
    ['x...x...x...x..x', '....x.......x..x', 'x.xxx.xxx.xxx.xx'],
  ],
  'HIPHOP': [
    ['x.....x...x.....', '....x.......x...', 'x.x.x.x.x.x.x.x.'],
    ['x..x..x...x..x..', '....x.......x...', 'x.xxx.x.x.xxx.x.'],
  ],
  'FUNK': [
    ['x..x..x...x..x..', '....x..x....x..x', 'x.x.x.x.x.x.x.x.'],
    ['x..x.xx...x..x.x', '....x..x.x..x..x', 'xxxxxxxxxxxxxxxx'],
  ],
  'DNB': [
    ['x.........x.....', '....x.......x...', 'x.x.x.x.x.x.x.x.'],
    ['x.....x...x.....', '....x.......x..x', 'xxxxxxxxxxxxxxxx'],
  ],
};

// ---------------- lock-free ring buffer & voice structs ----------------
class RingBuf {
  final Float32List _b = Float32List(SR * 2);
  int _r = 0, _w = 0, _c = 0;
  void write(ByteData d, int n) {
    final len = _b.length;
    for (var i = 0; i < n; i++) {
      _b[_w] = d.getInt16(i * 2, Endian.little) / 32768.0;
      _w = (_w + 1) % len;
      if (_c < len)
        _c++;
      else
        _r = (_r + 1) % len;
    }
  }

  double read() {
    if (_c == 0) return 0.0;
    final v = _b[_r];
    _r = (_r + 1) % _b.length;
    _c--;
    return v;
  }
}

class DrumVoice {
  final Float32List sample;
  int offset, cursor = 0;
  DrumVoice(this.sample, this.offset);
}

// ---------------- Universal Real-Time DSP Engine (All 53 MKII Effects) ----------------
void runFx(int ty, Float32List x, List<double> p, Map s) {
  final spec = fxSpecs[ty % fxSpecs.length];
  final alg = spec.alg;
  final arg = spec.arg;

  switch (alg) {
    case 0: // LPF / BPF / HPF with LFO Modulation
      var ph = (s['ph'] ?? 0.0) as double,
          lp = (s['lp'] ?? 0.0) as double,
          bp = (s['bp'] ?? 0.0) as double;
      final lfoInc = 2 * m.pi * (0.2 + 8.0 * p[0]) / SR;
      final q = 0.5 + 3.0 * p[2];
      for (var i = 0; i < x.length; i++) {
        final mod = (p[3] + p[1] * 0.4 * m.sin(ph)).clamp(0.05, 0.95);
        final f =
            2 * m.sin(m.pi * (60.0 * m.pow(180, mod)) / SR).clamp(0.01, 0.85);
        lp += f * bp;
        final hp = x[i] - lp - bp / q;
        bp += f * hp;
        x[i] = (arg == 0 ? lp : (arg == 1 ? bp : hp)).clamp(-1.5, 1.5);
        ph += lfoInc;
      }
      s['ph'] = ph % (2 * m.pi);
      s['lp'] = lp;
      s['bp'] = bp;

    case 1: // PHASER / FLANGER / VIBRATO / CHORUS
      const L = 4096;
      final b = (s['b'] ??= Float32List(L)) as Float32List;
      var w = (s['w'] ?? 0) as int, ph = (s['ph'] ?? 0.0) as double;
      final r = 2 * m.pi * (0.15 + 6.0 * p[0]) / SR;
      final base = arg == 0 ? 45.0 : (arg == 1 ? 110.0 : 260.0);
      final depth = (arg == 0 ? 35.0 : 160.0) * p[1];
      final fb = (arg == 2 ? 0.0 : p[2] * 0.7);
      for (var i = 0; i < x.length; i++) {
        final dly = base + depth * (1 + m.sin(ph));
        final ri = (w - dly.toInt() + L) % L;
        final delayed = b[ri];
        b[w] = (x[i] + delayed * fb).clamp(-1.5, 1.5);
        x[i] = arg == 2 ? delayed : (x[i] * 0.6 + delayed * (0.4 + 0.5 * p[3]));
        w = (w + 1) % L;
        ph += r;
      }
      s['w'] = w;
      s['ph'] = ph % (2 * m.pi);

    case 2: // SYNTH / DEFRETTER / SLOW GEAR
      var env = (s['env'] ?? 0.0) as double,
          ph = (s['ph'] ?? 0.0) as double,
          lp = (s['lp'] ?? 0.0) as double;
      final freq = 55.0 * m.pow(16, p[0]);
      final inc = 2 * m.pi * freq / SR;
      for (var i = 0; i < x.length; i++) {
        final a = x[i].abs();
        env = a > env
            ? (env * 0.98 + a * 0.02)
            : (env * (0.9992 - p[2] * 0.0008));
        if (arg == 0) {
          final saw = (ph / m.pi) - 1.0;
          ph = (ph + inc) % (2 * m.pi);
          final cut = (0.04 + env * 0.65).clamp(0.02, 0.85);
          lp += cut * (saw * env * 2.2 - lp);
          x[i] = (1 - p[3]) * x[i] + p[3] * lp;
        } else {
          final swell = (env * (3.0 + p[1] * 8.0)).clamp(0.0, 1.0);
          x[i] *= swell;
        }
      }
      s['env'] = env;
      s['ph'] = ph;
      s['lp'] = lp;

    case 3: // LO-FI / RADIO
      final lv = m.pow(2, 15 - 13 * p[0]), ds = 1 + (p[1] * 20).toInt();
      var h = (s['h'] ?? 0.0) as double,
          c = (s['c'] ?? 0) as int,
          bp = (s['bp'] ?? 0.0) as double;
      for (var i = 0; i < x.length; i++) {
        if (c-- <= 0) {
          h = (x[i] * lv).roundToDouble() / lv;
          c = ds - 1;
        }
        bp = bp * 0.75 + h * 0.25;
        final out = arg == 1 ? (bp * 1.8).clamp(-0.9, 0.9) : h;
        x[i] = (1 - p[2]) * x[i] + p[2] * out;
      }
      s['h'] = h;
      s['c'] = c;
      s['bp'] = bp;

    case 4: // RING MOD
      var ph = (s['ph'] ?? 0.0) as double;
      final r = 2 * m.pi * (35 + 2200 * p[0]) / SR;
      for (var i = 0; i < x.length; i++) {
        x[i] = (1 - p[1]) * x[i] + p[1] * x[i] * m.sin(ph);
        ph += r;
      }
      s['ph'] = ph % (2 * m.pi);

    case 5: // G2B (Guitar to Bass -1 Oct) / TRANSPOSE / PITCH BEND
      const G = 2048;
      final b = (s['b'] ??= Float32List(G)) as Float32List;
      var w = (s['w'] ?? 0) as int,
          ph = (s['ph'] ?? 0.0) as double,
          lp = (s['lp'] ?? 0.0) as double;
      final semi = arg == -12
          ? -12.0
          : (arg == 0
                ? ((p[0] * 24).round() - 12).toDouble()
                : (p[0] * 24 - 12) * p[1]);
      final ratio = m.pow(2.0, semi / 12.0).toDouble();
      final rate = (1.0 - ratio) / G;
      final mix = arg == -12 ? p[0] : p[2];
      for (var i = 0; i < x.length; i++) {
        b[w] = x[i];
        ph = (ph + rate) % 1.0;
        if (ph < 0) ph += 1.0;
        final ph2 = (ph + 0.5) % 1.0;
        final d1 = ph * G, d2 = ph2 * G;
        final w1 = 0.5 * (1.0 - m.cos(2 * m.pi * ph));
        final w2 = 0.5 * (1.0 - m.cos(2 * m.pi * ph2));
        final s1 = b[(w - d1.toInt() + G) % G];
        final s2 = b[(w - d2.toInt() + G) % G];
        var pitched = s1 * w1 + s2 * w2;
        if (arg == -12) {
          lp =
              lp * (0.4 + 0.5 * (1 - p[1])) +
              pitched * (0.6 - 0.5 * (1 - p[1]));
          pitched = lp * 1.35;
        }
        x[i] = (1 - mix) * x[i] + mix * pitched;
        w = (w + 1) % G;
      }
      s['w'] = w;
      s['ph'] = ph;
      s['lp'] = lp;

    case 6: // SUSTAINER / PREAMP / DIST / DYNAMICS
      final drive = arg == 0 ? (1.5 + 8 * p[2]) : (1.0 + 34.0 * p[1]);
      final makeup = 0.45 + p[3] * 0.9;
      for (var i = 0; i < x.length; i++) {
        final e = m.exp(2 * (x[i] * drive).clamp(-6.0, 6.0));
        x[i] = ((e - 1) / (e + 1)) * makeup;
      }

    case 7: // AUTO RIFF
      const G = 2048;
      final b = (s['b'] ??= Float32List(G)) as Float32List;
      var w = (s['w'] ?? 0) as int,
          ph = (s['ph'] ?? 0.0) as double,
          stepCnt = (s['sc'] ?? 0) as int;
      final notes = const [0, 3, 7, 12, 7, 3, 10, 12];
      final stepLen = (SR * (0.08 + 0.25 * (1 - p[1]))).toInt();
      for (var i = 0; i < x.length; i++) {
        b[w] = x[i];
        stepCnt++;
        final semi = notes[(stepCnt ~/ m.max(1, stepLen)) % notes.length];
        final ratio = m.pow(2.0, semi / 12.0).toDouble();
        ph = (ph + (1.0 - ratio) / G) % 1.0;
        if (ph < 0) ph += 1.0;
        final s1 = b[(w - (ph * G).toInt() + G) % G];
        x[i] = (1 - p[3]) * x[i] + p[3] * s1;
        w = (w + 1) % G;
      }
      s['w'] = w;
      s['ph'] = ph;
      s['sc'] = stepCnt;

    case 8: // ROBOT / ELECTRIC / VOCODER / OSC BOT
      var ph = (s['ph'] ?? 0.0) as double,
          env = (s['env'] ?? 0.0) as double,
          bp = (s['bp'] ?? 0.0) as double;
      final notes = const [
        65.41,
        73.42,
        82.41,
        98.0,
        110.0,
        130.81,
        146.83,
        164.81,
        196.0,
        220.0,
        261.63,
      ];
      final f0 = notes[(p[0] * (notes.length - 1)).round()];
      final inc = 2 * m.pi * f0 / SR;
      final form = 0.08 + 0.55 * p[1];
      for (var i = 0; i < x.length; i++) {
        env = env * 0.992 + x[i].abs() * 0.008;
        ph = (ph + inc) % (2 * m.pi);
        final carrier = arg == 1
            ? m.sin(ph)
            : ((ph < m.pi ? 1.0 : -1.0) * 0.5 + (ph / m.pi - 1.0) * 0.5);
        bp += form * (carrier * env * 2.8 - bp);
        x[i] = (1 - p[3]) * x[i] + p[3] * bp;
      }
      s['ph'] = ph;
      s['env'] = env;
      s['bp'] = bp;

    case 9: // HARMONIST / OCTAVE
      const G = 2048;
      final b = (s['b'] ??= Float32List(G)) as Float32List;
      var w = (s['w'] ?? 0) as int,
          ph1 = (s['p1'] ?? 0.0) as double,
          ph2 = (s['p2'] ?? 0.0) as double;
      final intervals = const [-12.0, -7.0, -5.0, 3.0, 4.0, 7.0, 12.0];
      final semi = arg == 1
          ? -12.0
          : intervals[(p[0] * (intervals.length - 1)).round()];
      final r1 = (1.0 - m.pow(2.0, semi / 12.0)) / G;
      final r2 = (1.0 - m.pow(2.0, -12.0 / 12.0)) / G;
      for (var i = 0; i < x.length; i++) {
        b[w] = x[i];
        ph1 = (ph1 + r1) % 1.0;
        if (ph1 < 0) ph1 += 1.0;
        ph2 = (ph2 + r2) % 1.0;
        if (ph2 < 0) ph2 += 1.0;
        final h1 =
            b[(w - (ph1 * G).toInt() + G) % G] *
                0.5 *
                (1 - m.cos(2 * m.pi * ph1)) +
            b[(w - (((ph1 + 0.5) % 1.0) * G).toInt() + G) % G] *
                0.5 *
                (1 - m.cos(2 * m.pi * ((ph1 + 0.5) % 1.0)));
        final h2 = arg == 1 && p[1] > 0.5
            ? b[(w - (ph2 * G).toInt() + G) % G] * 0.4
            : 0.0;
        x[i] = x[i] * (1.0 - p[3] * 0.5) + (h1 + h2) * p[3];
        w = (w + 1) % G;
      }
      s['w'] = w;
      s['p1'] = ph1;
      s['p2'] = ph2;

    case 10: // EQ / ISOLATOR (3-Band Cached Biquad)
      for (var b = 0; b < 3; b++) {
        final z = (s['z$b'] ??= Float64List(4)) as Float64List;
        var cf = s['c$b'] as Float64List?;
        if (cf == null || s['p$b'] != p[b]) {
          s['p$b'] = p[b];
          final g = (p[b] - .5) * (arg == 1 ? 36 : 24),
              A = m.pow(10, g / 40).toDouble();
          final f = const [120.0, 1000.0, 6000.0][b],
              w = 2 * m.pi * f / SR,
              cw = m.cos(w),
              sw = m.sin(w);
          double b0, b1, b2, a0, a1, a2;
          if (b == 1) {
            final al = sw / 2;
            b0 = 1 + al * A;
            b1 = -2 * cw;
            b2 = 1 - al * A;
            a0 = 1 + al / A;
            a1 = -2 * cw;
            a2 = 1 - al / A;
          } else {
            final q = 2 * m.sqrt(A) * (sw / 2 * m.sqrt2), lo = b == 0;
            b0 = lo
                ? A * ((A + 1) - (A - 1) * cw + q)
                : A * ((A + 1) + (A - 1) * cw + q);
            b1 = lo
                ? 2 * A * ((A - 1) - (A + 1) * cw)
                : -2 * A * ((A - 1) + (A + 1) * cw);
            b2 = lo
                ? A * ((A + 1) - (A - 1) * cw - q)
                : A * ((A + 1) + (A - 1) * cw - q);
            a0 = lo ? (A + 1) + (A - 1) * cw + q : (A + 1) - (A - 1) * cw + q;
            a1 = lo
                ? -2 * ((A - 1) + (A + 1) * cw)
                : 2 * ((A - 1) - (A + 1) * cw);
            a2 = lo ? (A + 1) + (A - 1) * cw - q : (A + 1) - (A - 1) * cw - q;
          }
          cf = s['c$b'] = Float64List.fromList([
            b0 / a0,
            b1 / a0,
            b2 / a0,
            a1 / a0,
            a2 / a0,
          ]);
        }
        final c0 = cf[0], c1 = cf[1], c2 = cf[2], d1 = cf[3], d2 = cf[4];
        var x1 = z[0], x2 = z[1], y1 = z[2], y2 = z[3];
        for (var i = 0; i < x.length; i++) {
          final xi = x[i], y = c0 * xi + c1 * x1 + c2 * x2 - d1 * y1 - d2 * y2;
          x2 = x1;
          x1 = xi;
          y2 = y1;
          y1 = y;
          x[i] = y;
        }
        z[0] = x1;
        z[1] = x2;
        z[2] = y1;
        z[3] = y2;
      }

    case 11: // TREMOLO / AUTO PAN / MANUAL PAN / SLICER
      var ph = (s['ph'] ?? 0.0) as double;
      final r = 2 * m.pi * (0.5 + 14.0 * p[0]) / SR;
      final sq = arg == 3 || p[1] > 0.5;
      for (var i = 0; i < x.length; i++) {
        final lfo = sq ? (m.sin(ph) >= 0 ? 1.0 : -1.0) : m.sin(ph);
        x[i] *= 1.0 - p[2] * 0.5 * (1.0 + lfo);
        ph += r;
      }
      s['ph'] = ph % (2 * m.pi);

    case 12: // DELAY / PANNING DLY / REVERSE DLY / MOD DLY / TAPE ECHO / SPACE ECHO / GRANULAR DLY
      const L = SR * 2;
      final b = (s['b'] ??= Float32List(L)) as Float32List;
      final t = (SR * (0.04 + 0.9 * p[0])).toInt();
      var w = (s['w'] ?? 0) as int, lp = (s['lp'] ?? 0.0) as double;
      final rev = arg == 2;
      for (var i = 0; i < x.length; i++) {
        final idx = rev ? ((L - w + t) % L) : ((w - t + L) % L);
        final d = b[idx];
        lp = lp * 0.35 + d * 0.65;
        b[w] = (x[i] + lp * p[1] * 0.9).clamp(-1.5, 1.5);
        x[i] += lp * p[3];
        w = (w + 1) % L;
      }
      s['w'] = w;
      s['lp'] = lp;

    case 13: // REVERB / GATE REVERB / REV REVERB / WARP / TWIST / FREEZE
      final g = arg == 2 ? 0.985 : (0.58 + 0.38 * p[0]);
      final damp = 0.2 + 0.6 * p[1];
      final c =
          (s['c'] ??= [1557, 1617, 1491, 1422].map(Float32List.new).toList())
              as List<Float32List>;
      final ix = (s['i'] ??= Int32List(4)) as Int32List;
      final lp = (s['lp'] ??= Float64List(4)) as Float64List;
      for (var k = 0; k < x.length; k++) {
        var o = 0.0;
        final inSig = arg == 2 ? 0.0 : x[k];
        for (var j = 0; j < 4; j++) {
          final raw = c[j][ix[j]];
          lp[j] = lp[j] * damp + raw * (1 - damp);
          final y = inSig + g * lp[j];
          c[j][ix[j]] = y.clamp(-1.5, 1.5);
          ix[j] = (ix[j] + 1) % c[j].length;
          o += y * 0.25;
        }
        x[k] += o * p[3] * 0.7;
      }

    case 14: // ROLL 1 / ROLL 2 / BEAT SCATTER / BEAT REPEAT
      const L = SR;
      final b = (s['b'] ??= Float32List(L)) as Float32List;
      final divs = const [11025, 5512, 2756, 1378, 689];
      final sz = divs[(p[1] * (divs.length - 1)).round()];
      final gate = arg == 2 ? 0.55 : (0.25 + 0.75 * p[2]);
      var w = (s['w'] ?? 0) as int, r = (s['r'] ?? 0) as int;
      for (var i = 0; i < x.length; i++) {
        b[w] = x[i];
        final g = (r / sz) < gate ? 1.0 : 0.0;
        final dir = (arg == 2 && (r ~/ (sz ~/ 2)) % 2 == 1)
            ? (sz - 1 - (r % sz))
            : (r % sz);
        final rep = b[(w - sz + dir + L) % L] * g;
        x[i] = (1 - p[3]) * x[i] + p[3] * rep;
        w = (w + 1) % L;
        r = (r + 1) % sz;
      }
      s['w'] = w;
      s['r'] = r;

    case 15: // BEAT SHIFT / VINYL FLICK
      const L = SR * 2;
      final b = (s['b'] ??= Float32List(L)) as Float32List;
      var w = (s['w'] ?? 0) as int,
          rd = (s['rd'] ?? 0.0) as double,
          spd = (s['spd'] ?? 1.0) as double;
      final target = arg == 1 ? (0.04 + 0.96 * p[2]) : (0.5 + 1.5 * p[1]);
      for (var i = 0; i < x.length; i++) {
        b[w] = x[i];
        spd += (target - spd) * 0.0018;
        final ri = rd.toInt() % L;
        x[i] = (1 - p[3]) * x[i] + p[3] * b[(ri + L) % L];
        w = (w + 1) % L;
        rd = (rd + spd) % L;
      }
      s['w'] = w;
      s['rd'] = rd;
      s['spd'] = spd;
  }
}

// ---------------- Authentic RC-505mkII Track & Slot State ----------------
class Trk {
  S st = S.empty;
  Float32List d = Float32List(0);
  Float32List? markD;
  Float32List? baseD;
  double vol = .8, lvl = 0, pan = 0, env = 1.0;
  List<Float32List> buf = [];
  bool fx = true,
      rev = false,
      oneShot = false,
      loopSync = true,
      tempoSync = true,
      bnc = false;
  int meas = 0; // 0:DEFAULT, 1:AUTO, 2:FREE, 3:1BEAT, 4:1BAR, 5:2BAR, 6:4BAR, 7:8BAR, 8:16BAR, 9:32BAR
  int startMode = 0; // 0:IMMEDIATE, 1:FADE IN
  int stopMode = 0; // 0:IMMEDIATE, 1:FADE OUT, 2:LOOP END
  int dubMode = 0; // 0:OVERDUB, 1:REPLACE
  int spd = 1; // 0:HALF, 1:NORMAL, 2:DOUBLE
  double pos = 0;

  // Dedicated Per-Track Output Insert Effect (processes this track's recorded audio specifically)
  bool insOn = false;
  int insTy = 9; // Default G2B
  int insT0 = -1;
  List<double> insP = [.6, .5, .6, .75];
  Map insS = {};
}

class Slot {
  int ty;
  bool on = false;
  int t0 = -1;
  int target = 0; // 0: ALL (Tracks with FX button ON), 1..5: Specific Track 1..5 Output Only!
  List<double> p = [.5, .5, .5, .65];
  Map s = {};
  Slot(this.ty);
}

class MI {
  final String n;
  final List<MI>? k;
  final List<String> o;
  final int Function()? g;
  final void Function(int)? s;
  MI(this.n, {this.k, this.o = const [], this.g, this.s});
}

class Eng extends ChangeNotifier {
  final t = List.generate(5, (_) => Trk());
  static List<List<Slot>> _mk(List<int> b, int lim) => List.generate(
    4,
    (k) => List.generate(4, (i) => Slot((b[i] + k * 4) % lim)),
  );
  final banks = {
    'in': _mk([9, 18, 16, 0], 49), // 49 Input FX
    'trk': _mk([50, 52, 49, 26], 53), // 53 Track FX
  };
  final bk = {'in': 0, 'trk': 0};
  String? bankMode;
  Map<String, List<Slot>> get fx => {
    'in': banks['in']![bk['in']!],
    'trk': banks['trk']![bk['trk']!],
  };
  final sel = {'in': 0, 'trk': 0};

  String last = 'in', statusMsg = '';
  int loopMeas = 0; // 0:AUTO, 1:FREE, 2:1BEAT, 3:1BAR..
  int quantize = 1, autoRec = 0;
  int seltrk = 0,
      mlen = 0,
      mpos = 0,
      rpos = 0,
      gi = 0,
      vi = 0,
      ra = 0,
      pm = 0,
      mem = 1;
  int homePage = 0, trkPage = 0, fxPage = 0;
  double bpm = 120, master = .8, rvol = .7, inLvl = 0, mfx = 0;
  bool rh = false,
      flip = false,
      audio = false,
      edit = false,
      fxEdit = false,
      trkEdit = false,
      armedAuto = false,
      showHelp = false;
  String err = '';
  int editUntil = 0, msgUntil = 0;

  final undo = <(int, Float32List)>[], redo = <(int, Float32List)>[];
  final mic = RingBuf();
  final voices = <DrumVoice>[];
  final taps = <int>[];
  final mfxS = {};
  late final List<Float32List> dr;
  final rnd = m.Random(1);
  List<(List<MI>, int)> stack = [];
  Timer? _uiTimer, _demoTimer, _memTimer;

  // Pre-allocated real-time audio buffers (including isolated per-track buffers _trkBuf[0..4])
  Float32List _x = Float32List(512),
      _mix = Float32List(512),
      _md = Float32List(512),
      _tot = Float32List(512),
      _prevTot = Float32List(512);
  List<Float32List> _trkBuf = List.generate(5, (_) => Float32List(512));
  Int16List _out = Int16List(512);

  void flashMsg(String m) {
    statusMsg = m;
    msgUntil = DateTime.now().millisecondsSinceEpoch + 1400;
    notifyListeners();
  }

  int effMeas(Trk tr) => tr.meas == 0 ? loopMeas : tr.meas - 1;
  String effMeasLabel(Trk tr) => loopMeasOpts[effMeas(tr)];

  int fixedTargetSamples(Trk tr) {
    final mMode = effMeas(tr);
    if (mMode < 2) return 0;
    final beats = const [1, 4, 8, 16, 32, 64, 128][mMode - 2];
    return (SR * 60.0 / bpm * beats).round();
  }

  // Permanently print/bake a Track's Insert FX (or active Track FX) into its recorded loop audio
  void printFxToTrack(int ti) {
    final tr = t[ti];
    if (tr.d.isEmpty) {
      flashMsg('TRK ${ti + 1} IS EMPTY');
      return;
    }
    push(ti); // Save current audio to Undo stack first!
    final ty = tr.insOn ? tr.insTy : fx['trk']![sel['trk']!].ty;
    final params = tr.insOn ? tr.insP : fx['trk']![sel['trk']!].p;
    final tempState = <dynamic, dynamic>{};
    final copy = Float32List.fromList(tr.d);
    for (var offset = 0; offset < copy.length; offset += 512) {
      final end = m.min(offset + 512, copy.length);
      final view = Float32List.sublistView(copy, offset, end);
      runFx(ty, view, params, tempState);
    }
    _declick(copy);
    tr.d = copy;
    tr.insOn = false; // Turn off insert after baking so it isn't double-applied
    flashMsg('FX PRINTED TO TRK ${ti + 1}');
  }

  // Quick-target a specific track for Track FX editing
  void targetTrackFx(int trkIdx) {
    last = 'trk';
    fxEdit = true;
    trkEdit = false;
    stack = [];
    final sf = fx['trk']![sel['trk']!];
    sf.target = trkIdx + 1; // 1..5 = TRK 1..5
    sf.on = true;
    t[trkIdx].fx = true;
    flashMsg('TRK FX ${'ABCD'[sel['trk']!]} -> TRK ${trkIdx + 1}');
  }

  // Big INPUT FX / TRACK FX Knobs
  void bigFxKnob(String b, int d) {
    last = b;
    final sf = fx[b]![sel[b]!];
    if (fxEdit && last == b && fxPage == 1) {
      final lim = b == 'in' ? 49 : 53;
      sf.ty = (sf.ty + d) % lim;
      sf.t0 = -1;
    } else {
      sf.p[3] = (sf.p[3] + d * 0.03).clamp(0.0, 1.0);
      editUntil = DateTime.now().millisecondsSinceEpoch + 2200;
    }
    notifyListeners();
  }

  // Under-LCD Knobs 1-4 (Turn & Push-Click)
  void fKnob(int idx, int d) {
    if (fxEdit || DateTime.now().millisecondsSinceEpoch < editUntil) {
      final sf = fx[last]![sel[last]!];
      final lim = last == 'in' ? 49 : 53;
      if (fxEdit && fxPage == 1) {
        if (idx == 0) {
          sf.ty = (sf.ty + d) % lim;
          sf.t0 = -1;
        } else if (idx == 1) {
          if (last == 'trk')
            sf.target = (sf.target + d) % tgtOpts.length;
          else
            sf.on = d > 0;
        } else if (idx == 2)
          bk[last] = (bk[last]! + d) % 4;
        else if (idx == 3)
          sel[last] = (sel[last]! + d) % 4;
      } else {
        sf.p[idx] = (sf.p[idx] + d * 0.025).clamp(0.0, 1.0);
        if (!fxEdit) editUntil = DateTime.now().millisecondsSinceEpoch + 2200;
      }
    } else if (trkEdit) {
      final tr = t[seltrk];
      if (trkPage == 0) {
        if (idx == 0)
          tr.rev = d > 0;
        else if (idx == 1)
          tr.oneShot = d > 0;
        else if (idx == 2)
          tr.pan = (tr.pan + d * 0.05).clamp(-1.0, 1.0);
        else if (idx == 3)
          tr.meas = (tr.meas + d) % measOpts.length;
      } else if (trkPage == 1) {
        if (idx == 0)
          tr.startMode = (tr.startMode + d) % startOpts.length;
        else if (idx == 1)
          tr.stopMode = (tr.stopMode + d) % stopOpts.length;
        else if (idx == 2)
          tr.dubMode = (tr.dubMode + d) % dubOpts.length;
        else if (idx == 3)
          tr.loopSync = d > 0;
      } else if (trkPage == 2) {
        // Page 3: Per-Track Dedicated Output FX & Print FX
        if (idx == 0)
          tr.insOn = d > 0;
        else if (idx == 1) {
          tr.insTy = (tr.insTy + d) % 53;
          tr.insT0 = -1;
        } else if (idx == 2) {
          final v = (tr.insP[3] + d * 0.04).clamp(0.0, 1.0);
          tr.insP[0] = v;
          tr.insP[3] = v;
        } else if (idx == 3)
          tr.fx = d > 0;
      } else {
        if (idx == 0)
          tr.spd = (tr.spd + d) % spdOpts.length;
        else if (idx == 1)
          tr.tempoSync = d > 0;
        else if (idx == 2)
          tr.fx = d > 0;
        else if (idx == 3)
          tr.bnc = d > 0;
      }
    } else if (stack.isNotEmpty) {
      if (idx == 0)
        rotate(d);
      else if (idx == 1) {
        edit = true;
        rotate(d);
        edit = false;
      } else if (idx == 3 && d < 0)
        exit();
    } else {
      if (idx == 0)
        chmem(d);
      else if (idx == 1)
        bpm = (bpm + d * 0.5).clamp(40.0, 300.0);
      else if (idx == 2)
        loopMeas = (loopMeas + d) % loopMeasOpts.length;
      else if (idx == 3)
        mfx = (mfx + d * 0.04).clamp(0.0, 1.0);
    }
    notifyListeners();
  }

  void fKnobPush(int idx) {
    if (trkEdit) {
      final tr = t[seltrk];
      if (trkPage == 0) {
        if (idx == 0)
          tr.rev = !tr.rev;
        else if (idx == 1)
          tr.oneShot = !tr.oneShot;
        else if (idx == 2)
          tr.pan = 0.0;
        else if (idx == 3)
          tr.meas = (tr.meas + 1) % measOpts.length;
      } else if (trkPage == 1) {
        if (idx == 0)
          tr.startMode = (tr.startMode + 1) % startOpts.length;
        else if (idx == 1)
          tr.stopMode = (tr.stopMode + 1) % stopOpts.length;
        else if (idx == 2)
          tr.dubMode = (tr.dubMode + 1) % dubOpts.length;
        else if (idx == 3)
          tr.loopSync = !tr.loopSync;
      } else if (trkPage == 2) {
        if (idx == 0)
          tr.insOn = !tr.insOn;
        else if (idx == 1) {
          tr.insTy = (tr.insTy + 1) % 53;
          tr.insT0 = -1;
        } else if (idx == 2)
          tr.fx = !tr.fx;
        else if (idx == 3)
          printFxToTrack(
            seltrk,
          ); // Push Knob 4 to permanently BAKE/PRINT FX to Track!
      } else {
        if (idx == 0)
          tr.spd = 1;
        else if (idx == 1)
          tr.tempoSync = !tr.tempoSync;
        else if (idx == 2)
          tr.fx = !tr.fx;
        else if (idx == 3)
          tr.bnc = !tr.bnc;
      }
    } else if (fxEdit) {
      fxPage = (fxPage + 1) % 2;
    } else if (stack.isNotEmpty) {
      enter();
    } else {
      if (idx == 2)
        loopMeas = (loopMeas + 1) % loopMeasOpts.length;
      else if (idx == 3)
        toggleRh();
    }
    notifyListeners();
  }

  void toggleEdit(String b) {
    bankMode = null;
    trkEdit = false;
    if (fxEdit && last == b) {
      fxEdit = false;
    } else {
      last = b;
      fxEdit = true;
      fxPage = 0;
      stack = [];
    }
    notifyListeners();
  }

  void selectTrack(int i) {
    if (seltrk == i && trkEdit) {
      trkEdit = false;
    } else {
      seltrk = i;
      trkEdit = true;
      fxEdit = false;
      bankMode = null;
      stack = [];
    }
    notifyListeners();
  }

  // ---- audio io (Android + Linux PipeWire/ALSA Native Bridge)
  static const _ac = MethodChannel('rc505/audio'),
      _mc = EventChannel('rc505/mic');
  Process? _recProc, _playProc;

  Future<void> start() async {
    dr = _drums();
    _uiTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => notifyListeners(),
    );

    if (Platform.isLinux) {
      await _startLinuxAudio();
    } else if (Platform.isWindows) {
      await _startWindowsAudio();
    } else {
      try {
        audio = await _ac.invokeMethod('start') == true;
        if (!audio) err = 'MIC DENIED';
        _mc.receiveBroadcastStream().listen((b) {
          final bytes = b as Uint8List;
          final d = ByteData.sublistView(bytes), n = d.lengthInBytes ~/ 2;
          mic.write(d, n);
          _ac.invokeMethod('play', run(n).buffer.asUint8List());
        });
      } on MissingPluginException {
        err = 'DEMO MODE (NO NATIVE AUDIO)';
      } catch (_) {
        err = 'AUDIO ERROR';
      }
    }

    if (!audio)
      _demoTimer = Timer.periodic(
        const Duration(milliseconds: 11),
        (_) => run(512),
      );
    await load(1);
  }

  Future<void> _startLinuxAudio() async {
    try {
      final hasPw = (await Process.run('which', ['pw-cat'])).exitCode == 0;
      if (hasPw) {
        _recProc = await Process.start('pw-cat', [
          '--record',
          '--raw',
          '--rate',
          '$SR',
          '--channels',
          '1',
          '--format',
          's16',
          '--latency',
          '128',
          '-',
        ]);
        _playProc = await Process.start('pw-cat', [
          '--playback',
          '--raw',
          '--rate',
          '$SR',
          '--channels',
          '1',
          '--format',
          's16',
          '--latency',
          '128',
          '-',
        ]);
      } else {
        _recProc = await Process.start('arecord', [
          '-q',
          '-t',
          'raw',
          '-f',
          'S16_LE',
          '-r',
          '$SR',
          '-c',
          '1',
          '--buffer-size=1024',
          '-',
        ]);
        _playProc = await Process.start('aplay', [
          '-q',
          '-t',
          'raw',
          '-f',
          'S16_LE',
          '-r',
          '$SR',
          '-c',
          '1',
          '--buffer-size=1024',
          '-',
        ]);
      }

      audio = true;
      err = '';
      _playProc!.stdout.drain();
      _playProc!.stderr.drain();
      _recProc!.stderr.drain();

      _recProc!.stdout.listen((chunk) {
        final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        final n = bytes.lengthInBytes ~/ 2;
        if (n == 0) return;
        final d = ByteData.sublistView(bytes);
        mic.write(d, n);
        var rem = n;
        while (rem > 0) {
          final step = m.min(rem, 512);
          final out = run(step);
          _playProc?.stdin.add(
            Uint8List.view(out.buffer, out.offsetInBytes, out.lengthInBytes),
          );
          rem -= step;
        }
      });
    } catch (e) {
      audio = false;
      err = 'LINUX AUDIO ERR: INSTALL PIPEWIRE OR ALSA-UTILS';
    }
  }

  Future<void> _startWindowsAudio() async {
    try {
      // Uses Windows WASAPI / DirectShow via FFmpeg for raw 16-bit 44.1kHz PCM I/O
      _recProc = await Process.start('ffmpeg', [
        '-loglevel',
        'quiet',
        '-fflags',
        'nobuffer',
        '-flags',
        'low_delay',
        '-f',
        'dshow',
        '-audio_buffer_size',
        '20',
        '-i',
        'audio=default',
        '-f',
        's16le',
        '-ar',
        '$SR',
        '-ac',
        '1',
        '-',
      ]);
      _playProc = await Process.start('ffmpeg', [
        '-loglevel',
        'quiet',
        '-fflags',
        'nobuffer',
        '-flags',
        'low_delay',
        '-f',
        's16le',
        '-ar',
        '$SR',
        '-ac',
        '1',
        '-i',
        '-',
        '-f',
        'audiodriver',
        'default',
      ]);

      audio = true;
      err = '';
      _playProc!.stdout.drain();
      _playProc!.stderr.drain();
      _recProc!.stderr.drain();

      _recProc!.stdout.listen((chunk) {
        final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        final n = bytes.lengthInBytes ~/ 2;
        if (n == 0) return;
        mic.write(ByteData.sublistView(bytes), n);
        var rem = n;
        while (rem > 0) {
          final step = m.min(rem, 512);
          final out = run(step);
          _playProc?.stdin.add(
            Uint8List.view(out.buffer, out.offsetInBytes, out.lengthInBytes),
          );
          rem -= step;
        }
      });
    } catch (_) {
      audio = false;
      err = 'WIN AUDIO: INSTALL FFMPEG OR USE C++ CHANNEL';
    }
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _demoTimer?.cancel();
    _memTimer?.cancel();
    _recProc?.kill();
    _playProc?.kill();
    super.dispose();
  }

  List<Float32List> _drums() {
    final k = Float32List((SR * .25).toInt()),
        s = Float32List((SR * .2).toInt()),
        h = Float32List((SR * .06).toInt());
    var ph = 0.0, pr = 0.0;
    for (var i = 0; i < k.length; i++) {
      final x = i / SR;
      ph += 2 * m.pi * (45 + 115 * m.exp(-x * 26)) / SR;
      k[i] = m.sin(ph) * m.exp(-x * 12) * .92;
    }
    for (var i = 0; i < s.length; i++) {
      final x = i / SR;
      s[i] =
          (rnd.nextDouble() * 2 - 1) * m.exp(-x * 22) * .45 +
          m.sin(2 * m.pi * 185 * x) * m.exp(-x * 30) * .42;
    }
    for (var i = 0; i < h.length; i++) {
      final x = i / SR, n = rnd.nextDouble() * 2 - 1;
      h[i] = (n - pr) * m.exp(-x * 90) * .32;
      pr = n;
    }
    return [k, s, h];
  }

  void chainIn(Float32List x) {
    for (final f in fx['in']!) {
      if (f.on) {
        if (f.ty != f.t0) {
          f.s = {};
          f.t0 = f.ty;
        }
        runFx(f.ty, x, f.p, f.s);
      }
    }
  }

  void chainTrkTarget(int target, Float32List x) {
    for (final f in fx['trk']!) {
      if (f.on && f.target == target) {
        if (f.ty != f.t0) {
          f.s = {};
          f.t0 = f.ty;
        }
        runFx(f.ty, x, f.p, f.s);
      }
    }
  }

  void push(int i) {
    final snap = t[i].markD ?? t[i].d;
    undo.add((i, Float32List.fromList(snap)));
    redo.clear();
    flip = false;
    if (undo.length > 20) undo.removeAt(0);
  }

  void markBack({bool revertBase = false}) {
    final tr = t[seltrk];
    if (tr.d.isEmpty) return;
    if (revertBase && tr.baseD != null) {
      tr.d = Float32List.fromList(tr.baseD!);
      flashMsg('TRK ${seltrk + 1} BASE RESTORED');
    } else {
      tr.markD = Float32List.fromList(tr.d);
      flashMsg('MARK SET TRK ${seltrk + 1}');
    }
  }

  void single(int i) {
    if (pm == 1) {
      for (var j = 0; j < 5; j++) {
        if (j != i && (t[j].st == S.play || t[j].st == S.dub)) t[j].st = S.stop;
      }
    }
  }

  void _declick(Float32List d) {
    const fade = 64;
    if (d.length < fade * 2) return;
    for (var i = 0; i < fade; i++) {
      final w = i / fade;
      d[i] *= w;
      d[d.length - 1 - i] *= w;
    }
  }

  void finish(int i) {
    final tr = t[i];
    final rawLen = tr.buf.fold(0, (a, b) => a + b.length);
    if (rawLen == 0) {
      tr.st = S.empty;
      return;
    }
    final d = Float32List(rawLen);
    var o = 0;
    for (final b in tr.buf) {
      d.setRange(o, o + b.length, b);
      o += b.length;
    }

    final mMode = effMeas(tr);
    int targetLen = rawLen;

    if (mMode == 1) {
      targetLen = rawLen;
    } else if (mMode >= 2) {
      targetLen = fixedTargetSamples(tr);
      if (mlen == 0) {
        mlen = targetLen;
        mpos = 0;
        rpos = 0;
      }
    } else {
      if (mlen == 0) {
        if (rh && quantize == 1) {
          final barSamples = (SR * 240.0 / bpm).round();
          final bars = m.max(1, (rawLen / barSamples).round());
          targetLen = bars * barSamples;
        } else {
          targetLen = rawLen;
          var b = 240.0 * SR / targetLen;
          while (b > 160) b /= 2;
          while (b < 70) b *= 2;
          bpm = b;
        }
        mlen = targetLen;
        mpos = 0;
        rpos = 0;
      } else {
        final mult = m.max(1, (rawLen / mlen).round());
        targetLen = mlen * mult;
      }
    }

    final aligned = Float32List(targetLen);
    aligned.setRange(0, m.min(targetLen, rawLen), d);
    _declick(aligned);
    tr.d = aligned;
    tr.baseD = Float32List.fromList(aligned);
    tr.markD = null;
    tr.buf = [];
    tr.pos = 0;
    tr.env = 1.0;
    tr.st = ra == 1 ? S.dub : S.play;
    single(i);
    flashMsg(
      'T${i + 1} ${effMeasLabel(tr)} (${(targetLen / SR).toStringAsFixed(1)}s)',
    );
  }

  void press(int i) {
    final tr = t[i];
    seltrk = i;
    switch (tr.st) {
      case S.empty:
        push(i);
        tr.buf = [];
        if (autoRec == 1 && !armedAuto) {
          armedAuto = true;
          tr.st = S.wait;
          flashMsg('AUTO-REC ARMED');
        } else {
          final syncWait =
              tr.loopSync && mlen > 0 && effMeas(tr) != 1 && quantize == 1;
          tr.st = syncWait ? S.wait : S.rec;
        }
        single(i);
      case S.rec:
        if (tr.buf.isNotEmpty) finish(i);
      case S.wait:
        tr.st = S.empty;
        armedAuto = false;
      case S.play:
        if (tr.oneShot) {
          tr.pos = 0;
          tr.env = 1.0;
        } else {
          push(i);
          tr.st = S.dub;
        }
      case S.dub:
        _declick(tr.d);
        tr.st = S.play;
      case S.stop:
      case S.stopping:
        tr.pos = tr.loopSync && mlen > 0 && tr.d.isNotEmpty
            ? (mpos % tr.d.length).toDouble()
            : 0.0;
        tr.env = tr.startMode == 1 ? 0.0 : 1.0;
        tr.st = S.play;
        single(i);
    }
    notifyListeners();
  }

  void stop(int i) {
    final tr = t[i];
    if (tr.st == S.play || tr.st == S.dub) {
      if (tr.stopMode == 0) {
        tr.st = tr.d.isNotEmpty ? S.stop : S.empty;
      } else {
        tr.st = S.stopping;
      }
    } else if (tr.st == S.wait || (tr.st == S.rec && mlen > 0)) {
      tr.st = tr.d.isNotEmpty ? S.stop : S.empty;
      armedAuto = false;
    } else if (tr.st == S.rec) {
      tr.st = S.empty;
      tr.buf = [];
    } else if (tr.st == S.stopping) {
      tr.st = S.stop;
    }
    notifyListeners();
  }

  void clear(int i) {
    t[i].d = Float32List(0);
    t[i].baseD = null;
    t[i].markD = null;
    t[i].st = S.empty;
    t[i].buf = [];
    t[i].pos = 0;
    if (t.every((q) => q.st == S.empty)) {
      mlen = 0;
      mpos = 0;
    }
    flashMsg('TRACK ${i + 1} CLEARED');
  }

  void clearAll() {
    for (var i = 0; i < 5; i++) {
      t[i].d = Float32List(0);
      t[i].baseD = null;
      t[i].markD = null;
      t[i].st = S.empty;
      t[i].buf = [];
      t[i].pos = 0;
    }
    undo.clear();
    redo.clear();
    flip = false;
    mlen = 0;
    mpos = 0;
    flashMsg('ALL CLEARED');
  }

  void allss() {
    if (t.any((x) => x.st == S.play || x.st == S.dub || x.st == S.rec)) {
      for (var i = 0; i < 5; i++) {
        if (t[i].st == S.play || t[i].st == S.dub) stop(i);
      }
    } else {
      for (final x in t) {
        if (x.st == S.stop || x.st == S.stopping) {
          x.pos = 0;
          x.env = x.startMode == 1 ? 0.0 : 1.0;
          x.st = S.play;
        }
      }
    }
    notifyListeners();
  }

  void _sw(
    List<(int, Float32List)> a,
    List<(int, Float32List)> b,
    String label,
  ) {
    final (i, d) = a.removeLast();
    b.add((i, Float32List.fromList(t[i].d)));
    t[i].d = d;
    t[i].st = d.isNotEmpty ? S.play : S.empty;
    flashMsg('$label TRK ${i + 1}');
  }

  void ur() {
    if (flip && redo.isNotEmpty) {
      _sw(redo, undo, 'REDO');
      flip = false;
    } else if (undo.isNotEmpty) {
      _sw(undo, redo, 'UNDO');
      flip = true;
    }
  }

  void tap() {
    final n = DateTime.now().millisecondsSinceEpoch;
    taps.removeWhere((x) => n - x > 2500);
    taps.add(n);
    if (taps.length > 1) {
      bpm = (60000 / ((taps.last - taps.first) / (taps.length - 1)))
          .clamp(40, 300)
          .toDouble();
      flashMsg('TEMPO ${bpm.toStringAsFixed(1)}');
    }
  }

  void toggleRh() {
    rh = !rh;
    rpos = 0;
    notifyListeners();
  }

  void fxpress(String b, int i) {
    if (bankMode == b) {
      bk[b] = i;
      bankMode = null;
      sel[b] = 0;
      last = b;
      notifyListeners();
      return;
    }
    if (fxEdit && last == b) {
      sel[b] = i;
      notifyListeners();
      return;
    }
    fx[b]![i].on = !fx[b]![i].on;
    sel[b] = i;
    last = b;
    notifyListeners();
  }

  void holdEdit(String b) {
    fxEdit = false;
    trkEdit = false;
    stack = [];
    bankMode = b;
    last = b;
    notifyListeners();
  }

  Future<File> _f(int k) async => File(
    '${Directory.systemTemp.path}/rc505_m${k.toString().padLeft(2, '0')}.bin',
  );
  Future<void> save(int k) async {
    final h = ByteData(32);
    h.setFloat64(0, bpm);
    h.setInt32(8, loopMeas);
    for (var i = 0; i < 5; i++) h.setInt32(12 + i * 4, t[i].d.length);
    final b = BytesBuilder()..add(h.buffer.asUint8List());
    for (final x in t)
      b.add(x.d.buffer.asUint8List(x.d.offsetInBytes, x.d.lengthInBytes));
    await (await _f(k)).writeAsBytes(b.takeBytes());
    flashMsg('MEMORY ${k.toString().padLeft(2, '0')} SAVED');
  }

  Future<void> load(int k) async {
    for (var i = 0; i < 5; i++) {
      t[i].d = Float32List(0);
      t[i].st = S.empty;
      t[i].buf = [];
    }
    undo.clear();
    redo.clear();
    mlen = 0;
    mpos = 0;
    final f = await _f(k);
    if (!await f.exists()) return;
    final by = await f.readAsBytes();
    if (by.length < 32) return;
    final h = ByteData.sublistView(by);
    bpm = h.getFloat64(0);
    loopMeas = h.getInt32(8).clamp(0, loopMeasOpts.length - 1);
    var o = 32;
    for (var i = 0; i < 5; i++) {
      final n = h.getInt32(12 + i * 4);
      if (n > 0 && by.length >= o + n * 4) {
        t[i].d = Float32List.fromList(
          Float32List.view(by.buffer, by.offsetInBytes + o, n),
        );
        t[i].baseD = Float32List.fromList(t[i].d);
        t[i].st = S.stop;
        if (mlen == 0) mlen = n;
      }
      o += n * 4;
    }
    notifyListeners();
  }

  void chmem(int d) {
    final prev = mem;
    mem = (mem - 1 + d) % 99 + 1;
    _memTimer?.cancel();
    _memTimer = Timer(const Duration(milliseconds: 280), () async {
      await save(prev);
      await load(mem);
    });
    notifyListeners();
  }

  List<MI> fxm(String b) {
    final names = fxSpecs.take(b == 'in' ? 49 : 53).map((e) => e.name).toList();
    return List.generate(
      4,
      (i) => MI(
        'FX ${'ABCD'[i]}',
        o: names,
        g: () => fx[b]![i].ty,
        s: (v) {
          fx[b]![i].ty = v;
          fx[b]![i].t0 = -1;
        },
      ),
    );
  }

  late final menu = <MI>[
    MI(
      'LOOP / REC',
      k: [
        MI(
          'MEASURE',
          o: loopMeasOpts,
          g: () => loopMeas,
          s: (i) => loopMeas = i,
        ),
        MI(
          'REC ACTION',
          o: ['REC->PLAY', 'REC->DUB'],
          g: () => ra,
          s: (i) => ra = i,
        ),
        MI(
          'QUANTIZE',
          o: ['OFF', 'MEASURE'],
          g: () => quantize,
          s: (i) => quantize = i,
        ),
        MI(
          'AUTO REC',
          o: ['OFF', 'ON'],
          g: () => autoRec,
          s: (i) => autoRec = i,
        ),
        MI('PLAY MODE', o: ['MULTI', 'SINGLE'], g: () => pm, s: (i) => pm = i),
      ],
    ),
    MI('INPUT FX', k: fxm('in')),
    MI('TRACK FX', k: fxm('trk')),
    MI(
      'RHYTHM',
      k: [
        MI('GENRE', o: PAT.keys.toList(), g: () => gi, s: (i) => gi = i),
        MI('VARIATION', o: ['A', 'B'], g: () => vi, s: (i) => vi = i),
        MI(
          'LEVEL',
          o: List.generate(11, (i) => '${i * 10}'),
          g: () => (rvol * 10).round(),
          s: (i) => rvol = i / 10,
        ),
      ],
    ),
    MI(
      'MEMORY',
      k: [
        MI(
          'WRITE',
          o: ['CANCEL', 'EXEC'],
          g: () => 0,
          s: (i) {
            if (i == 1) save(mem);
          },
        ),
        MI(
          'CLEAR ALL',
          o: ['CANCEL', 'EXEC'],
          g: () => 0,
          s: (i) {
            if (i == 1) clearAll();
          },
        ),
      ],
    ),
  ];

  void openMenu() {
    stack = [(menu, 0)];
    edit = false;
    fxEdit = false;
    trkEdit = false;
    notifyListeners();
  }

  void jump(int k) {
    stack = [(menu, k)];
    edit = false;
    fxEdit = false;
    trkEdit = false;
    enter();
  }

  void exit() {
    if (showHelp) {
      showHelp = false;
      notifyListeners();
      return;
    }
    if (bankMode != null) {
      bankMode = null;
      notifyListeners();
      return;
    }
    if (fxEdit) {
      fxEdit = false;
      notifyListeners();
      return;
    }
    if (trkEdit) {
      trkEdit = false;
      notifyListeners();
      return;
    }
    if (edit)
      edit = false;
    else if (stack.isNotEmpty)
      stack.removeLast();
    notifyListeners();
  }

  void enter() {
    if (stack.isEmpty) {
      homePage = (homePage + 1) % 2;
      notifyListeners();
      return;
    }
    final (it, c) = stack.last;
    final x = it[c];
    if (x.k != null)
      stack.add((x.k!, 0));
    else
      edit = !edit;
    notifyListeners();
  }

  void rotate(int d) {
    if (stack.isEmpty) {
      bpm = (bpm + d).clamp(40, 300).toDouble();
      notifyListeners();
      return;
    }
    final (it, c) = stack.last;
    final x = it[c];
    if (edit)
      x.s!((x.g!() + d) % x.o.length);
    else
      stack[stack.length - 1] = (it, (c + d) % it.length);
    notifyListeners();
  }

  void pageBtn(int d) {
    if (trkEdit)
      trkPage = (trkPage + d) % 4;
    else if (fxEdit)
      fxPage = (fxPage + d) % 2;
    else if (stack.isNotEmpty)
      rotate(d);
    else
      homePage = (homePage + d) % 2;
    notifyListeners();
  }

  // ---- zero-allocation realtime DSP block with per-track isolated FX routing
  Int16List run(int n) {
    if (_x.length != n) {
      _x = Float32List(n);
      _mix = Float32List(n);
      _md = Float32List(n);
      _tot = Float32List(n);
      _prevTot = Float32List(n);
      _out = Int16List(n);
      _trkBuf = List.generate(5, (_) => Float32List(n));
    } else {
      _mix.fillRange(0, n, 0.0);
      _md.fillRange(0, n, 0.0);
    }

    var mx = 0.0;
    for (var i = 0; i < n; i++) {
      final s = mic.read();
      _x[i] = s;
      if (s.abs() > mx) mx = s.abs();
    }
    inLvl = inLvl * 0.82 + mx * 0.18;
    chainIn(_x);

    final ph = mlen > 0 ? mpos % mlen : 0;
    for (var ti = 0; ti < 5; ti++) {
      final tr = t[ti];
      final tb = _trkBuf[ti];
      tb.fillRange(0, n, 0.0);
      var st = tr.st;

      if (st == S.wait) {
        if (armedAuto && mx > 0.035) {
          armedAuto = false;
          tr.buf = [Float32List.fromList(_x)];
          tr.st = st = S.rec;
        } else if (!armedAuto && mlen > 0 && ph + n >= mlen) {
          tr.buf = [Float32List.fromList(_x.sublist(mlen - ph))];
          tr.st = st = S.rec;
        }
      } else if (st == S.rec) {
        if (tr.bnc) {
          final bncBuf = Float32List(n);
          for (var i = 0; i < n; i++)
            bncBuf[i] = (_x[i] + _prevTot[i]).clamp(-1.0, 1.0);
          tr.buf.add(bncBuf);
        } else {
          tr.buf.add(Float32List.fromList(_x));
        }
        final curRecLen = tr.buf.fold(0, (a, b) => a + b.length);
        final fixedLim = fixedTargetSamples(tr);
        if (fixedLim > 0 && curRecLen >= fixedLim) {
          finish(ti);
        } else if (effMeas(tr) == 0 &&
            mlen > 0 &&
            curRecLen >= mlen &&
            quantize == 1) {
          finish(ti);
        }
      }

      if ((st == S.play || st == S.dub || st == S.stopping) &&
          tr.d.isNotEmpty) {
        final d = tr.d, L = d.length;
        final step = tr.spd == 0 ? 0.5 : (tr.spd == 2 ? 2.0 : 1.0);

        for (var k = 0; k < n; k++) {
          if (st == S.stopping && tr.stopMode == 1) {
            tr.env -= 1.0 / (SR * 1.5);
            if (tr.env <= 0) {
              tr.env = 0;
              tr.st = S.stop;
              break;
            }
          } else if (st != S.stopping && tr.env < 1.0) {
            tr.env = m.min(1.0, tr.env + 1.0 / (SR * 1.2));
          }

          int rawIdx;
          if (tr.oneShot || !tr.loopSync || effMeas(tr) == 1 || tr.spd != 1) {
            rawIdx = tr.pos.toInt();
            tr.pos += step;
            if (rawIdx >= L) {
              if (tr.oneShot || (st == S.stopping && tr.stopMode == 2)) {
                tr.st = S.stop;
                tr.pos = 0;
                break;
              }
              tr.pos %= L;
              rawIdx %= L;
            }
          } else {
            rawIdx = (mpos + k) % L;
            if (st == S.stopping && tr.stopMode == 2 && rawIdx == L - 1) {
              tr.st = S.stop;
              break;
            }
          }

          final j = tr.rev ? (L - 1 - (rawIdx % L)) : (rawIdx % L);
          if (st == S.dub) {
            final inSig = tr.bnc ? (_x[k] + _prevTot[k]) : _x[k];
            d[j] = (tr.dubMode == 1 ? inSig : (d[j] + inSig)).clamp(-1.0, 1.0);
          }
          tb[k] = d[j] * tr.vol * tr.env;
        }

        // 1. Apply Dedicated Per-Track Output Insert FX if enabled on this track
        if (tr.insOn) {
          if (tr.insTy != tr.insT0) {
            tr.insS = {};
            tr.insT0 = tr.insTy;
          }
          runFx(tr.insTy, tb, tr.insP, tr.insS);
        }

        // 2. Apply any Track FX Slot (A-D) specifically targeting THIS track (target == ti + 1)
        if (tr.fx) {
          chainTrkTarget(ti + 1, tb);
        }

        // 3. Measure post-FX track level and route to Track FX ALL bus (_mix) or Dry bus (_md)
        var pk = 0.0;
        final dst = tr.fx ? _mix : _md;
        for (var k = 0; k < n; k++) {
          final v = tb[k];
          dst[k] += v;
          if (v.abs() > pk) pk = v.abs();
        }
        tr.lvl = tr.lvl * 0.8 + pk * 0.2;
      } else {
        tr.lvl *= 0.85;
      }
    }

    if (mlen > 0 && t.every((q) => q.st == S.empty)) {
      mlen = 0;
      mpos = 0;
    }
    if (mlen > 0) {
      mpos =
          t.any(
            (q) =>
                q.st == S.play ||
                q.st == S.dub ||
                q.st == S.wait ||
                q.st == S.stopping,
          )
          ? (mpos + n) % (mlen * 64)
          : 0;
    }

    // 4. Apply Track FX Slots (A-D) targeting ALL (target == 0) to the shared FX bus
    chainTrkTarget(0, _mix);

    if (rh) {
      final sl = SR * 60 / bpm / 4,
          p0 = rpos,
          p1 = p0 + n,
          pat = PAT[PAT.keys.elementAt(gi)]![vi];
      for (var k = (p0 / sl).ceil(); k < (p1 / sl).ceil(); k++) {
        for (var j = 0; j < 3; j++) {
          if (pat[j][k % 16] == 'x')
            voices.add(DrumVoice(dr[j], (k * sl).floor() - p0));
        }
      }
      rpos = p1;
      for (final v in voices) {
        final s = v.sample,
            a = m.max(v.offset, 0),
            c = v.cursor,
            mm = m.min(n - a, s.length - c);
        for (var i = 0; i < mm; i++) _md[a + i] += s[c + i] * rvol;
        if (mm > 0) v.cursor = c + mm;
        v.offset = 0;
      }
      voices.removeWhere((v) => v.cursor >= v.sample.length);
    }

    for (var i = 0; i < n; i++) {
      _tot[i] = _mix[i] + _md[i];
      _prevTot[i] = _mix[i];
    }
    if (mfx > .01) runFx(46, _tot, [.7, .5, .5, mfx], mfxS);
    for (var i = 0; i < n; i++)
      _out[i] = ((_tot[i] * master).clamp(-1.0, 1.0) * 32767).toInt();
    return _out;
  }
}

// ---------------- Authentic RC-505mkII Hardware Widgets ----------------
Color c8(int v) => Color(v);

class Btn extends StatefulWidget {
  final String t;
  final double w, h;
  final String kind;
  final Color col;
  final bool lit;
  final VoidCallback? down, tap, hold;
  const Btn(
    this.t,
    this.w,
    this.h, {
    this.kind = 'pill',
    this.col = Colors.white,
    this.lit = false,
    this.down,
    this.tap,
    this.hold,
    super.key,
  });
  @override
  State<Btn> createState() => _B();
}

class _B extends State<Btn> {
  bool dn = false, held = false;
  Timer? ht;
  @override
  void dispose() {
    ht?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final w = widget, on = w.lit || dn;
    final isRound = w.kind == 'round' || w.kind == 'stop' || w.kind == 'fxpad';
    return Listener(
      onPointerDown: (_) {
        setState(() => dn = true);
        held = false;
        HapticFeedback.selectionClick();
        w.down?.call();
        if (w.hold != null)
          ht = Timer(const Duration(milliseconds: 600), () {
            held = true;
            w.hold!();
          });
      },
      onPointerUp: (_) {
        ht?.cancel();
        if (mounted) setState(() => dn = false);
        if (!held) w.tap?.call();
      },
      onPointerCancel: (_) {
        ht?.cancel();
        if (mounted) setState(() => dn = false);
      },
      child: Container(
        width: w.w,
        height: w.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: isRound ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isRound
              ? null
              : BorderRadius.circular(w.kind == 'rect' ? 4 : w.h / 2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dn
                ? [c8(0xFF0E0E10), c8(0xFF161618)]
                : [c8(0xFF34343A), c8(0xFF17171B)],
          ),
          border: Border.all(
            color: on
                ? w.col
                : (w.kind == 'fxpad' ? c8(0xFF662838) : c8(0xFF4C4C54)),
            width: on ? 2.5 : (isRound ? 2.0 : 1.3),
          ),
          boxShadow: on
              ? [
                  BoxShadow(
                    color: w.col.withAlpha(135),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: w.kind == 'stop'
            ? Container(
                width: w.h * .30,
                height: w.h * .30,
                decoration: BoxDecoration(
                  color: on ? Colors.white : c8(0xFFB8B8C0),
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : Text(
                w.t,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: on ? Colors.white : c8(0xFFD8D8DE),
                  fontSize: w.kind == 'fxpad'
                      ? 13
                      : (w.h < 24 ? 7.2 : (w.h < 30 ? 8.2 : 9.2)),
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
      ),
    );
  }
}

class Knob extends StatefulWidget {
  final double size, val;
  final bool endless, silverRim;
  final ValueChanged<double>? ch;
  final ValueChanged<int>? step;
  final VoidCallback? tap;
  const Knob(
    this.size, {
    this.val = .5,
    this.endless = false,
    this.silverRim = false,
    this.ch,
    this.step,
    this.tap,
    super.key,
  });
  @override
  State<Knob> createState() => _K();
}

class _K extends State<Knob> {
  double v = 0, acc = 0;
  @override
  Widget build(BuildContext c) {
    final w = widget;
    return GestureDetector(
      onTap: w.tap,
      onPanUpdate: (d) {
        if (w.endless) {
          acc -= d.delta.dy;
          while (acc.abs() >= 7) {
            final k = acc > 0 ? 1 : -1;
            acc -= 7 * k;
            v = (v + .05 * k) % 1;
            w.step?.call(k);
          }
          setState(() {});
        } else {
          w.ch?.call((w.val - d.delta.dy / 140).clamp(0.0, 1.0));
        }
      },
      child: CustomPaint(
        size: Size(w.size + 8, w.size + 8),
        painter: _KP(w.endless ? v : w.val, w.size, w.endless, w.silverRim),
      ),
    );
  }
}

class _KP extends CustomPainter {
  final double v, sz;
  final bool end, silverRim;
  _KP(this.v, this.sz, this.end, this.silverRim);
  @override
  void paint(Canvas c, Size z) {
    final o = Offset(4 + sz / 2, 4 + sz / 2);
    c.drawCircle(o.translate(0, 2.5), sz / 2, Paint()..color = Colors.black54);
    if (silverRim) {
      c.drawCircle(
        o,
        sz / 2,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD8D8E0), Color(0xFF686870), Color(0xFFB8B8C0)],
          ).createShader(Rect.fromCircle(center: o, radius: sz / 2)),
      );
      c.drawCircle(
        o,
        sz * 0.39,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.3, -.4),
            colors: [c8(0xFF38383E), c8(0xFF0A0A0D)],
          ).createShader(Rect.fromCircle(center: o, radius: sz * 0.39)),
      );
    } else {
      c.drawCircle(
        o,
        sz / 2,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.3, -.4),
            colors: [c8(0xFF4C4C52), c8(0xFF0A0A0D)],
          ).createShader(Rect.fromCircle(center: o, radius: sz / 2)),
      );
      c.drawCircle(
        o,
        sz / 2,
        Paint()
          ..color = c8(0xFF28282C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
    final a = end ? (90 - 360 * v) * m.pi / 180 : (225 - 270 * v) * m.pi / 180,
        d = Offset(m.cos(a), -m.sin(a));
    c.drawLine(
      o + d * sz * .16,
      o + d * sz * (silverRim ? .36 : .43),
      Paint()
        ..color = c8(0xFFF4F4F4)
        ..strokeWidth = m.max(2, sz / 12)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_KP o) => o.v != v;
}

class Fader extends StatelessWidget {
  final double val, lvl;
  final ValueChanged<double> ch;
  const Fader(this.val, this.lvl, this.ch, {super.key});
  @override
  Widget build(BuildContext c) {
    void mv(Offset p) => ch(((150 - p.dy) / 134).clamp(0.0, 1.0));
    return GestureDetector(
      onPanDown: (d) => mv(d.localPosition),
      onPanUpdate: (d) => mv(d.localPosition),
      child: CustomPaint(size: const Size(64, 170), painter: _FP(val, lvl)),
    );
  }
}

class _FP extends CustomPainter {
  final double v, lvl;
  _FP(this.v, this.lvl);
  @override
  void paint(Canvas c, Size z) {
    for (var i = 0; i <= 10; i++) {
      final ty = 16.0 + i * 13.4;
      final w = i % 5 == 0 ? 1.6 : 0.9;
      final col = i % 5 == 0 ? c8(0xFF909098) : c8(0xFF55555C);
      c.drawLine(
        Offset(6, ty),
        Offset(18, ty),
        Paint()
          ..color = col
          ..strokeWidth = w,
      );
      c.drawLine(
        Offset(34, ty),
        Offset(46, ty),
        Paint()
          ..color = col
          ..strokeWidth = w,
      );
    }
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(22, 6, 8, 158),
        const Radius.circular(3),
      ),
      Paint()..color = c8(0xFF040405),
    );
    for (var s = 0; s < 8; s++) {
      final sy = 148.0 - s * 17.5;
      final lit = lvl > (s + 0.4) / 8.0;
      final col = s >= 7 ? red : (s >= 5 ? orange : green);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(52, sy, 4.5, 11),
          const Radius.circular(1),
        ),
        Paint()..color = lit ? col : c8(0xFF151519),
      );
    }
    final y = 150 - v * 134,
        r = RRect.fromRectAndRadius(
          Rect.fromLTWH(7, y - 13, 38, 26),
          const Radius.circular(3),
        );
    c.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF626268), Color(0xFF1C1C20), Color(0xFF525258)],
        ).createShader(r.outerRect),
    );
    c.drawRRect(
      r,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    c.drawLine(
      Offset(10, y),
      Offset(42, y),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.4,
    );
  }

  @override
  bool shouldRepaint(_FP o) => o.v != v || (o.lvl - lvl).abs() > 0.01;
}

class TrackPad extends StatefulWidget {
  final Trk tr;
  final double pos;
  final VoidCallback down;
  const TrackPad(this.tr, this.pos, this.down, {super.key});
  @override
  State<TrackPad> createState() => _TP();
}

class _TP extends State<TrackPad> {
  bool dn = false;
  @override
  Widget build(BuildContext c) => Listener(
    onPointerDown: (_) {
      setState(() => dn = true);
      HapticFeedback.mediumImpact();
      widget.down();
    },
    onPointerUp: (_) => setState(() => dn = false),
    onPointerCancel: (_) => setState(() => dn = false),
    child: CustomPaint(
      size: const Size(134, 134),
      painter: _TPP(
        widget.tr.st,
        widget.pos,
        dn,
        widget.tr.rev,
        widget.tr.oneShot,
      ),
    ),
  );
}

class _TPP extends CustomPainter {
  final S st;
  final double pos;
  final bool dn, rev, oneShot;
  _TPP(this.st, this.pos, this.dn, this.rev, this.oneShot);
  @override
  void paint(Canvas c, Size z) {
    const o = Offset(67, 67);
    final bl = (DateTime.now().millisecondsSinceEpoch ~/ 200) % 2 == 1;
    final act = st == S.play || st == S.dub || st == S.rec || st == S.stopping;
    c.drawCircle(o, 65, Paint()..color = c8(0xFF050506));
    final oc = (st == S.play || st == S.stopping)
        ? (oneShot ? cyan : green)
        : st == S.dub
        ? orange
        : red;
    final pUse = rev ? (1.0 - pos) % 1.0 : pos;

    for (var k = 0; k < 40; k++) {
      final f = k / 40;
      int a;
      if (act)
        a = (st == S.rec || ((pUse - f) % 1) < .15) ? 255 : 95;
      else if (st == S.wait)
        a = bl ? 255 : 40;
      else
        a = st == S.empty ? 85 : 45;
      c.drawArc(
        const Rect.fromLTWH(10, 10, 114, 114),
        (-90 + f * 360 + 3) * m.pi / 180,
        6.5 * m.pi / 180,
        false,
        Paint()
          ..color = oc.withAlpha(a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.5,
      );
    }
    final ic = {
      S.empty: c8(0xFF283038),
      S.stop: c8(0xFF1E8A45),
      S.play: oneShot ? cyan : green,
      S.stopping: bl ? green : c8(0xFF1E8A45),
      S.rec: red,
      S.dub: orange,
      S.wait: bl ? red : c8(0xFF4A1010),
    }[st]!;
    final r = dn ? 37.0 : 39.0;
    if (act || dn)
      c.drawCircle(o, r + 9, Paint()..color = ic.withAlpha(dn ? 110 : 60));
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [dn ? c8(0xFF0D0D0F) : c8(0xFF2C2C32), c8(0xFF0A0A0C)],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
    c.drawCircle(
      o,
      r,
      Paint()
        ..color = ic
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    c.drawPath(
      Path()
        ..moveTo(49, 52)
        ..lineTo(49, 82)
        ..lineTo(71, 67)
        ..close(),
      Paint()..color = ic,
    );
    c.drawCircle(const Offset(83, 73), 6.5, Paint()..color = ic);
  }

  @override
  bool shouldRepaint(_TPP o) => true;
}

void tx(
  Canvas c,
  String s,
  double x,
  double y,
  double sz,
  Color col, [
  FontWeight fw = FontWeight.w900,
]) {
  (TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        color: col,
        fontSize: sz,
        fontWeight: fw,
        letterSpacing: 0.3,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout()).paint(c, Offset(x, y - sz));
}

class Chassis extends CustomPainter {
  final double wd;
  Chassis(this.wd);
  @override
  void paint(Canvas c, Size z) {
    final k = wd / 1020, tr = Rect.fromLTWH(0, 0, wd, 214);
    c.drawRect(Offset.zero & z, Paint()..color = c8(0xFF08080A));
    c.drawRect(
      tr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF222226), Color(0xFF0E0E11)],
        ).createShader(tr),
    );
    c.drawRect(Rect.fromLTWH(0, 214, wd, 2.5), Paint()..color = c8(0xFF707078));

    final inRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(20 * k, 18, 206 * k, 188),
      const Radius.circular(6),
    );
    final trkRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(794 * k, 18, 206 * k, 188),
      const Radius.circular(6),
    );
    c.drawRRect(
      inRect,
      Paint()
        ..color = c8(0xFF3A3A42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    c.drawRRect(
      trkRect,
      Paint()
        ..color = c8(0xFF3A3A42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    tx(c, 'INPUT FX', 32 * k, 140, 10.5, red);
    tx(c, 'FX BANK: HOLD', 112 * k, 130, 6.5, c8(0xFF9898A0));
    tx(c, 'TRACK FX', 918 * k, 140, 10.5, red);
    tx(c, 'FX BANK: HOLD', 816 * k, 130, 6.5, c8(0xFF9898A0));

    tx(c, 'BOSS', 324 * k, 24, 13, Colors.white);
    tx(c, 'RC-505mkII  LOOP STATION', 402 * k, 24, 10.5, c8(0xFFD8D8E0));
    tx(c, 'OUTPUT LEVEL', 732 * k, 40, 6.8, c8(0xFFCCCCCC));
    tx(c, 'PUSH: ENTER   [H]: KEYS', 455 * k, 206, 6.5, c8(0xFF9898A0));
    for (var i = 0; i < 4; i++) {
      tx(c, '${i + 1}', (425 + i * 54) * k, 152, 8.5, c8(0xFFCCCCCC));
    }

    for (var i = 0; i < 5; i++) {
      final cx = (22.0 + i * 196) * k,
          r = RRect.fromRectAndRadius(
            Rect.fromLTWH(cx, 224, 188 * k, 338),
            const Radius.circular(8),
          );
      c.drawRRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF242429), Color(0xFF101013)],
          ).createShader(r.outerRect),
      );
      c.drawRRect(
        r,
        Paint()
          ..color = c8(0xFF383840)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );

      final badge = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 12, 392, 24, 24),
        const Radius.circular(4),
      );
      c.drawRRect(badge, Paint()..color = c8(0xFFDDDDDF));
      tx(c, '${i + 1}', cx + 19, 410, 15, c8(0xFF101013));
      tx(c, 'CLEAR: HOLD', cx + 22 + (k - 1) * 92, 384, 6.8, c8(0xFF9898A0));
    }
  }

  @override
  bool shouldRepaint(Chassis o) => o.wd != wd;
}

Widget P(double x, double y, Widget c) => Positioned(left: x, top: y, child: c);

class Unit extends StatelessWidget {
  final Eng e;
  final double wd;
  const Unit(this.e, {this.wd = 1020, super.key});

  Widget lcd([double w = 216, double h = 108]) {
    const ink = Color(0xFF081016),
        bg = Color(0xFFDCE6EE),
        hi = Color(0xFFB4C4D0);
    TextStyle ts(double s) => TextStyle(
      color: ink,
      fontSize: s,
      fontWeight: FontWeight.w900,
      fontFamily: 'monospace',
      decoration: TextDecoration.none,
    );

    Widget fBar(List<String> labels) => Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 2 : 0),
                padding: const EdgeInsets.symmetric(vertical: 2),
                color: ink,
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: ts(6.8).copyWith(color: bg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );

    final Widget body;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (e.stack.isNotEmpty) {
      final (items, cur) = e.stack.last;
      final top = m.max(0, m.min(cur - 2, items.length - 4));
      body = Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('SYSTEM / LOOP MENU', style: ts(8.2)),
              for (var n = 0; n < m.min(4, items.length - top); n++)
                Builder(
                  builder: (_) {
                    final it = items[top + n], on = top + n == cur;
                    final v = it.k != null
                        ? '►'
                        : (on && e.edit
                              ? '[${it.o[it.g!() % it.o.length]}]'
                              : it.o[it.g!() % it.o.length]);
                    return Container(
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      color: on ? ink : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            it.n,
                            style: ts(9.2).copyWith(color: on ? bg : ink),
                          ),
                          Text(
                            v,
                            style: ts(9.2).copyWith(color: on ? bg : ink),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          fBar(['1:ITEM', '2:VALUE', '-', '4:EXIT']),
        ],
      );
    } else if (e.bankMode != null) {
      final b = e.bankMode!;
      body = Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${b == 'in' ? 'INPUT' : 'TRACK'} FX BANK SELECT',
                style: ts(9.2),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        height: 32,
                        alignment: Alignment.center,
                        color: e.bk[b] == i ? ink : hi,
                        child: Text(
                          'ABCD'[i],
                          style: ts(13)
                              .copyWith(color: e.bk[b] == i ? bg : ink),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Press A-D button to switch bank', style: ts(7.8)),
            ],
          ),
          fBar(['BANK A', 'BANK B', 'BANK C', 'BANK D']),
        ],
      );
    } else if (e.trkEdit) {
      final tr = e.t[e.seltrk];
      body = Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TRACK ${e.seltrk + 1} [P${e.trkPage + 1}/4]',
                    style: ts(9.0),
                  ),
                  Text('◄/► PAGE', style: ts(7.5)),
                ],
              ),
              const SizedBox(height: 6),
              if (e.trkPage == 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('REV: ${tr.rev ? "ON" : "OFF"}', style: ts(9)),
                    Text('1SHOT: ${tr.oneShot ? "ON" : "OFF"}', style: ts(9)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PAN: ${tr.pan == 0 ? "CNTR" : (tr.pan < 0 ? "L${(-tr.pan * 50).round()}" : "R${(tr.pan * 50).round()}")}',
                      style: ts(9),
                    ),
                    Text('MEAS: ${measOpts[tr.meas]}', style: ts(9)),
                  ],
                ),
              ] else if (e.trkPage == 1) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('START:${startOpts[tr.startMode]}', style: ts(8.5)),
                    Text('STOP:${stopOpts[tr.stopMode]}', style: ts(8.5)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DUB: ${dubOpts[tr.dubMode]}', style: ts(9)),
                    Text('L.SYNC: ${tr.loopSync ? "ON" : "OFF"}', style: ts(9)),
                  ],
                ),
              ] else if (e.trkPage == 2) ...[
                // Page 3: Specific Track Recorded Output FX & Print/Bake
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('OUT FX: ${tr.insOn ? "ON" : "OFF"}', style: ts(8.8)),
                    Text('TYPE: ${fxSpecs[tr.insTy].name}', style: ts(8.8)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MIX: ${(tr.insP[3] * 100).round()}%', style: ts(8.8)),
                    Text('TRK BUS: ${tr.fx ? "ON" : "OFF"}', style: ts(8.8)),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SPD: ${spdOpts[tr.spd]}', style: ts(9)),
                    Text(
                      'T.SYNC: ${tr.tempoSync ? "ON" : "OFF"}',
                      style: ts(9),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('FX BUS: ${tr.fx ? "ON" : "OFF"}', style: ts(9)),
                    Text('BOUNCE: ${tr.bnc ? "ON" : "OFF"}', style: ts(9)),
                  ],
                ),
              ],
            ],
          ),
          if (e.trkPage == 0)
            fBar(['REV', '1SHOT', 'PAN', 'MEAS'])
          else if (e.trkPage == 1)
            fBar(['START', 'STOP', 'DUB', 'L.SYNC'])
          else if (e.trkPage == 2)
            fBar(['INS ON', 'FX TYPE', 'MIX', 'PRINT FX'])
          else
            fBar(['SPEED', 'T.SYNC', 'FX BUS', 'BOUNCE']),
        ],
      );
    } else if (e.fxEdit || now < e.editUntil) {
      final f = e.fx[e.last]![e.sel[e.last]!];
      final spec = fxSpecs[f.ty % fxSpecs.length];
      final nm = spec.p;
      final tgtStr = e.last == 'trk' ? '->${tgtOpts[f.target]}' : '';
      if (e.fxEdit && e.fxPage == 1) {
        body = Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${e.last == 'in' ? 'IN' : 'TRK'} FX ${'ABCD'[e.bk[e.last]!]}-${'ABCD'[e.sel[e.last]!]} SETUP',
                      style: ts(8.8),
                    ),
                    Text('◄/► PRM', style: ts(7.5)),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(3),
                  color: ink,
                  child: Text(
                    '${(f.ty + 1).toString().padLeft(2, '0')}: ${spec.name}',
                    style: ts(11.5).copyWith(color: bg),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  e.last == 'trk'
                      ? 'TARGET: ${tgtOpts[f.target]}   BANK:${'ABCD'[e.bk[e.last]!]}  SLOT:${'ABCD'[e.sel[e.last]!]}'
                      : 'SW: ${f.on ? "ON" : "OFF"}   BANK: ${'ABCD'[e.bk[e.last]!]}   SLOT: ${'ABCD'[e.sel[e.last]!]}',
                  style: ts(8.0),
                ),
              ],
            ),
            fBar([
              'FX TYPE',
              e.last == 'trk' ? 'TARGET' : 'SW ON/OFF',
              'BANK',
              'SLOT',
            ]),
          ],
        );
      } else {
        body = Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${e.last == 'in' ? 'IN' : 'TRK'} ${'ABCD'[e.bk[e.last]!]}-${'ABCD'[e.sel[e.last]!]}:${spec.name}$tgtStr',
                      style: ts(8.2),
                    ),
                    Text(f.on ? '[ON]' : '[OFF]', style: ts(7.8)),
                  ],
                ),
                const SizedBox(height: 2),
                for (var j = 0; j < 4; j++)
                  SizedBox(
                    height: 17,
                    child: Row(
                      children: [
                        SizedBox(width: 56, child: Text(nm[j], style: ts(8.0))),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: f.p[j],
                            minHeight: 6,
                            color: ink,
                            backgroundColor: hi,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${(f.p[j] * 100).round()}',
                            style: ts(8.0),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            fBar([nm[0], nm[1], nm[2], nm[3]]),
          ],
        );
      }
    } else if (e.homePage == 1) {
      body = Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'M${e.mem.toString().padLeft(2, '0')} TRACK VIEW',
                    style: ts(8.8),
                  ),
                  Text('♩=${e.bpm.toStringAsFixed(1)}', style: ts(8.8)),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 5; i++)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: e.seltrk == i ? ink : hi,
                              width: e.seltrk == i ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                e.t[i].insOn
                                    ? fxSpecs[e.t[i].insTy].name.substring(
                                        0,
                                        m.min(
                                          4,
                                          fxSpecs[e.t[i].insTy].name.length,
                                        ),
                                      )
                                    : e
                                          .effMeasLabel(e.t[i])
                                          .substring(
                                            0,
                                            m.min(
                                              4,
                                              e.effMeasLabel(e.t[i]).length,
                                            ),
                                          ),
                                style: ts(6.5),
                              ),
                              const SizedBox(height: 2),
                              LinearProgressIndicator(
                                value: (e.t[i].vol / 1.25).clamp(0.0, 1.0),
                                minHeight: 5,
                                color: ink,
                                backgroundColor: hi,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'T${i + 1}${e.t[i].fx ? "*" : ""}',
                                style: ts(7.8),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
          fBar([
            'MEM ${e.mem}',
            'BPM',
            'MEAS:${loopMeasOpts[e.loopMeas]}',
            'MFX ${(e.mfx * 100).round()}',
          ]),
        ],
      );
    } else {
      final tr = e.t[e.seltrk];
      final tf = e.fx['trk']![e.sel['trk']!];
      final msg = now < e.msgUntil
          ? e.statusMsg
          : (e.err.isNotEmpty
                ? e.err
                : 'T${e.seltrk + 1}:${e.effMeasLabel(tr)} ${tr.insOn ? "[${fxSpecs[tr.insTy].name}]" : "TFX->${tgtOpts[tf.target]}"}');
      body = Stack(
        children: [
          Text(e.mem.toString().padLeft(2, '0'), style: ts(26)),
          Positioned(
            right: 0,
            top: 0,
            child: Text('♩=${e.bpm.toStringAsFixed(1)}', style: ts(9.5)),
          ),
          Positioned(
            right: 0,
            top: 13,
            child: Text(
              'IN:${(e.inLvl * 100).round().toString().padLeft(2, '0')}% ${e.pm == 1 ? "SGL" : "MLT"}',
              style: ts(7.8),
            ),
          ),
          Positioned(
            top: 34,
            child: Text(
              'MEMORY ${e.mem.toString().padLeft(2, '0')} [${loopMeasOpts[e.loopMeas]}]',
              style: ts(11.0),
            ),
          ),
          Positioned(
            top: 52,
            child: Text(
              msg,
              style: ts(8.0).copyWith(
                color: now < e.msgUntil
                    ? const Color(0xFF0055AA)
                    : (e.err.isNotEmpty ? const Color(0xFFC02020) : ink),
              ),
            ),
          ),
          fBar([
            'MEMORY',
            'TEMPO',
            'MEAS:${loopMeasOpts[e.loopMeas]}',
            'MFX ${(e.mfx * 100).round()}',
          ]),
        ],
      );
    }

    return Container(
      width: w,
      height: h,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c8(0xFF282E34), width: 2.5),
      ),
      child: body,
    );
  }

  Widget _helpOverlay() => Positioned.fill(
    child: GestureDetector(
      onTap: () {
        e.showHelp = false;
        e.notifyListeners();
      },
      child: Container(
        color: Colors.black.withAlpha(220),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c8(0xFF16181E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: red, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BOSS RC-505mkII — KEYBOARD & TRACK FX ROUTING GUIDE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Press [H] or [ESC] to Close',
                    style: TextStyle(
                      color: orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 18),
              const Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'TRACK 1–5 CONTROLS:\n'
                        '• [1] [2] [3] [4] [5] : Rec / Overdub / Play Track 1–5\n'
                        '• [Shift + 1..5]      : Toggle Reverse on Track 1–5\n'
                        '• [Q] [W] [E] [R] [T] : Stop Track 1–5\n'
                        '• [Shift + Q..T]      : Clear Track 1–5\n'
                        '• [A] [S] [D] [F] [G] : Toggle Track 1–5 FX Bus Switch\n'
                        '• [Shift + A..G]      : Lock Track FX Target to Track 1–5\n'
                        '• [Z] [X] [C] [V] [B] : Open TRACK 1–5 Edit Menu\n'
                        '• [Shift + Z..B]      : Toggle 1-Shot Mode on Track 1–5',
                        style: TextStyle(
                          color: Color(0xFFD8E0E8),
                          fontSize: 12,
                          fontFamily: 'monospace',
                          height: 1.55,
                        ),
                      ),
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        'FX, NAVIGATION & TRANSPORT:\n'
                        '• [6] [7] [8] [9]     : Toggle INPUT FX A, B, C, D\n'
                        '• [Shift + 6..9] / [0]: Input FX Bank A–D / [0] Edit\n'
                        '• [Y] [U] [I] [O]     : Toggle TRACK FX A, B, C, D\n'
                        '• [Shift + Y..O] / [P]: Track FX Bank A–D / [P] Edit\n'
                        '• [Space] / [N]       : All Start/Stop / [N] Rhythm\n'
                        '• [Backspace]         : Undo/Redo ([Shift] Mark Back)\n'
                        '• [Left/Right/Up/Down]: Page ◄/► & Value Adjust\n'
                        '• [M] / [L] / [F] / [K]: Menu / Loop / Free-Auto / Tap',
                        style: TextStyle(
                          color: Color(0xFFD8E0E8),
                          fontSize: 12,
                          fontFamily: 'monospace',
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c8(0xFF222630),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'HOW TO ADD FX TO A SPECIFIC RECORDED TRACK OUTPUT:\n'
                  '1) Press [Shift + A/S/D/F/G] to target Track FX directly to Track 1–5 (or set TARGET in TRACK FX EDIT Page 2).\n'
                  '2) Or press [Z/X/C/V/B] -> Page ► to Page 3 (OUT FX) to enable a dedicated per-track effect or click Knob 4 (PRINT FX) to bake it into the recording!',
                  style: TextStyle(
                    color: mint,
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final k = wd / 1020;
    Widget X(double x, double y, Widget w) => P(x * k, y, w);
    Widget C(int i, double o, double y, Widget w) =>
        P((22 + i * 196) * k + o + (k - 1) * 92, y, w);

    final ch = <Widget>[
      Positioned.fill(child: CustomPaint(painter: Chassis(wd))),
    ];

    for (final bank in ['in', 'trk']) {
      final isIn = bank == 'in';
      final x0 = isIn ? 30.0 : 804.0;
      final kx = isIn ? 36.0 : 906.0;
      final editX = isIn ? 124.0 : 816.0;
      ch.add(
        X(
          kx,
          26,
          Knob(
            68,
            endless: true,
            silverRim: true,
            step: (d) => e.bigFxKnob(bank, d),
            tap: () => e.toggleEdit(bank),
          ),
        ),
      );
      ch.add(
        X(
          editX,
          92,
          Btn(
            'EDIT',
            46,
            22,
            col: orange,
            lit: (e.fxEdit && e.last == bank) || e.bankMode == bank,
            tap: () => e.toggleEdit(bank),
            hold: () => e.holdEdit(bank),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        ch.add(
          X(
            x0 + i * 47,
            152,
            Btn(
              'ABCD'[i],
              40,
              40,
              kind: 'fxpad',
              col: red,
              lit: e.fx[bank]![i].on,
              down: () => e.fxpress(bank, i),
            ),
          ),
        );
      }
    }

    ch.addAll([
      X(244, 52, Btn('MENU', 56, 22, tap: e.openMenu)),
      X(312, 52, Btn('LOOP', 56, 22, tap: () => e.jump(0))),
      X(240, 146, Btn('ALL\nSTART/STOP', 62, 36, col: blue, down: e.allss)),
      X(
        310,
        146,
        Btn('UNDO/\nREDO', 54, 36, col: green, lit: e.flip, down: e.ur),
      ),
      X(
        370,
        152,
        Btn(
          'MARK\nBACK',
          30,
          26,
          col: orange,
          tap: () => e.markBack(),
          hold: () => e.markBack(revertBase: true),
        ),
      ),
    ]);

    ch.add(X(402, 30, lcd()));
    for (var i = 0; i < 4; i++) {
      ch.add(
        X(
          409.0 + i * 54,
          152,
          Knob(
            36,
            endless: true,
            step: (d) => e.fKnob(i, d),
            tap: () => e.fKnobPush(i),
          ),
        ),
      );
    }

    ch.addAll([
      X(632, 48, Btn('◄', 42, 22, down: () => e.pageBtn(-1))),
      X(680, 48, Btn('►', 42, 22, down: () => e.pageBtn(1))),
      X(632, 82, Btn('EXIT', 42, 22, tap: e.exit, hold: () => e.save(e.mem))),
      X(680, 82, Btn('ENTER', 42, 22, tap: e.enter)),
      X(
        734,
        46,
        Knob(
          42,
          val: e.master,
          ch: (v) {
            e.master = v;
            e.notifyListeners();
          },
        ),
      ),
      X(
        636,
        146,
        Btn(
          'RHYTHM\nSTART/STOP',
          66,
          36,
          col: red,
          lit: e.rh,
          tap: e.toggleRh,
          hold: () => e.jump(3),
        ),
      ),
      X(714, 146, Btn('TAP\nTEMPO', 62, 36, col: blue, down: e.tap)),
    ]);

    for (var i = 0; i < 5; i++) {
      final tr = e.t[i];
      final pos = tr.d.isNotEmpty
          ? ((tr.oneShot || !tr.loopSync || e.effMeas(tr) == 1 || tr.spd != 1)
                ? (tr.pos / tr.d.length).clamp(0.0, 1.0)
                : (e.mpos % tr.d.length) / tr.d.length)
          : (DateTime.now().millisecondsSinceEpoch % 2500) / 2500;

      ch.addAll([
        C(
          i,
          22,
          238,
          Btn(
            'FX',
            54,
            24,
            col: tr.insOn ? orange : red,
            lit: tr.fx || tr.insOn,
            tap: () {
              tr.fx = !tr.fx;
              e.flashMsg('TRK ${i + 1} FX: ${tr.fx ? "ON" : "OFF"}');
            },
            hold: () => e.targetTrackFx(i),
          ),
        ),
        C(
          i,
          22,
          274,
          Btn(
            'TRACK',
            54,
            24,
            col: mint,
            lit: e.seltrk == i && e.trkEdit,
            down: () => e.selectTrack(i),
          ),
        ),
        C(
          i,
          23,
          316,
          Btn(
            '',
            52,
            52,
            kind: 'stop',
            col: orange,
            lit: tr.st == S.stop || tr.st == S.stopping,
            tap: () => e.stop(i),
            hold: () => e.clear(i),
          ),
        ),
        C(
          i,
          114,
          234,
          Fader(tr.vol / 1.25, tr.lvl, (v) {
            tr.vol = v * 1.25;
            e.notifyListeners();
          }),
        ),
        C(i, 27, 416, TrackPad(tr, pos, () => e.press(i))),
      ]);
    }

    if (e.showHelp) ch.add(_helpOverlay());
    return SizedBox(
      width: wd,
      height: 572,
      child: Stack(children: ch),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const Home(),
    ),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _H();
}

class _H extends State<Home> {
  final e = Eng();
  @override
  void initState() {
    super.initState();
    e.start();
  }

  @override
  void dispose() {
    e.dispose();
    super.dispose();
  }

  // Hardware-key mapped handler (works reliably with Shift/Ctrl on Linux, Windows, macOS & Android)
  KeyEventResult key(FocusNode n, KeyEvent ev) {
    if (ev is! KeyDownEvent) return KeyEventResult.ignored;
    final k = ev.logicalKey;
    final sh = HardwareKeyboard.instance.isShiftPressed;
    final ctrl = HardwareKeyboard.instance.isControlPressed;

    // 1..5: Track Rec/Play/Dub (Shift + 1..5 = Reverse, Ctrl + 1..5 = Target Track FX)
    const tKeys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
    ];
    final ti = tKeys.indexOf(k);
    if (ti != -1) {
      if (ctrl)
        e.targetTrackFx(ti);
      else if (sh) {
        e.t[ti].rev = !e.t[ti].rev;
        e.flashMsg('TRK ${ti + 1} REV: ${e.t[ti].rev ? "ON" : "OFF"}');
      } else
        e.press(ti);
      return KeyEventResult.handled;
    }

    // Q W E R T: Track Stop (Shift + Q..T = Track Clear)
    const sKeys = [
      LogicalKeyboardKey.keyQ,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyE,
      LogicalKeyboardKey.keyR,
      LogicalKeyboardKey.keyT,
    ];
    final si = sKeys.indexOf(k);
    if (si != -1) {
      sh ? e.clear(si) : e.stop(si);
      return KeyEventResult.handled;
    }

    // A S D F G: Track FX Switch (Shift + A..G = Lock Track FX Slot to Track 1..5 & Open Editor)
    const fxKeys = [
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyG,
    ];
    final fi = fxKeys.indexOf(k);
    if (fi != -1) {
      if (sh) {
        e.targetTrackFx(fi);
      } else {
        e.t[fi].fx = !e.t[fi].fx;
        e.flashMsg('TRK ${fi + 1} FX: ${e.t[fi].fx ? "ON" : "OFF"}');
      }
      return KeyEventResult.handled;
    }

    // Z X C V B: Track Edit Button (Shift + Z..B = Toggle 1-Shot)
    const trkKeys = [
      LogicalKeyboardKey.keyZ,
      LogicalKeyboardKey.keyX,
      LogicalKeyboardKey.keyC,
      LogicalKeyboardKey.keyV,
      LogicalKeyboardKey.keyB,
    ];
    final zIdx = trkKeys.indexOf(k);
    if (zIdx != -1) {
      if (sh) {
        e.t[zIdx].oneShot = !e.t[zIdx].oneShot;
        e.flashMsg(
          'TRK ${zIdx + 1} 1SHOT: ${e.t[zIdx].oneShot ? "ON" : "OFF"}',
        );
      } else {
        e.selectTrack(zIdx);
      }
      return KeyEventResult.handled;
    }

    // 6 7 8 9 0: INPUT FX A, B, C, D & Edit (Shift + 6..9 = Bank A..D)
    const inFxKeys = [
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    final inIdx = inFxKeys.indexOf(k);
    if (inIdx != -1) {
      if (sh) {
        e.bk['in'] = inIdx;
        e.flashMsg('INPUT FX BANK ${'ABCD'[inIdx]}');
      } else
        e.fxpress('in', inIdx);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.digit0) {
      e.toggleEdit('in');
      return KeyEventResult.handled;
    }

    // Y U I O P: TRACK FX A, B, C, D & Edit (Shift + Y..O = Bank A..D)
    const trkFxKeys = [
      LogicalKeyboardKey.keyY,
      LogicalKeyboardKey.keyU,
      LogicalKeyboardKey.keyI,
      LogicalKeyboardKey.keyO,
    ];
    final tfIdx = trkFxKeys.indexOf(k);
    if (tfIdx != -1) {
      if (sh) {
        e.bk['trk'] = tfIdx;
        e.flashMsg('TRACK FX BANK ${'ABCD'[tfIdx]}');
      } else
        e.fxpress('trk', tfIdx);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyP) {
      e.toggleEdit('trk');
      return KeyEventResult.handled;
    }

    // Transport, Navigation & Function Keys
    if (k == LogicalKeyboardKey.space) {
      sh ? e.toggleRh() : e.allss();
    } else if (k == LogicalKeyboardKey.keyN) {
      ctrl ? e.jump(3) : e.toggleRh();
    } else if (k == LogicalKeyboardKey.keyK)
      e.tap();
    else if (k == LogicalKeyboardKey.backspace) {
      if (ctrl)
        e.markBack(revertBase: true);
      else if (sh)
        e.markBack();
      else
        e.ur();
    } else if (k == LogicalKeyboardKey.keyM)
      e.openMenu();
    else if (k == LogicalKeyboardKey.keyL) {
      if (sh) {
        e.loopMeas = e.loopMeas == 1 ? 0 : 1;
        e.flashMsg('LOOP MEAS: ${loopMeasOpts[e.loopMeas]}');
      } else
        e.jump(0);
    } else if (k == LogicalKeyboardKey.arrowLeft)
      e.pageBtn(-1);
    else if (k == LogicalKeyboardKey.arrowRight)
      e.pageBtn(1);
    else if (k == LogicalKeyboardKey.arrowUp)
      e.fKnob(0, 1);
    else if (k == LogicalKeyboardKey.arrowDown)
      e.fKnob(0, -1);
    else if (k == LogicalKeyboardKey.bracketLeft)
      e.chmem(-1);
    else if (k == LogicalKeyboardKey.bracketRight)
      e.chmem(1);
    else if (k == LogicalKeyboardKey.enter) {
      sh ? e.save(e.mem) : e.enter();
    } else if (k == LogicalKeyboardKey.escape)
      e.exit();
    else if (k == LogicalKeyboardKey.keyH || k == LogicalKeyboardKey.slash) {
      e.showHelp = !e.showHelp;
      e.notifyListeners();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: const Color(0xFF060607),
    body: Focus(
      autofocus: true,
      onKeyEvent: key,
      child: LayoutBuilder(
        builder: (ctx, bc) {
          var s = bc.maxHeight / 572, wd = bc.maxWidth / s;
          if (wd < 1020) {
            s = bc.maxWidth / 1020;
            wd = 1020;
          }
          return Center(
            child: SizedBox(
              width: wd * s,
              height: 572 * s,
              child: FittedBox(
                child: SizedBox(
                  width: wd,
                  height: 572,
                  child: AnimatedBuilder(
                    animation: e,
                    builder: (_, __) => Unit(e, wd: wd),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
