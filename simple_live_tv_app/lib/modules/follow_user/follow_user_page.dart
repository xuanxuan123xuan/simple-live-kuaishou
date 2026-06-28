import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/services/current_room_service.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/card/anchor_card.dart';

class FollowUserPage extends StatefulWidget {
  const FollowUserPage({super.key});

  @override
  State<FollowUserPage> createState() => _FollowUserPageState();
}

class _FollowUserPageState extends State<FollowUserPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, AppFocusNode> _focusNodes = <String, AppFocusNode>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusCurrentRoom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    super.dispose();
  }

  AppFocusNode _focusNodeFor(String key) {
    return _focusNodes.putIfAbsent(key, AppFocusNode.new);
  }

  void _focusCurrentRoom() {
    final currentKey = CurrentRoomService.instance.currentKey;
    if (currentKey.isEmpty) {
      return;
    }
    final index = FollowUserService.instance.list
        .indexWhere((item) => "${item.siteId}_${item.roomId}" == currentKey);
    if (index < 0) {
      return;
    }
    final row = index ~/ 3;
    final targetOffset = (row * 172.w).toDouble();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    }
    final item = FollowUserService.instance.list[index];
    _focusNodeFor(item.id).requestFocus();
  }

  KeyEventResult _handleShortcutKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        !FollowUserService.instance.paginationEnabled.value) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final altPressed = HardwareKeyboard.instance.isAltPressed;
    if (key == LogicalKeyboardKey.pageDown ||
        (altPressed && key == LogicalKeyboardKey.arrowRight)) {
      FollowUserService.instance.goToNextPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp ||
        (altPressed && key == LogicalKeyboardKey.arrowLeft)) {
      FollowUserService.instance.goToPreviousPage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleShortcutKey,
        child: Column(
          children: [
            AppStyle.vGap32,
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppStyle.hGap48,
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.arrow_back,
                  text: "返回",
                  autofocus: true,
                  onTap: () {
                    Get.back();
                  },
                ),
                AppStyle.hGap32,
                Text(
                  "我的关注",
                  style: AppStyle.titleStyleWhite.copyWith(
                    fontSize: 36.w,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppStyle.hGap24,
                const Spacer(),
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.refresh,
                  text: FollowUserService.instance.paginationEnabled.value
                      ? "重载列表"
                      : "刷新",
                  onTap: () {
                    FollowUserService.instance.refreshData();
                  },
                ),
                AppStyle.hGap24,
                AppStyle.hGap48,
              ],
            ),
            Obx(
              () => Visibility(
                visible: FollowUserService.instance.paginationEnabled.value,
                child: Padding(
                  padding: EdgeInsets.only(top: 20.w, left: 48.w, right: 48.w),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "当前页刷新只处理本页目标；刷新全部会覆盖当前关注总表。",
                      style: AppStyle.subTextStyleWhite,
                    ),
                  ),
                ),
              ),
            ),
            Obx(() => _buildRefreshProgress()),
            AppStyle.vGap32,
            Expanded(
              child: Stack(
                children: [
                  Obx(
                    () => GridView.builder(
                      controller: _scrollController,
                      primary: false,
                      cacheExtent: 1200.w,
                      padding: EdgeInsets.only(
                        left: 48.w,
                        right: 48.w,
                        bottom:
                            FollowUserService.instance.paginationEnabled.value
                                ? 120.w
                                : 0,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 48.w,
                        mainAxisSpacing: 40.w,
                        childAspectRatio: 2.75,
                      ),
                      itemCount: FollowUserService.instance.list.length,
                      itemBuilder: (_, i) {
                        var item = FollowUserService.instance.list[i];
                        final isCurrent = "${item.siteId}_${item.roomId}" ==
                            CurrentRoomService.instance.currentKey;
                        return SizedBox(
                          height: 164.w,
                          child: Obx(
                            () => Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: AnchorCard(
                                    face: item.face,
                                    name: item.userName,
                                    siteId: item.siteId,
                                    liveStatus: item.liveStatus.value,
                                    roomId: item.roomId,
                                    autofocus: isCurrent,
                                    focusNode: _focusNodeFor(item.id),
                                    onTap: null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Obx(
                    () => FollowUserService.instance.paginationEnabled.value
                        ? Positioned(
                            left: 48.w,
                            right: 48.w,
                            bottom: 24.w,
                            child: _buildFloatingPaginationBar(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingPaginationBar() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.w),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(160),
          borderRadius: AppStyle.radius16,
          border: Border.all(color: Colors.white24),
        ),
        child: Obx(
          () => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.chevron_left,
                text: "上一页",
                onTap: FollowUserService.instance.currentDisplayPage.value > 1
                    ? FollowUserService.instance.goToPreviousPage
                    : null,
              ),
              AppStyle.hGap16,
              Text(
                "${FollowUserService.instance.currentDisplayPage.value}/${FollowUserService.instance.totalDisplayPages.value}",
                style: AppStyle.textStyleWhite.copyWith(fontSize: 28.w),
              ),
              AppStyle.hGap16,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.chevron_right,
                text: "下一页",
                onTap: FollowUserService.instance.currentDisplayPage.value <
                        FollowUserService.instance.totalDisplayPages.value
                    ? FollowUserService.instance.goToNextPage
                    : null,
              ),
              AppStyle.hGap16,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.refresh,
                text: "刷新当前页",
                onTap: FollowUserService.instance.refreshCurrentPageStatus,
              ),
              AppStyle.hGap16,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.sync,
                text: "刷新全部",
                onTap: FollowUserService.instance.refreshAllStatus,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshProgress() {
    final progress = FollowUserService.instance.refreshProgress.value;
    if (!progress.active) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: 12.w, left: 48.w, right: 48.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.w),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(progress.automatic ? 120 : 160),
          borderRadius: AppStyle.radius16,
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    progress.stage,
                    style: AppStyle.textStyleWhite.copyWith(fontSize: 24.w),
                  ),
                ),
                Text(
                  "${progress.resolvedCount}/${progress.total}",
                  style: AppStyle.textStyleWhite.copyWith(fontSize: 24.w),
                ),
              ],
            ),
            if (progress.detail.isNotEmpty) ...[
              AppStyle.vGap8,
              Text(
                progress.detail,
                style: AppStyle.textStyleWhite.copyWith(fontSize: 20.w),
              ),
            ],
            AppStyle.vGap12,
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.total > 0 ? progress.percent : null,
                minHeight: 8.w,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Colors.lightGreenAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
