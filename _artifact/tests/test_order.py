import pytest

from shop.pricing import order_total


def test_order_simple():
    assert order_total(1000, 1) == 1500


def test_order_bulk_and_free_shipping():
    assert order_total(1000, 10) == 9000


def test_order_with_percent_coupon():
    assert order_total(1000, 3, "PCT10") == 3200


def test_order_with_welcome():
    assert order_total(1000, 2, "WELCOME500") == 2000


def test_order_free_shipping_exact():
    assert order_total(1250, 4) == 5000


def test_order_quantity_99():
    assert order_total(100, 99) == 8415


def test_order_quantity_100_rejected():
    with pytest.raises(ValueError):
        order_total(100, 100)


def test_order_unknown_coupon_rejected():
    with pytest.raises(ValueError):
        order_total(1000, 1, "FOO")


def test_order_total_smoke():
    # 呼ぶだけ(わざと入れた)
    order_total(1000, 3, "PCT10")
