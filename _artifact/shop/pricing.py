"""料金計算。数量の上限、まとめ買い割引、クーポン、送料無料の境界を持つ。"""

QUANTITY_MIN = 1
QUANTITY_MAX = 99
FREE_SHIPPING_FROM = 5000
SHIPPING_FEE = 500
WELCOME_AMOUNT = 500
PERCENT_MAX = 30


def validate_quantity(quantity):
    if isinstance(quantity, bool) or not isinstance(quantity, int):
        raise TypeError("quantity must be int")
    if quantity < QUANTITY_MIN or quantity > QUANTITY_MAX:
        raise ValueError("quantity out of range")
    return quantity


def bulk_discount_rate(quantity):
    if quantity >= 50:
        return 15
    if quantity >= 10:
        return 10
    if quantity >= 5:
        return 5
    return 0


def parse_coupon(code):
    if not code:
        return ("none", 0)
    if code == "WELCOME500":
        return ("fixed", WELCOME_AMOUNT)
    if code.startswith("PCT") and code[3:].isdigit():
        percent = int(code[3:])
        if percent < 1 or percent > PERCENT_MAX:
            raise ValueError("percent out of range")
        return ("percent", percent)
    raise ValueError("unknown coupon")


def apply_coupon(amount, coupon):
    kind, value = coupon
    if kind == "percent":
        return amount - amount * value // 100
    if kind == "fixed":
        return max(amount - value, 0)
    return amount


def shipping_fee(amount):
    if amount >= FREE_SHIPPING_FROM:
        return 0
    return SHIPPING_FEE


def order_total(unit_price, quantity, coupon_code=""):
    validate_quantity(quantity)
    subtotal = unit_price * quantity
    subtotal = subtotal - subtotal * bulk_discount_rate(quantity) // 100
    discounted = apply_coupon(subtotal, parse_coupon(coupon_code))
    return discounted + shipping_fee(discounted)
