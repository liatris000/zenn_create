import pytest

from shop.pricing import parse_coupon


def test_empty_coupon():
    assert parse_coupon("") == ("none", 0)


def test_none_coupon():
    assert parse_coupon(None) == ("none", 0)


def test_welcome_coupon():
    assert parse_coupon("WELCOME500") == ("fixed", 500)


def test_percent_coupon():
    assert parse_coupon("PCT10") == ("percent", 10)


def test_percent_coupon_upper_bound():
    assert parse_coupon("PCT30") == ("percent", 30)


def test_percent_coupon_over_upper_rejected():
    with pytest.raises(ValueError):
        parse_coupon("PCT31")


def test_percent_coupon_zero_rejected():
    with pytest.raises(ValueError):
        parse_coupon("PCT0")


def test_percent_coupon_lower_bound():
    assert parse_coupon("PCT1") == ("percent", 1)


def test_unknown_coupon_rejected():
    with pytest.raises(ValueError):
        parse_coupon("FOO")


def test_pct_non_digit_rejected():
    with pytest.raises(ValueError):
        parse_coupon("PCTx")


def test_welcome_coupon_parsed():
    # test_welcome_coupon と同じ入力(わざと入れた重複)
    assert parse_coupon("WELCOME500") == ("fixed", 500)


def test_parse_coupon_smoke():
    # 呼ぶだけ(わざと入れた)
    parse_coupon("PCT5")
