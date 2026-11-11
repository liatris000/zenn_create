"""人が決めた「残す線」。守るべき規則ごとに、消さないテストを挙げる。"""

GUARD = {
    "数量は 1〜99": [
        "tests/test_quantity.py::test_quantity_min_ok",
        "tests/test_quantity.py::test_quantity_max_ok",
        "tests/test_quantity.py::test_quantity_zero_rejected",
        "tests/test_quantity.py::test_quantity_over_max_rejected",
    ],
    "まとめ買い割引は 5・10・50 本から": [
        "tests/test_bulk.py::test_bulk_5",
        "tests/test_bulk.py::test_bulk_10",
        "tests/test_bulk.py::test_bulk_50",
    ],
    "送料無料は 5000 円ちょうどから": [
        "tests/test_shipping.py::test_shipping_below",
        "tests/test_shipping.py::test_shipping_free_at_threshold",
    ],
    "割合クーポンは 1〜30%": [
        "tests/test_coupon.py::test_percent_coupon_upper_bound",
        "tests/test_coupon.py::test_percent_coupon_over_upper_rejected",
    ],
    "知らないクーポンは拒否する": ["tests/test_coupon.py::test_unknown_coupon_rejected"],
    "固定値引きで 0 円を下回らない": ["tests/test_apply.py::test_apply_fixed_floor_zero"],
    "割合の値引きは切り捨て": ["tests/test_apply.py::test_apply_percent_rounds_down"],
}

PROTECTED = frozenset(t for tests in GUARD.values() for t in tests)
