import 'package:flutter/material.dart';
import 'package:flutter_openmoji/flutter_openmoji.dart';

class AppIcons {
  static const Map<String, Map<String, IconData>> categorizedIcons = {
    'Exercise': {
      'Running': OpenmojiIcons.person_running,
      'Walking': OpenmojiIcons.person_walking,
      'Swimming': OpenmojiIcons.person_swimming,
      'Cycling': OpenmojiIcons.person_biking,
      'Yoga': OpenmojiIcons.person_in_lotus_position,
      'Weightlifting': OpenmojiIcons.person_lifting_weights,
      'Stretching': OpenmojiIcons.person_cartwheeling,
      'Meditation': OpenmojiIcons.person_in_lotus_position,
      'Hiking': OpenmojiIcons.hiking_boot,
      'Tennis': OpenmojiIcons.tennis,
      'Soccer': OpenmojiIcons.soccer_ball,
      'Basketball': OpenmojiIcons.basketball,
      'Golf': OpenmojiIcons.person_golfing,
      'Boxing': OpenmojiIcons.boxing_glove,
      'Skateboarding': OpenmojiIcons.skateboard,
      'Pilates': OpenmojiIcons.person_in_lotus_position,
      'Badminton': OpenmojiIcons.badminton,
      'Table Tennis': OpenmojiIcons.ping_pong,
      'Bowling': OpenmojiIcons.bowling,
      'Dance': OpenmojiIcons.man_dancing
    },
    'Daily Life': {
      'Wake Up': OpenmojiIcons.sun,
      'Sleep': OpenmojiIcons.bed,
      'Shower': OpenmojiIcons.shower,
      'Brush Teeth': OpenmojiIcons.toothbrush,
      'Drink Water': OpenmojiIcons.glass_of_milk,
      'Reading': OpenmojiIcons.books,
      'Journal': OpenmojiIcons.memo,
      'Cleaning': OpenmojiIcons.broom,
      'Cooking': OpenmojiIcons.cooking,
      'Gardening': OpenmojiIcons.extras_lawn_mower,
      'Pet Care': OpenmojiIcons.dog,
      'Movie': OpenmojiIcons.film_projector,
      'Laundry': OpenmojiIcons.extras_washing_machine,
      'Shopping': OpenmojiIcons.shopping_cart,
      'Recycling': OpenmojiIcons.recycling_symbol,
      'Saving': OpenmojiIcons.money_bag,
      'Schedule': OpenmojiIcons.calendar,
      'Eating': OpenmojiIcons.steaming_bowl
    },
    'Learning': {
      'Coding': OpenmojiIcons.extras_code_editor,
      'Language': OpenmojiIcons.extras_chats,
      'Music': OpenmojiIcons.musical_notes,
      'Drawing': OpenmojiIcons.paintbrush,
      'Writing': OpenmojiIcons.memo,
      'Online': OpenmojiIcons.desktop_computer,
      'Study': OpenmojiIcons.extras_compose,
      'Podcast': OpenmojiIcons.extras_web_syndication,
      'Puzzle': OpenmojiIcons.puzzle_piece,
      'Chess': OpenmojiIcons.chess_pawn,
      'Discussion': OpenmojiIcons.extras_people_dialogue
    },
    'Health': {
      'Meditation': OpenmojiIcons.person_in_lotus_position,
      'Water': OpenmojiIcons.glass_of_milk,
      'Vitamin': OpenmojiIcons.pill,
      'Weight': OpenmojiIcons.extras_scales,
      'No Smoking': OpenmojiIcons.no_smoking,
      'Healthy Food': OpenmojiIcons.steaming_bowl,
      'Sleep': OpenmojiIcons.bed,
      'Relax': OpenmojiIcons.couch_and_lamp,
      'Mental': OpenmojiIcons.thinking_face,
      'Heart': OpenmojiIcons.red_heart,
      'Sun': OpenmojiIcons.sun,
      'Digital Detox': OpenmojiIcons.no_mobile_phones
    },
    'Productivity': {
      'Todo': OpenmojiIcons.memo,
      'Time': OpenmojiIcons.mantelpiece_clock,
      'Goal': OpenmojiIcons.goal_net,
      'Read': OpenmojiIcons.books,
      'Email': OpenmojiIcons.e_mail,
      'Focus': OpenmojiIcons.hourglass_done,
      'No Phone': OpenmojiIcons.no_mobile_phones,
      'Organize': OpenmojiIcons.broom,
      'Timer': OpenmojiIcons.timer_clock,
      'Idea': OpenmojiIcons.light_bulb,
      'Meeting': OpenmojiIcons.speaking_head
    },
    'Finance': {
      'Wallet': OpenmojiIcons.credit_card,
      'Save': OpenmojiIcons.money_bag,
      'Invest': OpenmojiIcons.chart_increasing,
      'Expense': OpenmojiIcons.receipt,
      'Debt': OpenmojiIcons.money_with_wings,
      'Account': OpenmojiIcons.bank
    },
    'Social': {
      'Volunteer': OpenmojiIcons.extras_help_others,
      'Friends': OpenmojiIcons.busts_in_silhouette,
      'Family': OpenmojiIcons.family,
      'Network': OpenmojiIcons.extras_instagram,
      'Share': OpenmojiIcons.extras_share
    },
    'Creative': {
      'Photo': OpenmojiIcons.camera,
      'Journal': OpenmojiIcons.memo,
      'DIY': OpenmojiIcons.hammer_and_wrench,
      'Cook': OpenmojiIcons.cooking
    }
  };

  static IconData getIconData(String category, String name) {
    return categorizedIcons[category]?[name] ?? Icons.error;
  }

  static IconData getIconDataByName(String name) {
    for (var category in categorizedIcons.values) {
      if (category.containsKey(name)) {
        return category[name]!;
      }
    }
    return Icons.error;
  }

  Widget adjustedIcon(String category, String name, double size) {
    double offsetX = -15.0;
    double offsetY = 8.0;

    final iconData = getIconData(category, name);

    return Transform.translate(
      offset: Offset(offsetX * 0.01 * size, offsetY * 0.01 * size),
      child: Icon(iconData, size: size),
    );
  }
}
