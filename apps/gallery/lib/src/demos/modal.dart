import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget _bodyText(BuildContext context, String text) {
  return Text(
    text,
    style: KunText.sm.copyWith(
      color: KunTheme.of(context).colors.neutral.shade600,
    ),
  );
}

Widget modalBasic(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _ModalBasic(),
  );
}

Widget modalSizes(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _ModalSizes(),
  );
}

Widget modalPlacement(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _ModalPlacement(),
  );
}

Widget modalScroll(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _ModalScroll(),
  );
}

Widget modalNonDismissable(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _ModalNonDismissable(),
  );
}

Widget modalAlert(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _ModalAlert(),
  );
}

Widget modalForm(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _ModalForm(),
  );
}

Widget modalNested(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _ModalNested(),
  );
}

Widget modalEvents(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _ModalEvents(),
  );
}

Widget modalBare(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _ModalBare(),
  );
}

class _ModalBasic extends StatefulWidget {
  const _ModalBasic();

  @override
  State<_ModalBasic> createState() => _ModalBasicState();
}

class _ModalBasicState extends State<_ModalBasic> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KunButton(
          onPressed: () => setState(() => _open = true),
          child: const Text('Open modal'),
        ),
        KunModal(
          value: _open,
          onChanged: (bool value) => setState(() => _open = value),
          title: 'Hello from a modal',
          description:
              'Teleported to body, focus-trapped, body-scroll-locked. Press Esc or click the backdrop to close.',
          child: _bodyText(
            context,
            'title 渲染为面板的 h2 并关联 aria-labelledby, description 关联 aria-describedby — 屏幕阅读器念到的名字就是屏幕上看到的那个。',
          ),
        ),
      ],
    );
  }
}

class _ModalSizes extends StatefulWidget {
  const _ModalSizes();

  @override
  State<_ModalSizes> createState() => _ModalSizesState();
}

class _ModalSizesState extends State<_ModalSizes> {
  bool _open = false;
  KunModalSize _size = KunModalSize.md;

  void _openWith(KunModalSize size) {
    setState(() {
      _size = size;
      _open = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: KunSpacing.unit * 2,
          runSpacing: KunSpacing.unit * 2,
          children: [
            for (final KunModalSize size in KunModalSize.values)
              KunButton(
                variant: KunUIVariant.bordered,
                onPressed: () => _openWith(size),
                child: Text(size.name),
              ),
          ],
        ),
        KunModal(
          value: _open,
          onChanged: (bool value) => setState(() => _open = value),
          size: _size,
          title: '尺寸:${_size.name}',
          description: '通过 size 控制面板的最大宽度,可选 sm / md / lg / xl / full。',
          child: KunButton(
            onPressed: () => setState(() => _open = false),
            child: const Text('关闭'),
          ),
        ),
      ],
    );
  }
}

class _ModalPlacement extends StatefulWidget {
  const _ModalPlacement();

  @override
  State<_ModalPlacement> createState() => _ModalPlacementState();
}

class _ModalPlacementState extends State<_ModalPlacement> {
  bool _auto = false;
  bool _top = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: KunSpacing.unit * 2,
          runSpacing: KunSpacing.unit * 2,
          children: [
            KunButton(
              onPressed: () => setState(() => _auto = true),
              child: const Text('自适应(默认)'),
            ),
            KunButton(
              variant: KunUIVariant.bordered,
              onPressed: () => setState(() => _top = true),
              child: const Text('顶部对齐'),
            ),
          ],
        ),
        KunModal(
          value: _auto,
          onChanged: (bool value) => setState(() => _auto = value),
          title: '自适应对齐',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunSpacing.unit * 3,
            children: [
              _bodyText(
                context,
                '默认值 placement="auto":窄屏(md 以下)从底部升起、贴边铺满,更贴近手机的操作习惯;md 及以上恢复居中。把浏览器窗口拉窄再打开一次就能看到差别。',
              ),
              _bodyText(
                context,
                '需要在所有宽度都居中,传 placement="center"。',
              ),
              KunButton(
                onPressed: () => setState(() => _auto = false),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
        KunModal(
          value: _top,
          onChanged: (bool value) => setState(() => _top = value),
          placement: KunModalPlacement.top,
          title: '顶部对齐',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunSpacing.unit * 3,
            children: [
              _bodyText(
                context,
                'placement="top" 在所有宽度下都贴近视口顶部。',
              ),
              KunButton(
                onPressed: () => setState(() => _top = false),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModalScroll extends StatefulWidget {
  const _ModalScroll();

  @override
  State<_ModalScroll> createState() => _ModalScrollState();
}

class _ModalScrollState extends State<_ModalScroll> {
  bool _outside = false;
  bool _inside = false;

  Widget _paragraphs(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 3,
      children: [
        _bodyText(
          context,
          '当内容超出视口时,scrollBehavior="outside" 让整个遮罩层滚动;默认的 inside 则只滚动面板内部。',
        ),
        for (int n = 1; n <= 12; n++)
          _bodyText(context, '第 $n 段内容,用于撑高对话框以演示滚动效果。'),
        KunButton(
          onPressed: () => setState(() {
            _outside = false;
            _inside = false;
          }),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: KunSpacing.unit * 2,
          runSpacing: KunSpacing.unit * 2,
          children: [
            KunButton(
              onPressed: () => setState(() => _outside = true),
              child: const Text('外部滚动'),
            ),
            KunButton(
              variant: KunUIVariant.bordered,
              onPressed: () => setState(() => _inside = true),
              child: const Text('内部滚动'),
            ),
          ],
        ),
        KunModal(
          value: _outside,
          onChanged: (bool value) => setState(() => _outside = value),
          scrollBehavior: KunModalScrollBehavior.outside,
          title: '滚动行为:outside',
          child: _paragraphs(context),
        ),
        KunModal(
          value: _inside,
          onChanged: (bool value) => setState(() => _inside = value),
          scrollBehavior: KunModalScrollBehavior.inside,
          title: '滚动行为:inside',
          child: _paragraphs(context),
        ),
      ],
    );
  }
}

class _ModalNonDismissable extends StatefulWidget {
  const _ModalNonDismissable();

  @override
  State<_ModalNonDismissable> createState() => _ModalNonDismissableState();
}

class _ModalNonDismissableState extends State<_ModalNonDismissable> {
  bool _locked = false;
  bool _noClose = false;
  bool _backNavigates = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: KunSpacing.unit * 2,
          runSpacing: KunSpacing.unit * 2,
          children: [
            KunButton(
              variant: KunUIVariant.bordered,
              onPressed: () => setState(() => _locked = true),
              child: const Text('不可关闭背景'),
            ),
            KunButton(
              variant: KunUIVariant.bordered,
              onPressed: () => setState(() => _noClose = true),
              child: const Text('隐藏关闭按钮'),
            ),
            KunButton(
              variant: KunUIVariant.bordered,
              onPressed: () => setState(() => _backNavigates = true),
              child: const Text('返回关闭页面'),
            ),
          ],
        ),
        KunModal(
          value: _locked,
          onChanged: (bool value) => setState(() => _locked = value),
          isDismissable: false,
          title: '不可关闭背景',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunSpacing.unit * 3,
            children: [
              _bodyText(
                context,
                '设置 isDismissable=false 后,点击背景和按下 Esc 都不会关闭,只能通过按钮主动关闭。',
              ),
              KunButton(
                color: KunUIColor.danger,
                onPressed: () => setState(() => _locked = false),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
        KunModal(
          value: _noClose,
          onChanged: (bool value) => setState(() => _noClose = value),
          isShowCloseButton: false,
          title: '隐藏关闭按钮',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunSpacing.unit * 3,
            children: [
              _bodyText(
                context,
                '设置 isShowCloseButton=false 隐藏右上角的关闭按钮,仍可点击背景或按 Esc 关闭。',
              ),
              KunButton(
                onPressed: () => setState(() => _noClose = false),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
        KunModal(
          value: _backNavigates,
          onChanged: (bool value) => setState(() => _backNavigates = value),
          isCloseRequestDismissable: false,
          title: '返回关闭页面',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunSpacing.unit * 3,
            children: [
              _bodyText(
                context,
                'isCloseRequestDismissable=false 时系统返回不再关闭对话框,而是把关闭请求交给下面的页面,页面会退出。',
              ),
              KunButton(
                onPressed: () => setState(() => _backNavigates = false),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModalAlert extends StatefulWidget {
  const _ModalAlert();

  @override
  State<_ModalAlert> createState() => _ModalAlertState();
}

class _ModalAlertState extends State<_ModalAlert> {
  bool _alert = false;
  bool _unnamed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: KunSpacing.unit * 2,
          runSpacing: KunSpacing.unit * 2,
          children: [
            KunButton(
              color: KunUIColor.danger,
              onPressed: () => setState(() => _alert = true),
              child: const Text('删除账户'),
            ),
            KunButton(
              variant: KunUIVariant.bordered,
              onPressed: () => setState(() => _unnamed = true),
              child: const Text('无标题对话框'),
            ),
          ],
        ),
        KunModal(
          value: _alert,
          onChanged: (bool value) => setState(() => _alert = value),
          role: KunModalRole.alertdialog,
          title: '确认删除?',
          description: '此操作不可撤销,账户下的全部数据都会被移除。',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunSpacing.unit * 3,
            children: [
              _bodyText(
                context,
                'role="alertdialog" 把对话框标记为警告语义,用于需要用户明确回答的破坏性操作。它同时让点击背景不再关闭对话框 — 落在遮罩上的一次点击不算一个回答;Esc 仍然可以取消,和 Radix / Reka 的 AlertDialog 一致。',
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: KunSpacing.unit * 2,
                children: [
                  KunButton(
                    variant: KunUIVariant.bordered,
                    onPressed: () => setState(() => _alert = false),
                    child: const Text('取消'),
                  ),
                  KunButton(
                    color: KunUIColor.danger,
                    onPressed: () => setState(() => _alert = false),
                    child: const Text('确认删除'),
                  ),
                ],
              ),
            ],
          ),
        ),
        KunModal(
          value: _unnamed,
          onChanged: (bool value) => setState(() => _unnamed = value),
          role: KunModalRole.alertdialog,
          semanticLabel: '无标题警告',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunSpacing.unit * 3,
            children: [
              _bodyText(
                context,
                '没有 title 时用 semanticLabel (web ariaLabel) 给对话框一个可访问的名字。',
              ),
              KunButton(
                variant: KunUIVariant.bordered,
                onPressed: () => setState(() => _unnamed = false),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModalForm extends StatefulWidget {
  const _ModalForm();

  @override
  State<_ModalForm> createState() => _ModalFormState();
}

class _ModalFormState extends State<_ModalForm> {
  bool _open = false;
  String _name = '';
  String _email = '';
  String _bio = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KunButton(
          onPressed: () => setState(() => _open = true),
          child: const Text('打开表单'),
        ),
        KunModal(
          value: _open,
          onChanged: (bool value) => setState(() => _open = value),
          title: '编辑资料',
          rounded: KunUIRounded.lg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunSpacing.unit * 4,
            children: [
              KunInput(
                label: '名称',
                value: _name,
                onChanged: (String value) => setState(() => _name = value),
              ),
              KunInput(
                label: '邮箱',
                value: _email,
                onChanged: (String value) => setState(() => _email = value),
              ),
              KunTextarea(
                label: '简介',
                value: _bio,
                onChanged: (String value) => setState(() => _bio = value),
              ),
              KunButton(
                onPressed: () => setState(() => _open = false),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModalNested extends StatefulWidget {
  const _ModalNested();

  @override
  State<_ModalNested> createState() => _ModalNestedState();
}

class _ModalNestedState extends State<_ModalNested> {
  bool _outer = false;
  bool _inner = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KunButton(
          onPressed: () => setState(() => _outer = true),
          child: const Text('打开外层'),
        ),
        KunModal(
          value: _outer,
          onChanged: (bool value) => setState(() => _outer = value),
          title: '外层对话框',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunSpacing.unit * 3,
            children: [
              _bodyText(context, '再打开一层。Esc 只关闭最上面的那一层。'),
              KunButton(
                onPressed: () => setState(() => _inner = true),
                child: const Text('打开内层'),
              ),
              KunModal(
                value: _inner,
                onChanged: (bool value) => setState(() => _inner = value),
                title: '内层对话框',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: KunSpacing.unit * 3,
                  children: [
                    _bodyText(context, '这是叠在上面的第二层。'),
                    KunButton(
                      onPressed: () => setState(() => _inner = false),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModalEvents extends StatefulWidget {
  const _ModalEvents();

  @override
  State<_ModalEvents> createState() => _ModalEventsState();
}

class _ModalEventsState extends State<_ModalEvents> {
  bool _open = false;
  int _changed = 0;
  int _closed = 0;
  final List<String> _order = <String>[];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 3,
      children: [
        KunButton(
          onPressed: () => setState(() => _open = true),
          child: const Text('打开'),
        ),
        Text('onChanged: $_changed'),
        Text('onClose: $_closed'),
        Text('order: ${_order.join(', ')}'),
        KunModal(
          value: _open,
          onChanged: (bool value) {
            setState(() {
              _open = value;
              _changed += 1;
              _order.add('onChanged');
            });
          },
          onClose: () {
            setState(() {
              _closed += 1;
              _order.add('onClose');
            });
          },
          title: '事件',
          child: _bodyText(context, '关闭后下面会记下 onChanged 和 onClose 的顺序。'),
        ),
      ],
    );
  }
}

class _ModalBare extends StatefulWidget {
  const _ModalBare();

  @override
  State<_ModalBare> createState() => _ModalBareState();
}

class _ModalBareState extends State<_ModalBare> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KunButton(
          variant: KunUIVariant.bordered,
          onPressed: () => setState(() => _open = true),
          child: const Text('无容器'),
        ),
        KunModal(
          value: _open,
          onChanged: (bool value) => setState(() => _open = value),
          withContainer: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.content1,
              borderRadius: BorderRadius.circular(KunRadius.lg),
              boxShadow: KunShadows.lg,
            ),
            child: Padding(
              padding: const EdgeInsets.all(KunSpacing.unit * 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: KunSpacing.unit * 3,
                children: [
                  Text(
                    '自定义卡片',
                    style: KunText.lg.copyWith(
                      fontWeight: KunFontWeights.semibold,
                      color: scheme.foreground,
                    ),
                  ),
                  _bodyText(
                      context, 'withContainer=false 时内容直接放在遮罩层里,没有面板和关闭按钮。'),
                  KunButton(
                    onPressed: () => setState(() => _open = false),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
