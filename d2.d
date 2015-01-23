/*
 * Lifts one dimensional objects into 2D
 *
 * Authors:
 *    Michael Sloan <mgsloan@gmail.com>
 *    Liam P. White
 *
 * Copyright (C) 2007-2015 Authors
 *
 * This file is part of dgeom.
 * 
 * dgeom is free software: you can redistribute 
 * it and/or modify it under the terms of the GNU General Public 
 * License as published by the Free Software Foundation, either 
 * version 3 of the License, or (at your option) any later version.
 * 
 * dgeom is distributed in the hope that it will 
 * be useful, but WITHOUT ANY WARRANTY; without even the implied warranty 
 * of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with dgeom.  If not, see <http://www.gnu.org/licenses/>.
 */

module geom.d2;

public import geom.coord;

import geom.point; // TODO: convert Point to D2!Coord

/**
 * The D2 class takes two instances of a scalar data type and treats them
 * like a point. All operations which make sense on a point are deﬁned for D2.
 * A D2!Coord is a Point. A D2!Interval is a standard axis aligned rectangle.
 * D2!SBasis provides a 2d parametric function which maps t to a point
 * x(t), y(t)
 */
struct D2(T)
{
    @disable this();

    this(T a, T b)
    { f = [a, b]; }

    this(const(T[2]) arr)
    { f = [T(arr[0]), T(arr[1])]; }

    ref inout(T) opIndex(size_t i) inout
    { return f[i]; }
    
    bool opEquals(in D2!T o) const
    { return f[X] == o.f[X] && f[Y] == o.f[Y]; }

    private T[2] f;
}

/+ Template specializations (dunno if any of these will actually work) +/

bool isZero()(in D2!T f, Coord eps = EPSILON)
{ return f[X].isZero(eps) && f[Y].isZero(eps); }

bool isConstant()(in D2!T f, Coord eps = EPSILON)
{ return f[X].isConstant(eps) && f[Y].isConstant(eps); }

bool isFinite()(in D2!T f)
{ return f[X].isFinite() && f[Y].isFinite(); }

Point at0()(in D2!T f)
{ return Point(f[X].at0(), f[Y].at0()); }

Point at1()(in D2!T f)
{ return Point(f[X].at1(), f[Y].at1()); }

Point valueAt()(in D2!T f, Coord t)
{ return Point(f[X](t), f[Y](t)); }

Point[] valueAndDerivatives()(in D2!T f, Coord t, uint n)
{
    Coord[] x = f[X].valueAndDerivatives(t, n),
            y = f[Y].valueAndDerivatives(t, n); // always returns a slice of size n+1

    Point[n+1] res;
    foreach(i, ref r; res) {
        r = Point(x[i], y[i]);
    }
    return res;
}

D2!T reverse()(in D2!T a)
{ return D2!T(reverse(a[X]), reverse(a[Y])); }

D2!T portion()(in D2!T a, Coord f, Coord t)
{ return D2!T(portion(a[X], f, t), portion(a[Y], f, t)); }

D2!T portion()(in D2!T a, Interval i)
{ return D2!T(portion(a[X], i), portion(a[Y], i)); }

bool are_near(T)(in D2!T a, in D2!T b, Coord tol = EPSILON)
{ return are_near(a[0], b[0], tol) && are_near(a[1], b[1], tol); }

import geom.sbasis;

D2!SBasis toSBasis()(in D2!T f)
{ return D2!SBasis(f[X].toSBasis(), f[Y].toSBasis()); }

/** Calculates the 'dot product' or 'inner product' of \c a and \c b
 * @return \f$a \bullet b = a_X b_X + a_Y b_Y\f$.
 * @relates D2 */
T dot(T, U)(in D2!T a, in U b)
{
    T r;
    for (uint i = 0; i < 2; i++)
        r += a[i] * b[i];
    return r;
}

/** Calculates the 'cross product' or 'outer product' of \c a and \c b
 * @return \f$a \times b = a_Y b_X - a_X b_Y\f$.
 * @relates D2 */
T cross(T, U)(in D2!T a, in U b)
{ return a[1] * b[0] - a[0] * b[1]; }

// equivalent to cw/ccw, for use in situations where rotation direction doesn't matter.
D2!T rot90()(in D2!T a)
{ return D2!T(-a[Y], a[X]); }

D2!T compose()(in D2!T a, in T b)
{
    D2!T r;
    r[X] = a[X].compose(b);
    r[Y] = a[Y].compose(b);
    return r;
}

D2!T compose_each()(in D2!T a, in D2!T b)
{
    D2!T r;
    r[X] = a[X].compose(b[X]);
    r[Y] = a[Y].compose(b[Y]);
    return r;
}

D2!T compose_each()(in T a, in D2!T b)
{
    D2!T r;
    for(uint i = 0; i < 2; i++)
        r[i] = compose(a,b[i]);
    return r;
}

/*
  Local Variables:
  mode:d
  c-file-style:"stroustrup"
  c-file-offsets:((innamespace . 0)(inline-open . 0)(case-label . +))
  indent-tabs-mode:nil
  fill-column:99
  End:
*/
// vim: filetype=d:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:fileencoding=utf-8 :
