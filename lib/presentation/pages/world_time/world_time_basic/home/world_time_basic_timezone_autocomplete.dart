import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

/// A reusable wrapper around RawAutocomplete for timezone lookup.
///
/// - controller: TextEditingController bound to the input field.
/// - focusNode: FocusNode for the text field.
/// - onSelected: callback when the user picks a timezone string.
/// - maxOptions: optional cap on suggestions shown.
class WorldTimeBasicTimezoneAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSelected;
  final int maxOptions;

  const WorldTimeBasicTimezoneAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSelected,
    this.maxOptions = 50,
  });

  @override
  State<WorldTimeBasicTimezoneAutocomplete> createState() => _WorldTimeBasicTimezoneAutocompleteState();
}

class _WorldTimeBasicTimezoneAutocompleteState extends State<WorldTimeBasicTimezoneAutocomplete> {
  final LayerLink _layerLink = LayerLink();
  late final List<String> _allZones;

  @override
  void initState() {
    super.initState();
    // Use timezone database keys and keep them sorted for stable suggestions
    _allZones = tz.timeZoneDatabase.locations.keys.toList()..sort();
  }

  List<String> _getSuggestions(String input) {
    if (input.trim().isEmpty) return const [];
    final lower = input.toLowerCase();
    final matches = _allZones.where((z) => z.toLowerCase().contains(lower)).toList();

    // friendly heuristic: if user types hanoi/ha_ etc, prefer Ho Chi Minh
    if ((lower.contains('hanoi') || lower.startsWith('ha_')) &&
        !matches.contains('Asia/Ho_Chi_Minh')) {
      matches.insert(0, 'Asia/Ho_Chi_Minh');
    }

    if (matches.length > widget.maxOptions) {
      return matches.take(widget.maxOptions).toList();
    }
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: widget.focusNode,
        optionsBuilder: (TextEditingValue textEditingValue) {
          return _getSuggestions(textEditingValue.text);
        },
        displayStringForOption: (option) => option,
        onSelected: (value) => widget.onSelected(value),
        fieldViewBuilder: (context, controllerText, focusNode, onFieldSubmitted) {
          return TextField(
            controller: controllerText,
            focusNode: focusNode,
            decoration: const InputDecoration(
              hintText: 'Search timezone (e.g. Asia/Tokyo)',
            ),
            onSubmitted: (_) => onFieldSubmitted(),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 40),
            child: Material(
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240, maxWidth: 600),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      title: Text(option),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}