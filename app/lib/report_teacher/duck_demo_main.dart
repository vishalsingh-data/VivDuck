import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import 'widgets/duck_avatar.dart';

void main() {
  runApp(const DuckDemoApp());
}

class DuckDemoApp extends StatefulWidget {
  const DuckDemoApp({super.key});

  @override
  State<DuckDemoApp> createState() => _DuckDemoAppState();
}

class _DuckDemoAppState extends State<DuckDemoApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VivDuck Avatar Mood Demo',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: DuckDemoScreen(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class DuckDemoScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const DuckDemoScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<DuckDemoScreen> createState() => _DuckDemoScreenState();
}

class _DuckDemoScreenState extends State<DuckDemoScreen> {
  late DuckMood _currentMood;
  late bool _disableAnimations;
  int _triggerNonce = 0;

  @override
  void initState() {
    super.initState();
    final paramMood = Uri.base.queryParameters['mood']?.toLowerCase();
    _currentMood = switch (paramMood) {
      'thinking' => DuckMood.thinking,
      'asking' => DuckMood.asking,
      'happy' => DuckMood.happy,
      _ => DuckMood.idle,
    };
    _disableAnimations = Uri.base.queryParameters['disableAnimations'] == 'true';
  }

  void _setMood(DuckMood mood) {
    setState(() {
      _currentMood = mood;
      _triggerNonce++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: _disableAnimations,
      ),
      child: Scaffold(
        backgroundColor: dark ? VD.darkBg : VD.cream,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    _buildHeader(context, dark),
                    const SizedBox(height: 28),

                    // Central Duck Display Card
                    _buildAvatarCard(context, dark),
                    const SizedBox(height: 28),

                    // Mood Selector Buttons Card
                    _buildControlsCard(context, dark),
                    const SizedBox(height: 24),

                    // Mood Specifications Table Card
                    _buildSpecCard(context, dark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool dark) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: VD.yellowSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VD.yellow, width: 1.5),
          ),
          child: const Center(
            child: Text(
              '🦆',
              style: TextStyle(fontSize: 24),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VivDuck Mascot Demo',
                style: GoogleFonts.fredoka(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : VD.ink,
                ),
              ),
              Text(
                'Single-controller mood reactions & accessibility',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: dark ? const Color(0xFFA3ABC6) : VD.inkSoft,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: dark ? 'Switch to Light mode' : 'Switch to Dark mode',
          onPressed: widget.onToggleTheme,
          icon: Icon(
            dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarCard(BuildContext context, bool dark) {
    final spec = _moodSpec(_currentMood);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
        color: dark ? VD.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(VD.radius),
        border: Border.all(
          color: dark ? VD.darkLine : VD.line,
          width: 1.5,
        ),
        boxShadow: [
          if (!dark)
            BoxShadow(
              color: const Color(0xFFB08A2E).withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        children: [
          // Current Mood Pill
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: spec.color.withValues(alpha: dark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: spec.color.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(spec.icon, size: 18, color: spec.color),
                const SizedBox(width: 8),
                Text(
                  spec.title.toUpperCase(),
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: spec.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Description of current reaction
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              spec.description,
              key: ValueKey('${spec.title}-$_disableAnimations'),
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: dark ? const Color(0xFFE2E6F0) : VD.ink,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Pond & Duck container with generous vertical room for jumping
          Container(
            width: double.infinity,
            height: 230,
            alignment: Alignment.bottomCenter,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.45),
                radius: 0.75,
                colors: [
                  (dark ? const Color(0xFF1E3547) : const Color(0xFFE0F4F2))
                      .withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: DuckAvatar(
                key: ValueKey('duck-$_currentMood-$_triggerNonce'),
                size: 150,
                mood: _currentMood,
                float: false,
              ),
            ),
          ),

          // Disable Animations Warning Banner
          if (_disableAnimations)
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: VD.partial.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VD.partial.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.motion_photos_off_rounded,
                      size: 18, color: VD.partial),
                  const SizedBox(width: 8),
                  Text(
                    'MediaQuery.disableAnimations = true (Showing still image)',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: VD.partial,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlsCard(BuildContext context, bool dark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: dark ? VD.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(VD.radius),
        border: Border.all(
          color: dark ? VD.darkLine : VD.line,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Select Mood',
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : VD.ink,
                ),
              ),
              const Spacer(),
              // Accessibility Toggle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Disable Animations',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: dark ? const Color(0xFFA3ABC6) : VD.inkSoft,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    key: const Key('disable-animations-toggle'),
                    value: _disableAnimations,
                    activeThumbColor: VD.teal,
                    onChanged: (val) {
                      setState(() => _disableAnimations = val);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4 Mood Buttons Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 580;
              final buttons = [
                _buildMoodButton(
                  mood: DuckMood.idle,
                  label: 'Idle',
                  subtitle: 'Breathing (3.0s)',
                  icon: Icons.air_rounded,
                  color: VD.teal,
                  keyId: 'mood-idle-button',
                  dark: dark,
                ),
                _buildMoodButton(
                  mood: DuckMood.thinking,
                  label: 'Thinking',
                  subtitle: 'Tilt ±6° (0.9s)',
                  icon: Icons.psychology_rounded,
                  color: const Color(0xFF8B5CF6),
                  keyId: 'mood-thinking-button',
                  dark: dark,
                ),
                _buildMoodButton(
                  mood: DuckMood.asking,
                  label: 'Asking',
                  subtitle: '1 Hop (16px)',
                  icon: Icons.help_outline_rounded,
                  color: VD.orange,
                  keyId: 'mood-asking-button',
                  dark: dark,
                ),
                _buildMoodButton(
                  mood: DuckMood.happy,
                  label: 'Happy',
                  subtitle: '3 Jumps (40px)',
                  icon: Icons.celebration_rounded,
                  color: VD.solid,
                  keyId: 'mood-happy-button',
                  dark: dark,
                ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    for (int i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: buttons[i]),
                    ],
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: buttons[0]),
                        const SizedBox(width: 12),
                        Expanded(child: buttons[1]),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: buttons[2]),
                        const SizedBox(width: 12),
                        Expanded(child: buttons[3]),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // Replay hint
          Center(
            child: TextButton.icon(
              onPressed: () => _setMood(_currentMood),
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: Text(
                'Replay active mood animation',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodButton({
    required DuckMood mood,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String keyId,
    required bool dark,
  }) {
    final isSelected = _currentMood == mood;

    return InkWell(
      key: Key(keyId),
      onTap: () => _setMood(mood),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: dark ? 0.28 : 0.15)
              : (dark ? const Color(0xFF14192B) : const Color(0xFFF9F6EE)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (dark ? VD.darkLine : VD.line),
            width: isSelected ? 2.2 : 1.2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected
                  ? color
                  : (dark ? const Color(0xFFA3ABC6) : VD.inkSoft),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.fredoka(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (dark ? Colors.white : VD.ink)
                    : (dark ? const Color(0xFFC7CDDE) : VD.ink),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? color
                    : (dark ? const Color(0xFF828AA6) : VD.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecCard(BuildContext context, bool dark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (dark ? VD.darkSurface : Colors.white).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(VD.radius),
        border: Border.all(
          color: dark ? VD.darkLine : VD.line,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Specification Checklist',
            style: GoogleFonts.fredoka(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: dark ? Colors.white : VD.ink,
            ),
          ),
          const SizedBox(height: 12),
          _buildSpecRow(
            'idle',
            'Slow breathing scale 1.0 → 1.03, repeating every 3s',
            _currentMood == DuckMood.idle,
            dark,
          ),
          _buildSpecRow(
            'thinking',
            'Head-tilt rotation 6° each way (±6°), repeating every 0.9s',
            _currentMood == DuckMood.thinking,
            dark,
          ),
          _buildSpecRow(
            'asking',
            'One small hop of 16 px, then still',
            _currentMood == DuckMood.asking,
            dark,
          ),
          _buildSpecRow(
            'happy',
            'Three jumps of 40 px',
            _currentMood == DuckMood.happy,
            dark,
          ),
          _buildSpecRow(
            'accessibility',
            'If MediaQuery.disableAnimations is true, show still image',
            _disableAnimations,
            dark,
          ),
          _buildSpecRow(
            'lifecycle',
            'Single AnimationController created and disposed',
            true,
            dark,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(
    String label,
    String desc,
    bool active,
    bool dark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: active
                ? VD.solid
                : (dark ? const Color(0xFF6B7280) : const Color(0xFFB0B5C4)),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active
                  ? (dark ? Colors.white : VD.ink)
                  : (dark ? const Color(0xFF8B92A7) : VD.inkSoft),
            ),
          ),
          Expanded(
            child: Text(
              desc,
              style: GoogleFonts.nunito(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? (dark ? Colors.white : VD.ink)
                    : (dark ? const Color(0xFF8B92A7) : VD.inkSoft),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _MoodSpec _moodSpec(DuckMood mood) {
    switch (mood) {
      case DuckMood.idle:
        return const _MoodSpec(
          title: 'Idle',
          description:
              'Slow breathing scale from 1.0 to 1.03, repeating every 3 seconds',
          icon: Icons.air_rounded,
          color: VD.teal,
        );
      case DuckMood.thinking:
        return const _MoodSpec(
          title: 'Thinking',
          description:
              'Head-tilt rotation of 6 degrees each way, repeating every 0.9 seconds',
          icon: Icons.psychology_rounded,
          color: Color(0xFF8B5CF6),
        );
      case DuckMood.asking:
        return const _MoodSpec(
          title: 'Asking',
          description: 'One small hop of 16 px, then still',
          icon: Icons.help_outline_rounded,
          color: VD.orange,
        );
      case DuckMood.happy:
        return const _MoodSpec(
          title: 'Happy',
          description: 'Three jumps of 40 px',
          icon: Icons.celebration_rounded,
          color: VD.solid,
        );
      default:
        return const _MoodSpec(
          title: 'Idle',
          description:
              'Slow breathing scale from 1.0 to 1.03, repeating every 3 seconds',
          icon: Icons.air_rounded,
          color: VD.teal,
        );
    }
  }
}

class _MoodSpec {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _MoodSpec({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
