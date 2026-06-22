import 'package:flutter/material.dart';

class DropdownButtonFormFieldCompat<T> extends StatelessWidget {
  const DropdownButtonFormFieldCompat({
    super.key,
    this.initialValue,
    required this.items,
    this.selectedItemBuilder,
    this.onChanged,
    this.onSaved,
    this.validator,
    this.decoration,
    this.hint,
    this.disabledHint,
    this.isDense = false,
    this.isExpanded = false,
    this.autofocus = false,
    this.focusNode,
    this.icon,
    this.iconDisabledColor,
    this.iconEnabledColor,
    this.iconSize = 24.0,
    this.itemHeight,
    this.style,
    this.dropdownColor,
    this.menuMaxHeight,
    this.alignment = AlignmentDirectional.centerStart,
    this.borderRadius,
    this.padding,
    this.enableFeedback,
    this.barrierDismissible,
  });

  final T? initialValue;
  final List<DropdownMenuItem<T>>? items;
  final DropdownButtonBuilder? selectedItemBuilder;
  final ValueChanged<T?>? onChanged;
  final FormFieldSetter<T>? onSaved;
  final FormFieldValidator<T>? validator;
  final InputDecoration? decoration;
  final Widget? hint;
  final Widget? disabledHint;
  final bool isDense;
  final bool isExpanded;
  final bool autofocus;
  final FocusNode? focusNode;
  final Widget? icon;
  final Color? iconDisabledColor;
  final Color? iconEnabledColor;
  final double iconSize;
  final double? itemHeight;
  final TextStyle? style;
  final Color? dropdownColor;
  final double? menuMaxHeight;
  final AlignmentGeometry alignment;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool? enableFeedback;
  final bool? barrierDismissible;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: key,
      initialValue: initialValue,
      items: items,
      selectedItemBuilder: selectedItemBuilder,
      onChanged: onChanged,
      onSaved: onSaved,
      validator: validator,
      decoration: decoration,
      hint: hint,
      disabledHint: disabledHint,
      isDense: isDense,
      isExpanded: isExpanded,
      autofocus: autofocus,
      focusNode: focusNode,
      icon: icon,
      iconDisabledColor: iconDisabledColor,
      iconEnabledColor: iconEnabledColor,
      iconSize: iconSize,
      itemHeight: itemHeight,
      style: style,
      dropdownColor: dropdownColor,
      menuMaxHeight: menuMaxHeight,
      alignment: alignment,
      borderRadius: borderRadius,
      padding: padding,
      enableFeedback: enableFeedback,
      barrierDismissible: barrierDismissible ?? true,
    );
  }
}

class SwitchListTileCompat extends StatelessWidget {
  const SwitchListTileCompat({
    super.key,
    this.contentPadding,
    this.secondary,
    this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeThumbColor,
  });

  final EdgeInsetsGeometry? contentPadding;
  final Widget? secondary;
  final Widget? title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeThumbColor;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: key,
      contentPadding: contentPadding,
      secondary: secondary,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
      activeThumbColor: activeThumbColor,
    );
  }
}
