from shop.pricing import apply_coupon


def test_apply_percent():
    assert apply_coupon(1000, ("percent", 10)) == 900


def test_apply_percent_rounds_down():
    assert apply_coupon(999, ("percent", 10)) == 900


def test_apply_fixed():
    assert apply_coupon(1000, ("fixed", 500)) == 500


def test_apply_fixed_floor_zero():
    assert apply_coupon(300, ("fixed", 500)) == 0


def test_apply_none():
    assert apply_coupon(1000, ("none", 0)) == 1000


def test_apply_ten_percent():
    # test_apply_percent と同じ入力(わざと入れた重複)
    assert apply_coupon(1000, ("percent", 10)) == 900
