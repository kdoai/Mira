/// Coach data model.
/// Ref: PLAN.md Section 3.4 (Coach Decisions), Section 6 (Firestore Schema)
library;

import 'package:flutter/material.dart';
import 'package:mira/theme/app_theme.dart';

class Coach {
  final String id;
  final String name;
  final String focus;
  final String style;
  final String description;
  final bool isBuiltIn;
  final bool isPro;
  final String shareCode;
  final String? creatorName;
  final int usageCount;
  final IconData icon;
  final Color color;

  const Coach({
    required this.id,
    required this.name,
    required this.focus,
    this.style = 'warm',
    this.description = '',
    this.isBuiltIn = false,
    this.isPro = false,
    this.shareCode = '',
    this.creatorName,
    this.usageCount = 0,
    this.icon = Icons.circle_outlined,
    this.color = MiraColors.forestGreen,
  });

  /// Built-in coaches
  /// Ref: PLAN.md Section 3.4
  static const List<Coach> builtIn = [
    Coach(
      id: 'mira',
      name: 'Mira',
      focus: 'General coaching',
      description: 'Your go-to thinking partner. Calm, thoughtful, genuinely curious.',
      isBuiltIn: true,
      isPro: false,
      icon: Icons.circle_outlined,
      color: MiraColors.coachMira,
    ),
    Coach(
      id: 'atlas',
      name: 'Atlas',
      focus: 'Career coaching',
      description: 'Your career strategist. Sharp, strategic, encouraging.',
      isBuiltIn: true,
      isPro: true,
      icon: Icons.change_history_outlined,
      color: MiraColors.coachAtlas,
    ),
    Coach(
      id: 'lyra',
      name: 'Lyra',
      focus: 'Creativity coaching',
      description: 'Your creative catalyst. Playful, curious, surprising.',
      isBuiltIn: true,
      isPro: true,
      icon: Icons.star_border,
      color: MiraColors.coachLyra,
    ),
    Coach(
      id: 'sol',
      name: 'Sol',
      focus: 'Wellness coaching',
      description: 'Your mindfulness guide. Grounded, gentle, wise.',
      isBuiltIn: true,
      isPro: true,
      icon: Icons.waves,
      color: MiraColors.coachSol,
    ),
    Coach(
      id: 'ember',
      name: 'Ember',
      focus: 'Relationships coaching',
      description: 'Your connection guide. Warm, empathetic, perceptive.',
      isBuiltIn: true,
      isPro: true,
      icon: Icons.favorite_border,
      color: MiraColors.coachEmber,
    ),
  ];

  factory Coach.fromJson(Map<String, dynamic> json) {
    return Coach(
      id: json['coach_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      focus: json['focus'] ?? '',
      style: json['style'] ?? 'warm',
      description: json['description'] ?? json['focus'] ?? '',
      isBuiltIn: json['is_built_in'] ?? json['isBuiltIn'] ?? false,
      isPro: json['isPro'] ?? true,
      shareCode: json['share_code'] ?? json['shareCode'] ?? '',
      creatorName: json['creator_name'] ?? json['creatorName'],
      usageCount: json['usage_count'] ?? json['usageCount'] ?? 0,
      icon: Icons.auto_awesome_outlined,
      color: MiraColors.gold,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'focus': focus,
      'style': style,
    };
  }
}
