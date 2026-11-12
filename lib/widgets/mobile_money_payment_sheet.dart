import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum MalawiMobileMoneyProvider { airtelMoney, tnmMpamba }

class MobileMoneyPaymentChoice {
  final String gateway;
  final MalawiMobileMoneyProvider provider;

  const MobileMoneyPaymentChoice({
    this.gateway = 'PayChangu',
    required this.provider,
  });

  String get providerName => switch (provider) {
    MalawiMobileMoneyProvider.airtelMoney => 'Airtel Money',
    MalawiMobileMoneyProvider.tnmMpamba => 'TNM Mpamba',
  };
}

Future<MobileMoneyPaymentChoice?> showMobileMoneyPaymentSheet(
  BuildContext context, {
  required String action,
  required double amount,
}) {
  return showModalBottomSheet<MobileMoneyPaymentChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MobileMoneyPaymentSheet(
      action: action,
      amount: amount,
    ),
  );
}

class _MobileMoneyPaymentSheet extends StatelessWidget {
  final String action;
  final double amount;

  const _MobileMoneyPaymentSheet({required this.action, required this.amount});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          22 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              action == 'Deposit' ? 'Choose how to add funds' : 'Choose where to receive funds',
              style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  'MK ${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Image.asset(
                  'assets/images/payment/paychangu.png',
                  height: 30,
                  width: 58,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ProviderTile(
              name: 'Airtel Money',
              subtitle: 'Mobile money',
              logoAsset: 'assets/images/payment/airtel_money.png',
              onTap: () => Navigator.pop(
                context,
                const MobileMoneyPaymentChoice(provider: MalawiMobileMoneyProvider.airtelMoney),
              ),
            ),
            const SizedBox(height: 10),
            _ProviderTile(
              name: 'TNM Mpamba',
              subtitle: 'Mobile money',
              logoAsset: 'assets/images/payment/tnm.png',
              onTap: () => Navigator.pop(
                context,
                const MobileMoneyPaymentChoice(provider: MalawiMobileMoneyProvider.tnmMpamba),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String logoAsset;
  final VoidCallback onTap;

  const _ProviderTile({
    required this.name,
    required this.subtitle,
    required this.logoAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Image.asset(
                  logoAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(subtitle, style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
