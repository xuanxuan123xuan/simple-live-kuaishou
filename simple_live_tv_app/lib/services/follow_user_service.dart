import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/event_bus.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';
import 'package:simple_live_tv_app/services/current_room_service.dart';
import 'package:simple_live_tv_app/services/db_service.dart';
import 'package:simple_live_tv_app/services/local_storage_service.dart';

class FollowUserService extends BasePageController<FollowUser> {
  static const Duration updateStatusCooldown = Duration(seconds: 10);
  static const int paginationThreshold = 400;
  static const int kDouyinGuestRefreshLimit = 100;
  static const String _refreshTaskStateStorageKey =
      LocalStorageService.kFollowRefreshTaskState;
  static const String _refreshTaskTargetsStorageKey =
      LocalStorageService.kFollowRefreshTaskTargets;

  static FollowUserService get instance => Get.find<FollowUserService>();

  StreamSubscription<dynamic>? subscription;
  RxList<FollowUser> allList = RxList<FollowUser>();
  RxList<FollowUser> livingList = RxList<FollowUser>();
  var currentDisplayPage = 1.obs;
  var totalDisplayPages = 1.obs;
  var paginationEnabled = false.obs;
  var updating = false.obs;
  var refreshProgress = const FollowRefreshProgress.idle().obs;

  Timer? updateTimer;
  bool needUpdate = true;
  int _updateGeneration = 0;
  DateTime? _lastUpdateStatusStartedAt;
  bool _forceNextStatusRefresh = false;

  FollowUserService() {
    pageSize = AppSettingsController.kFollowPageSizeDefault;
  }

  @override
  void onInit() {
    subscription = EventBus.instance.listen(Constant.kUpdateFollow, (p0) {
      needUpdate = false;
      refreshData(forceStatus: false);
    });

    if (list.isEmpty) {
      refreshData(forceStatus: false);
    }
    initTimer();
    super.onInit();
  }

  void initTimer() {
    if (AppSettingsController.instance.autoUpdateFollowEnable.value) {
      updateTimer?.cancel();
      updateTimer = Timer.periodic(
        Duration(
          minutes:
              AppSettingsController.instance.autoUpdateFollowDuration.value,
        ),
        (_) {
          if (updating.value) {
            Log.logPrint("上一轮仍在刷新，跳过本次自动刷新");
            return;
          }
          Log.logPrint("Update Follow Timer");
          refreshData(forceStatus: false);
        },
      );
    } else {
      updateTimer?.cancel();
    }
  }

  @override
  Future refreshData({bool forceStatus = true}) async {
    pageSize = AppSettingsController.instance.followPageSize.value;
    _forceNextStatusRefresh = forceStatus;
    await super.refreshData();
  }

  @override
  Future<List<FollowUser>> getData(int page, int pageSize) async {
    if (page == 1) {
      this.pageSize = AppSettingsController.instance.followPageSize.value;
      allList.assignAll(_sortFollowUsers(DBService.instance.getFollowList()));
      updateLivingList();
      if (needUpdate && _forceNextStatusRefresh) {
        unawaited(
          startUpdateStatus(
            allList.toList(),
            force: _forceNextStatusRefresh,
          ),
        );
      }
      _forceNextStatusRefresh = false;
      needUpdate = true;
      if (allList.isEmpty) {
        updating.value = false;
      }
    }

    paginationEnabled.value = allList.length > paginationThreshold;
    if (!paginationEnabled.value) {
      currentDisplayPage.value = 1;
      totalDisplayPages.value = 1;
      return allList.toList();
    }

    final effectivePageSize = _effectivePageSizeFor(allList.length);
    final pageCount = _pageCountFor(allList.length);
    final safePage = currentDisplayPage.value.clamp(1, pageCount);
    currentDisplayPage.value = safePage;
    totalDisplayPages.value = pageCount;

    final start = (safePage - 1) * effectivePageSize;
    if (start >= allList.length) {
      return [];
    }
    final end = (start + effectivePageSize).clamp(0, allList.length).toInt();
    return allList.sublist(start, end);
  }

  void sortList() {
    allList.assignAll(_sortFollowUsers(allList));
    paginationEnabled.value = allList.length > paginationThreshold;
    if (!paginationEnabled.value) {
      currentDisplayPage.value = 1;
      totalDisplayPages.value = 1;
      list.assignAll(allList);
    } else {
      final pageCount = _pageCountFor(allList.length);
      totalDisplayPages.value = pageCount;
      if (currentDisplayPage.value > pageCount) {
        currentDisplayPage.value = pageCount;
      }
      if (currentDisplayPage.value < 1) {
        currentDisplayPage.value = 1;
      }
      final pageSize = _effectivePageSizeFor(allList.length);
      final start = (currentDisplayPage.value - 1) * pageSize;
      final end = (start + pageSize).clamp(0, allList.length).toInt();
      list.assignAll(allList.sublist(start, end));
    }
    currentPage = currentDisplayPage.value;
    canLoadMore.value = false;
    updateLivingList();
  }

  int _effectivePageSizeFor(int total) {
    if (total <= paginationThreshold) {
      return total <= 0 ? pageSize : total;
    }
    final maxPageSize = ((total / 2).floor() + 1).clamp(2, total).toInt();
    final effective = AppSettingsController.instance.followPageSize.value
        .clamp(2, maxPageSize)
        .toInt();
    if (effective != AppSettingsController.instance.followPageSize.value) {
      AppSettingsController.instance.setFollowPageSize(effective);
    }
    pageSize = effective;
    return effective;
  }

  int _pageCountFor(int total) {
    if (total <= paginationThreshold) {
      return 1;
    }
    return (total / _effectivePageSizeFor(total)).ceil().clamp(1, total);
  }

  void applyPageSizeSetting() {
    currentDisplayPage.value = 1;
    sortList();
  }

  List<FollowUser> get currentPageTargets => list.toList();

  String get currentRefreshScopeKey => "page:${currentDisplayPage.value}";

  Future<void> refreshCurrentPageStatus() async {
    await startUpdateStatus(
      paginationEnabled.value ? currentPageTargets : allList.toList(),
      force: true,
      scope: FollowRefreshScope.page(scopeKey: currentRefreshScopeKey),
    );
  }

  Future<void> refreshAllStatus() async {
    await startUpdateStatus(
      _buildRefreshTargets(allList, includeAllNormals: true),
      force: true,
      scope: const FollowRefreshScope.all(),
    );
  }

  List<FollowUser> _buildRefreshTargets(
    Iterable<FollowUser> normalTargets, {
    bool includeAllNormals = false,
  }) {
    final specials = allList.where((item) => item.isSpecialFollow).toList();
    final normals = includeAllNormals
        ? allList.where((item) => !item.isSpecialFollow).toList()
        : normalTargets.where((item) => !item.isSpecialFollow).toList();
    return _distinctFollowUsers([
      ..._sortFollowUsers(specials),
      ..._sortFollowUsers(normals),
    ]);
  }

  _RefreshTargetPolicyResult _applyDouyinRefreshPolicy(
    List<FollowUser> orderedTargets, {
    required FollowRefreshScope scope,
    required bool hasFullDouyinCookie,
  }) {
    if (!scope.includeAllNormals || hasFullDouyinCookie) {
      return _RefreshTargetPolicyResult(
        allowedTargets: orderedTargets,
        deferredTargets: const [],
      );
    }

    final allowed = <FollowUser>[];
    final deferred = <FollowUser>[];
    var allowedDouyinCount = 0;

    for (final item in orderedTargets) {
      if (item.siteId != Constant.kDouyin) {
        allowed.add(item);
        continue;
      }
      if (allowedDouyinCount < kDouyinGuestRefreshLimit) {
        allowedDouyinCount++;
        allowed.add(item);
      } else {
        deferred.add(item);
      }
    }

    final toastMessage = deferred.isEmpty
        ? ""
        : "抖音本次仅刷新前 $kDouyinGuestRefreshLimit 个，剩余需要完整 Cookie";
    return _RefreshTargetPolicyResult(
      allowedTargets: allowed,
      deferredTargets: deferred,
      toastMessage: toastMessage,
    );
  }

  List<FollowUser> _distinctFollowUsers(Iterable<FollowUser> items) {
    final result = <FollowUser>[];
    final seenIds = <String>{};
    for (final item in items) {
      final uniqueId = item.id.trim().isNotEmpty
          ? item.id.trim()
          : "${item.siteId}_${item.roomId}";
      if (seenIds.add(uniqueId)) {
        result.add(item);
      }
    }
    return result;
  }

  String _refreshTargetKey(FollowUser item) {
    final uniqueId = item.id.trim().isNotEmpty
        ? item.id.trim()
        : "${item.siteId}_${item.roomId}";
    return "${item.siteId}|${item.roomId}|$uniqueId";
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  _PersistedFollowRefreshTaskState? _loadPersistedRefreshTask(String scopeKey) {
    try {
      final rawState = LocalStorageService.instance.getValue(
        _refreshTaskStateStorageKey,
        "",
      );
      final rawTargets = LocalStorageService.instance.getValue(
        _refreshTaskTargetsStorageKey,
        "",
      );
      if (rawState.isEmpty || rawTargets.isEmpty) {
        return null;
      }
      final stateMap = jsonDecode(rawState);
      final targetsMap = jsonDecode(rawTargets);
      if (stateMap is! Map || targetsMap is! Map) {
        return null;
      }
      final state = _PersistedFollowRefreshTaskState.fromMaps(
        stateMap.cast<String, dynamic>(),
        targetsMap.cast<String, dynamic>(),
      );
      if (state.scopeKey != scopeKey) {
        return null;
      }
      return state;
    } catch (e) {
      Log.w("读取关注刷新续跑状态失败: $e");
      return null;
    }
  }

  Future<void> _persistRefreshTask({
    required FollowRefreshScope scope,
    required int total,
    required List<String> orderedKeys,
    required List<String> pendingKeys,
    required int successCount,
    required int failedCount,
    required int deferredCount,
  }) async {
    if (!scope.includeAllNormals) {
      return;
    }
    final statePayload = {
      "scopeKey": scope.scopeKey,
      "total": total,
      "successCount": successCount,
      "failedCount": failedCount,
      "deferredCount": deferredCount,
      "updatedAt": DateTime.now().toIso8601String(),
    };
    final targetPayload = {
      "orderedKeys": orderedKeys,
      "pendingKeys": pendingKeys,
    };
    await LocalStorageService.instance.setValue(
      _refreshTaskStateStorageKey,
      jsonEncode(statePayload),
    );
    await LocalStorageService.instance.setValue(
      _refreshTaskTargetsStorageKey,
      jsonEncode(targetPayload),
    );
    // Fix TV多开灰屏: 频繁写入导致localstorage膨胀，compact防止文件过大
    try {
      await LocalStorageService.instance.settingsBox.compact();
    } catch (e) {
      // compact失败不影响刷新，静默忽略
    }
  }

  Future<void> _clearPersistedRefreshTask() async {
    await LocalStorageService.instance.removeValue(_refreshTaskStateStorageKey);
    await LocalStorageService.instance.removeValue(_refreshTaskTargetsStorageKey);
  }

  void goToNextPage() {
    if (!paginationEnabled.value ||
        currentDisplayPage.value >= totalDisplayPages.value) {
      return;
    }
    currentDisplayPage.value += 1;
    sortList();
  }

  void goToPreviousPage() {
    if (!paginationEnabled.value || currentDisplayPage.value <= 1) {
      return;
    }
    currentDisplayPage.value -= 1;
    sortList();
  }

  List<FollowUser> _sortFollowUsers(Iterable<FollowUser> items) {
    return items.toList()..sort(compareFollowUsers);
  }

  int compareFollowUsers(FollowUser a, FollowUser b) {
    if (a.isSpecialFollow != b.isSpecialFollow) {
      return a.isSpecialFollow ? -1 : 1;
    }
    final aLiving = a.liveStatus.value == 2;
    final bLiving = b.liveStatus.value == 2;
    if (aLiving != bLiving) {
      return aLiving ? -1 : 1;
    }
    return b.addTime.compareTo(a.addTime);
  }

  void updateLivingList() {
    livingList.assignAll(
      _sortFollowUsers(allList.where((x) => x.liveStatus.value == 2)),
    );
  }

  int _getConcurrency(int total) {
    if (total <= 0) {
      return 1;
    }
    final currentSiteId = CurrentRoomService.instance.siteId.value;
    final maxWhenPlayingDouyin = currentSiteId == Constant.kDouyin ? 4 : null;
    int cap(int value) {
      if (maxWhenPlayingDouyin == null) {
        return value;
      }
      return value.clamp(1, maxWhenPlayingDouyin).toInt();
    }

    final manual =
        AppSettingsController.instance.effectiveUpdateFollowThreadCount;
    if (manual > 0) {
      return cap(manual.clamp(1, total).toInt());
    }
    if (total <= 300) {
      return cap(total < 48 ? total : 48);
    }
    if (total <= 1000) {
      return cap(32);
    }
    if (total <= 3000) {
      return cap(20);
    }
    if (total <= 5000) {
      return cap(12);
    }
    return cap(8);
  }

  String _getConcurrencyMode() {
    final manual =
        AppSettingsController.instance.effectiveUpdateFollowThreadCount;
    return manual > 0 ? "手动($manual)" : "自动";
  }

  List<FollowUser> _interleaveByPlatform(List<FollowUser> items) {
    final grouped = <String, Queue<FollowUser>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.siteId, () => Queue<FollowUser>()).add(item);
    }

    final result = <FollowUser>[];
    while (grouped.values.any((queue) => queue.isNotEmpty)) {
      for (final queue in grouped.values) {
        if (queue.isNotEmpty) {
          result.add(queue.removeFirst());
        }
      }
    }
    return result;
  }

  List<FollowUser> _deprioritizeCurrentRoom(List<FollowUser> items) {
    final currentKey = CurrentRoomService.instance.currentKey;
    if (currentKey.isEmpty) {
      return items;
    }
    final currentItems = <FollowUser>[];
    final others = <FollowUser>[];
    for (final item in items) {
      final itemKey = "${item.siteId}_${item.roomId}";
      if (itemKey == currentKey) {
        currentItems.add(item);
      } else {
        others.add(item);
      }
    }
    return [...others, ...currentItems];
  }

  Future<void> startUpdateStatus(
    List<FollowUser> followList, {
    bool force = false,
    FollowRefreshScope? scope,
  }) async {
    final resolvedScope = scope ?? FollowRefreshScope.all(automatic: !force);
    final now = DateTime.now();
    final lastStartedAt = _lastUpdateStatusStartedAt;
    if (!force &&
        lastStartedAt != null &&
        now.difference(lastStartedAt) < updateStatusCooldown) {
      Log.logPrint("关注状态刷新过于频繁，已跳过本次网络刷新");
      updating.value = false;
      _resetRefreshProgress();
      sortList();
      return;
    }

    if (updating.value &&
        refreshProgress.value.active &&
        refreshProgress.value.scopeKey == resolvedScope.scopeKey &&
        !refreshProgress.value.completed) {
      Log.logPrint("同一刷新任务仍在进行，复用当前进度: ${resolvedScope.scopeKey}");
      return;
    }

    _lastUpdateStatusStartedAt = now;
    final generation = ++_updateGeneration;
    final automatic = resolvedScope.automatic;
    if (updating.value) {
      Log.logPrint("已有关注状态刷新任务，旧任务会被新任务替换");
    }
    updating.value = true;
    _setRefreshProgress(
      active: true,
      automatic: automatic,
      scopeKey: resolvedScope.scopeKey,
      stage: resolvedScope.stage,
      current: 0,
      total: followList.length,
    );

    try {
      if (followList.isEmpty) {
        sortList();
        return;
      }

      final concurrency = _getConcurrency(followList.length);
      final hasFullDouyinCookie = DouyinCookieHelper.hasFullCookie(
        (Sites.allSites[Constant.kDouyin]?.liveSite as DouyinSite?)?.cookie ?? "",
      );
      Log.logPrint(
        "开始更新关注状态，并发数: $concurrency，模式: ${_getConcurrencyMode()}，总数: ${followList.length}，"
        "scope=${resolvedScope.scopeKey} fullDouyinCookie=$hasFullDouyinCookie",
      );

      final orderedTargets = _deprioritizeCurrentRoom(
        _interleaveByPlatform(followList),
      );
      final filteredTargets = _applyDouyinRefreshPolicy(
        orderedTargets,
        scope: resolvedScope,
        hasFullDouyinCookie: hasFullDouyinCookie,
      );
      final allowedTargets = filteredTargets.allowedTargets;
      final orderedAllowedKeys = allowedTargets.map(_refreshTargetKey).toList();
      final targetByKey = <String, FollowUser>{
        for (final item in allowedTargets) _refreshTargetKey(item): item,
      };
      final persistedTask = _loadPersistedRefreshTask(resolvedScope.scopeKey);
      final resumeTask = resolvedScope.includeAllNormals &&
          persistedTask != null &&
          _sameStringList(persistedTask.orderedKeys, orderedAllowedKeys) &&
          persistedTask.pendingKeys.isNotEmpty;
      final pendingKeys = resumeTask
          ? persistedTask.pendingKeys
              .where(targetByKey.containsKey)
              .toList(growable: true)
          : orderedAllowedKeys.toList(growable: true);
      final taskQueue = Queue<FollowUser>.from(
        pendingKeys
            .map((key) => targetByKey[key])
            .whereType<FollowUser>(),
      );
      final douyinTargetCount = filteredTargets.allowedTargets
          .where((item) => item.siteId == Constant.kDouyin)
          .length;
      final douyinLimiter = douyinTargetCount > 0
          ? DouyinFollowRefreshLimiter.forTargetCount(douyinTargetCount)
          : null;
      final resumedSuccessCount = persistedTask?.successCount ?? 0;
      final resumedFailedCount = persistedTask?.failedCount ?? 0;
      var completed = resumeTask ? resumedSuccessCount + resumedFailedCount : 0;
      var successCount = resumeTask ? resumedSuccessCount : 0;
      var failedCount = resumeTask ? resumedFailedCount : 0;
      final deferredCount = filteredTargets.deferredTargets.length;
      var limitedCount = 0;

      if (resolvedScope.includeAllNormals) {
        unawaited(
          _persistRefreshTask(
            scope: resolvedScope,
            total: followList.length,
            orderedKeys: orderedAllowedKeys,
            pendingKeys: pendingKeys,
            successCount: successCount,
            failedCount: failedCount,
            deferredCount: deferredCount,
          ),
        );
      }

      if (filteredTargets.deferredTargets.isNotEmpty) {
        Log.w(
          "抖音全量刷新受限：scope=${resolvedScope.scopeKey} deferred=$deferredCount "
          "allowedDouyin=$douyinTargetCount requiresFullCookie=true",
        );
        if (filteredTargets.toastMessage.isNotEmpty) {
          SmartDialog.showToast(filteredTargets.toastMessage);
        }
      }
      if (resumeTask) {
        Log.logPrint(
          "继续上次未完成的全量关注刷新：scope=${resolvedScope.scopeKey} remaining=$pendingKeys.length",
        );
      }

      void updateProgress({required bool active, required bool done}) {
        final detail = [
          "成功 $successCount",
          if (failedCount > 0) "失败 $failedCount",
          if (deferredCount > 0) "未执行 $deferredCount",
        ].join("  ");
        _setRefreshProgress(
          active: active,
          automatic: automatic,
          scopeKey: resolvedScope.scopeKey,
          stage: resolvedScope.stage,
          current: completed,
          total: followList.length,
          successCount: successCount,
          failedCount: failedCount,
          deferredCount: deferredCount,
          detail: detail,
          completed: done,
        );
      }

      updateProgress(active: true, done: false);

      Future<void> worker(int workerIndex) async {
        while (taskQueue.isNotEmpty) {
          if (generation != _updateGeneration) {
            return;
          }
          final item = taskQueue.removeFirst();
          final result = await _updateLiveStatus(
            item,
            generation: generation,
            douyinLimiter: douyinLimiter,
            workerIndex: workerIndex,
          );
          if (generation != _updateGeneration) {
            return;
          }
          if (result.limited) {
            limitedCount++;
          }
          final targetKey = _refreshTargetKey(item);
          pendingKeys.remove(targetKey);
          switch (result.outcome) {
            case _FollowRefreshItemOutcome.success:
              successCount++;
              completed++;
              break;
            case _FollowRefreshItemOutcome.failed:
              failedCount++;
              completed++;
              break;
            case _FollowRefreshItemOutcome.deferred:
            case _FollowRefreshItemOutcome.skipped:
              break;
          }
          if (resolvedScope.includeAllNormals) {
            unawaited(
              _persistRefreshTask(
                scope: resolvedScope,
                total: followList.length,
                orderedKeys: orderedAllowedKeys,
                pendingKeys: pendingKeys,
                successCount: successCount,
                failedCount: failedCount,
                deferredCount: deferredCount,
              ),
            );
          }
          updateProgress(active: true, done: false);
        }
      }

      final workers = <Future<void>>[];
      for (var i = 0; i < concurrency; i++) {
        workers.add(worker(i));
      }
      await Future.wait(workers);

      if (generation != _updateGeneration) {
        return;
      }
      if (douyinLimiter != null) {
        final summary = douyinLimiter.finish(douyinTargetCount);
        Log.logPrint(
          "抖音关注刷新总结 scope=${resolvedScope.scopeKey} target=${summary.targetCount} "
          "startConcurrency=${summary.initialConcurrency} "
          "startInterval=${summary.initialInterval.inMilliseconds}ms "
          "finalInterval=${summary.finalInterval.inMilliseconds}ms "
          "success=${summary.successCount} limited=${summary.limitedCount} "
          "cooldown=${summary.cooledDown} elapsed=${summary.elapsed.inMilliseconds}ms "
          "failed=$failedCount deferred=$deferredCount limitedObserved=$limitedCount",
        );
      }
      updateProgress(active: false, done: true);
      if (resolvedScope.includeAllNormals) {
        await _clearPersistedRefreshTask();
      }
      sortList();
      Log.logPrint("关注状态更新完成");
    } finally {
      if (generation == _updateGeneration) {
        updating.value = false;
        _resetRefreshProgress();
      }
    }
  }

  void _setRefreshProgress({
    required bool active,
    required bool automatic,
    required String scopeKey,
    required String stage,
    required int current,
    required int total,
    int successCount = 0,
    int failedCount = 0,
    int deferredCount = 0,
    int skippedCount = 0,
    bool completed = false,
    bool background = false,
    String detail = "",
  }) {
    refreshProgress.value = FollowRefreshProgress(
      active: active,
      automatic: automatic,
      scopeKey: scopeKey,
      stage: stage,
      current: current.clamp(0, total).toInt(),
      total: total,
      successCount: successCount,
      failedCount: failedCount,
      deferredCount: deferredCount,
      skippedCount: skippedCount,
      completed: completed,
      background: background,
      detail: detail,
    );
  }

  void _resetRefreshProgress() {
    refreshProgress.value = const FollowRefreshProgress.idle();
  }

  Future<_FollowRefreshItemResult> _updateLiveStatus(
    FollowUser item, {
    int? generation,
    DouyinFollowRefreshLimiter? douyinLimiter,
    int workerIndex = 0,
  }) async {
    try {
      if (item.siteId == Constant.kDouyin && douyinLimiter != null) {
        await douyinLimiter.beforeRequest(workerIndex);
      }
      final site = Sites.allSites[item.siteId]!;
      final isLiving = await site.liveSite.getLiveStatus(roomId: item.roomId);
      if (generation != null && generation != _updateGeneration) {
        return const _FollowRefreshItemResult(_FollowRefreshItemOutcome.deferred);
      }
      if (item.siteId == Constant.kDouyin && douyinLimiter != null) {
        douyinLimiter.onSuccess();
      }
      item.liveStatus.value = isLiving ? 2 : 1;
      return const _FollowRefreshItemResult(_FollowRefreshItemOutcome.success);
    } catch (e) {
      if (generation != null && generation != _updateGeneration) {
        return const _FollowRefreshItemResult(_FollowRefreshItemOutcome.deferred);
      }
      var limited = false;
      if (_isDouyinLimited(item, e)) {
        limited = true;
        if (douyinLimiter != null) {
          douyinLimiter.onLimited();
          _handleDouyinLimited();
        } else {
          _handleDouyinLimited();
        }
      }
      Log.logPrint(e);
      return _FollowRefreshItemResult(
        _FollowRefreshItemOutcome.failed,
        limited: limited,
      );
    }
  }

  bool _isDouyinLimited(FollowUser item, Object error) {
    return item.siteId == Constant.kDouyin &&
        error is CoreError &&
        error.statusCode == 444;
  }

  void _handleDouyinLimited() {
    Log.w("抖音访问受限，已自动降速并继续刷新当前任务");
  }

  void removeItem(FollowUser item, {bool refresh = true}) async {
    final result = await Utils.showAlertDialog(
      "确定要取消关注 ${item.userName} 吗?",
      title: "取消关注",
    );
    if (!result) {
      return;
    }
    await DBService.instance.followBox.delete(item.id);
    if (refresh) {
      refreshData(forceStatus: false);
    } else {
      allList.remove(item);
      list.remove(item);
      livingList.remove(item);
    }
  }

  @override
  void onClose() {
    _updateGeneration++;
    updating.value = false;
    _resetRefreshProgress();
    updateTimer?.cancel();
    subscription?.cancel();
    super.onClose();
  }
}

enum _FollowRefreshItemOutcome {
  success,
  failed,
  deferred,
  skipped,
}

class _FollowRefreshItemResult {
  final _FollowRefreshItemOutcome outcome;
  final bool limited;

  const _FollowRefreshItemResult(this.outcome, {this.limited = false});
}

class _RefreshTargetPolicyResult {
  final List<FollowUser> allowedTargets;
  final List<FollowUser> deferredTargets;
  final String toastMessage;

  const _RefreshTargetPolicyResult({
    required this.allowedTargets,
    required this.deferredTargets,
    this.toastMessage = "",
  });
}

class _PersistedFollowRefreshTaskState {
  final String scopeKey;
  final int total;
  final int successCount;
  final int failedCount;
  final int deferredCount;
  final List<String> orderedKeys;
  final List<String> pendingKeys;

  const _PersistedFollowRefreshTaskState({
    required this.scopeKey,
    required this.total,
    required this.successCount,
    required this.failedCount,
    required this.deferredCount,
    required this.orderedKeys,
    required this.pendingKeys,
  });

  factory _PersistedFollowRefreshTaskState.fromMaps(
    Map<String, dynamic> state,
    Map<String, dynamic> targets,
  ) {
    List<String> readList(dynamic value) {
      if (value is! List) {
        return const [];
      }
      return value.map((item) => item.toString()).toList();
    }

    return _PersistedFollowRefreshTaskState(
      scopeKey: state["scopeKey"]?.toString() ?? "",
      total: (state["total"] as num?)?.toInt() ?? 0,
      successCount: (state["successCount"] as num?)?.toInt() ?? 0,
      failedCount: (state["failedCount"] as num?)?.toInt() ?? 0,
      deferredCount: (state["deferredCount"] as num?)?.toInt() ?? 0,
      orderedKeys: readList(targets["orderedKeys"]),
      pendingKeys: readList(targets["pendingKeys"]),
    );
  }
}
