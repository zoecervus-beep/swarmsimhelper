"""Numbers for the simulator that cannot overflow, and that change nothing while they fit in a float.

F is a float subclass. Every operation is done with the ordinary float operation, so while a result fits in
a double it is bit-for-bit the float result the simulator always produced. Only when that operation would
overflow (inf, or OverflowError from **) is the result computed as a Big: value = m x 2^e with a float
mantissa 0.5 <= |m| < 1 and an unbounded int exponent (53-bit precision, like a double). A Big that falls
back under 2^1000 (about 1e301) turns into an F again.

The game itself uses decimal.js with a unit limit of 1e100000; Big has no limit.

Use lg(x) for log10 (math.log10 cannot take a Big), and big(x) to make a number overflow-safe.
"""
import math

_TOP = 1000          # a Big whose exponent drops below this becomes an F again


def _is_bad(r):
    return r != r or r == math.inf or r == -math.inf


class Big(object):
    __slots__ = ('m', 'e')

    def __init__(self, m, e):
        self.m = m; self.e = e

    @staticmethod
    def make(m, e):
        """Normalise m x 2^e; return an F when it fits comfortably in a float."""
        if m == 0:
            return F(0.0)
        m2, e2 = math.frexp(m)
        e = e + e2
        if e < _TOP:
            return F(math.ldexp(m2, e))
        return Big(m2, e)

    @staticmethod
    def of(x):
        if isinstance(x, Big):
            return x
        m, e = math.frexp(float(x))
        b = Big(m, e)
        return b

    # arithmetic -------------------------------------------------------------------------------------
    def __add__(a, b):
        b = Big.of(b)
        if a.m == 0: return Big.make(b.m, b.e)
        if b.m == 0: return Big.make(a.m, a.e)
        if a.e < b.e: a, b = b, a
        d = a.e - b.e
        if d > 64: return Big.make(a.m, a.e)
        return Big.make(a.m + math.ldexp(b.m, -d), a.e)
    __radd__ = __add__

    def __neg__(a): return Big(-a.m, a.e)
    def __pos__(a): return a
    def __abs__(a): return Big(abs(a.m), a.e)
    def __sub__(a, b): return a + (-Big.of(b))
    def __rsub__(a, b): return Big.of(b) + (-a)

    def __mul__(a, b):
        b = Big.of(b)
        return Big.make(a.m * b.m, a.e + b.e)
    __rmul__ = __mul__

    def __truediv__(a, b):
        b = Big.of(b)
        if b.m == 0: raise ZeroDivisionError('Big division by zero')
        return Big.make(a.m / b.m, a.e - b.e)

    def __rtruediv__(a, b):
        return Big.of(b) / a

    def __pow__(a, y):
        if a.m <= 0: raise ValueError('Big power of a non-positive number')
        t = float(y) * (a.e + math.log2(a.m))       # log2 of the result
        e = math.floor(t)
        return Big.make(2.0 ** (t - e), e)

    def log2(a):
        if a.m <= 0: raise ValueError('log of a non-positive Big')
        return a.e + math.log2(a.m)

    # comparisons ------------------------------------------------------------------------------------
    def _cmp(a, b):
        b = Big.of(b)
        sa = (a.m > 0) - (a.m < 0); sb = (b.m > 0) - (b.m < 0)
        if sa != sb: return (sa > sb) - (sa < sb)
        if sa == 0: return 0
        if a.e != b.e:
            r = 1 if a.e > b.e else -1
            return r if sa > 0 else -r
        return (a.m > b.m) - (a.m < b.m)

    def __lt__(a, b): return a._cmp(b) < 0
    def __le__(a, b): return a._cmp(b) <= 0
    def __gt__(a, b): return a._cmp(b) > 0
    def __ge__(a, b): return a._cmp(b) >= 0
    def __eq__(a, b):
        try: return a._cmp(b) == 0
        except (TypeError, ValueError): return False
    def __ne__(a, b): return not a.__eq__(b)
    __hash__ = None

    def __bool__(a): return a.m != 0
    def __floor__(a): return a if a.e > 60 else math.floor(math.ldexp(a.m, a.e))
    def __ceil__(a): return a if a.e > 60 else math.ceil(math.ldexp(a.m, a.e))

    def __float__(a):
        raise OverflowError('Big value %r does not fit in a float' % (a,))

    def __repr__(a):
        l = lg(a)
        ex = math.floor(l)
        return '%s%.6fe%d' % ('-' if a.m < 0 else '', 10 ** (l - ex), ex)
    __str__ = __repr__

    def __format__(a, spec):
        return repr(a)

    def __deepcopy__(a, memo):
        return Big(a.m, a.e)

    def __reduce__(a):
        return (Big, (a.m, a.e))


def _wrap(r, slow):
    """Return the float result r as an F, or compute it as a Big when it overflowed."""
    if _is_bad(r):
        if r != r:
            return r
        return slow()
    return F.__new__(F, r)


class F(float):
    __slots__ = ()

    def __add__(a, b):
        if type(b) is Big: return b.__radd__(a)
        r = float.__add__(a, b)
        if r is NotImplemented: return r
        return _wrap(r, lambda: Big.of(a) + b)
    __radd__ = __add__

    def __sub__(a, b):
        if type(b) is Big: return b.__rsub__(a)
        r = float.__sub__(a, b)
        if r is NotImplemented: return r
        return _wrap(r, lambda: Big.of(a) - b)

    def __rsub__(a, b):
        r = float.__rsub__(a, b)
        if r is NotImplemented: return r
        return _wrap(r, lambda: Big.of(b) - a)

    def __mul__(a, b):
        if type(b) is Big: return b.__rmul__(a)
        r = float.__mul__(a, b)
        if r is NotImplemented: return r
        return _wrap(r, lambda: Big.of(a) * b)
    __rmul__ = __mul__

    def __truediv__(a, b):
        if type(b) is Big: return b.__rtruediv__(a)
        r = float.__truediv__(a, b)
        if r is NotImplemented: return r
        return _wrap(r, lambda: Big.of(a) / b)

    def __rtruediv__(a, b):
        r = float.__rtruediv__(a, b)
        if r is NotImplemented: return r
        return _wrap(r, lambda: Big.of(b) / a)

    def __pow__(a, y):
        try:
            r = float.__pow__(a, y)
        except OverflowError:
            return Big.of(a) ** y
        if r is NotImplemented: return r
        return _wrap(r, lambda: Big.of(a) ** y)

    def __neg__(a): return F.__new__(F, -float(a))
    def __abs__(a): return F.__new__(F, abs(float(a)))

    # comparisons with a Big: float's own methods return NotImplemented for it, and Python then asks the
    # Big; float-vs-float comparisons are float's own.


def num(x):
    """A number from a save (string, int or float): an F when it fits in a float, else a Big."""
    if isinstance(x, (F, Big)): return x
    try:
        f = float(x)
    except OverflowError:
        f = math.inf
    if not _is_bad(f): return F(f)
    import decimal
    ctx = decimal.Context(prec=40, Emax=10 ** 12, Emin=-10 ** 12)
    d = ctx.create_decimal(str(x))
    if d == 0: return F(0.0)
    sign = -1 if d < 0 else 1; d = abs(d)
    e = int(math.floor(float(d.adjusted()) * math.log2(10))) - 2      # a binary exponent just below the value's
    m = ctx.divide(d, ctx.power(decimal.Decimal(2), e))                 # 1 <= m < 16, exact to 40 digits
    return Big.make(sign * float(m), e)


def dec(x, digits=17):
    """A decimal string of x (float or Big) with `digits` significant digits, e.g. '1.2345678901234567e+1234'.
    Exact to the double's own precision: Big's mantissa and binary exponent go through Python's decimal."""
    import decimal
    if not isinstance(x, Big):
        x = float(x)
        if x == 0: return '0'
        return repr(x) if abs(x) < 1e16 and x == int(x) else '%.*e' % (digits - 1, x)
    if x.m == 0: return '0'
    ctx = decimal.Context(prec=digits + 5, Emax=10 ** 12, Emin=-10 ** 12)
    v = ctx.multiply(decimal.Decimal(x.m), ctx.power(decimal.Decimal(2), x.e))
    s = '{:.{p}e}'.format(ctx.create_decimal(v), p=digits - 1)
    return s


def big(x):
    """An overflow-safe copy of x (an F, or x itself if it is a Big)."""
    if isinstance(x, Big): return x
    return F(x)


def lg(x):
    """log10 of a positive number, float or Big."""
    if isinstance(x, Big):
        return x.log2() * math.log10(2)
    return math.log10(x)


def isbig(x): return isinstance(x, Big)
