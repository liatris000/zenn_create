"""失敗の履歴の代わり。起きそうなバグを手で 6 件書き、それぞれで落ちたテストを履歴とみなす。"""

BUGS = {
    "送料無料の境界を > にした": ("amount >= FREE_SHIPPING_FROM", "amount > FREE_SHIPPING_FROM"),
    "10 本からの割引率を 5% にした": ("        return 10\n", "        return 5\n"),
    "初回クーポンの値引きを 50 円にした": ("WELCOME_AMOUNT = 500", "WELCOME_AMOUNT = 50"),
    "固定値引きの 0 円下限を外した": ("max(amount - value, 0)", "amount - value"),
    "未知のクーポンを黙って無視した": ('raise ValueError("unknown coupon")', 'return ("none", 0)'),
    "数量の上限を 100 にした": ("quantity > QUANTITY_MAX", "quantity > QUANTITY_MAX + 1"),
}


def bug_sources(source):
    out = {}
    for name, (before, after) in BUGS.items():
        assert source.count(before) == 1, name
        out[name] = source.replace(before, after)
    return out
