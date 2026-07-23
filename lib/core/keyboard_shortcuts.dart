import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard shortcuts management for Bivium.
class BiviumShortcuts extends StatelessWidget {
  final Widget child;
  final Map<ShortcutActivator, VoidCallback> bindings;

  const BiviumShortcuts({
    super.key,
    required this.child,
    required this.bindings,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        ...bindings.map((key, value) => MapEntry(key, VoidCallbackIntent(value))),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          VoidCallbackIntent: CallbackAction<VoidCallbackIntent>(
            onInvoke: (intent) => intent.callback(),
          ),
        },
        child: child,
      ),
    );
  }
}

class VoidCallbackIntent extends Intent {
  final VoidCallback callback;
  const VoidCallbackIntent(this.callback);
}

/// Centralized shortcut definitions
class AppShortcuts {
  static final save = LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyS,
  );
  
  static final nextCard = LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.arrowRight,
  );

  static final prevCard = LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.arrowLeft,
  );

  static final pageUp = LogicalKeySet(LogicalKeyboardKey.pageUp);
  static final pageDown = LogicalKeySet(LogicalKeyboardKey.pageDown);

  static final search = LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyF,
  );

  static final toggleFlag = LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.keyF,
  );

  static final jumpTo = LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyG,
  );

  static final close = LogicalKeySet(LogicalKeyboardKey.escape);

  static final help = LogicalKeySet(LogicalKeyboardKey.slash); // '?' is Shift + '/'
}
