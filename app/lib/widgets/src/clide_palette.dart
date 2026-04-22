import 'package:clide_app/kernel/kernel.dart';
import 'package:clide_app/widgets/src/clide_text.dart';
import 'package:clide_app/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

class ClidePalette extends StatefulWidget {
  const ClidePalette({super.key});

  @override
  State<ClidePalette> createState() => _ClidePaletteState();
}

class _ClidePaletteState extends State<ClidePalette> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return ListenableBuilder(
      listenable: kernel.palette,
      builder: (ctx, _) {
        if (!kernel.palette.isOpen) return const SizedBox.shrink();
        final filtered = kernel.palette.filtered();
        return Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 480,
              constraints: const BoxConstraints(maxHeight: 360),
              decoration: BoxDecoration(
                color: tokens.dropdownBackground,
                border: Border.all(color: tokens.dropdownBorder),
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: EditableText(
                      controller: _input,
                      focusNode: _focus,
                      style: TextStyle(
                        fontFamily: clideMonoFamily,
                        fontSize: clideFontMono,
                        color: tokens.dropdownForeground,
                      ),
                      cursorColor: tokens.globalFocus,
                      backgroundCursorColor: tokens.globalFocus,
                      maxLines: 1,
                      onChanged: (v) => kernel.palette.setFilter(v),
                      onSubmitted: (_) {
                        if (filtered.isNotEmpty) {
                          kernel.palette.invoke(filtered.first.command);
                          _input.clear();
                        }
                      },
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final cmd = filtered[i];
                        return _PaletteItem(
                          title: cmd.title ?? cmd.command,
                          command: cmd.command,
                          binding: cmd.defaultBinding,
                          onTap: () {
                            kernel.palette.invoke(cmd.command);
                            _input.clear();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaletteItem extends StatefulWidget {
  const _PaletteItem({
    required this.title,
    required this.command,
    required this.onTap,
    this.binding,
  });

  final String title;
  final String command;
  final String? binding;
  final VoidCallback onTap;

  @override
  State<_PaletteItem> createState() => _PaletteItemState();
}

class _PaletteItemState extends State<_PaletteItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hover ? tokens.listItemHoverBackground : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: ClideText(
                  widget.title,
                  color: tokens.listItemForeground,
                ),
              ),
              if (widget.binding != null)
                ClideText(
                  widget.binding!,
                  fontSize: clideFontCaption,
                  fontFamily: clideMonoFamily,
                  color: tokens.globalTextMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
