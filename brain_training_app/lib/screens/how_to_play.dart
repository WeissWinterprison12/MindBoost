import 'dart:async';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Colors (same palette as the rest of the app)
// ---------------------------------------------------------------------------
const Color _cyan = Color(0xFF18FFFF);
const Color _amber = Color(0xFFFFC107);
const Color _gold = Color(0xFFFFD700);
const Color _magenta = Color(0xFFE040FB);
const Color _mint = Color(0xFF69F0AE);
const Color _btn = Color(0xFF5A3FC0);
const Color _deep = Color(0xFF4A0E4E);

const List<String> _diffNames = ['EASY', 'MEDIUM', 'HARD'];
const List<String> _diffEmoji = ['😊', '😎', '🔥'];
const List<Color> _diffColors = [
  Color(0xFF2E7D32),
  Color(0xFFE08A00),
  Color(0xFFC62828),
];

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------
class _Chip {
  final String label;
  final String value;
  final Color color;
  const _Chip(this.label, this.value, this.color);
}

class _Step {
  final String label;
  final Color labelColor;
  final Widget visual;
  final String sub;
  final String caption;
  final List<_Chip>? hud;

  _Step({
    required this.label,
    required this.labelColor,
    required this.visual,
    required this.sub,
    required this.caption,
    this.hud,
  });
}

class _Diff {
  final String big;
  final String text;
  const _Diff(this.big, this.text);
}

class _TutorialPage {
  final String emoji;
  final String title;
  final String goal;
  final List<_Diff>? diffs;
  final List<_Chip>? Function(int dd) hud;
  final List<_Step> Function(int dd) steps;

  _TutorialPage({
    required this.emoji,
    required this.title,
    required this.goal,
    required this.diffs,
    required this.hud,
    required this.steps,
  });
}

// ---------------------------------------------------------------------------
// Small UI helpers
// ---------------------------------------------------------------------------
Widget _t(String s,
        {double size = 14,
        Color color = Colors.white,
        FontWeight w = FontWeight.w600,
        double? height}) =>
    Text(
      s,
      textAlign: TextAlign.center,
      style: TextStyle(
          color: color, fontSize: size, fontWeight: w, height: height),
    );

Widget _col(List<Widget> c, {double gap = 8}) {
  final out = <Widget>[];
  for (int i = 0; i < c.length; i++) {
    if (i > 0) out.add(SizedBox(height: gap));
    out.add(c[i]);
  }
  return Column(mainAxisSize: MainAxisSize.min, children: out);
}

Widget _row(List<Widget> c, {double gap = 6}) {
  final out = <Widget>[];
  for (int i = 0; i < c.length; i++) {
    if (i > 0) out.add(SizedBox(width: gap));
    out.add(c[i]);
  }
  return Row(mainAxisSize: MainAxisSize.min, children: out);
}

Widget _qbox(String s, {double size = 24}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
      ),
      child: _t(s, size: size, w: FontWeight.bold),
    );

Widget _pill(String s, Color bg,
        {Color fg = Colors.white, double? width, double size = 13}) =>
    Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: _t(s, size: size, color: fg, w: FontWeight.bold),
    );

Widget _opts(List<String> a, int? hi) => SizedBox(
      width: 200,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 2.9,
        children: [
          for (int i = 0; i < a.length; i++)
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hi == i ? const Color(0xFF2E9E44) : _btn,
                borderRadius: BorderRadius.circular(10),
                border: hi == i
                    ? Border.all(color: const Color(0xFFB9F6CA), width: 2)
                    : null,
              ),
              child: _t(a[i], size: 18, w: FontWeight.bold),
            ),
        ],
      ),
    );

Widget _ev(int n, String text) => Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: _gold, shape: BoxShape.circle),
            child: Text('$n',
                style: const TextStyle(
                    color: _deep, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, height: 1.2)),
          ),
        ],
      ),
    );

Widget _ans(String l, String text, {bool good = false}) => Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: good
            ? const Color(0xFF2E9E44)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(l,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(good ? '$text  ✓' : text,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );

// ---------------------------------------------------------------------------
// Level 2: science picture (drawn in code, swap for Image.asset if you like)
// ---------------------------------------------------------------------------
void _paintSpace(Canvas canvas, Size s) {
  final w = s.width, h = s.height;
  canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF0B0A1F));
  final sunC = Offset(w * .62, h * .38);
  final sunR = w * .3;
  canvas.drawCircle(
    sunC,
    sunR,
    Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFFFFBE0),
          Color(0xFFFFD54F),
          Color(0xFFFF9800),
          Color(0xFFE65100),
          Color(0x00E65100),
        ],
        stops: [0, .2, .45, .7, 1],
      ).createShader(Rect.fromCircle(center: sunC, radius: sunR)),
  );
  canvas.drawCircle(
      Offset(w * .2, h * .72), w * .045, Paint()..color = const Color(0xFFD7B48C));
  canvas.drawCircle(
      Offset(w * .88, h * .8), w * .035, Paint()..color = const Color(0xFF64B5F6));
  canvas.drawCircle(
      Offset(w * .9, h * .18), w * .033, Paint()..color = const Color(0xFFB0894F));
  final star = Paint()..color = Colors.white;
  for (final o in const [
    Offset(.12, .15),
    Offset(.4, .9),
    Offset(.78, .62),
    Offset(.3, .35),
    Offset(.05, .55),
    Offset(.55, .75),
  ]) {
    canvas.drawCircle(Offset(w * o.dx, h * o.dy), 1.2, star);
  }
}

class _SpaceTilePainter extends CustomPainter {
  final int n;
  final int idx;
  const _SpaceTilePainter(this.n, this.idx);

  @override
  void paint(Canvas canvas, Size size) {
    final r = idx ~/ n, c = idx % n;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-c * size.width, -r * size.height);
    _paintSpace(canvas, Size(size.width * n, size.height * n));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpaceTilePainter old) =>
      old.n != n || old.idx != idx;
}

const List<int> _scramble3 = [4, 0, 7, 2, 8, 1, 6, 3, 5];
const List<int> _scramble4 = [5, 12, 3, 9, 0, 14, 7, 2, 10, 15, 1, 6, 13, 4, 11, 8];

Widget _puzzle(int n, {List<int>? order, List<int> hl = const []}) {
  final gap = order == null ? 0.0 : 3.0;
  return SizedBox(
    width: 140,
    height: 140,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GridView.count(
        crossAxisCount: n,
        padding: EdgeInsets.zero,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (int p = 0; p < n * n; p++)
            Container(
              foregroundDecoration: hl.contains(p)
                  ? BoxDecoration(border: Border.all(color: _gold, width: 2))
                  : null,
              child: CustomPaint(
                painter: _SpaceTilePainter(n, order == null ? p : order[p]),
              ),
            ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Level 3: memory cards
// ---------------------------------------------------------------------------
const List<String> _cards6 = ['🌱', '🪐', '🐘', '⭐', '🔢', '⭐', '🔬', '🐘', '🪐', '🔢', '🌱', '🔬'];
const List<String> _cards8 = ['⭐', '🌈', '🔬', '🦋', '🦋', '🐘', '🐘', '🔬', '🪐', '🌱', '🔢', '🌈', '⭐', '🌱', '🪐', '🔢'];

// state: 0 = face down, 1 = face up, 2 = selected
Widget _cardGrid(int cols, List<String> faces, int Function(int) state) {
  final h = cols == 3 ? 33.0 : 31.0;
  return SizedBox(
    width: cols == 3 ? 150 : 176,
    child: GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: faces.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        mainAxisExtent: h,
      ),
      itemBuilder: (_, i) {
        final s = state(i);
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s == 0
                ? _btn
                : s == 2
                    ? const Color(0xFFCFCFCF)
                    : const Color(0xFFF7F4FA),
            borderRadius: BorderRadius.circular(6),
            border: s == 2 ? Border.all(color: _gold, width: 2) : null,
          ),
          child: s == 0
              ? _t('?', size: 15)
              : Text(faces[i], style: const TextStyle(fontSize: 19)),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Level 5: glowing star tiles
// ---------------------------------------------------------------------------
Widget _tiles(int n, List<int> stars, double size) => SizedBox(
      width: size,
      child: GridView.count(
        crossAxisCount: n,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: [
          for (int i = 0; i < n * n; i++)
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: stars.contains(i)
                    ? _gold
                    : Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Colors.white30),
              ),
              child: stars.contains(i)
                  ? Icon(Icons.star_rounded,
                      color: _deep, size: n == 3 ? 24 : 16)
                  : Container(
                      width: size / n * 0.38,
                      height: size / n * 0.38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white38, width: 1.5),
                      ),
                    ),
            ),
        ],
      ),
    );

// ---------------------------------------------------------------------------
// Level 6: detective picture
// ---------------------------------------------------------------------------
Widget _garden() => ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 220,
        height: 110,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2F5D3A), Color(0xFF17301F)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 80,
              top: 0,
              bottom: 0,
              width: 70,
              child: Container(color: const Color(0xCC8A7A55)),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('🔍 Inspect image',
                    style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Level 7: word quest
// ---------------------------------------------------------------------------
Widget _pics() => SizedBox(
      width: 150,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.6,
        children: [
          for (int i = 0; i < 4; i++)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF5A4A3A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(const ['🍞', '🥪', '🥖', '🧈'][i],
                        style: const TextStyle(fontSize: 24)),
                  ),
                  Positioned(
                    left: 3,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

Widget _clue(String text) => Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NEED A CLUE?',
              style: TextStyle(color: _amber, fontSize: 11)),
          Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );

Widget _answerBoxes(String word, {Color? solved, int? hintIdx}) => _row([
      for (int i = 0; i < word.length; i++)
        Container(
          width: 28,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: solved ??
                (hintIdx == i
                    ? const Color(0xFFF5A623)
                    : Colors.white.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white38),
          ),
          child: Text(word[i] == '_' ? '' : word[i],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
    ], gap: 4);

Widget _letters(List<String> a, Set<int> used) => SizedBox(
      width: 186,
      child: GridView.count(
        crossAxisCount: 6,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.1,
        children: [
          for (int i = 0; i < a.length; i++)
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: used.contains(i)
                    ? Colors.white.withValues(alpha: 0.12)
                    : _btn,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(a[i],
                  style: TextStyle(
                    color: used.contains(i) ? Colors.white30 : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  )),
            ),
        ],
      ),
    );

// ---------------------------------------------------------------------------
// Level 8: path finder maze
// ---------------------------------------------------------------------------
const List<String> _maze = [
  '0000000',
  '0111010',
  '0001010',
  '0111010',
  '0100010',
  '0111110',
  '0000011',
  '0000000',
];
const List<String> _path = [
  '1,1', '2,1', '3,1', '3,2', '3,3', '2,3', '1,3', '1,4',
  '1,5', '2,5', '3,5', '4,5', '5,5', '5,6', '6,6',
];

Widget _dot(String s, Color bg, Color fg) => Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(s,
          style: TextStyle(
              color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );

Widget _mazeView({required bool show, int upto = -1, bool bad = false}) {
  final rows = <Widget>[];
  for (int r = 0; r < _maze.length; r++) {
    final cells = <Widget>[];
    for (int c = 0; c < 7; c++) {
      final on = _maze[r][c] == '1';
      final key = '$c,$r';
      final pi = _path.indexOf(key);
      Color bg = show
          ? (on ? const Color(0xFFE8E0F8) : const Color(0xFF3A0F5E))
          : Colors.white.withValues(alpha: 0.08);
      if (!show && pi > -1 && pi <= upto) {
        bg = _gold.withValues(alpha: 0.75);
      }
      if (bad && key == '2,2') bg = const Color(0xFFFF5252);
      Widget? mark;
      if (key == '1,1') mark = _dot('S', const Color(0xFF2ECC71), Colors.white);
      if (key == '6,6') mark = _dot('F', _gold, _deep);
      cells.add(Expanded(
        child: Container(
          height: 19,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: Colors.white12, width: 0.5),
          ),
          child: mark,
        ),
      ));
    }
    rows.add(Row(children: cells));
  }
  return Container(
    width: 154,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.white30),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: rows),
  );
}

// ---------------------------------------------------------------------------
// All pages. Edit the text here if timers or rules change.
// ---------------------------------------------------------------------------
const List<List<String>> _mathQ = [
  ['14 − 5 = ?', '9'],
  ['7 × 7 = ?', '49'],
  ['56 ÷ 7 = ?', '8'],
];
const List<String> _time23 = ['∞', '60s', '45s'];

final List<_TutorialPage> _pages = [
  // ----- Intro -----
  _TutorialPage(
    emoji: '🎮',
    title: 'PICK YOUR DIFFICULTY',
    goal: 'Choose Easy, Medium or Hard before each level.',
    diffs: null,
    hud: (dd) => null,
    steps: (dd) => [
      _Step(
        label: 'LEVEL SELECT',
        labelColor: _cyan,
        visual: _col([
          for (final x in const [
            ['Math Challenge', 0xFF1E88E5],
            ['Science Puzzle', 0xFF2E9E6A],
            ['Memory Match', 0xFF7E3FD0],
            ['Pattern Logic', 0xFFF29A1F],
          ])
            Container(
              width: 190,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Color(x[1] as int),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(x[0] as String,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
        ], gap: 5),
        sub: 'Pick your puzzle arena',
        caption: 'Tap a level to start.',
      ),
      _Step(
        label: 'SELECT DIFFICULTY',
        labelColor: _amber,
        visual: _col([
          for (int i = 0; i < 3; i++)
            Container(
              width: 190,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: _diffColors[i], width: 5)),
              ),
              child: Text('${_diffEmoji[i]} ${_diffNames[i]}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
        ], gap: 6),
        sub: 'Math Challenge',
        caption: 'Choose Easy, Medium or Hard.',
      ),
      _Step(
        label: '🏆 LEVEL UP!',
        labelColor: _amber,
        visual: _t('😊➜😎➜🔥', size: 44),
        sub: 'Easy: relax · Medium: timer · Hard: fast timer',
        caption: 'Start easy, then level up when you are ready!',
      ),
    ],
  ),

  // ----- Level 1 -----
  _TutorialPage(
    emoji: '🔢',
    title: 'LEVEL 1: MATH CHALLENGE',
    goal: 'Answer 10 math questions correctly.',
    diffs: const [
      _Diff('∞', 'No timer. Each right answer gives +10 XP.'),
      _Diff('20s', '20 seconds for each question.'),
      _Diff('10s', '10 seconds for each question.'),
    ],
    hud: (dd) => dd == 0
        ? const [_Chip('XP', '0', _gold), _Chip('STREAK', '0', _gold), _Chip('BEST', '0', _gold)]
        : [
            _Chip('TIME', dd == 1 ? '20s' : '10s', _cyan),
            const _Chip('XP', '0', _gold),
            const _Chip('STREAK', '0', _gold),
            const _Chip('BEST', '0', _gold),
          ],
    steps: (dd) {
      final q = _mathQ[dd];
      return [
        _Step(
          label: 'QUESTION 1 OF 10',
          labelColor: _cyan,
          visual: _qbox(q[0], size: 28),
          sub: 'Read the question at the top',
          caption: 'Read the question.',
        ),
        _Step(
          label: 'QUESTION 1 OF 10',
          labelColor: _cyan,
          visual: _col([
            _qbox(q[0]),
            Container(
              width: 120,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _amber, width: 2),
              ),
              child: _t(q[1], size: 22, color: _deep, w: FontWeight.bold),
            ),
            _pill('SUBMIT', const Color(0xFF2EBD59), width: 140),
          ], gap: 7),
          sub: 'Type your answer, then tap SUBMIT',
          caption: 'Type your answer and tap SUBMIT.',
        ),
        _Step(
          label: 'CORRECT! 🎉',
          labelColor: _mint,
          visual: _col([
            _pill(dd == 0 ? '+10 XP' : '+XP', const Color(0xFF2EBD59), size: 18),
            _qbox(q[0].replaceAll('?', q[1])),
          ]),
          sub: 'Get 3 right in a row for bonus XP!',
          caption: 'Right answer = XP! 3 in a row = bonus!',
        ),
        _Step(
          label: '🎉 LEVEL COMPLETE!',
          labelColor: _amber,
          visual: _col([
            _t('6 / 10', size: 42, color: _gold, w: FontWeight.bold),
            _t('✅ Level passed!', size: 15),
          ], gap: 6),
          sub: 'You need 60% correct',
          caption: 'Get 6 out of 10 right to pass.',
        ),
      ];
    },
  ),

  // ----- Level 2 -----
  _TutorialPage(
    emoji: '🧩',
    title: 'LEVEL 2: SCIENCE PUZZLE',
    goal: 'Rebuild the science picture.',
    diffs: const [
      _Diff('∞', '3×3 pieces. Look for 10 sec. Unlimited time. Moves are counted.'),
      _Diff('60s', '3×3 pieces. Look for 5 sec, then 60 seconds.'),
      _Diff('45s', '4×4 pieces. Look for 5 sec, then 45 seconds.'),
    ],
    hud: (dd) => [
      _Chip('TIME', _time23[dd], _cyan),
      const _Chip('MOVES', '0', _magenta),
      const _Chip('STREAK', '0', _gold),
    ],
    steps: (dd) {
      final n = dd == 2 ? 4 : 3;
      final sc = dd == 2 ? _scramble4 : _scramble3;
      return [
        _Step(
          label: 'MEMORIZE THE IMAGE',
          labelColor: _amber,
          visual: _puzzle(n),
          sub: 'Study the image carefully!',
          caption: 'Look at the picture and remember it.',
        ),
        _Step(
          label: 'SOLVE THE PUZZLE',
          labelColor: _cyan,
          visual: _puzzle(n, order: sc),
          sub: 'Tap two pieces to swap them',
          caption: 'It breaks into pieces and gets mixed up!',
        ),
        _Step(
          label: 'SOLVE THE PUZZLE',
          labelColor: _cyan,
          visual: _puzzle(n, order: sc, hl: const [0, 1]),
          sub: 'Tap two pieces to swap them',
          caption: 'Tap one piece, then tap another to swap them.',
          hud: [
            _Chip('TIME', _time23[dd], _cyan),
            const _Chip('MOVES', '1', _magenta),
            const _Chip('STREAK', '0', _gold),
          ],
        ),
        _Step(
          label: '🎉 LEVEL COMPLETE!',
          labelColor: _amber,
          visual: _puzzle(n),
          sub: 'Fewer moves and faster time = a better grade',
          caption: 'Put every piece back to win!',
          hud: [
            _Chip('TIME', _time23[dd], _cyan),
            const _Chip('MOVES', '7', _magenta),
            const _Chip('STREAK', '1', _gold),
          ],
        ),
      ];
    },
  ),

  // ----- Level 3 -----
  _TutorialPage(
    emoji: '🧠',
    title: 'LEVEL 3: MEMORY MATCH',
    goal: 'Find all the matching pairs.',
    diffs: const [
      _Diff('∞', 'Peek 5 sec. 6 pairs. No timer.'),
      _Diff('60s', 'Peek 3 sec. 6 pairs. 60 seconds.'),
      _Diff('45s', 'Peek 3 sec. 8 pairs. 45 seconds.'),
    ],
    hud: (dd) => [
      _Chip('TIME', _time23[dd], _cyan),
      _Chip('PAIRS', '0/${dd == 2 ? 8 : 6}', _mint),
      const _Chip('MOVES', '0', _magenta),
      const _Chip('STREAK', '0', _gold),
    ],
    steps: (dd) {
      final cols = dd == 2 ? 4 : 3;
      final f = dd == 2 ? _cards8 : _cards6;
      final e1 = dd == 2 ? 5 : 2;
      final e2 = dd == 2 ? 6 : 7;
      final pv = dd == 0 ? '5s' : '3s';
      final tot = dd == 2 ? 8 : 6;
      return [
        _Step(
          label: 'MEMORIZE THE CARDS',
          labelColor: _amber,
          visual: _cardGrid(cols, f, (_) => 1),
          sub: 'Peek for $pv. Remember where each symbol is!',
          caption: 'Peek at the cards and remember them.',
          hud: [
            _Chip('PREVIEW', pv, _cyan),
            _Chip('PAIRS', '0/$tot', _mint),
            const _Chip('MOVES', '0', _magenta),
            const _Chip('STREAK', '0', _gold),
          ],
        ),
        _Step(
          label: 'FIND THE PAIRS',
          labelColor: _cyan,
          visual: _cardGrid(cols, f, (_) => 0),
          sub: 'The cards flip face down',
          caption: 'The cards flip face down.',
        ),
        _Step(
          label: 'FIND THE PAIRS',
          labelColor: _cyan,
          visual: _cardGrid(cols, f, (i) => (i == e1 || i == e2) ? 2 : 0),
          sub: 'Tap two cards to flip them',
          caption: 'Tap two cards. If they match, they stay open!',
          hud: [
            _Chip('TIME', _time23[dd], _cyan),
            _Chip('PAIRS', '1/$tot', _mint),
            const _Chip('MOVES', '1', _magenta),
            const _Chip('STREAK', '1', _gold),
          ],
        ),
        _Step(
          label: '🎉 ALL PAIRS FOUND!',
          labelColor: _amber,
          visual: _cardGrid(cols, f, (_) => 1),
          sub: 'Match every pair to finish',
          caption: 'Match every pair to win!',
          hud: [
            _Chip('TIME', _time23[dd], _cyan),
            _Chip('PAIRS', '$tot/$tot', _mint),
            _Chip('MOVES', '${tot + 4}', _magenta),
            const _Chip('STREAK', '3', _gold),
          ],
        ),
      ];
    },
  ),

  // ----- Level 4 -----
  _TutorialPage(
    emoji: '🔮',
    title: 'LEVEL 4: PATTERN LOGIC',
    goal: 'Find what comes next in each pattern.',
    diffs: const [
      _Diff('∞', '5 questions. No timer.'),
      _Diff('15s', '7 questions. 15 seconds each.'),
      _Diff('10s', '10 questions. 10 seconds each.'),
    ],
    hud: (dd) => dd == 0
        ? const [_Chip('XP', '0', _gold), _Chip('STREAK', '0', _gold), _Chip('BEST', '0', _gold)]
        : [
            _Chip('TIME', dd == 1 ? '15s' : '10s', _cyan),
            const _Chip('XP', '0', _gold),
            const _Chip('STREAK', '0', _gold),
            const _Chip('BEST', '0', _gold),
          ],
    steps: (dd) {
      final n = const ['1/5', '1/7', '1/10'][dd];
      return [
        _Step(
          label: 'QUESTION $n',
          labelColor: _cyan,
          visual: _qbox('2 → 6 → 12 → 20 → ?', size: 17),
          sub: 'Look at the numbers',
          caption: 'Look at the pattern.',
        ),
        _Step(
          label: 'QUESTION $n',
          labelColor: _cyan,
          visual: _col([
            _qbox('2 → 6 → 12 → 20 → ?', size: 17),
            _t('+4 · +6 · +8 · +10 = ?', size: 15, color: _gold, w: FontWeight.bold),
          ]),
          sub: 'What is the secret rule?',
          caption: 'Find the secret rule (adding more each time).',
        ),
        _Step(
          label: 'QUESTION $n',
          labelColor: _cyan,
          visual: _col([
            _qbox('2 → 6 → 12 → 20 → ?', size: 17),
            _opts(const ['24', '28', '30', '32'], 2),
            _t('Correct! ✓', size: 13),
          ]),
          sub: 'Green means correct',
          caption: 'Tap the answer that comes next.',
        ),
      ];
    },
  ),

  // ----- Level 5 -----
  _TutorialPage(
    emoji: '⭐',
    title: 'LEVEL 5: MEMORY MATRIX',
    goal: 'Remember where the glowing stars were.',
    diffs: const [
      _Diff('∞', '5 rounds. No timer.'),
      _Diff('30s', '7 rounds. 30 seconds.'),
      _Diff('20s', '10 rounds. 20 seconds.'),
    ],
    hud: (dd) => [
      _Chip(dd == 0 ? 'NO TIMER' : 'TIME', const ['∞', '30s', '20s'][dd], _cyan),
      _Chip('ROUND', '1/${const [5, 7, 10][dd]}', _magenta),
      const _Chip('XP', '0', _gold),
      const _Chip('STREAK', '0', _gold),
    ],
    steps: (dd) => [
      _Step(
        label: 'MEMORIZE THE TILES!',
        labelColor: _amber,
        visual: _tiles(3, const [3, 4, 7, 8], 150),
        sub: 'Remember which tiles are glowing. Showing for 5 seconds',
        caption: 'Watch the tiles glow with stars.',
      ),
      _Step(
        label: 'YOUR TURN!',
        labelColor: _amber,
        visual: _tiles(3, const [], 150),
        sub: 'Tap the 4 tiles you remember',
        caption: 'The stars disappear!',
      ),
      _Step(
        label: 'YOUR TURN!',
        labelColor: _amber,
        visual: _tiles(3, const [3, 4], 150),
        sub: 'Correct tiles: 2/4',
        caption: 'Tap the tiles where the stars were.',
      ),
      _Step(
        label: 'ROUND 2',
        labelColor: _amber,
        visual: _tiles(4, const [0, 5, 6, 11, 14], 150),
        sub: 'More stars and a bigger grid!',
        caption: 'Each round adds more stars.',
        hud: [
          const _Chip('TIME', '∞', _cyan),
          const _Chip('ROUND', '2', _magenta),
          const _Chip('XP', '10', _gold),
          const _Chip('STREAK', '1', _gold),
        ],
      ),
    ],
  ),

  // ----- Level 6 -----
  _TutorialPage(
    emoji: '🕵️',
    title: 'LEVEL 6: LOGIC DETECTIVE',
    goal: 'Solve the mystery case.',
    diffs: const [
      _Diff('∞', 'Unlimited time to answer.'),
      _Diff('50s', '50 seconds to answer.'),
      _Diff('20s', '20 seconds to answer.'),
    ],
    hud: (dd) => [
      _Chip('TIME', const ['∞', '50s', '20s'][dd], _cyan),
      const _Chip('LEVEL', '6', _magenta),
      const _Chip('XP', '0', _gold),
    ],
    steps: (dd) => [
      _Step(
        label: 'CURRENT CASE',
        labelColor: _amber,
        visual: _col([
          Container(
            width: 220,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white30),
            ),
            child: const Text('📁 The Garden Mystery',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(
            width: 220,
            child: Text(
              'THE MYSTERY\nThe watering can has been moved from its usual place. Use the evidence to work out who most likely moved it.',
              style: TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
            ),
          ),
        ]),
        sub: 'Read the story first',
        caption: 'Read the story of the mystery.',
      ),
      _Step(
        label: 'INSPECT THE IMAGE',
        labelColor: _cyan,
        visual: _garden(),
        sub: 'Tap the picture. Pinch to zoom!',
        caption: 'Tap the picture to look closer.',
      ),
      _Step(
        label: 'EVIDENCE & CLUES',
        labelColor: _amber,
        visual: _col([
          _ev(1, 'The watering can was beside the flowerpots earlier.'),
          _ev(2, 'Muddy footprints lead from the garden gate.'),
          _ev(3, 'Leo was the only student seen entering the garden.'),
        ], gap: 5),
        sub: 'Read every clue',
        caption: 'Read all the evidence and clues.',
      ),
      _Step(
        label: 'WHO OR WHAT IS THE ANSWER?',
        labelColor: _cyan,
        visual: _col([
          _ans('A', 'Leo', good: true),
          _ans('B', 'The librarian'),
          _ans('C', 'The science teacher'),
          _ans('D', 'A student who never entered'),
        ], gap: 4),
        sub: 'Pick the answer the clues point to',
        caption: 'Choose the answer the evidence points to.',
      ),
    ],
  ),

  // ----- Level 7 -----
  _TutorialPage(
    emoji: '🖼️',
    title: 'LEVEL 7: WORD QUEST',
    goal: 'Guess the one word that links 4 pictures.',
    diffs: const [
      _Diff('∞', '5 rounds. 5 hints. No timer.'),
      _Diff('30s', '7 rounds. 3 hints. 30 seconds.'),
      _Diff('10s', '10 rounds. 1 hint. 10 seconds.'),
    ],
    hud: (dd) => [
      _Chip('TIME', const ['∞', '30s', '10s'][dd], _cyan),
      _Chip('SOLVED', '0/${const [5, 7, 10][dd]}', _mint),
      const _Chip('XP', '0', _gold),
      const _Chip('STREAK', '0', _gold),
    ],
    steps: (dd) {
      final h = const ['5/5', '3/3', '1/1'][dd];
      return [
        _Step(
          label: 'Word Quest',
          labelColor: _cyan,
          visual: _col([_pics(), _clue('A food commonly made from flour.')]),
          sub: 'Tap a picture to zoom in',
          caption: 'Look at the 4 pictures. Read the clue if you need help.',
        ),
        _Step(
          label: 'YOUR ANSWER',
          labelColor: _amber,
          visual: _col([
            _answerBoxes('BR___'),
            _t('CHOOSE YOUR LETTERS', size: 11, color: Colors.white70, w: FontWeight.normal),
            _letters(const ['E', 'D', 'B', 'M', 'S', 'R', 'N', 'I', 'D', 'A', 'R', 'T'], const {2, 5}),
          ]),
          sub: 'Tap a filled box to take a letter back',
          caption: 'Tap letters to fill the answer boxes.',
        ),
        _Step(
          label: 'NEED A HINT?',
          labelColor: _amber,
          visual: _col([
            _answerBoxes('BRE__', hintIdx: 2),
            _pill('💡 USE HINT ($h)', const Color(0xFFF5A623), width: 190),
            _t('Hint revealed!', size: 12, w: FontWeight.normal),
          ], gap: 9),
          sub: 'A hint reveals one correct letter',
          caption: 'Stuck? Use a hint to reveal one correct letter.',
        ),
        _Step(
          label: '🎉 YOU GOT IT!',
          labelColor: _mint,
          visual: _col([
            _answerBoxes('BREAD', solved: const Color(0xFF1DA38E)),
            _pill('+5 XP', const Color(0xFF2EBD59), size: 14),
          ], gap: 10),
          sub: 'Solved 1 word!',
          caption: 'Fill every box with the right word.',
        ),
      ];
    },
  ),

  // ----- Level 8 -----
  _TutorialPage(
    emoji: '🧭',
    title: 'LEVEL 8: PATH FINDER',
    goal: 'Remember the maze and trace the path.',
    diffs: const [
      _Diff('45s', '3 mazes. 3 hearts. 45 seconds.'),
      _Diff('45s', '3 mazes. Trickier paths.'),
      _Diff('45s', '5 mazes. The hardest paths.'),
    ],
    hud: (dd) => [
      _Chip('ROUND', '1/${dd == 2 ? 5 : 3}', _magenta),
      const _Chip('TIME', '45s', _cyan),
      const _Chip('XP', '0', _gold),
      const _Chip('LIVES', '❤️❤️❤️', Colors.white),
    ],
    steps: (dd) => [
      _Step(
        label: 'MEMORIZE THE MAZE',
        labelColor: _amber,
        visual: _mazeView(show: true),
        sub: 'Memorize the route before the maze hides',
        caption: 'Memorize the maze and the route from S to F.',
      ),
      _Step(
        label: 'TRACE TO THE FINISH',
        labelColor: _cyan,
        visual: _mazeView(show: false),
        sub: 'Drag from START (S) through the corridors to FINISH (F)',
        caption: 'The maze hides after a few seconds!',
      ),
      _Step(
        label: 'TRACE TO THE FINISH',
        labelColor: _cyan,
        visual: _mazeView(show: false, upto: 7),
        sub: 'Keep dragging along the corridor',
        caption: 'Drag your finger from S through the corridors to F.',
      ),
      _Step(
        label: 'OUCH! WRONG PATH',
        labelColor: const Color(0xFFFF8A80),
        visual: _mazeView(show: false, upto: 3, bad: true),
        sub: 'You lose 1 heart. At 0 hearts, game over.',
        caption: 'Choosing a wrong path costs 1 heart.',
        hud: [
          const _Chip('ROUND', '1/3', _magenta),
          const _Chip('TIME', '31s', _cyan),
          const _Chip('XP', '0', _gold),
          const _Chip('LIVES', '❤️❤️🖤', Colors.white),
        ],
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class HowToPlayScreen extends StatefulWidget {
  final int initialPage;

  const HowToPlayScreen({super.key, this.initialPage = 0});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialPage.clamp(0, _pages.length - 1);
    _controller = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFirst = _current == 0;
    final bool isLast = _current == _pages.length - 1;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0E4E), Color(0xFF811252), Color(0xFF2E0854)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const Expanded(
                      child: Text(
                        'HOW TO PLAY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (context, index) =>
                      _LevelPage(page: _pages[index]),
                ),
              ),

              // Dots
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final bool active = i == _current;
                    return GestureDetector(
                      onTap: () => _go(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              active ? const Color(0xFFFFD700) : Colors.white30,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: _navButton(
                        label: 'Previous',
                        icon: Icons.arrow_back_rounded,
                        color: const Color(0xFF9B8AD6),
                        enabled: !isFirst,
                        onPressed: () => _go(_current - 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _navButton(
                        label: isLast ? 'Done' : 'Next',
                        icon: isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        color: const Color(0xFFFFD700),
                        textColor: const Color(0xFF3B0B46),
                        iconAfterText: !isLast,
                        onPressed: () =>
                            isLast ? Navigator.pop(context) : _go(_current + 1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    Color textColor = Colors.white,
    bool enabled = true,
    bool iconAfterText = false,
  }) {
    final iconWidget = Icon(icon, color: textColor, size: 20);
    final textWidget = Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                offset: const Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: iconAfterText
                ? [textWidget, const SizedBox(width: 8), iconWidget]
                : [iconWidget, const SizedBox(width: 8), textWidget],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One level page: auto-playing demo + difficulty tabs
// ---------------------------------------------------------------------------
class _LevelPage extends StatefulWidget {
  final _TutorialPage page;
  const _LevelPage({required this.page});

  @override
  State<_LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<_LevelPage> {
  int _k = 0;
  int _dd = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (!mounted) return;
      final n = widget.page.steps(_dd).length;
      setState(() => _k = (_k + 1) % n);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _pickStep(int n) {
    setState(() => _k = n);
    _startTimer();
  }

  void _pickDiff(int n) {
    setState(() {
      _dd = n;
      _k = 0;
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.page;
    final steps = p.steps(_dd);
    if (_k >= steps.length) _k = 0;
    final s = steps[_k];
    final hud = s.hud ?? p.hud(_dd);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // Title pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold, width: 1.5),
            ),
            child: Text(
              '${p.emoji}  ${p.title}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _gold,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Goal
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_rounded, color: Colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.goal,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Demo card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30, width: 2),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black45,
                    blurRadius: 15,
                    offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                if (hud != null) _hudRow(hud),
                const SizedBox(height: 10),
                Text(
                  s.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: s.labelColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 150),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        key: ValueKey('${_dd}_$_k'),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: FittedBox(
                            fit: BoxFit.scaleDown, child: s.visual),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 42),
                  child: Center(
                    child: Text(
                      s.caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: GestureDetector(
                          onTap: () => _pickStep(i),
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _k
                                  ? _gold
                                  : Colors.white.withValues(alpha: 0.2),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: i == _k ? _deep : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Difficulty tabs
          if (p.diffs != null) ...[
            const SizedBox(height: 10),
            _difficultyBox(p.diffs!),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _hudRow(List<_Chip> chips) {
    final out = <Widget>[];
    for (int i = 0; i < chips.length; i++) {
      if (i > 0) out.add(const SizedBox(width: 5));
      final c = chips[i];
      out.add(Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              Text(c.label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text(c.value,
                  style: TextStyle(
                      color: c.color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ));
    }
    return Row(children: out);
  }

  Widget _difficultyBox(List<_Diff> diffs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.speed_rounded, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 6),
              Text('Tap a difficulty',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int j = 0; j < 3; j++) ...[
                if (j > 0) const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDiff(j),
                    child: Opacity(
                      opacity: j == _dd ? 1 : 0.6,
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _diffColors[j],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: j == _dd ? _gold : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '${_diffEmoji[j]} ${_diffNames[j]}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 84),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _diffColors[_dd],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  diffs[_dd].big,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  diffs[_dd].text,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}