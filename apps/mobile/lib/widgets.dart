import 'package:flutter/material.dart';
import 'theme.dart';

class YellowCta extends StatelessWidget {
  const YellowCta({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onPressed,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Pb.yellow,
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Pb.ink)),
      ),
    );
  }
}

class RoundAction extends StatelessWidget {
  const RoundAction({super.key, required this.icon, required this.color, this.onTap, this.size = 64});
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Icon(icon, color: color, size: size * 0.42),
      ),
    );
  }
}

class RolePill extends StatelessWidget {
  const RolePill({super.key, required this.host, required this.onChanged, required this.renterLabel, required this.hostLabel});
  final bool host;
  final ValueChanged<bool> onChanged;
  final String renterLabel;
  final String hostLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(renterLabel, !host, () => onChanged(false)),
          _seg(hostLabel, host, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _seg(String label, bool on, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: on ? Pb.yellow : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    );
  }
}

class PhotoCard extends StatelessWidget {
  const PhotoCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.badge,
    this.stamp,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final String? badge;
  final String? stamp;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE8D9B8)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.transparent, Color(0xCC000000)],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Pb.yellow, borderRadius: BorderRadius.circular(20)),
                child: Text(badge!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
          if (stamp != null)
            Positioned(
              top: 28,
              right: 20,
              child: Transform.rotate(
                angle: -0.35,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: stamp == 'BOOK' ? Pb.stampGreen : Pb.stampSkip,
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stamp!,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      color: stamp == 'BOOK' ? Pb.stampGreen : Pb.stampSkip,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SpotDeck extends StatefulWidget {
  const SpotDeck({
    super.key,
    required this.spots,
    required this.onBook,
    required this.onSkip,
    required this.bookLabel,
    required this.skipLabel,
  });

  final List<Map<String, dynamic>> spots;
  final void Function(Map<String, dynamic>) onBook;
  final void Function(Map<String, dynamic>) onSkip;
  final String bookLabel;
  final String skipLabel;

  @override
  State<SpotDeck> createState() => _SpotDeckState();
}

class _SpotDeckState extends State<SpotDeck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  double dx = 0;
  double dy = 0;
  bool _isAnimating = false;

  late Animation<Offset> _offsetAnim;
  late Animation<double> _rotationAnim;

  Map<String, dynamic>? get top => widget.spots.isEmpty ? null : widget.spots.first;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _swipe(bool right) {
    if (_isAnimating || top == null) return;
    _isAnimating = true;

    final startOffset = Offset(dx, dy);
    final endOffset = Offset(right ? 550.0 : -550.0, dy * 0.5);
    final startRot = dx / 420.0;
    final endRot = right ? 0.65 : -0.65;

    _offsetAnim = Tween<Offset>(begin: startOffset, end: endOffset).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _rotationAnim = Tween<double>(begin: startRot, end: endRot).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward(from: 0).then((_) {
      final s = top;
      if (s != null) {
        if (right) {
          widget.onBook(s);
        } else {
          widget.onSkip(s);
        }
      }
      dx = 0;
      dy = 0;
      _isAnimating = false;
      setState(() {});
    });
  }

  void _snapBack() {
    if (_isAnimating) return;
    _isAnimating = true;

    final startOffset = Offset(dx, dy);
    final endOffset = Offset.zero;
    final startRot = dx / 420.0;
    const endRot = 0.0;

    _offsetAnim = Tween<Offset>(begin: startOffset, end: endOffset).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _rotationAnim = Tween<double>(begin: startRot, end: endRot).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward(from: 0).then((_) {
      dx = 0;
      dy = 0;
      _isAnimating = false;
      setState(() {});
    });
  }

  double get swipeProgress {
    if (_isAnimating) {
      return (_offsetAnim.value.dx.abs() / 150.0).clamp(0.0, 1.0);
    }
    return (dx.abs() / 150.0).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.spots.isEmpty) {
      return const Center(child: Text('No spots nearby — try the map.'));
    }

    final back = widget.spots.length > 1 ? widget.spots[1] : null;

    return Column(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final double scale = 0.95 + 0.05 * swipeProgress;
              final double opacity = 0.8 + 0.2 * swipeProgress;

              Widget topCard = PhotoCard(
                imageUrl: _photo(top!),
                title: '${top!['area']} · ${(top!['distanceKm'] ?? '').toString()} km',
                subtitle: '৳${top!['monthlyPrice']} / month · ${top!['covered'] == true ? 'Covered' : 'Open'}',
                badge: top!['verified'] == true ? 'Verified' : null,
                stamp: _isAnimating
                    ? (_offsetAnim.value.dx > 40 ? 'BOOK' : (_offsetAnim.value.dx < -40 ? 'SKIP' : null))
                    : (dx > 40 ? 'BOOK' : (dx < -40 ? 'SKIP' : null)),
              );

              Widget animatedTopCard;
              if (_isAnimating) {
                animatedTopCard = Transform.translate(
                  offset: _offsetAnim.value,
                  child: Transform.rotate(
                    angle: _rotationAnim.value,
                    child: topCard,
                  ),
                );
              } else {
                animatedTopCard = Transform.translate(
                  offset: Offset(dx, dy * 0.25),
                  child: Transform.rotate(
                    angle: dx / 420.0,
                    child: topCard,
                  ),
                );
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (back != null)
                    Positioned.fill(
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: PhotoCard(
                            imageUrl: _photo(back),
                            title: back['area']?.toString() ?? '',
                            subtitle: '৳${back['monthlyPrice']} / mo',
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: GestureDetector(
                      onPanUpdate: _isAnimating
                          ? null
                          : (d) => setState(() {
                                dx += d.delta.dx;
                                dy += d.delta.dy;
                              }),
                      onPanEnd: _isAnimating
                          ? null
                          : (_) {
                              if (dx.abs() > 115) {
                                _swipe(dx > 0);
                              } else {
                                _snapBack();
                              }
                            },
                      child: animatedTopCard,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            RoundAction(
              icon: Icons.close,
              color: Pb.stampSkip,
              onTap: () => _swipe(false),
            ),
            RoundAction(
              icon: Icons.star_rounded,
              color: Pb.yellowDeep,
              size: 54,
              onTap: () {
                if (top != null) widget.onBook(top!);
              },
            ),
            RoundAction(
              icon: Icons.favorite_rounded,
              color: Pb.stampGreen,
              onTap: () => _swipe(true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('${widget.bookLabel} · ${widget.skipLabel}', style: const TextStyle(color: Pb.muted, fontSize: 12)),
      ],
    );
  }

  String _photo(Map s) {
    final photos = s['photos'];
    if (photos is List && photos.isNotEmpty) return photos.first.toString();
    return 'https://images.unsplash.com/photo-1590674899484-d5640e854abe?w=1200';
  }
}
