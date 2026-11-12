import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../models/savings_plan.dart';
import '../../models/savings_transaction.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/finance_overview_provider.dart';
import '../../providers/savings_provider.dart';
import '../../utils/currency_util.dart';
import '../../widgets/candlestick_chart.dart';
import '../../widgets/dashboard_kit.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/shimmer_loading.dart';

class DashboardScreenV2 extends StatefulWidget {
  const DashboardScreenV2({super.key});

  @override
  State<DashboardScreenV2> createState() => _DashboardScreenV2State();
}

class _DashboardScreenV2State extends State<DashboardScreenV2> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
      context.read<SavingsProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceOverviewProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final plans = finance.livePlans
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
    final transactions = finance.recentTransactions;
    final candles = _buildSavingsCandles(finance);
    final userName = _firstName(finance.user?.name);
    final darkMode = false;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.aiAssistant),
        backgroundColor: AppColors.primaryTiffany,
        foregroundColor: Colors.white,
        tooltip: 'AI Coach',
        child: const Icon(Icons.auto_awesome_rounded, size: 20),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          DashboardBackdrop(darkMode: darkMode),
          SafeArea(
            child: Column(
              children: [
                _PhoneHeader(
                  name: userName,
                  darkMode: darkMode,
                  onNotifications: () => Navigator.pushNamed(
                    context,
                    AppRoutes.notifications,
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.loadingRed,
                    onRefresh: () async {
                      await Future.wait([
                        context.read<DashboardProvider>().loadDashboard(),
                        context.read<SavingsProvider>().loadData(),
                      ]);
                    },
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 76),
                      children: [
                  _SectionRow(
                    title: 'Nzeru Savings Plans',
                    trailing: plans.isEmpty ? null : '${plans.length} tracked',
                    darkMode: darkMode,
                  ),
                  const SizedBox(height: 6),
                      plans.isEmpty
                      ? const _EmptyPlanShimmer()
                      : _TopPlansRail(plans: plans, darkMode: darkMode),
                  const SizedBox(height: 8),
                  _PerformanceCard(candles: candles, finance: finance),
                  const SizedBox(height: 8),
                  _SectionRow(title: 'Nzeru Quick Actions', darkMode: darkMode),
                  const SizedBox(height: 6),
                  const _QuickActionsRow(),
                  const SizedBox(height: 8),
                  _SectionRow(
                    title: 'Recent Transactions',
                    trailing: DateFormat('dd MMM').format(DateTime.now()),
                    darkMode: darkMode,
                  ),
                  const SizedBox(height: 6),
                  _TransactionsPanel(
                    transactions: transactions.take(5).toList(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.savingsPlans),
                      child: Text(
                        'See more',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: darkMode
                              ? const Color(0xFF8DE8E5)
                              : AppColors.brandBlue,
                        ),
                      ),
                    ),
                  ),
                  if (dashboard.isLoading) ...[
                    const SizedBox(height: 20),
                    const DashboardPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBlock(width: 150, height: 14),
                          SizedBox(height: 14),
                          ShimmerBlock(height: 12),
                          SizedBox(height: 10),
                          ShimmerBlock(width: 220, height: 12),
                        ],
                      ),
                    ),
                  ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        ],
      ),
    );
  }
}

class _PhoneHeader extends StatelessWidget {
  final String name;
  final bool darkMode;
  final VoidCallback onNotifications;

  const _PhoneHeader({
    required this.name,
    required this.darkMode,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? 'U' : name[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandBlue, AppColors.brandBlueDark],
        ),
        borderRadius: BorderRadius.zero,
        boxShadow: const [],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
              radius: 17,
                backgroundColor: AppColors.tiffanyBlueLight,
                child: Text(
                  initial,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.brandBlueDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 1.0,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onNotifications,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Center(
                        child: Icon(
                          Icons.notifications_none_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 7,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF801818),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String title;
  final String? trailing;
  final bool darkMode;

  const _SectionRow({
    required this.title,
    this.trailing,
    this.darkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                      fontSize: 17,
                fontWeight: FontWeight.w700,
                color: darkMode ? Colors.white : const Color(0xFF111111),
              ),
            ),
            const Spacer(),
            if (trailing != null)
              Text(
                trailing!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: darkMode
                      ? const Color(0xFF8DE8E5)
                      : AppColors.brandBlue,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 3,
          width: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: AppColors.brandBlue,
          ),
        ),
      ],
    );
  }
}

class _TopSavingsPlanCard extends StatelessWidget {
  final SavingsPlan plan;
  final bool darkMode;

  const _TopSavingsPlanCard({required this.plan, required this.darkMode});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(plan.health);
    final percent = (plan.progressPercent * 100).round();
    final rateLabel = _topRateLabel(plan);
    final progressLabel = '+$percent%';

    return Container(
      decoration: BoxDecoration(
        color: darkMode
            ? const Color(0xE61B2430)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: darkMode ? const Color(0x334D5B6C) : const Color(0xFFE8E0D3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayTopTitle(plan.title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: darkMode
                              ? Colors.white
                              : const Color(0xFF111111),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: plan.progressPercent,
                        strokeWidth: 4,
                        backgroundColor: AppColors.primaryTiffanyLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          percent >= 50
                              ? AppColors.loadingGreen
                              : AppColors.loadingRed,
                        ),
                      ),
                      Center(
                        child: Text(
                          '$percent%',
                          style: GoogleFonts.poppins(
                        fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: darkMode
                                ? const Color(0xFFF3F4F6)
                                : const Color(0xFF1F1F1F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${plan.progressPercent >= 1 ? 'Goal' : 'Target'}  ${CurrencyUtil.formatNoDecimal(plan.goalAmount)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: darkMode ? const Color(0xFFF3F4F6) : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              rateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 8,
                color: darkMode
                    ? const Color(0xFFD8E0EB)
                    : const Color(0xFF2E2E2E),
                height: 1.15,
              ),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: plan.progressPercent,
                minHeight: 6,
                backgroundColor: AppColors.primaryTiffanyLight,
                color: percent >= 50
                    ? AppColors.loadingGreen
                    : AppColors.loadingRed,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlueLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    plan.isEstimatedToFinishOnTime ? 'On track' : 'Behind',
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
                Text(
                  progressLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('d MMM yyyy').format(plan.endDate),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: darkMode
                    ? const Color(0xFFD8E0EB)
                    : const Color(0xFF3A3A3A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _displayTopTitle(String title) {
    final trimmed = title.trim();
    return trimmed.isEmpty ? 'Savings' : trimmed;
  }

  static String _topRateLabel(SavingsPlan plan) {
    if (plan.progressPercent >= 1) return 'Saved in full';
    switch (plan.frequency) {
      case PlanFrequency.daily:
        return 'Remaining ${CurrencyUtil.formatNoDecimal(plan.requiredPerDay)}/day';
      case PlanFrequency.weekly:
      case PlanFrequency.biweekly:
        return 'Remaining ${CurrencyUtil.formatNoDecimal(plan.requiredPerWeek)}/week';
      case PlanFrequency.monthly:
        return 'Saved ${CurrencyUtil.formatNoDecimal(plan.currentAmount)}';
    }
  }

  static Color _statusColor(PlanHealth health) {
    switch (health) {
      case PlanHealth.onTrack:
        return AppColors.brandBlue;
      case PlanHealth.watch:
        return const Color(0xFFC21A03);
      case PlanHealth.behind:
        return const Color(0xFF801818);
    }
  }
}

class _TopPlansRail extends StatelessWidget {
  final List<SavingsPlan> plans;
  final bool darkMode;

  const _TopPlansRail({required this.plans, required this.darkMode});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: plans.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 136,
            child: _TopSavingsPlanCard(plan: plans[index], darkMode: darkMode),
          );
        },
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final List<CandleData> candles;
  final FinanceOverviewProvider finance;

  const _PerformanceCard({required this.candles, required this.finance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8B0000), Color(0xFF6D0000)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nzeru Performance',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Savings Analytics',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTAL SAVED',
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                    Text(
                      CurrencyUtil.formatCompact(
                        finance.totalSaved,
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CandlestickChart(
            candles: candles,
            title: '',
            subtitle: '',
            darkMode: false,
            height: 50,
            borderRadius: BorderRadius.circular(18),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  label: 'Deposits',
                  value: CurrencyUtil.formatCompact(finance.totalDeposits),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricPill(
                  label: 'Withdrawals',
                  value: CurrencyUtil.formatCompact(finance.totalWithdrawals),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricPill(
                  label: 'Interest',
                  value: CurrencyUtil.formatCompact(finance.interestEarned),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        label: 'Deposit',
        icon: Icons.download_rounded,
        route: AppRoutes.deposit,
      ),
      (
        label: 'New Plan',
        icon: Icons.note_alt_rounded,
        route: AppRoutes.createPlan,
      ),
      (
        label: 'Credit',
        icon: Icons.account_balance_wallet_rounded,
        route: AppRoutes.requestLoan,
      ),
      (label: 'Repay', icon: Icons.refresh_rounded, route: AppRoutes.repayment),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, items[i].route),
                child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.brandBlueLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.brandBlue.withAlpha(55)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.brandBlueDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        items[i].icon,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      items[i].label,
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandBlueDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (i != items.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _TransactionsPanel extends StatelessWidget {
  final List<SavingsTransaction> transactions;

  const _TransactionsPanel({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < transactions.length; i++) ...[
            _TransactionRow(txn: transactions[i]),
            if (i != transactions.length - 1)
              Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: const Color(0xFFEFE9DE),
              ),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final SavingsTransaction txn;

  const _TransactionRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    final color = txn.isCredit
        ? AppColors.brandBlue
        : const Color(0xFF801818);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F7),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(
              txn.isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.typeLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF171412),
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy, HH:mm').format(txn.date),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF55504A),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${txn.isCredit ? '+' : '-'}${CurrencyUtil.formatNoDecimal(txn.amount)}',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlanShimmer extends StatelessWidget {
  const _EmptyPlanShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: Row(
        children: List.generate(3, (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
            child: const DashboardPanel(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerBlock(width: 62, height: 9),
                  SizedBox(height: 8),
                  ShimmerBlock(width: 44, height: 8),
                  SizedBox(height: 10),
                  ShimmerBlock(height: 7),
                ],
              ),
            ),
          ),
        )),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7DED1)),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF55504A),
          ),
        ),
      ),
    );
  }
}

List<CandleData> _buildSavingsCandles(FinanceOverviewProvider finance) {
  final transactions = finance.transactions
      .where((txn) => txn.status == TransactionStatus.completed)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  var running = 0.0;
  final candles = transactions.map((txn) {
    final open = running;
    running = (running + (txn.isCredit ? txn.amount : -txn.amount))
        .clamp(0.0, double.infinity)
        .toDouble();
    final close = running;
    return CandleData(
      time: txn.date,
      open: open,
      high: _maxDouble(open, close),
      low: _minDouble(open, close),
      close: close,
      volume: txn.amount,
    );
  }).toList();

  return candles.length <= 42
      ? candles
      : candles.sublist(candles.length - 42);
}

String _firstName(String? name) {
  final trimmed = (name ?? '').trim();
  if (trimmed.isEmpty) return 'User';
  return trimmed.split(' ').first;
}

double _maxDouble(double a, double b) => a > b ? a : b;
double _minDouble(double a, double b) => a < b ? a : b;
