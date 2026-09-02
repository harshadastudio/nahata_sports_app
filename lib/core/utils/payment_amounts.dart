/// Amount checks that run between creating a Razorpay order and opening the
/// checkout — the last point where a wrong figure can still be stopped.
library;

/// Whether a Razorpay order is for the amount the customer was actually shown.
///
/// [orderAmount] is what `POST /payments/create-order` reported, in paise;
/// [expectedRupees] is the total on screen, coupon already deducted.
///
/// Unlike a "covers the basket" check this is two-sided, because with a coupon
/// both directions are wrong in their own way:
///
/// * an order **below** the shown total means the discount was taken twice —
///   the client sent an already-discounted amount and the backend applied the
///   code to it again,
/// * an order **above** it means the code was not honoured at all and the
///   customer is about to pay the undiscounted price they were told they
///   would not.
///
/// [tolerancePaise] absorbs the rounding between the on-screen double and the
/// whole rupees the request carried; a rupee is far below any real discount.
///
/// A missing or unreadable amount returns true. The check needs a number to
/// compare, and refusing every checkout because a backend stopped reporting
/// one would be worse than the risk it guards.
bool orderMatchesExpected(
  Object? orderAmount,
  num expectedRupees, {
  int tolerancePaise = 100,
}) {
  final paise = orderAmount is num
      ? orderAmount.round()
      : int.tryParse('$orderAmount');

  if (paise == null || paise <= 0) return true;

  final expectedPaise = (expectedRupees * 100).round();
  return (paise - expectedPaise).abs() <= tolerancePaise;
}
