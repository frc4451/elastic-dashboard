import 'dart:math';

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ReefSelectorModel extends MultiTopicNTWidgetModel {
  @override
  String type = ReefSelector.widgetType;

  String get optionsTopicName => '$topic/options';
  String get selectedTopicName => '$topic/selected';
  String get activeTopicName => '$topic/active';
  String get defaultTopicName => '$topic/default';

  late NT4Subscription optionsSubscription;
  late NT4Subscription selectedSubscription;
  late NT4Subscription activeSubscription;
  late NT4Subscription defaultSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
        optionsSubscription,
        selectedSubscription,
        activeSubscription,
        defaultSubscription,
      ];

  String? _selectedChoice;

  String? get selectedChoice => _selectedChoice;

  set selectedChoice(value) {
    _selectedChoice = value;
    refresh();
  }

  StringChooserData? previousData;

  NT4Topic? _selectedTopic;

  late final Image reefTreeImage;

  ReefSelectorModel(
      {required super.ntConnection,
      required super.preferences,
      required super.topic,
      super.dataType,
      super.period})
      : super();

  ReefSelectorModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void init() {
    super.init();

    reefTreeImage = Image.asset(
      "assets/fields/2025-the-tree.png",
      width: 600,
      height: 600,
      fit: BoxFit.cover,
    );
  }

  @override
  void initializeSubscriptions() {
    optionsSubscription =
        ntConnection.subscribe(optionsTopicName, super.period);
    selectedSubscription =
        ntConnection.subscribe(selectedTopicName, super.period);
    activeSubscription = ntConnection.subscribe(activeTopicName, super.period);
    defaultSubscription =
        ntConnection.subscribe(defaultTopicName, super.period);
  }

  @override
  void resetSubscription() {
    _selectedTopic = null;

    super.resetSubscription();
  }

  void publishSelectedValue(String? selected) {
    if (selected == null || !ntConnection.isNT4Connected) {
      return;
    }

    _selectedTopic ??=
        ntConnection.publishNewTopic(selectedTopicName, NT4TypeStr.kString);

    Future(() => ntConnection.updateDataFromTopic(_selectedTopic!, selected));
  }
}

class ReefSelector extends NTWidget {
  static const String widgetType = 'Reef Chooser';

  const ReefSelector({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    ReefSelectorModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
        listenable: Listenable.merge(model.subscriptions),
        child: model.reefTreeImage,
        builder: (context, child) {
          // --- This is mostly copy-pasta from split_button_chooser for prototyping
          List<Object?> rawOptions =
              model.optionsSubscription.value?.tryCast<List<Object?>>() ?? [];

          List<String> options = rawOptions.whereType<String>().toList();

          String? active = tryCast(model.activeSubscription.value);
          if (active != null && active == '') {
            active = null;
          }

          String? selected = tryCast(model.selectedSubscription.value);
          if (selected != null && selected == '') {
            selected = null;
          }

          String? defaultOption = tryCast(model.defaultSubscription.value);
          if (defaultOption != null && defaultOption == '') {
            defaultOption = null;
          }

          if (!model.ntConnection.isNT4Connected) {
            active = null;
            selected = null;
            defaultOption = null;
          }

          StringChooserData currentData = StringChooserData(
              options: options,
              active: active,
              defaultOption: defaultOption,
              selected: selected);

          // If a choice has been selected previously but the topic on NT has no value, publish it
          // This can happen if NT happens to restart
          if (currentData.selectedChanged(model.previousData)) {
            if (selected != null && model.selectedChoice != selected) {
              model.selectedChoice = selected;
            }
          } else if (currentData.activeChanged(model.previousData) ||
              active == null) {
            if (selected == null && model.selectedChoice != null) {
              if (options.contains(model.selectedChoice!)) {
                model.publishSelectedValue(model.selectedChoice!);
              } else if (options.isNotEmpty) {
                model.selectedChoice = active;
              }
            }
          }

          // If nothing is selected but NT has an active value, set the selected to the NT value
          // This happens on program startup
          if (active != null && model.selectedChoice == null) {
            model.selectedChoice = active;
          }

          model.previousData = currentData;

          bool showWarning = active != model.selectedChoice;

          // --- End copy-pasta

          // Run UI calculations SPECIFICALLY for Reef selector
          const double radius = 250;
          const double xyOffset = radius / 10;
          const double centerX = 300;
          const double centerY = 300;
          const double radianOffset = 3 * pi / 4;

          final List<Widget> buttons = [];
          final List<String> reefOptions = "ABCDEFGHIJKL".split("");

          for (int i = 0; i < reefOptions.length; ++i) {
            double angle = i * (2 * pi / reefOptions.length) + radianOffset;

            double x = centerX + radius * cos(angle);
            double y = centerY + radius * sin(angle);

            int offsetReefIndex = reefOptions.length - 1 - i;

            buttons.add(Positioned(
              left: x - xyOffset,
              top: y - xyOffset,
              child: ElevatedButton(
                onPressed: () {
                  model.selectedChoice = reefOptions[offsetReefIndex];
                  model.publishSelectedValue(model.selectedChoice);
                },
                style: ElevatedButton.styleFrom(
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.all(20),
                  backgroundColor:
                      currentData.active == reefOptions[offsetReefIndex]
                          ? Colors.white
                          : Colors.red,
                  foregroundColor: Colors.black,
                ),
                child: Text(reefOptions[offsetReefIndex]),
              ),
            ));
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              model.reefTreeImage,
              ...buttons,
              Positioned(
                  bottom: 5,
                  right: 5,
                  child: SizedBox(
                      child: (showWarning)
                          ? const Tooltip(
                              message:
                                  'Selected value has not been published to Network Tables.\nRobot code will not be receiving the correct value.',
                              child:
                                  Icon(Icons.priority_high, color: Colors.red),
                            )
                          : const Icon(Icons.check, color: Colors.green)))
            ],
          );
        });
  }
}
