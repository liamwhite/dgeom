/**
 * Defines S-power basis function class
 *
 *  Authors:
 *    Nathan Hurst <njh@mail.csse.monash.edu.au>
 *    Michael Sloan <mgsloan@gmail.com>
 *    Liam P. White
 *
 * Copyright (C) 2006-2015 authors
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

module geom.sbasis;

public import geom.coord;
import math = std.math;
import geom.linear;
import geom.interval;

/**
* S-power basis function class
*
* An empty SBasis is identically 0.
*/
struct SBasis
{
    /* Construct an SBasis from a single value. */
    this(Coord a) { push_back(Linear(a)); }

    /* Construct an SBasis from a linear fragment. */
    this(Coord a, Coord b) { push_back(Linear(a, b)); }

    /* Construct an SBasis from a linear fragment. */
    this(in Linear bo) { push_back(bo); }

    /* Construct from another SBasis. */
    this(in SBasis a) { d = a.d.dup; }

    /* Construct from an array of linear fragments. */
    this(const(Linear[]) ls) { d = ls.dup; }


    /+ Get information about the SBasis +/

    Coord at0() const { return empty() ? 0 : d[0][0]; }
    Coord at1() const { return empty() ? 0 : d[0][1]; }

    int degreesOfFreedom() const { return cast(int)size() * 2; }
    
    Coord valueAt(Coord t) const
    {
        import std.range : retro;
        Coord s = t * (1 - t);
        Coord p0 = 0, p1 = 0;
        foreach (lin; retro(d)) {
            p0 = p0 * s + lin[0];
            p1 = p1 * s + lin[1];
        }
        return (1 - t)*p0 + t*p1;
    }

    /* Test to see if any of the pieces are zero. */
    bool isZero(Coord eps = EPSILON) const
    {
        if (empty()) return true;
        foreach (i; d)
            if (i.isZero(eps)) return false;
        return true;
    }

    bool isConstant(Coord eps = EPSILON) const
    {
        if (empty()) return true;
        if (!d[0].isConstant(eps)) return false;
        foreach (i; d[1..$])
            if (!i.isZero(eps)) return false;
        return true;
    }

    bool isFinite() const
    {
        foreach (i; d)
            if(!i.isFinite()) return false;
        return true;
    }

    /** Compute the value and the first n derivatives
     * @param t position to evaluate
     * @param n number of derivatives (not counting value)
     * @return an array with the value and the n derivative evaluations
     *
     * There is an elegant way to compute the value and n derivatives for a polynomial using
     * a variant of horner's rule.  Someone will someday work out how for sbasis.
     */
    Coord[] valueAndDerivatives(Coord t, uint n) const
    {
        Coord[] ret;
        ret.length = n+1;
        ret[0] = valueAt(t);
        SBasis tmp = SBasis(this);
        for (uint i = 1; i < n + 1; ++i) {
            tmp.derive();
            ret[i] = tmp.valueAt(t);
        }
        return ret;
    }

    SBasis toSBasis() const { return SBasis(this); }

    /** bound the error from term truncation
     * @param tail first term to chop
     * @return the largest possible error this truncation could give
     */
    Coord tailError(uint tail) const
    {
        Interval bs = bounds_fast(this, tail);
        return math.fmax(math.fabs(bs.min()), math.fabs(bs.max()));
    }

    // compute f(g)
    SBasis opCall(in SBasis g) const
    { return compose(this, g); }

    Coord opCall(Coord t) const { return valueAt(t); }

    // remove extra zeros
    void normalize()
    {
        while (!empty() && 0 == back()[0] && 0 == back()[1])
            pop_back();
    }

    void truncate(uint k) { if (k < size()) d = d[0..k]; }
    
    SBasis opBinary(string op, T)(T b) const
    {
        static if (op == "+") {
            const uint out_size = cast(uint)math.fmax(size(), b.size());
            const uint min_size = cast(uint)math.fmin(size(), b.size());
            SBasis result;
            result.resize(out_size);

            for (uint i = 0; i < min_size; i++)
                result[i] = this[i] + b[i];
            for (uint i = min_size; i < size(); i++)
                result[i] = this[i];
            for (uint i = min_size; i < b.size(); i++)
                result[i] = b[i];

            assert(result.size() == out_size);
            return result;
        } else static if (op == "-") {
            const uint out_size = cast(uint)math.fmax(size(), b.size());
            const uint min_size = cast(uint)math.fmin(size(), b.size());
            SBasis result;
            result.resize(out_size);

            for (uint i = 0; i < min_size; i++)
                result[i] = this[i] + b[i];
            for (uint i = min_size; i < size(); i++)
                result[i] = this[i];
            for (uint i = min_size; i < b.size(); i++)
                result[i] = b[i];

            assert(result.size() == out_size);
            return result;
        } else static assert(false, "SBasis operator "~op~" not implemented");
    }
    
    SBasis opBinary(string op, T : Coord)(T k) const
    {
        static if (op == "+") {
            if (isZero()) return SBasis(Linear(k, k));
            SBasis a = this;
            a[0] += k;
            return a;
        } else static if (op == "-") {
            if (isZero()) return SBasis(Linear(-k, -k));
            SBasis a = SBasis(this);
            a[0] -= k;
            return a;
        } else static if (op == "*") {
            SBasis c;
            c.resize(size());
            for (uint i = 0; i < size(); i++)
                c[i] = this[i] * k;
            return c;
        } else static if (op == "/") { return this * (1./k); }
        else static assert(false, "SBasis operator "~op~" not implemented");
    }

    void opOpAssign(string op, T)(T rhs)
    { mixin("this = this "~op~" rhs;"); }


    /+ Array-like operations +/

    ref inout(Linear) opIndex(size_t i) inout
    { return d[i]; }
    ref inout(Linear) back() inout { return d[$-1]; }
    ref inout(Linear) at(size_t i) inout { return d[i]; }

    bool empty() const { return d.length == 0; }
    void pop_back() { if (size() > 0) d.length--; }
    void clear() { d = []; }
    void resize(in size_t new_sz) { d.length = new_sz; }
    size_t size() const { return d.length; }

    /++++++++++++++++++++++++/

    private Linear[] d;
    private void push_back(in Linear l) { d ~= l; }

    // in place version
    private void derive()
    { 
        if (isZero()) return;
        for (uint k = 0; k < size() - 1; k++) {
            double d = (2*k+1)*(this[k][1] - this[k][0]);
            
            this[k][0] = d + (k+1)*this[k+1][0];
            this[k][1] = d - (k+1)*this[k+1][1];
        }

        int k = cast(int) size() - 1;
        double d = (2*k+1)*(this[k][1] - this[k][0]);
        if (d == 0)
            pop_back();
        else {
            this[k][0] = d;
            this[k][1] = d;
        }
    }
}

// a(b(t))

/** Compute a composed with b
 * @param a,b sbasis functions
 * @return sbasis a(b(t))
 *
 * return a0 + s(a1 + s(a2 +...  where s = (1-u)u; ak =(1 - u)a^0_k + ua^1_k
 */
SBasis compose(in SBasis a, in SBasis b)
{
    SBasis ctmp = SBasis(Linear(1, 1)) - b;
    SBasis s = multiply(ctmp, b);
    SBasis r;

    for (size_t i = a.size() - 1; i >= 0; i--) {
        r = multiply_add(r, s, SBasis(Linear(a[i][0])) - b*a[i][0] + b*a[i][1]);
    }
    return r;
}

/** Compute a composed with b to k terms
 * @param a,b sbasis functions
 * @return sbasis a(b(t))
 *
 * return a0 + s(a1 + s(a2 +...  where s = (1-u)u; ak =(1 - u)a^0_k + ua^1_k
 */
SBasis compose(in SBasis a, in SBasis b, uint k)
{
    SBasis r = compose(a, b);
    r.truncate(k);
    return r;
}

/* Inversion algorithm. The notation is certainly very misleading. The
pseudocode should say:

c(v) := 0
r(u) := r_0(u) := u
for i:=0 to k do
  c_i(v) := H_0(r_i(u)/(t_1)^i; u)
  c(v) := c(v) + c_i(v)*t^i
  r(u) := r(u) ? c_i(u)*(t(u))^i
endfor
*/

/** find the function a^-1 such that a^-1 composed with a to k terms is the identity function
 * @param a sbasis function
 * @return sbasis a^-1 s.t. a^-1(a(t)) = 1
 *
 * The function must have 'unit range'("a00 = 0 and a01 = 1") and be monotonic.
 */
SBasis inverse(SBasis a, int k)
{
    debug(debug_inversion) import std.stdio;

    assert(a.size() > 0);
    Coord a0 = a[0][0];
    if (a0 != 0) {
        a -= a0;
    }
    Coord a1 = a[0][1];
    assert(a1 != 0); // not invertable.

    if(a1 != 1) {
        a /= a1;
    }
    SBasis c;
    c.resize(k);                           // c(v) := 0
    if (a.size() >= 2 && k == 2) {
        c[0] = Linear(0,1);
        Linear t1 = Linear(1+a[1][0], 1-a[1][1]);    // t_1
        c[1] = Linear(-a[1][0]/t1[0], -a[1][1]/t1[1]);
    } else if (a.size() >= 2) {                      // non linear
        SBasis r = Linear(0,1);             // r(u) := r_0(u) := u
        Linear t1 = Linear(1./(1+a[1][0]), 1./(1-a[1][1]));    // 1./t_1
        Linear one = Linear(1,1);
        Linear t1i = one;                   // t_1^0
        SBasis one_minus_a = SBasis(one) - a;
        SBasis t = multiply(one_minus_a, a); // t(u)
        SBasis ti = SBasis(one);                     // t(u)^0

        debug(debug_inversion) {
            writeln("a=", a);
            writeln("1-a=", one_minus_a);
            writeln("t1=", t1);
        }

        //c.resize(k+1, Linear(0,0));
        for (uint i = 0; i < cast(uint)k; i++) {   // for i:=0 to k do
            debug(debug_inversion) {
                writeln("-------", i, ": ---------");
                writeln("r=", r);
                writeln("c=", c);
                writeln("ti=", ti);
            }

            if(r.size() <= i)                // ensure enough space in the remainder, probably not needed
                r.resize(i+1);
            Linear ci = Linear(r[i][0]*t1i[0], r[i][1]*t1i[1]); // c_i(v) := H_0(r_i(u)/(t_1)^i; u)

            debug(debug_inversion) {
                writeln("t1i=", t1i);
                writeln("ci=", ci);
            }

            for(int dim = 0; dim < 2; dim++) // t1^-i *= 1./t1
                t1i[dim] *= t1[dim];
            c[i] = ci; // c(v) := c(v) + c_i(v)*t^i
            // change from v to u parameterisation
            SBasis civ = one_minus_a*ci[0] + a*ci[1];
            // r(u) := r(u) - c_i(u)*(t(u))^i
            // We can truncate this to the number of final terms, as no following terms can
            // contribute to the result.
            r -= multiply(civ,ti);
            r.truncate(k);
            if(r.tailError(i) == 0)
                break; // yay!
            ti = multiply(ti,t);
        }
        debug(debug_inversion) writeln("##########################");
    } else {
        c = SBasis(Linear(0,1)); // linear
    }

    c -= a0; // invert the offset
    c /= a1; // invert the slope
    return c;
}

/** Compute the pointwise product of a and b (Exact)
 * @param a,b sbasis functions
 * @returns sbasis equal to a*b
 */
SBasis multiply(in SBasis a, in SBasis b)
{
    SBasis c;
    c.resize(a.size() + b.size());
    if (a.isZero() || b.isZero())
        return c;
    return multiply_add(a, b, c);
}

/** Compute the pointwise product of a and b adding c (Exact)
 * @param a,b,c sbasis functions
 * @return sbasis equal to a*b+c
 *
 * The added term is almost free
 */
static SBasis multiply_add(in SBasis a, in SBasis b, SBasis c)
{
    if (a.isZero() || b.isZero())
        return c;
    c.resize(a.size() + b.size());

    for (uint j = 0; j < b.size(); j++) {
        for (uint i = j; i < a.size() + j; i++) {
            Coord tri = b[j].tri() * a[i-j].tri();
            c[i+1/*shift*/] += Linear(-tri);
        }
    }
    for (uint j = 0; j < b.size(); j++) {
        for (uint i = j; i < a.size() + j; i++) {
            c[i][X] += b[j][X]*a[i-j][X];
            c[i][Y] += b[j][Y]*a[i-j][Y];
        }
    }
    c.normalize();
    //assert(!(0 == c.back()[0] && 0 == c.back()[1]));
    return c;
}

Interval bounds_fast(in SBasis sb, int order)
{
    Interval res = Interval(0,0); // an empty sbasis is 0.

    for (int j = cast(int)sb.size() - 1; j >= order; j--) {
        Coord a = sb[j][0];
        Coord b = sb[j][1];

        Coord v, t = 0;
        v = res[0];
        if (v < 0) t = ((b-a)/v+1)*0.5;
        if (v >= 0 || t<0 || t>1) {
            res.setMin(math.fmin(a, b));
        } else {
            res.setMin(lerp(t, a+v*t, b));
        }

        v = res[1];
        if (v > 0) t = ((b-a)/v+1)*0.5;
        if (v <= 0 || t < 0 || t > 1) {
            res.setMax(math.fmax(a,b));
        } else {
            res.setMax(lerp(t, a+v*t, b));
        }
    }

    if (order > 0) res *= math.pow(.25, order);
    return res;
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