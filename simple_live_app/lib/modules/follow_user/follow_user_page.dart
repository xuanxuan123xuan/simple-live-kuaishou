import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/platform_utils.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/services/current_room_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/filter_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';

class FollowUserPage extends GetView<FollowUserController> {
  const FollowUserPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var count = MediaQuery.of(context).size.width ~/ 500;
    if (count < 1) count = 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text("关注用户"),
        actions: [
          Obx(
            () => Visibility(
              visible: controller.paginationEnabled.value,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: "上一页",
                    onPressed: controller.currentDisplayPage.value > 1
                        ? controller.goToPreviousPage
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    "${controller.currentDisplayPage.value}/${controller.totalDisplayPages.value}",
                  ),
                  IconButton(
                    tooltip: "下一页",
                    onPressed: controller.currentDisplayPage.value <
                            controller.totalDisplayPages.value
                        ? controller.goToNextPage
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  IconButton(
                    tooltip: "刷新当前页",
                    onPressed: controller.refreshCurrentPageStatus,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: "刷新全部",
                    onPressed: controller.refreshAllStatus,
                    icon: const Icon(Icons.sync),
                  ),
                ],
              ),
            ),
          ),
          if (PlatformUtils.supportsInlineMultiRoom) ...[
            Obx(
              () => TextButton.icon(
                onPressed: controller.multiSelectMode.value
                    ? controller.openSelectedMultiRooms
                    : controller.toggleMultiSelectMode,
                icon: Icon(
                  controller.multiSelectMode.value
                      ? Icons.grid_view
                      : Icons.grid_view_outlined,
                ),
                label: Text(
                  controller.multiSelectMode.value
                      ? "开始同屏(${controller.selectedMultiRoomKeys.length})"
                      : "多开同屏",
                ),
              ),
            ),
            Obx(
              () => Visibility(
                visible: controller.multiSelectMode.value,
                child: IconButton(
                  tooltip: "取消多选",
                  onPressed: controller.toggleMultiSelectMode,
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ],
          PopupMenuButton(
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.save_2_line),
                      AppStyle.hGap12,
                      Text("导出文件")
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.folder_open_line),
                      AppStyle.hGap12,
                      Text("导入文件")
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.text),
                      AppStyle.hGap12,
                      Text("导出文本"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 3,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.file_text_line),
                      AppStyle.hGap12,
                      Text("导入文本"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.price_tag_line),
                      AppStyle.hGap12,
                      Text("标签管理"),
                    ],
                  ),
                ),
              ];
            },
            onSelected: (value) {
              if (value == 0) {
                FollowService.instance.exportFile();
              } else if (value == 1) {
                FollowService.instance.inputFile();
              } else if (value == 2) {
                FollowService.instance.exportText();
              } else if (value == 3) {
                FollowService.instance.inputText();
              } else if (value == 4) {
                showTagsManager();
              }
            },
          ),
        ],
        leading: Obx(
          () => FollowService.instance.updating.value
              ? const IconButton(
                  onPressed: null,
                  icon: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  onPressed: () {
                    controller.refreshData();
                  },
                  icon: const Icon(Icons.refresh),
                ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(
                () => Visibility(
                  visible: controller.paginationEnabled.value,
                  child: Padding(
                    padding: AppStyle.edgeInsetsH8.copyWith(top: 8),
                    child: Text(
                      "当前页刷新只处理本页目标；刷新全部会覆盖当前分组全部关注。",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
              Obx(
                () => _buildRefreshProgress(context),
              ),
              Padding(
                padding: AppStyle.edgeInsetsH8,
                child: Obx(
                  () => Row(
                    children: [
                      ChoiceChip(
                        label: const Text("按状态"),
                        selected: controller.groupMode.value ==
                            FollowGroupMode.liveStatus,
                        onSelected: (_) {
                          controller.setGroupMode(FollowGroupMode.liveStatus);
                        },
                      ),
                      AppStyle.hGap8,
                      ChoiceChip(
                        label: const Text("按平台"),
                        selected: controller.groupMode.value ==
                            FollowGroupMode.platform,
                        onSelected: (_) {
                          controller.setGroupMode(FollowGroupMode.platform);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: AppStyle.edgeInsetsA8.copyWith(top: 4),
                child: Obx(
                  () => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Wrap(
                      spacing: 12,
                      children: controller.groupOptions.map((option) {
                        return FilterButton(
                          text: option.title,
                          selected:
                              controller.selectedGroupId.value == option.id,
                          onTap: () {
                            controller.setGroupOption(option);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) {
                    if (!controller.paginationEnabled.value) {
                      return;
                    }
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity < -260) {
                      controller.goToNextPage();
                    } else if (velocity > 260) {
                      controller.goToPreviousPage();
                    }
                  },
                  child: PageGridView(
                    padding: const EdgeInsets.only(bottom: 96.0),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 92,
                    useFixedGrid: true,
                    crossAxisCount: count,
                    pageController: controller,
                    firstRefresh: false,
                    showPCRefreshButton: false,
                    itemBuilder: (_, i) {
                      var item = controller.list[i];
                      var site = Sites.allSites[item.siteId]!;
                      final isCurrent = "${item.siteId}_${item.roomId}" ==
                          CurrentRoomService.instance.currentKey;
                      return FollowUserItem(
                        item: item,
                        onSpecialTap: () {
                          controller.toggleSpecialFollow(item);
                        },
                        onRemove: () {
                          controller.removeItem(item);
                        },
                        onTap: () {
                          if (PlatformUtils.supportsInlineMultiRoom &&
                              controller.multiSelectMode.value) {
                            controller.toggleMultiRoomItem(item);
                            return;
                          }
                          AppNavigator.toLiveRoomDetail(
                            site: site,
                            roomId: item.roomId,
                          );
                        },
                        onLongPress: () {
                          setFollowTagDialog(item);
                        },
                        playing: controller.isSelectedForMultiRoom(item) ||
                            isCurrent,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          Obx(
            () => controller.paginationEnabled.value
                ? Positioned(
                    left: 16,
                    right: 16,
                    bottom: Platform.isAndroid || Platform.isIOS ? 12 : 18,
                    child: _buildFloatingPaginationBar(context),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingPaginationBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: Material(
          elevation: 8,
          color: Theme.of(context).colorScheme.surface.withAlpha(242),
          borderRadius: AppStyle.radius8,
          child: Padding(
            padding: AppStyle.edgeInsetsH12.add(AppStyle.edgeInsetsV4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: "上一页",
                  onPressed: controller.currentDisplayPage.value > 1
                      ? controller.goToPreviousPage
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  "${controller.currentDisplayPage.value}/${controller.totalDisplayPages.value}",
                ),
                IconButton(
                  tooltip: "下一页",
                  onPressed: controller.currentDisplayPage.value <
                          controller.totalDisplayPages.value
                      ? controller.goToNextPage
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                AppStyle.hGap8,
                TextButton.icon(
                  onPressed: controller.refreshCurrentPageStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text("当前页"),
                ),
                AppStyle.hGap4,
                TextButton.icon(
                  onPressed: controller.refreshAllStatus,
                  icon: const Icon(Icons.sync),
                  label: const Text("全部"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshProgress(BuildContext context) {
    final progress = FollowService.instance.refreshProgress.value;
    if (!progress.active) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: AppStyle.edgeInsetsH8.copyWith(top: 4, bottom: 4),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withAlpha(
          progress.automatic ? 180 : 220,
        ),
        borderRadius: AppStyle.radius8,
        child: Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      progress.stage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text("${progress.resolvedCount}/${progress.total}"),
                ],
              ),
              if (progress.detail.isNotEmpty) ...[
                AppStyle.vGap4,
                Text(
                  progress.detail,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              AppStyle.vGap8,
              LinearProgressIndicator(
                value: progress.total > 0 ? progress.percent : null,
                minHeight: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void setFollowTagDialog(FollowUser item) {
    List<FollowUserTag> copiedList = [
      controller.tagList.first,
      ...controller.tagList.skip(3),
    ];
    Rx<FollowUserTag> checkTag = copiedList
        .firstWhere(
          (tag) => tag.tag == item.tag,
          orElse: () => copiedList.first,
        )
        .obs;
    final ScrollController scrollController = ScrollController();
    Get.dialog(
      AlertDialog(
        contentPadding: const EdgeInsets.all(16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '设置标签',
                  style: TextStyle(fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    controller.setItemTag(item, checkTag.value);
                    Get.back();
                  },
                ),
              ],
            ),
            const Divider(),
            Obx(
              () {
                int selectedIndex = copiedList.indexOf(checkTag.value);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (selectedIndex >= 0) {
                    scrollController.animateTo(
                      selectedIndex * 60.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                });
                return SizedBox(
                  height: 300,
                  width: 300,
                  child: RadioGroup(
                    groupValue: checkTag.value,
                    onChanged: (value) {
                      checkTag.value = value!;
                    },
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: copiedList.length,
                      itemBuilder: (context, index) {
                        var tagItem = copiedList[index];
                        return Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1.0,
                              ),
                            ),
                          ),
                          child: RadioListTile<FollowUserTag>(
                            title: Text(tagItem.tag),
                            value: tagItem,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void showTagsManager() {
    Utils.showBottomSheet(
      title: '标签管理',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppStyle.divider,
          ListTile(
            title: const Text("添加标签"),
            leading: const Icon(Icons.add),
            onTap: () {
              editTagDialog("添加标签");
            },
          ),
          AppStyle.divider,
          Expanded(
            child: Obx(
              () => ReorderableListView.builder(
                itemCount: controller.userTagList.length,
                itemBuilder: (context, index) {
                  FollowUserTag item = controller.userTagList[index];
                  return ListTile(
                    key: ValueKey(item.id),
                    title: GestureDetector(
                      child: Text(item.tag),
                      onLongPress: () {
                        editTagDialog("修改标签", followUserTag: item);
                      },
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        controller.removeTag(item);
                      },
                    ),
                  );
                },
                onReorder: (int oldIndex, int newIndex) {
                  controller.updateTagOrder(oldIndex, newIndex);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void editTagDialog(String title, {FollowUserTag? followUserTag}) {
    final TextEditingController tagEditController =
        TextEditingController(text: followUserTag?.tag);
    bool upMode = title == "添加标签";
    Get.dialog(
      AlertDialog(
        contentPadding: const EdgeInsets.all(16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        content: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(Get.context!).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 18)),
              TextField(
                controller: tagEditController,
                minLines: 1,
                maxLines: 1,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  contentPadding: AppStyle.edgeInsetsA12,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey.withAlpha(51),
                    ),
                  ),
                ),
                onSubmitted: (_) {
                  upMode
                      ? controller.addTag(tagEditController.text)
                      : controller.updateTagName(
                          followUserTag!,
                          tagEditController.text,
                        );
                  Get.back();
                },
              ),
              Container(
                margin: AppStyle.edgeInsetsB4,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Get.back();
                      },
                      child: const Text('否'),
                    ),
                    TextButton(
                      onPressed: () {
                        upMode
                            ? controller.addTag(tagEditController.text)
                            : controller.updateTagName(
                                followUserTag!,
                                tagEditController.text,
                              );
                        Get.back();
                      },
                      child: const Text('是'),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
