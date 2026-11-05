# Copyright (c) 2013-2014 Chukong Technologies Inc.
# http://www.cocos2d-x.org
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

extends RefCounted
# Original numeric TweenType IDs from cocos2d-x-3.6/cocos/2d/CCTweenFunction.
const SUPPORTED=[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30]
static func accepts(data: Dictionary) -> bool:
	var kind: int=int(data.get("type",0))
	var points: Array=data.get("points",[])
	if kind!=-1:return kind in SUPPORTED and points.is_empty()
	if points.size()!=4:return false
	for point: Variant in points:
		if not point is Array or point.size()!=2:return false
		for value: Variant in point:
			if not (value is float or value is int) or not is_finite(float(value)):return false
	return true
static func sample(kind: int, t: float, points: Array=[]) -> float:
	match kind:
		-1:
			# Cocos customEase evaluates the four Y ordinates directly. It does
			# not invert the X coordinates like a CSS cubic-bezier curve.
			var u: float=1.0-t
			return points[0][1]*u*u*u+3.0*points[1][1]*t*u*u+3.0*points[2][1]*t*t*u+points[3][1]*t*t*t
		1: return 1.0-cos(t*PI/2.0)
		2: return sin(t*PI/2.0)
		3: return (1.0-cos(PI*t))/2.0
		4: return t*t
		5: return t*(2.0-t)
		6:
			var u: float=t*2.0
			if u<1.0:return 0.5*u*u
			u-=1.0
			return -0.5*(u*(u-2.0)-1.0)
		7: return t*t*t
		8: return pow(t-1.0,3)+1.0
		9:
			var u: float=t*2.0
			return 0.5*u*u*u if u<1.0 else 0.5*(pow(u-2.0,3)+2.0)
		10: return t*t*t*t
		11: return 1.0-pow(t-1.0,4)
		12:
			var u: float=t*2.0
			return 0.5*pow(u,4) if u<1.0 else -0.5*(pow(u-2.0,4)-2.0)
		13: return pow(t,5)
		14: return pow(t-1.0,5)+1.0
		15:
			var u: float=t*2.0
			return 0.5*pow(u,5) if u<1.0 else 0.5*(pow(u-2.0,5)+2.0)
		16: return 0.0 if t==0.0 else pow(2.0,10.0*(t-1.0))-0.001
		17: return 1.0 if t==1.0 else 1.0-pow(2.0,-10.0*t)
		18:
			# Preserve the original nonzero endpoint values; no normalization.
			var u: float=t*2.0
			return 0.5*pow(2.0,10.0*(u-1.0)) if u<1.0 else 0.5*(-pow(2.0,-10.0*(u-1.0))+2.0)
		19: return 1.0-sqrt(1.0-t*t)
		20: return sqrt(1.0-(t-1.0)*(t-1.0))
		21:
			var u: float=t*2.0
			return -0.5*(sqrt(1.0-u*u)-1.0) if u<1.0 else 0.5*(sqrt(1.0-(u-2.0)*(u-2.0))+1.0)
		22:
			if t==0.0 or t==1.0:return t
			return -pow(2.0,10.0*(t-1.0))*sin((t-1.0-0.075)*TAU/0.3)
		23:
			if t==0.0 or t==1.0:return t
			return pow(2.0,-10.0*t)*sin((t-0.075)*TAU/0.3)+1.0
		24:
			if t==0.0 or t==1.0:return t
			var u: float=t*2.0-1.0
			if u<0.0:return -0.5*pow(2.0,10.0*u)*sin((u-0.075)*TAU/0.3)
			return 0.5*pow(2.0,-10.0*u)*sin((u-0.075)*TAU/0.3)+1.0
		26:
			var u: float=t-1.0
			return u*u*(2.70158*u+1.70158)+1.0
		28: return 1.0-bounce(1.0-t)
		30: return (1.0-bounce(1.0-t*2.0))*0.5 if t<0.5 else bounce(t*2.0-1.0)*0.5+0.5
		25: return t*t*(2.70158*t-1.70158)
		27:
			var s: float=1.70158*1.525
			var u: float=2.0*t
			if u<1.0:return u*u*((s+1.0)*u-s)/2.0
			u-=2.0
			return u*u*((s+1.0)*u+s)/2.0+1.0
		29: return bounce(t)
	return t
static func bounce(t: float) -> float:
	if t<1.0/2.75:return 7.5625*t*t
	if t<2.0/2.75:
		t-=1.5/2.75
		return 7.5625*t*t+0.75
	if t<2.5/2.75:
		t-=2.25/2.75
		return 7.5625*t*t+0.9375
	t-=2.625/2.75
	return 7.5625*t*t+0.984375
