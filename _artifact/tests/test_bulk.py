from shop.pricing import bulk_discount_rate


def test_bulk_none_below_5():
    assert bulk_discount_rate(4) == 0


def test_bulk_5():
    assert bulk_discount_rate(5) == 5


def test_bulk_9():
    assert bulk_discount_rate(9) == 5


def test_bulk_10():
    assert bulk_discount_rate(10) == 10


def test_bulk_49():
    assert bulk_discount_rate(49) == 10


def test_bulk_50():
    assert bulk_discount_rate(50) == 15


def test_bulk_five_units():
    # test_bulk_5 と同じ入力(わざと入れた重複)
    assert bulk_discount_rate(5) == 5


def test_bulk_rate_smoke():
    # 呼ぶだけ(わざと入れた)
    bulk_discount_rate(20)
