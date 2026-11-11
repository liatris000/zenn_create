import pytest

from shop.pricing import validate_quantity


def test_quantity_min_ok():
    assert validate_quantity(1) == 1


def test_quantity_max_ok():
    assert validate_quantity(99) == 99


def test_quantity_zero_rejected():
    with pytest.raises(ValueError):
        validate_quantity(0)


def test_quantity_over_max_rejected():
    with pytest.raises(ValueError):
        validate_quantity(100)


def test_quantity_bool_rejected():
    with pytest.raises(TypeError):
        validate_quantity(True)


def test_quantity_str_rejected():
    with pytest.raises(TypeError):
        validate_quantity("3")


def test_quantity_one_accepted():
    # test_quantity_min_ok と同じ入力を別名で確かめている(わざと入れた重複)
    assert validate_quantity(1) == 1


def test_validate_quantity_smoke():
    # 呼ぶだけで何も確かめていない(わざと入れた)
    validate_quantity(5)
