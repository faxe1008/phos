import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:phos_core/phos_core.dart';

import '../preview/preview_service.dart';
import '../theme/app_theme.dart';
import 'preview_box.dart';
import 'status_chips.dart';

/// A library tile: live preview + name + source/quality badges.
class StyleCard extends StatelessWidget {
  const StyleCard({
    super.key,
    required this.recipe,
    required this.service,
    required this.baseJpeg,
    required this.version,
    required this.onTap,
  });

  final UniversalRecipe recipe;
  final PreviewService service;
  final Uint8List baseJpeg;
  final int version;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 3 / 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PreviewBox(
                      service: service,
                      baseJpeg: baseJpeg,
                      params: recipe.nikon,
                      width: 360,
                      version: version,
                      borderRadius: 12,
                    ),
                    if (recipe.favorites)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.star,
                              size: 14, color: AppTheme.seed),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OverallChip(recipe: recipe),
                ],
              ),
              const SizedBox(height: 4),
              SourceBadge(recipe: recipe),
            ],
          ),
        ),
      ),
    );
  }
}