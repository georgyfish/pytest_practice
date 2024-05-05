import pytest
def func(x):
    if x == 0:
        raise ValueError('value error!')
    else:
        pass

# func(0)

def test_mytest1():
    with pytest.raises(ValueError):
        func(0)

def test_mytest2():
    assert func(1) == None