from shop.pricing import shipping_fee


def test_shipping_below():
    assert shipping_fee(4999) == 500


def test_shipping_free_at_threshold():
    assert shipping_fee(5000) == 0


def test_shipping_free_above():
    assert shipping_fee(8000) == 0


def test_shipping_at_5000():
    # test_shipping_free_at_threshold と同じ入力(わざと入れた重複)
    assert shipping_fee(5000) == 0


def test_shipping_fee_smoke():
    # 呼ぶだけ(わざと入れた)
    shipping_fee(3000)
