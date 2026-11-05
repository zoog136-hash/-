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
const SUPPORTED=[0,1,2,3,4,5,25,27,29]
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
