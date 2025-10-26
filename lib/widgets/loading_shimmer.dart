import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/app_theme.dart';

class LoadingShimmer extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;

  const LoadingShimmer({
    Key? key,
    this.itemCount = 5,
    this.itemHeight = 120,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildShimmerCard(),
        );
      },
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          height: itemHeight,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title and status
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 60,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 6),
              
              // Venue
              FractionallySizedBox(
                widthFactor: 0.7,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              
              const SizedBox(height: 6),
              
              // Date
              FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              
              const Spacer(flex: 1),
              
              // Stats row
              Row(
                children: [
                  _buildShimmerStat(),
                  const SizedBox(width: 12),
                  _buildShimmerStat(),
                  const SizedBox(width: 12),
                  _buildShimmerStat(),
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerStat() {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 20,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 30,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class LoadingShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;

  const LoadingShimmerList({
    Key? key,
    this.itemCount = 8,
    this.itemHeight = 80,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildShimmerListItem(),
        );
      },
    );
  }

  Widget _buildShimmerListItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: itemHeight,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Status indicator
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingShimmerGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double childAspectRatio;
  final EdgeInsets padding;

  const LoadingShimmerGrid({
    Key? key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.padding = const EdgeInsets.all(16),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return _buildShimmerGridItem();
      },
    );
  }

  Widget _buildShimmerGridItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              FractionallySizedBox(
                widthFactor: 0.7,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}