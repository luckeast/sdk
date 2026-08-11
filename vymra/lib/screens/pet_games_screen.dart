import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../providers/pet_profile_provider.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

/// Mini game hub attached to the growth journey screen.
class PetGamesScreen extends StatelessWidget {
  const PetGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_GameEntry> games = <_GameEntry>[
      _GameEntry(
        title: 'Pet Puzzle',
        subtitle: 'Import a photo, shuffle the tiles, and rebuild the moment.',
        icon: Icons.grid_view_rounded,
        colors: const <Color>[Color(0xFFF4A261), Color(0xFFE76F51)],
        builder: (_) => const PetPuzzleScreen(),
      ),
      _GameEntry(
        title: 'Treat Match',
        subtitle:
            'Flip pairs of pet toys and snacks before the board goes quiet.',
        icon: Icons.auto_awesome_motion_rounded,
        colors: const <Color>[Color(0xFF2A9D8F), Color(0xFF5DB7AE)],
        builder: (_) => const TreatMatchScreen(),
      ),
      _GameEntry(
        title: 'Nose Boop Dash',
        subtitle:
            'Boop the playful nose prints as quickly as you can in 20 seconds.',
        icon: Icons.ads_click_rounded,
        colors: const <Color>[Color(0xFFE9C46A), Color(0xFFF4A261)],
        builder: (_) => const NoseBoopDashScreen(),
      ),
      _GameEntry(
        title: 'Care Rush',
        subtitle:
            'Read your pet mood and pick the best care item for each round.',
        icon: Icons.pets_rounded,
        colors: const <Color>[Color(0xFF264653), Color(0xFF2A9D8F)],
        builder: (_) => const CareRushScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Pet Playroom'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[
                  Color(0xFFFFE0C2),
                  Color(0xFFF7F5F3),
                  Color(0xFFD8F3EE),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.tr('Small games for pet parents'),
                  style: AppTextStyles.headline.copyWith(
                    color: AppColors.secondaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Relax between care tasks with four light pet-themed mini games. Puzzle play uses your own pet photos.',
                  ),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.secondaryDark.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...games.map(
            (_GameEntry game) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _GameCard(entry: game),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final WidgetBuilder builder;

  const _GameEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.builder,
  });
}

class _GameCard extends StatelessWidget {
  final _GameEntry entry;

  const _GameCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(builder: entry.builder),
        );
      },
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: entry.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(entry.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.tr(entry.title),
                      style: AppTextStyles.title.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(entry.subtitle),
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rebuild a pet photo puzzle from shuffled tiles.
class PetPuzzleScreen extends StatefulWidget {
  const PetPuzzleScreen({super.key});

  @override
  State<PetPuzzleScreen> createState() => _PetPuzzleScreenState();
}

class _PetPuzzleScreenState extends State<PetPuzzleScreen> {
  final ImageService _imageService = ImageService();
  final math.Random _random = math.Random();
  final Map<int, int> _placements = <int, int>{};
  final Map<int, int> _pieceRotations = <int, int>{};
  final List<int> _trayPieces = <int>[];

  File? _selectedImage;
  int _gridSize = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileImage();
    });
  }

  Future<void> _loadProfileImage() async {
    final PetProfileProvider profileProvider = context
        .read<PetProfileProvider>();
    final String avatarPath = profileProvider.profile?.avatarPath ?? '';
    if (avatarPath.isEmpty) {
      return;
    }

    final File? avatarFile = await _imageService.loadImage(avatarPath);
    if (!mounted || avatarFile == null) {
      return;
    }

    setState(() {
      _selectedImage = avatarFile;
      _resetBoard();
    });
  }

  Future<void> _pickImage() async {
    final File? imageFile = await _imageService.pickFromGallery();
    if (!mounted || imageFile == null) {
      return;
    }

    setState(() {
      _selectedImage = imageFile;
      _resetBoard();
    });
  }

  void _setGridSize(int size) {
    if (_gridSize == size) {
      return;
    }

    setState(() {
      _gridSize = size;
      _resetBoard();
    });
  }

  void _resetBoard() {
    final int total = _gridSize * _gridSize;
    final List<int> shuffled = List<int>.generate(total, (int index) => index);
    do {
      shuffled.shuffle(_random);
    } while (_isSolvedOrder(shuffled) && total > 1);

    _placements.clear();
    _pieceRotations.clear();
    _trayPieces
      ..clear()
      ..addAll(shuffled);
    for (int pieceId = 0; pieceId < total; pieceId++) {
      _pieceRotations[pieceId] = _random.nextInt(4);
    }
  }

  bool _isSolvedOrder(List<int> values) {
    for (int index = 0; index < values.length; index++) {
      if (values[index] != index) {
        return false;
      }
    }
    return true;
  }

  void _applyMove(_PuzzleMove move, int targetSlot) {
    setState(() {
      final int? targetPiece = _placements[targetSlot];
      final int? originSlot = move.originSlot;

      if (originSlot != null) {
        _placements.remove(originSlot);
      } else {
        _trayPieces.remove(move.pieceId);
      }

      if (targetPiece != null && targetPiece != move.pieceId) {
        if (originSlot != null && originSlot != targetSlot) {
          _placements[originSlot] = targetPiece;
        } else if (!_trayPieces.contains(targetPiece)) {
          _trayPieces.add(targetPiece);
        }
      }

      _placements[targetSlot] = move.pieceId;
    });

    _checkPuzzleSolved();
  }

  void _moveBackToTray(_PuzzleMove move) {
    setState(() {
      if (move.originSlot != null) {
        _placements.remove(move.originSlot);
      }
      if (!_trayPieces.contains(move.pieceId)) {
        _trayPieces.add(move.pieceId);
      }
    });
  }

  Future<void> _checkPuzzleSolved() async {
    final int total = _gridSize * _gridSize;
    if (_placements.length != total) {
      return;
    }

    for (int index = 0; index < total; index++) {
      if (_placements[index] != index) {
        return;
      }
      if ((_pieceRotations[index] ?? 0) % 4 != 0) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(context.tr('Puzzle Completed')),
          content: Text(
            context.tr(
              'Your pet portrait is back together. Try a larger grid for a tougher challenge.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('Keep Playing')),
            ),
          ],
        );
      },
    );
  }

  void _rotatePiece(int pieceId) {
    setState(() {
      _pieceRotations[pieceId] = ((_pieceRotations[pieceId] ?? 0) + 1) % 4;
    });
    _checkPuzzleSolved();
  }

  Future<void> _showReferenceImage() async {
    final File? imageFile = _selectedImage;
    if (imageFile == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: <Widget>[
                InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.file(imageFile, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final File? imageFile = _selectedImage;
    final List<int> trayPieces = List<int>.from(_trayPieces)..sort();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Pet Puzzle'))),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: imageFile == null
                  ? _PuzzleSetupPanel(
                      gridSize: _gridSize,
                      onPickImage: _pickImage,
                      onGridSelected: _setGridSize,
                    )
                  : Column(
                      children: <Widget>[
                        _SectionHeader(
                          title: 'Tile tray',
                          subtitle:
                              'Tap a piece to rotate it. Long press and drag to place or swap it.',
                          trailing: Text(
                            context.tr(
                              '{count} left',
                              params: <String, String>{
                                'count': '${_trayPieces.length}',
                              },
                            ),
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 186,
                          child: AppCard(
                            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                            child: DragTarget<_PuzzleMove>(
                              onWillAcceptWithDetails: (_) => true,
                              onAcceptWithDetails:
                                  (DragTargetDetails<_PuzzleMove> details) {
                                    _moveBackToTray(details.data);
                                  },
                              builder:
                                  (
                                    BuildContext context,
                                    List<_PuzzleMove?> candidateData,
                                    List<dynamic> rejectedData,
                                  ) {
                                    final bool isHovering =
                                        candidateData.isNotEmpty;
                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isHovering
                                            ? AppColors.primary.withValues(
                                                alpha: 0.06,
                                              )
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: isHovering
                                              ? AppColors.primary
                                              : AppColors.textDisabled
                                                    .withValues(alpha: 0.35),
                                          width: isHovering ? 1.8 : 1,
                                        ),
                                      ),
                                      child: trayPieces.isEmpty
                                          ? Center(
                                              child: Text(
                                                context.tr(
                                                  'All pieces are on the board.',
                                                ),
                                                style: AppTextStyles.caption,
                                              ),
                                            )
                                          : SingleChildScrollView(
                                              child: Wrap(
                                                spacing: 12,
                                                runSpacing: 12,
                                                children: trayPieces
                                                    .map(
                                                      (
                                                        int pieceId,
                                                      ) => _PuzzleDraggableTile(
                                                        move: _PuzzleMove(
                                                          pieceId: pieceId,
                                                          originSlot: null,
                                                        ),
                                                        imageFile: imageFile,
                                                        gridSize: _gridSize,
                                                        extent: 74,
                                                        quarterTurns:
                                                            _pieceRotations[pieceId] ??
                                                            0,
                                                        onRotate: () =>
                                                            _rotatePiece(
                                                              pieceId,
                                                            ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ),
                                    );
                                  },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionHeader(
                          title: 'Puzzle board',
                          subtitle:
                              'The board is larger now, and placed pieces can be re-dragged.',
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: AppCard(
                            padding: const EdgeInsets.all(12),
                            child: LayoutBuilder(
                              builder:
                                  (
                                    BuildContext context,
                                    BoxConstraints constraints,
                                  ) {
                                    final double boardSize = math.min(
                                      constraints.maxWidth,
                                      constraints.maxHeight,
                                    );
                                    return Center(
                                      child: _PuzzleBoard(
                                        boardSize: boardSize,
                                        gridSize: _gridSize,
                                        imageFile: imageFile,
                                        placements: _placements,
                                        pieceRotations: _pieceRotations,
                                        onMove: _applyMove,
                                        onRotate: _rotatePiece,
                                      ),
                                    );
                                  },
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            if (imageFile != null)
              Positioned(
                top: 10,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    GestureDetector(
                      onTap: _showReferenceImage,
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(imageFile, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _pickImage,
                        tooltip: context.tr('Replace puzzle image'),
                        icon: const Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 22,
                          color: AppColors.secondaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PuzzleSetupPanel extends StatelessWidget {
  final int gridSize;
  final VoidCallback onPickImage;
  final ValueChanged<int> onGridSelected;

  const _PuzzleSetupPanel({
    required this.gridSize,
    required this.onPickImage,
    required this.onGridSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.primary,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('Choose a pet photo to build the puzzle.'),
              style: AppTextStyles.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'After import, the setup area hides automatically and only the floating preview remains on top of the board.',
              ),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: <Widget>[
                ...<int>[3, 4, 5].map(
                  (int size) => ChoiceChip(
                    label: Text('${size}x$size'),
                    selected: gridSize == size,
                    onSelected: (_) => onGridSelected(size),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onPickImage,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(context.tr('Import image')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PuzzleMove {
  final int pieceId;
  final int? originSlot;

  const _PuzzleMove({required this.pieceId, required this.originSlot});
}

class _PuzzleDraggableTile extends StatelessWidget {
  final _PuzzleMove move;
  final File imageFile;
  final int gridSize;
  final double extent;
  final int quarterTurns;
  final VoidCallback onRotate;

  const _PuzzleDraggableTile({
    required this.move,
    required this.imageFile,
    required this.gridSize,
    required this.extent,
    required this.quarterTurns,
    required this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    final Widget tile = _PuzzleTileFace(
      imageFile: imageFile,
      pieceId: move.pieceId,
      gridSize: gridSize,
      extent: extent,
      quarterTurns: quarterTurns,
    );

    return GestureDetector(
      onTap: onRotate,
      child: LongPressDraggable<_PuzzleMove>(
        data: move,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: extent, height: extent, child: tile),
        ),
        childWhenDragging: Opacity(
          opacity: 0.24,
          child: SizedBox(width: extent, height: extent, child: tile),
        ),
        child: SizedBox(width: extent, height: extent, child: tile),
      ),
    );
  }
}

class _PuzzleBoard extends StatelessWidget {
  final double boardSize;
  final int gridSize;
  final File imageFile;
  final Map<int, int> placements;
  final Map<int, int> pieceRotations;
  final void Function(_PuzzleMove move, int targetSlot) onMove;
  final ValueChanged<int> onRotate;

  const _PuzzleBoard({
    required this.boardSize,
    required this.gridSize,
    required this.imageFile,
    required this.placements,
    required this.pieceRotations,
    required this.onMove,
    required this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    final double cellSize = boardSize / gridSize;
    final double pieceExtent = cellSize * 1.38;
    final double pieceInset = (pieceExtent - cellSize) / 2;

    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F3EC),
              borderRadius: BorderRadius.circular(24),
            ),
            child: CustomPaint(
              painter: _PuzzleBoardPainter(
                gridSize: gridSize,
                lineColor: AppColors.textDisabled.withValues(alpha: 0.35),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          for (int slotIndex = 0; slotIndex < gridSize * gridSize; slotIndex++)
            Positioned(
              left: (slotIndex % gridSize) * cellSize,
              top: (slotIndex ~/ gridSize) * cellSize,
              width: cellSize,
              height: cellSize,
              child: DragTarget<_PuzzleMove>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails: (DragTargetDetails<_PuzzleMove> details) {
                  onMove(details.data, slotIndex);
                },
                builder:
                    (
                      BuildContext context,
                      List<_PuzzleMove?> candidateData,
                      List<dynamic> rejectedData,
                    ) {
                      final bool isHovering = candidateData.isNotEmpty;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isHovering
                              ? AppColors.secondary.withValues(alpha: 0.08)
                              : Colors.transparent,
                        ),
                      );
                    },
              ),
            ),
          for (final MapEntry<int, int> entry in placements.entries)
            Positioned(
              left: (entry.key % gridSize) * cellSize - pieceInset,
              top: (entry.key ~/ gridSize) * cellSize - pieceInset,
              width: pieceExtent,
              height: pieceExtent,
              child: _PuzzleDraggableTile(
                move: _PuzzleMove(pieceId: entry.value, originSlot: entry.key),
                imageFile: imageFile,
                gridSize: gridSize,
                extent: pieceExtent,
                quarterTurns: pieceRotations[entry.value] ?? 0,
                onRotate: () => onRotate(entry.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _PuzzleConnectorProfile {
  final int top;
  final int right;
  final int bottom;
  final int left;

  const _PuzzleConnectorProfile({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });
}

class _PuzzleTileFace extends StatelessWidget {
  final File imageFile;
  final int pieceId;
  final int gridSize;
  final double extent;
  final int quarterTurns;

  const _PuzzleTileFace({
    required this.imageFile,
    required this.pieceId,
    required this.gridSize,
    required this.extent,
    required this.quarterTurns,
  });

  @override
  Widget build(BuildContext context) {
    final int row = pieceId ~/ gridSize;
    final int column = pieceId % gridSize;
    final _PuzzleConnectorProfile profile = _PuzzleConnectorProfile(
      top: row == 0 ? 0 : -_edgeDirection(row - 1, column, true),
      right: column == gridSize - 1 ? 0 : _edgeDirection(row, column, false),
      bottom: row == gridSize - 1 ? 0 : _edgeDirection(row, column, true),
      left: column == 0 ? 0 : -_edgeDirection(row, column - 1, false),
    );
    final double contentExtent = extent * 0.72;
    final double inset = (extent - contentExtent) / 2;

    return RotatedBox(
      quarterTurns: quarterTurns,
      child: CustomPaint(
        painter: _PuzzlePieceOutlinePainter(
          profile: profile,
          strokeColor: Colors.white,
        ),
        child: ClipPath(
          clipper: _PuzzlePieceClipper(profile: profile),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: inset - (column * contentExtent),
                top: inset - (row * contentExtent),
                width: contentExtent * gridSize,
                height: contentExtent * gridSize,
                child: Image.file(imageFile, fit: BoxFit.cover),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _edgeDirection(int row, int column, bool vertical) {
    final int seed = vertical
        ? ((row + 3) * 37) + ((column + 5) * 11)
        : ((row + 7) * 17) + ((column + 2) * 29);
    return seed.isEven ? 1 : -1;
  }
}

class _PuzzlePieceClipper extends CustomClipper<Path> {
  final _PuzzleConnectorProfile profile;

  const _PuzzlePieceClipper({required this.profile});

  @override
  Path getClip(Size size) {
    final double width = size.width;
    final double height = size.height;
    final double insetX = width * 0.14;
    final double insetY = height * 0.14;
    final double bodyWidth = width - (insetX * 2);
    final double bodyHeight = height - (insetY * 2);
    final double tabRadiusX = bodyWidth * 0.14;
    final double tabRadiusY = bodyHeight * 0.14;

    final Path path = Path()..moveTo(insetX, insetY);
    _appendTopEdge(path, insetX, insetY, bodyWidth, tabRadiusX, tabRadiusY);
    _appendRightEdge(
      path,
      insetX + bodyWidth,
      insetY,
      bodyHeight,
      tabRadiusX,
      tabRadiusY,
    );
    _appendBottomEdge(
      path,
      insetX + bodyWidth,
      insetY + bodyHeight,
      bodyWidth,
      tabRadiusX,
      tabRadiusY,
    );
    _appendLeftEdge(
      path,
      insetX,
      insetY + bodyHeight,
      bodyHeight,
      tabRadiusX,
      tabRadiusY,
    );
    path.close();
    return path;
  }

  void _appendTopEdge(
    Path path,
    double startX,
    double y,
    double width,
    double radiusX,
    double radiusY,
  ) {
    final double middle = startX + (width / 2);
    final double first = middle - (radiusX * 1.1);
    final double second = middle + (radiusX * 1.1);
    path.lineTo(first, y);
    if (profile.top != 0) {
      final double arcY = y - (profile.top * radiusY);
      path.cubicTo(
        middle - (radiusX * 0.65),
        y,
        middle - (radiusX * 0.95),
        arcY,
        middle,
        arcY,
      );
      path.cubicTo(
        middle + (radiusX * 0.95),
        arcY,
        middle + (radiusX * 0.65),
        y,
        second,
        y,
      );
    }
    path.lineTo(startX + width, y);
  }

  void _appendRightEdge(
    Path path,
    double x,
    double startY,
    double height,
    double radiusX,
    double radiusY,
  ) {
    final double middle = startY + (height / 2);
    final double first = middle - (radiusY * 1.1);
    final double second = middle + (radiusY * 1.1);
    path.lineTo(x, first);
    if (profile.right != 0) {
      final double arcX = x + (profile.right * radiusX);
      path.cubicTo(
        x,
        middle - (radiusY * 0.65),
        arcX,
        middle - (radiusY * 0.95),
        arcX,
        middle,
      );
      path.cubicTo(
        arcX,
        middle + (radiusY * 0.95),
        x,
        middle + (radiusY * 0.65),
        x,
        second,
      );
    }
    path.lineTo(x, startY + height);
  }

  void _appendBottomEdge(
    Path path,
    double startX,
    double y,
    double width,
    double radiusX,
    double radiusY,
  ) {
    final double middle = startX - (width / 2);
    final double first = middle + (radiusX * 1.1);
    final double second = middle - (radiusX * 1.1);
    path.lineTo(first, y);
    if (profile.bottom != 0) {
      final double arcY = y + (profile.bottom * radiusY);
      path.cubicTo(
        middle + (radiusX * 0.65),
        y,
        middle + (radiusX * 0.95),
        arcY,
        middle,
        arcY,
      );
      path.cubicTo(
        middle - (radiusX * 0.95),
        arcY,
        middle - (radiusX * 0.65),
        y,
        second,
        y,
      );
    }
    path.lineTo(startX - width, y);
  }

  void _appendLeftEdge(
    Path path,
    double x,
    double startY,
    double height,
    double radiusX,
    double radiusY,
  ) {
    final double middle = startY - (height / 2);
    final double first = middle + (radiusY * 1.1);
    final double second = middle - (radiusY * 1.1);
    path.lineTo(x, first);
    if (profile.left != 0) {
      final double arcX = x - (profile.left * radiusX);
      path.cubicTo(
        x,
        middle + (radiusY * 0.65),
        arcX,
        middle + (radiusY * 0.95),
        arcX,
        middle,
      );
      path.cubicTo(
        arcX,
        middle - (radiusY * 0.95),
        x,
        middle - (radiusY * 0.65),
        x,
        second,
      );
    }
    path.lineTo(x, startY - height);
  }

  @override
  bool shouldReclip(covariant _PuzzlePieceClipper oldClipper) {
    return oldClipper.profile != profile;
  }
}

class _PuzzlePieceOutlinePainter extends CustomPainter {
  final _PuzzleConnectorProfile profile;
  final Color strokeColor;

  const _PuzzlePieceOutlinePainter({
    required this.profile,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _PuzzlePieceClipper(profile: profile).getClip(size);
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.16), 6, false);
    final Paint stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..isAntiAlias = true;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _PuzzlePieceOutlinePainter oldDelegate) {
    return oldDelegate.profile != profile ||
        oldDelegate.strokeColor != strokeColor;
  }
}

class _PuzzleBoardPainter extends CustomPainter {
  final int gridSize;
  final Color lineColor;

  const _PuzzleBoardPainter({required this.gridSize, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final double cell = size.width / gridSize;

    for (int index = 1; index < gridSize; index++) {
      final double offset = cell * index;
      canvas.drawLine(Offset(offset, 0), Offset(offset, size.height), paint);
      canvas.drawLine(Offset(0, offset), Offset(size.width, offset), paint);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PuzzleBoardPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize ||
        oldDelegate.lineColor != lineColor;
  }
}

/// Pet-themed memory matching game.
class TreatMatchScreen extends StatefulWidget {
  const TreatMatchScreen({super.key});

  @override
  State<TreatMatchScreen> createState() => _TreatMatchScreenState();
}

class _TreatMatchScreenState extends State<TreatMatchScreen> {
  final math.Random _random = math.Random();
  final List<_MemoryToken> _deck = <_MemoryToken>[];
  final List<int> _revealed = <int>[];
  final Set<int> _matched = <int>{};
  static const int _maxTaps = 30;
  bool _isResolvingTurn = false;
  int _moves = 0;
  int _tapCount = 0;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    final List<_MemoryToken> nextDeck = <_MemoryToken>[
      const _MemoryToken(
        symbol: 'Bone',
        icon: Icons.pets_rounded,
        accent: Color(0xFFF4A261),
      ),
      const _MemoryToken(
        symbol: 'Ball',
        icon: Icons.sports_tennis_rounded,
        accent: Color(0xFFE76F51),
      ),
      const _MemoryToken(
        symbol: 'Fish',
        icon: Icons.set_meal_rounded,
        accent: Color(0xFF2A9D8F),
      ),
      const _MemoryToken(
        symbol: 'Yarn',
        icon: Icons.blur_circular_rounded,
        accent: Color(0xFF8E6AC8),
      ),
      const _MemoryToken(
        symbol: 'Duck',
        icon: Icons.toys_rounded,
        accent: Color(0xFFE9C46A),
      ),
      const _MemoryToken(
        symbol: 'Treat',
        icon: Icons.cookie_rounded,
        accent: Color(0xFF264653),
      ),
    ];

    final List<_MemoryToken> doubled = <_MemoryToken>[...nextDeck, ...nextDeck]
      ..shuffle(_random);

    setState(() {
      _deck
        ..clear()
        ..addAll(doubled);
      _revealed.clear();
      _matched.clear();
      _moves = 0;
      _tapCount = 0;
      _isResolvingTurn = false;
    });
  }

  Future<void> _flipCard(int index) async {
    if (_isResolvingTurn ||
        _matched.contains(index) ||
        _revealed.contains(index)) {
      return;
    }

    setState(() {
      _tapCount += 1;
      _revealed.add(index);
    });

    if (_tapCount >= _maxTaps &&
        _revealed.length < 2 &&
        _matched.length != _deck.length) {
      await _showTapLimitResult();
      return;
    }

    if (_revealed.length < 2) {
      return;
    }

    _moves += 1;
    final int first = _revealed.first;
    final int second = _revealed.last;

    if (_deck[first].symbol == _deck[second].symbol) {
      setState(() {
        _matched.addAll(_revealed);
        _revealed.clear();
      });

      if (_matched.length == _deck.length && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'All matched in {moves} moves. Nice memory.',
                params: <String, String>{'moves': '$_moves'},
              ),
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isResolvingTurn = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }

    setState(() {
      _revealed.clear();
      _isResolvingTurn = false;
    });

    if (_tapCount >= _maxTaps && _matched.length != _deck.length) {
      await _showTapLimitResult();
    }
  }

  Future<void> _showTapLimitResult() async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(context.tr('30 taps used')),
          content: Text(
            context.tr(
              'You matched {count} of 6 pairs before the tap limit.',
              params: <String, String>{'count': '${_matched.length ~/ 2}'},
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('Close')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _resetGame();
              },
              child: Text(context.tr('Try Again')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Treat Match'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            AppCard(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricChip(
                      label: 'Taps',
                      value: '$_tapCount/$_maxTaps',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricChip(
                      label: 'Pairs',
                      value: '${_matched.length ~/ 2}/6',
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: _resetGame,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: context.tr('Restart'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.builder(
                itemCount: _deck.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.84,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final bool isVisible =
                      _matched.contains(index) || _revealed.contains(index);
                  final _MemoryToken token = _deck[index];
                  return GestureDetector(
                    onTap: () {
                      _flipCard(index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      decoration: BoxDecoration(
                        gradient: isVisible
                            ? const LinearGradient(
                                colors: <Color>[
                                  Color(0xFFFFF6E7),
                                  Color(0xFFD8F3EE),
                                ],
                              )
                            : AppColors.headerGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isVisible
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: token.accent.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Icon(
                                      token.icon,
                                      color: token.accent,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    context.tr(token.symbol),
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.secondaryDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : const Icon(
                                Icons.pets_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryToken {
  final String symbol;
  final IconData icon;
  final Color accent;

  const _MemoryToken({
    required this.symbol,
    required this.icon,
    required this.accent,
  });
}

/// Quick tap game with moving nose prints.
class NoseBoopDashScreen extends StatefulWidget {
  const NoseBoopDashScreen({super.key});

  @override
  State<NoseBoopDashScreen> createState() => _NoseBoopDashScreenState();
}

class _NoseBoopDashScreenState extends State<NoseBoopDashScreen> {
  final math.Random _random = math.Random();
  Timer? _timer;
  Timer? _refreshTimer;
  int _secondsLeft = 60;
  int _score = 0;
  List<_BoopTarget> _targets = <_BoopTarget>[];
  int _correctTargetId = 0;
  int _spawnVersion = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _restartRound();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _restartRound() {
    _timer?.cancel();
    _refreshTimer?.cancel();
    setState(() {
      _secondsLeft = 60;
      _score = 0;
      _isRunning = true;
      _spawnTargets();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsLeft == 1) {
        timer.cancel();
        _refreshTimer?.cancel();
        setState(() {
          _secondsLeft = 0;
          _isRunning = false;
        });
        _showRoundResult();
        return;
      }

      setState(() {
        _secondsLeft -= 1;
      });
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (Timer timer) {
      if (!mounted || !_isRunning) {
        timer.cancel();
        return;
      }

      setState(() {
        _spawnTargets();
      });
    });
  }

  void _spawnTargets() {
    final List<_BoopTarget> nextTargets = <_BoopTarget>[];
    final int count = 5;
    final int correctIndex = _random.nextInt(count);

    for (int index = 0; index < count; index++) {
      nextTargets.add(
        _BoopTarget(
          id: index,
          anchor: Offset(
            0.14 + (_random.nextDouble() * 0.72),
            0.18 + (_random.nextDouble() * 0.62),
          ),
          scale: 0.88 + (_random.nextDouble() * 0.38),
          isCorrect: index == correctIndex,
        ),
      );
    }

    _targets = nextTargets;
    _correctTargetId = correctIndex;
    _spawnVersion += 1;
  }

  Future<void> _showRoundResult() async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(context.tr('Time up')),
          content: Text(
            context.tr(
              'You booped {score} playful noses. Want another sprint?',
              params: <String, String>{'score': '$_score'},
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('Later')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _restartRound();
              },
              child: Text(context.tr('Replay')),
            ),
          ],
        );
      },
    );
  }

  void _boop(int targetId) {
    if (!_isRunning) {
      return;
    }

    setState(() {
      if (targetId == _correctTargetId) {
        _score += 1;
      } else {
        _score -= 1;
      }
      _spawnTargets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Nose Boop Dash'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            AppCard(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricChip(
                      label: 'Score',
                      value: '$_score',
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricChip(
                      label: 'Time',
                      value: '${_secondsLeft}s',
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: _restartRound,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: context.tr('Restart'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: AppCard(
                padding: EdgeInsets.zero,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  const Color(0xFFFFF7EC),
                                  AppColors.secondary.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        ..._targets.map((_BoopTarget target) {
                          final bool isCorrect = target.isCorrect;
                          return Positioned(
                            left:
                                (target.anchor.dx * constraints.maxWidth) - 34,
                            top:
                                (target.anchor.dy * constraints.maxHeight) - 34,
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey<String>(
                                '${target.id}_$_spawnVersion',
                              ),
                              tween: Tween<double>(
                                begin: 0.5,
                                end: target.scale,
                              ),
                              duration: Duration(
                                milliseconds: isCorrect ? 360 : 280,
                              ),
                              curve: Curves.easeOutBack,
                              builder:
                                  (
                                    BuildContext context,
                                    double animatedScale,
                                    Widget? child,
                                  ) {
                                    return Transform.scale(
                                      scale: animatedScale,
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        opacity: 1,
                                        child: child,
                                      ),
                                    );
                                  },
                              child: GestureDetector(
                                onTap: () => _boop(target.id),
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: isCorrect
                                        ? AppColors.primary
                                        : Colors.white.withValues(alpha: 0.78),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: isCorrect
                                          ? Colors.white
                                          : AppColors.textDisabled.withValues(
                                              alpha: 0.35,
                                            ),
                                      width: isCorrect ? 2.4 : 1.4,
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color:
                                            (isCorrect
                                                    ? AppColors.primary
                                                    : Colors.black)
                                                .withValues(
                                                  alpha: isCorrect
                                                      ? 0.28
                                                      : 0.08,
                                                ),
                                        blurRadius: isCorrect ? 18 : 12,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.pets_rounded,
                                    color: isCorrect
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        Positioned(
                          left: 18,
                          bottom: 18,
                          right: 18,
                          child: Text(
                            _isRunning
                                ? context.tr(
                                    'Each wave lasts 2 seconds. Tap the differently colored paw, and a wrong tap costs 1 point.',
                                  )
                                : context.tr(
                                    'Round finished. Tap restart to play again.',
                                  ),
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick decision care game themed around pet needs.
class CareRushScreen extends StatefulWidget {
  const CareRushScreen({super.key});

  @override
  State<CareRushScreen> createState() => _CareRushScreenState();
}

class _CareRushScreenState extends State<CareRushScreen> {
  final math.Random _random = math.Random();
  Timer? _feedbackTimer;
  int _round = 1;
  int _score = 0;
  int _bestStreak = 0;
  int _currentStreak = 0;
  final Map<String, int> _careStyleTally = <String, int>{};
  _CareBubbleData? _bubbleData;
  late _CarePrompt _prompt;

  static const List<_CarePrompt> _prompts = <_CarePrompt>[
    _CarePrompt(
      mood: 'Hungry after a long walk',
      choices: <_CareChoice>[
        _CareChoice(
          label: 'Healthy kibble bowl',
          icon: Icons.ramen_dining_rounded,
          isCorrect: true,
          styleKey: 'nurture',
        ),
        _CareChoice(
          label: 'Laser pointer',
          icon: Icons.wb_incandescent_rounded,
          styleKey: 'play',
        ),
        _CareChoice(
          label: 'Soft blanket',
          icon: Icons.bedtime_rounded,
          styleKey: 'comfort',
        ),
        _CareChoice(
          label: 'Bubble bath',
          icon: Icons.bathtub_rounded,
          styleKey: 'calm',
        ),
      ],
    ),
    _CarePrompt(
      mood: 'Sleepy after chasing toys',
      choices: <_CareChoice>[
        _CareChoice(
          label: 'Cozy nap bed',
          icon: Icons.bed_rounded,
          isCorrect: true,
          styleKey: 'comfort',
        ),
        _CareChoice(
          label: 'Tug rope',
          icon: Icons.sports_baseball_rounded,
          styleKey: 'play',
        ),
        _CareChoice(
          label: 'Crunchy treat',
          icon: Icons.cookie_rounded,
          styleKey: 'nurture',
        ),
        _CareChoice(
          label: 'Squeaky duck',
          icon: Icons.toys_rounded,
          styleKey: 'play',
        ),
      ],
    ),
    _CarePrompt(
      mood: 'Thirsty on a warm afternoon',
      choices: <_CareChoice>[
        _CareChoice(
          label: 'Fresh water bowl',
          icon: Icons.water_drop_rounded,
          isCorrect: true,
          styleKey: 'balance',
        ),
        _CareChoice(
          label: 'Winter sweater',
          icon: Icons.checkroom_rounded,
          styleKey: 'comfort',
        ),
        _CareChoice(
          label: 'Cat wand toy',
          icon: Icons.auto_fix_high_rounded,
          styleKey: 'play',
        ),
        _CareChoice(
          label: 'Story book',
          icon: Icons.menu_book_rounded,
          styleKey: 'calm',
        ),
      ],
    ),
    _CarePrompt(
      mood: 'Bursting with playful energy',
      choices: <_CareChoice>[
        _CareChoice(
          label: 'Fetch ball',
          icon: Icons.sports_tennis_rounded,
          isCorrect: true,
          styleKey: 'play',
        ),
        _CareChoice(
          label: 'Warm towel',
          icon: Icons.dry_cleaning_rounded,
          styleKey: 'comfort',
        ),
        _CareChoice(
          label: 'Dinner plate',
          icon: Icons.dinner_dining_rounded,
          styleKey: 'nurture',
        ),
        _CareChoice(
          label: 'Water fountain',
          icon: Icons.waterfall_chart_rounded,
          styleKey: 'balance',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _prompt = _prompts.first;
    _nextPrompt();
  }

  void _nextPrompt() {
    setState(() {
      _prompt = _prompts[_random.nextInt(_prompts.length)];
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _choose(_CareChoice choice) {
    final bool correct = choice.isCorrect;
    final int currentRound = _round;
    _careStyleTally.update(
      choice.styleKey,
      (int count) => count + 1,
      ifAbsent: () => 1,
    );

    setState(() {
      if (correct) {
        _score += 1;
        _currentStreak += 1;
        _bestStreak = math.max(_bestStreak, _currentStreak);
      } else {
        _currentStreak = 0;
      }
      if (currentRound < 10) {
        _round += 1;
        _prompt = _prompts[_random.nextInt(_prompts.length)];
      }
    });

    _showBubbleFeedback(choice, correct);

    if (currentRound >= 10) {
      _showEnding();
    }
  }

  void _showBubbleFeedback(_CareChoice choice, bool correct) {
    final _CareBubbleData nextBubble = _buildBubble(choice, correct);
    _feedbackTimer?.cancel();
    setState(() {
      _bubbleData = nextBubble;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _bubbleData = null;
      });
    });
  }

  _CareBubbleData _buildBubble(_CareChoice choice, bool correct) {
    if (correct) {
      switch (choice.styleKey) {
        case 'play':
          return const _CareBubbleData(
            expression: _PetExpression.grin,
            message: 'Yay, playtime! That was exactly the energy I needed.',
            color: Color(0xFFE76F51),
          );
        case 'comfort':
          return const _CareBubbleData(
            expression: _PetExpression.softSmile,
            message: 'So cozy... I feel safe and sleepy now.',
            color: Color(0xFF8E6AC8),
          );
        case 'nurture':
          return const _CareBubbleData(
            expression: _PetExpression.happyBlink,
            message: 'Mmm, perfect choice. My little tummy is happy.',
            color: Color(0xFFF4A261),
          );
        default:
          return const _CareBubbleData(
            expression: _PetExpression.calm,
            message: 'Ahh, much better. I feel refreshed already.',
            color: Color(0xFF2A9D8F),
          );
      }
    }

    switch (choice.styleKey) {
      case 'play':
        return const _CareBubbleData(
          expression: _PetExpression.confused,
          message: 'Fun idea, but that was not what I needed right now.',
          color: Color(0xFFE9C46A),
        );
      case 'comfort':
        return const _CareBubbleData(
          expression: _PetExpression.pleading,
          message: 'Sweet... but I was hoping for something else first.',
          color: Color(0xFFB8A1D9),
        );
      case 'nurture':
        return const _CareBubbleData(
          expression: _PetExpression.unsure,
          message: 'Close, but my mood is asking for a different kind of care.',
          color: Color(0xFFF0B36D),
        );
      default:
        return const _CareBubbleData(
          expression: _PetExpression.dizzy,
          message: 'Oops, that missed the moment. Let us try the next one.',
          color: Color(0xFF7EB8B0),
        );
    }
  }

  Future<void> _showEnding() async {
    final _CareEnding ending = _buildEnding();
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(context.tr(ending.title)),
          content: Text(context.tr(ending.description)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('Close')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _reset();
              },
              child: Text(context.tr('Play Again')),
            ),
          ],
        );
      },
    );
  }

  _CareEnding _buildEnding() {
    final List<MapEntry<String, int>> ranked = _careStyleTally.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );
    final String topStyle = ranked.isEmpty ? 'balance' : ranked.first.key;

    if (_score >= 8 && topStyle == 'balance') {
      return const _CareEnding(
        title: 'Ending: Balanced Guardian',
        description:
            'You mixed food, rest, play, and hydration with almost no misses. Your pet ends the day calm, strong, and deeply understood.',
      );
    }
    if (topStyle == 'play') {
      return const _CareEnding(
        title: 'Ending: Joy Scout',
        description:
            'You solve most moments through play and stimulation. Your pet sees you as the person who turns every ordinary day into an adventure.',
      );
    }
    if (topStyle == 'comfort') {
      return const _CareEnding(
        title: 'Ending: Cozy Keeper',
        description:
            'Warmth, blankets, and safe spaces shaped your choices. Your pet finishes the session feeling protected and wonderfully relaxed.',
      );
    }
    if (topStyle == 'nurture') {
      return const _CareEnding(
        title: 'Ending: Heartfelt Nurturer',
        description:
            'You consistently lean toward food, replenishment, and practical care. Your pet trusts you as the one who always shows up with what they need.',
      );
    }
    return const _CareEnding(
      title: 'Ending: Gentle Harmonizer',
      description:
          'Your decisions settle the mood and smooth out each rough patch. Your pet ends up centered, refreshed, and ready for tomorrow.',
    );
  }

  void _reset() {
    _feedbackTimer?.cancel();
    setState(() {
      _round = 1;
      _score = 0;
      _bestStreak = 0;
      _currentStreak = 0;
      _careStyleTally.clear();
      _bubbleData = null;
      _prompt = _prompts[_random.nextInt(_prompts.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Care Rush'))),
      body: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                AppCard(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricChip(
                          label: 'Round',
                          value: '$_round/10',
                          color: AppColors.secondaryDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricChip(
                          label: 'Score',
                          value: '$_score',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricChip(
                          label: 'Best streak',
                          value: '$_bestStreak',
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  backgroundColor: const Color(0xFFFFF9EE),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.tr('Pet mood'),
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr(_prompt.mood),
                        style: AppTextStyles.headline.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('Choose the best response for this moment.'),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.05,
                    children: _prompt.choices.map((_CareChoice choice) {
                      return AppCard(
                        onTap: () {
                          _choose(choice);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                choice.icon,
                                color: AppColors.secondaryDark,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              context.tr(choice.label),
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.tr('Reset session')),
                ),
              ],
            ),
          ),
          if (_bubbleData case final _CareBubbleData bubble)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey<String>(bubble.message),
                  tween: Tween<double>(begin: 0.86, end: 1),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  builder: (BuildContext context, double scale, Widget? child) {
                    return Transform.scale(
                      scale: scale,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 140),
                        opacity: 1,
                        child: child,
                      ),
                    );
                  },
                  child: _CareReactionBubble(data: bubble),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CarePrompt {
  final String mood;
  final List<_CareChoice> choices;

  const _CarePrompt({required this.mood, required this.choices});
}

class _CareChoice {
  final String label;
  final IconData icon;
  final bool isCorrect;
  final String styleKey;

  const _CareChoice({
    required this.label,
    required this.icon,
    this.isCorrect = false,
    required this.styleKey,
  });
}

class _BoopTarget {
  final int id;
  final Offset anchor;
  final double scale;
  final bool isCorrect;

  const _BoopTarget({
    required this.id,
    required this.anchor,
    required this.scale,
    required this.isCorrect,
  });
}

class _CareEnding {
  final String title;
  final String description;

  const _CareEnding({required this.title, required this.description});
}

class _CareBubbleData {
  final _PetExpression expression;
  final String message;
  final Color color;

  const _CareBubbleData({
    required this.expression,
    required this.message,
    required this.color,
  });
}

enum _PetExpression {
  grin,
  softSmile,
  happyBlink,
  calm,
  confused,
  pleading,
  unsure,
  dizzy,
}

class _CareReactionBubble extends StatelessWidget {
  final _CareBubbleData data;

  const _CareReactionBubble({required this.data});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(top: 18),
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: data.color.withValues(alpha: 0.22)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    context.tr(data.message),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: data.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: data.color.withValues(alpha: 0.32),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: _PetFaceBadge(expression: data.expression),
              ),
            ),
            Positioned(
              top: 58,
              child: CustomPaint(
                painter: _BubbleTailPainter(color: Colors.white),
                child: const SizedBox(width: 26, height: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetFaceBadge extends StatelessWidget {
  final _PetExpression expression;

  const _PetFaceBadge({required this.expression});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _PetFacePainter(expression: expression),
    );
  }
}

class _PetFacePainter extends CustomPainter {
  final _PetExpression expression;

  const _PetFacePainter({required this.expression});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint face = Paint()..color = Colors.white;
    final Paint stroke = Paint()
      ..color = const Color(0xFF264653)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final Paint fill = Paint()..color = const Color(0xFF264653);

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2.2,
      face,
    );

    final Path leftEar = Path()
      ..moveTo(5, 7)
      ..lineTo(8, 1)
      ..lineTo(11, 8)
      ..close();
    final Path rightEar = Path()
      ..moveTo(size.width - 5, 7)
      ..lineTo(size.width - 8, 1)
      ..lineTo(size.width - 11, 8)
      ..close();
    canvas.drawPath(leftEar, face);
    canvas.drawPath(rightEar, face);
    canvas.drawPath(leftEar, stroke);
    canvas.drawPath(rightEar, stroke);

    _drawEyes(canvas, stroke, fill, size);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2 + 1), 1.6, fill);
    _drawMouth(canvas, stroke, size);
  }

  void _drawEyes(Canvas canvas, Paint stroke, Paint fill, Size size) {
    switch (expression) {
      case _PetExpression.happyBlink:
      case _PetExpression.softSmile:
        canvas.drawLine(const Offset(8, 11), const Offset(10.5, 10), stroke);
        canvas.drawLine(const Offset(15.5, 10), const Offset(18, 11), stroke);
        break;
      case _PetExpression.pleading:
        canvas.drawCircle(const Offset(9, 10.5), 2, fill);
        canvas.drawCircle(const Offset(17, 10.5), 2, fill);
        final Paint highlight = Paint()..color = Colors.white;
        canvas.drawCircle(const Offset(8.3, 9.7), 0.6, highlight);
        canvas.drawCircle(const Offset(16.3, 9.7), 0.6, highlight);
        break;
      case _PetExpression.dizzy:
        canvas.drawLine(const Offset(7.5, 9), const Offset(10.5, 12), stroke);
        canvas.drawLine(const Offset(10.5, 9), const Offset(7.5, 12), stroke);
        canvas.drawLine(const Offset(15.5, 9), const Offset(18.5, 12), stroke);
        canvas.drawLine(const Offset(18.5, 9), const Offset(15.5, 12), stroke);
        break;
      case _PetExpression.confused:
        canvas.drawCircle(const Offset(9, 10.5), 1.5, fill);
        canvas.drawLine(const Offset(15.5, 10), const Offset(18, 11), stroke);
        break;
      case _PetExpression.unsure:
        canvas.drawCircle(const Offset(9, 10.5), 1.5, fill);
        canvas.drawCircle(const Offset(17, 10.5), 1.5, fill);
        break;
      case _PetExpression.grin:
      case _PetExpression.calm:
        canvas.drawCircle(const Offset(9, 10.5), 1.5, fill);
        canvas.drawCircle(const Offset(17, 10.5), 1.5, fill);
        break;
    }
  }

  void _drawMouth(Canvas canvas, Paint stroke, Size size) {
    final Path mouth = Path();
    switch (expression) {
      case _PetExpression.grin:
        mouth.moveTo(8.5, 15.5);
        mouth.quadraticBezierTo(size.width / 2, 19, 17.5, 15.5);
        break;
      case _PetExpression.softSmile:
      case _PetExpression.calm:
      case _PetExpression.happyBlink:
        mouth.moveTo(9.5, 15.2);
        mouth.quadraticBezierTo(size.width / 2, 17.3, 16.5, 15.2);
        break;
      case _PetExpression.confused:
        mouth.moveTo(9.5, 16);
        mouth.quadraticBezierTo(size.width / 2, 14.7, 16.5, 15.2);
        break;
      case _PetExpression.pleading:
        mouth.moveTo(9.5, 16.5);
        mouth.quadraticBezierTo(size.width / 2, 14.5, 16.5, 16.5);
        break;
      case _PetExpression.unsure:
        mouth.moveTo(9.5, 16);
        mouth.quadraticBezierTo(size.width / 2, 16.8, 16.5, 15.4);
        break;
      case _PetExpression.dizzy:
        mouth.moveTo(9.5, 15.8);
        mouth.lineTo(16.5, 15.8);
        break;
    }
    canvas.drawPath(mouth, stroke);
  }

  @override
  bool shouldRepaint(covariant _PetFacePainter oldDelegate) {
    return oldDelegate.expression != expression;
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;

  const _BubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    final Paint paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.tr(label),
            style: AppTextStyles.label.copyWith(
              color: color.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.title.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.tr(title),
                style: AppTextStyles.title.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 2),
              Text(context.tr(subtitle), style: AppTextStyles.caption),
            ],
          ),
        ),
        if (trailing case final Widget trailingWidget) trailingWidget,
      ],
    );
  }
}
