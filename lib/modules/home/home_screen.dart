import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:codeway_img_proc/app/theme/app_colors.dart';
import 'package:codeway_img_proc/modules/home/home_controller.dart';
import 'package:codeway_img_proc/modules/home/widgets/history_grid_item.dart';
import 'package:codeway_img_proc/modules/home/widgets/empty_state_widget.dart';
import 'package:codeway_img_proc/shared/widgets/app_loading_indicator.dart';
import 'package:codeway_img_proc/shared/widgets/app_error_view.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => controller.isSearching.value
            ? TextField(
                autofocus: true,
                style: const TextStyle(
                    fontSize: 16, color: AppColors.onSurface),
                decoration: const InputDecoration(
                  hintText: 'Search documents...',
                  hintStyle: TextStyle(
                      fontSize: 16, color: AppColors.onSurfaceVariant),
                  border: InputBorder.none,
                ),
                onChanged: controller.onSearchChanged,
              )
            : const Text('Recents')),
        actions: [
          Obx(() => IconButton(
                icon: Icon(
                    controller.isSearching.value ? Icons.close : Icons.search),
                onPressed: controller.toggleSearch,
              )),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const AppLoadingIndicator();
        }

        final error = controller.errorMessage.value;
        if (error != null) {
          return AppErrorView(
            message: error,
            onRetry: controller.loadHistory,
          );
        }

        final items = controller.displayItems;

        if (controller.isSearching.value &&
            controller.searchQuery.value.isNotEmpty &&
            items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off,
                    size: 48, color: AppColors.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  'No documents match "${controller.searchQuery.value}"',
                  style: const TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 14),
                ),
              ],
            ),
          );
        }

        if (items.isEmpty) {
          return const EmptyStateWidget();
        }

        return CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: controller.loadHistory,
            ),
            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = items[index];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300 + index * 80),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: _DismissableGridItem(
                        key: ValueKey(item.id),
                        itemKey: ValueKey(item.id),
                        onDismissed: () => controller.deleteItem(item),
                        child: HistoryGridItem(
                          item: item,
                          resolvedThumbnailPath:
                              controller.resolvedThumbnails[item.id] ?? '',
                          onTap: () => controller.navigateToDetail(item),
                        ),
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.navigateToCapture,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

class _DismissableGridItem extends StatefulWidget {
  const _DismissableGridItem({
    super.key,
    required this.itemKey,
    required this.onDismissed,
    required this.child,
  });

  final ValueKey itemKey;
  final VoidCallback onDismissed;
  final Widget child;

  @override
  State<_DismissableGridItem> createState() => _DismissableGridItemState();
}

class _DismissableGridItemState extends State<_DismissableGridItem> {
  double _opacity = 1.0;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: widget.itemKey,
      direction: DismissDirection.horizontal,
      background: const SizedBox.shrink(),
      secondaryBackground: const SizedBox.shrink(),
      dismissThresholds: const {
        DismissDirection.endToStart: 0.3,
        DismissDirection.startToEnd: 0.3,
      },
      movementDuration: const Duration(milliseconds: 200),
      onUpdate: (details) {
        setState(() => _opacity = 1.0 - details.progress);
      },
      onDismissed: (_) => widget.onDismissed(),
      child: Opacity(
        opacity: _opacity.clamp(0.0, 1.0),
        child: widget.child,
      ),
    );
  }
}
