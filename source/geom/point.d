/*
 * Cartesian point / 2D vector and related operations
 *
 * Authors:
 *   Michael G. Sloan <mgsloan@gmail.com>
 *   Nathan Hurst <njh@njhurst.com>
 *   Krzysztof Kosiński <tweenk.pl@gmail.com>
 *   Liam P. White
 *
 * Copyright (C) 2006-2015 Authors
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

module geom.point;

import geom.coord;
import geom.affine;
import geom.intpoint;
import geom.transforms;

struct Point
{
    /* Creating points */

    /** Construct a point from its coordinates. */
    this(Coord x, Coord y)
    { _pt = [x, y]; }
    
    this(const(Coord[2]) arr)
    { _pt = arr; }

    /** Construct from integer point. */
    this(IntPoint p)
    { _pt = [p[X], p[Y]]; }

    this(in Point p)
    { _pt = p._pt; }

    /** Construct a point from its polar coordinates.
     * The angle is specified in radians, in the mathematical convention (increasing
     * counter-clockwise from +X). */
    static Point polar(Coord angle, Coord radius)
    {
        Point ret = polar(angle);
        ret *= radius;
        return ret;
    }
    /** Construct an unit vector from its angle.
     * The angle is specified in radians, in the mathematical convention (increasing
     * counter-clockwise from +X). */
    static Point polar(Coord angle)
    {
        Point ret = [math.cos(angle), math.sin(angle)];
        return ret;
    }


    /* Access the coordinates of a point */

    ref inout(Coord) opIndex(size_t i) inout
    { return _pt[i]; }

    ref inout(Coord) x() inout { return _pt[X]; }
    ref inout(Coord) y() inout { return _pt[Y]; }

    /* Vector operations */

    /** Compute the distance from origin.
     * Returns: Length of the vector from origin to this point */
    Coord length() const { return math.hypot(_pt[X], _pt[Y]); }

    /** Return a point like this point but rotated -90 degrees.
     * If the y axis grows downwards and the x axis grows to the
     * right, then this is 90 degrees counter-clockwise. */
    Point ccw() const { return Point(_pt[Y], -_pt[X]);  }

    /** Return a point like this point but rotated +90 degrees.
     * If the y axis grows downwards and the x axis grows to the
     * right, then this is 90 degrees clockwise. */
    Point cw() const { return Point(-_pt[Y], _pt[X]); }


    /* Conversion to integer points */

    /** Round to nearest integer coordinates. */
    IntPoint round() const
    {
        IntPoint ret = [cast(IntCoord)math.round(_pt[X]), cast(IntCoord)math.round(_pt[Y])];
        return ret;
    }
    /** Round coordinates downwards. */
    IntPoint floor() const
    {
        IntPoint ret = [cast(IntCoord)math.floor(_pt[X]), cast(IntCoord)math.floor(_pt[Y])];
        return ret;
    }
    /** Round coordinates upwards. */
    IntPoint ceil() const
    {
        IntPoint ret = [cast(IntCoord)math.ceil(_pt[X]), cast(IntCoord)math.ceil(_pt[Y])];
        return ret;
    }

    /* Arithmetic operations */
    Point opUnary(string s)() const if (s == "-") { return Point(-_pt[X], -_pt[Y]); } /* negation */
    
    Point opBinary(string op, T)(T rhs) const
    {
        static if (op == "+") { return Point(_pt[X] + rhs[X], _pt[Y] + rhs[Y]); }
        else static if (op == "-") { return Point(_pt[X] - rhs[X], _pt[Y] - rhs[Y]); }
        else static if (op == "*") { return Point(_pt[X] * rhs, _pt[Y] * rhs); }
        else static if (op == "/") { return Point(_pt[X] / rhs, _pt[Y] / rhs); } // TODO division by zero?
        else static assert(0, "Point operator "~op~" not implemented");
    }
    
    Point opBinary(string op, T : Affine)(T m) const if (op == "*")
    {
        /* Transform the point by the specified matrix. */
        Point lhs = this;
        Coord x = _pt[X], y = _pt[Y];
        lhs[X] = x * m[0] + y * m[2] + m[4];
        lhs[Y] = x * m[1] + y * m[3] + m[5];
        return lhs;
    }
    
    void opOpAssign(string op, T)(T rhs)
    { mixin("this = this "~op~" rhs;"); }
    
    /* Various utilities */
    
    /** Check whether both coordinates are finite. */
    bool isFinite()
    { return !(_pt[X] == Coord.infinity || _pt[Y] == Coord.infinity); }

    /** Check whether the length of the vector is close to 1. */
    bool isNormalized(Coord eps = EPSILON) const { return geom.coord.are_near(length(), 1.0, eps); }

    /** Check whether both coordinates are zero. */
    bool isZero() const { return _pt[X] == 0 && _pt[Y] == 0; }

    /** Lexicographical ordering for points.
     * Y coordinate is regarded as more significant. When sorting according to this
     * ordering, the points will be sorted according to the Y coordinate, and within
     * points with the same Y coordinate according to the X coordinate. */
    int opCmp(ref const(Point) rhs) const
    { return ((_pt[Y] < rhs[Y]) || (( _pt[Y] == rhs[Y] ) && ( _pt[X] < rhs[X] ))) ? -1 : 1; }

    /** Normalize the vector representing the point.
     * After this method returns, the length of the vector will be 1 (unless both coordinates are
     * zero - the zero point will be returned then). The function tries to handle infinite
     * coordinates gracefully. If any of the coordinates are NaN, the function will do nothing.
     * Post: \f$-\epsilon < \left|this\right| - 1 < \epsilon\f$
     * See: unit_vector(geom.Point) */
    void normalize()
    {
        auto len = length();
        if (len == 0) return;
        if (len != len.infinity) {
            this /= len;
        } else {
            /* Delay updating pt in case neither coord is infinite. */
            uint n_inf_coords = 0;
            Point tmp = [0, 0];
            foreach (i, crd; _pt) {
                if (crd == crd.infinity) {
                    ++n_inf_coords;
                    tmp[i] = 1;
                } else if (crd == -crd.infinity) {
                    ++n_inf_coords;
                    tmp[i] = -1;
                }
            }
            final switch (n_inf_coords) {
                case 0:
                    /* Can happen if both coords are near +/-DBL_MAX. */
                    this /= 4.0; // ok, where did 4.0 come from?
                    len = length();
                    assert(len != len.infinity);
                    this /= len;
                    break;
                case 1:
                    this = tmp;
                    break;
                case 2:
                    this = tmp * math.sqrt(0.5);
            }
        }
    }

    string toString() const
    {
        import std.conv : text;
        return text(_pt[X])~","~text(_pt[Y]);
    }

    private Coord[2] _pt = [0, 0];
}


/** Compute the second (Euclidean) norm of @a p.
 * This corresponds to the length of @a p. The result will not overflow even if
 * \f$p_X^2 + p_Y^2\f$ is larger that the maximum value that can be stored
 * in a <code>double</code>.
 * @return \f$\sqrt{p_X^2 + p_Y^2}\f$
 * @relates Point */
Coord L2(Point p)
{ return p.length(); }

/** Compute the square of the Euclidean norm of @a p.
 * Warning: this can overflow where L2 won't.
 * @return \f$p_X^2 + p_Y^2\f$
 * @relates Point */
Coord L2sq(Point p)
{ return p[X]*p[X] + p[Y]*p[Y]; }

// IMPL: NearConcept
/** Nearness predicate for points.
 * True if neither coordinate of @a a is further than @a eps from the corresponding
 * coordinate of @a b.
 * @relates Point */
bool are_near(in Point a, in Point b, in double eps = EPSILON)
{ return (geom.coord.are_near(a[X],b[X],eps) && geom.coord.are_near(a[Y],b[Y],eps)); }

/** Return a point halfway between the specified ones.
 * @relates Point */
Point middle_point(in Point P1, in Point P2)
{ return (P1 + P2) / 2; }

/** Returns p * geom.rotate_degrees(90), but more efficient. (XXX !?)
 *
 * Angle direction in 2Geom: If you use the traditional mathematics convention that y
 * increases upwards, then positive angles are anticlockwise as per the mathematics convention.  If
 * you take the common non-mathematical convention that y increases downwards, then positive angles
 * are clockwise, as is common outside of mathematics.
 *
 * There is no function to rotate by -90 degrees: use -rot90(p) instead.
 * @relates Point */
Point rot90(in Point p)
{ return p.cw(); }

/** Linear interpolation between two points.
 * @param t Time value
 * @param a First point
 * @param b Second point
 * @return Point on a line between a and b. The ratio of its distance from a
 *         and the distance between a and b will be equal to t.
 * @relates Point */
Point lerp(in Point a, in Point b, in double t)
{ return (a * (1 - t) + b * t); }

/** Compute the dot product of a and b.
 * Dot product can be interpreted as a measure of how parallel the vectors are.
 * For perpendicular vectors, it is zero. For parallel ones, its absolute value is highest,
 * and the sign depends on whether they point in the same direction (+) or opposite ones (-).
 * @return \f$a \cdot b = a_X b_X + a_Y b_Y\f$.
 * @relates Point */
Coord dot(in Point a, in Point b)
{ return a[X] * b[X] + a[Y] * b[Y]; }

/** Compute the 2D cross product.
 * Defined as dot(a, b.cw()). This means it will be zero for parallel vectors,
 * and its absolute value highest for perpendicular vectors.
 * @relates Point*/
Coord cross(in Point a, in Point b)
{ return dot(a, b.cw()); }

/** Compute the (Euclidean) distance between points.
 * @relates Point */
Coord distance (in Point a, in Point b)
{ return L2(a - b); }

/** Compute the square of the distance between points.
 * @relates Point */
Coord distanceSq (in Point a, in Point b)
{ return L2sq(a - b); }

/** Create a normalized version of a point.
 * This is equivalent to copying the point and calling its normalize() method.
 * The returned point will be (0,0) if the argument has both coordinates equal to zero.
 * If any coordinate is NaN, this function will do nothing.
 * @param a Input point
 * @return Point on the unit circle in the same direction from origin as a, or the origin
 *         if a has both coordinates equal to zero
 * @relates Point */
Point unit_vector(Point a)
{ a.normalize(); return a; }

/** Compute the first norm (Manhattan distance) of @a p.
 * This is equal to the sum of absolutes values of the coordinates.
 * @return \f$|p_X| + |p_Y|\f$
 * @relates Point */
Coord L1(in Point p)
{ return math.fabs(p[X]) + math.fabs(p[Y]); }

/** @brief Compute the infinity norm (maximum norm) of @a p.
 * @return \f$\max(|p_X|, |p_Y|)\f$
 * @relates Point */
Coord LInfty(in Point p)
{
    Coord a = math.fabs(p[X]);
    Coord b = math.fabs(p[Y]);
    return (a < b || math.isNaN(b) ? b : a);
}

/** True if the point has both coordinates zero.
 * NaNs are treated as not equal to zero.
 * @relates Point */
bool is_zero(in Point p)
{ return p.isZero(); }

/** True if the point has a length near 1. The are_near() function is used.
 * @relates Point */
bool is_unit_vector(in Point p)
{ return p.isNormalized(); }

/** Return the angle between the point and the +X axis.
 * @return Angle in \f$(-\pi, \pi]\f$.
 * @relates Point */
Coord atan2(in Point p)
{ return math.atan2(p[Y], p[X]); }

/** @brief Compute the angle between a and b relative to the origin.
 * The computation is done by projecting b onto the basis defined by a, rot90(a).
 * @return Angle in \f$(-\pi, \pi]\f$.
 * @relates Point */
Coord angle_between(in Point a, in Point b)
{ return math.atan2(cross(b,a), dot(b,a)); }

/** Return the "absolute value" of the point's vector.
 * This is defined in terms of the default lexicographical ordering. If the point is "larger"
 * that the origin (0, 0), its negation is returned. You can check whether
 * the points' vectors have the same direction (e.g. lie
 * on the same line passing through the origin) using
 * @code abs(a).normalize() == abs(b).normalize() @endcode
 * To check with some margin of error, use
 * @code are_near(abs(a).normalize(), abs(b).normalize()) @endcode
 * Although naively this should take the absolute value of each coordinate, such an operation
 * is not very useful.
 * @relates Point */
Point abs(in Point b)
{
    Point ret = [0, 0];
    if (b[Y] < 0.0) {
        ret = -b;
    } else if (b[Y] == 0.0) {
        ret = b[X] < 0.0 ? -b : b;
    } else {
        ret = b;
    }
    return ret;
}

/** Snap the angle B - A - dir to multiples of \f$2\pi/n\f$.
 * The 'dir' argument must be normalized (have unit length), otherwise the result
 * is undefined.
 * @return Point with the same distance from A as B, with a snapped angle.
 * @post distance(A, B) == distance(A, result)
 * @post angle_between(result - A, dir) == \f$2k\pi/n, k \in \mathbb{N}\f$
 * @relates Point */
Point constrain_angle(in Point A, in Point B, uint n, in Point dir)
{
    // for special cases we could perhaps use explicit testing (which might be faster)
    if (n == 0) {
        return B;
    }
    Point diff = B - A;
    double angle = -angle_between(diff, dir);
    double k = math.round(angle * cast(Coord)n / (2.0*math.PI));
    return A + dir * Rotate(k * 2.0 * math.PI / cast(Coord)n) * L2(diff);
}

Point intersection_point(in Point origin_a, in Point vector_a, in Point origin_b, in Point vector_b)
{
    Coord denom = cross(vector_b, vector_a);
    if (!geom.coord.are_near(denom,0.)) {
        Coord t = (cross(origin_a,vector_b) + cross(vector_b,origin_b)) / denom;
        return origin_a + vector_a*t;
    }
    return Point(Coord.infinity, Coord.infinity);
}


unittest
{
    /+ normalization +/
    Point a = [1e-18, 0];
    Point b = a;
    a.normalize();

    assert(a == Point(1, 0));
    assert(b != a);

    /+ scalar ops +/
    a = Point(1, 2);
    assert(a * 2 == Point(2, 4));
    assert(a / 2 == Point(0.5, 1));

    b = a;
    a *= 2;
    a /= 2;
    assert(a == b);

    /+ rounding +/
    a = Point(-0.7, 0.7);
    IntPoint aceil = IntPoint(0, 1);
    IntPoint afloor = IntPoint(-1, 0);
    IntPoint around = IntPoint(-1, 1);

    assert(a.ceil() == aceil);
    assert(a.floor() == afloor);
    assert(a.round() == around);
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
