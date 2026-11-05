# Copyright (c) 2008-2010 Ricardo Quesada
# Copyright (c) 2010-2012 cocos2d-x.org
# Copyright (c) 2011 Zynga Inc.
# Copyright (c) 2013-2014 Chukong Technologies Inc.
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
## Source Cocos ParticleSystem's GROUPED simulation. No new effect parameters.
var config: Dictionary={}
var particles: Array[Dictionary]=[]
var active: bool=true
var elapsed: float=0.0
var emit_counter: float=0.0
var emission_rate: float=0.0
var maximum: int=0
var mode: int=0
var random_source: Callable
var _random:=RandomNumberGenerator.new()
func configure(values: Dictionary, source_random: Callable=Callable()) -> Dictionary:
	if not str(values.get("configName","")).is_empty() or int(values.get("yCoordFlipped",1))!=1:return {"ok":false,"error":"unverified_particle_config_variant"}
	maximum=int(values.get("maxParticles",0))
	mode=int(values.get("emitterType",-1))
	if maximum<0 or maximum>4096 or mode not in [0,1] or float(values.get("particleLifespan",0))<=0:return {"ok":false,"error":"unsupported_particle_limits_or_mode"}
	config=values.duplicate(true)
	for key: Variant in config:
		if config[key] is float or config[key] is int:config[key]=f32(float(config[key]))
	emission_rate=f32(float(maximum)/number("particleLifespan"))
	random_source=source_random
	_random.randomize()
	particles.clear();active=true;elapsed=0.0;emit_counter=0.0
	return {"ok":true}
func number(key: String) -> float:return float(config.get(key,0.0))
static func f32(value: float) -> float:return PackedFloat32Array([value])[0]
func random_signed() -> float:
	return f32(float(random_source.call())) if random_source.is_valid() else _random.randf_range(-1.0,1.0)
func varied(key: String, variance: String) -> float:return f32(number(key)+f32(number(variance)*random_signed()))
func random_color(prefix: String) -> Color:
	return Color(clampf(varied(prefix+"ColorRed",prefix+"ColorVarianceRed"),0,1),clampf(varied(prefix+"ColorGreen",prefix+"ColorVarianceGreen"),0,1),clampf(varied(prefix+"ColorBlue",prefix+"ColorVarianceBlue"),0,1),clampf(varied(prefix+"ColorAlpha",prefix+"ColorVarianceAlpha"),0,1))
func add_particle() -> void:
	var life: float=maxf(0.0,varied("particleLifespan","particleLifespanVariance"))
	# Zero-life particles are removed by this same update before drawing.
	var divisor: float=life if life>0.0 else 1.0
	var position:=Vector2(f32(number("sourcePositionVariancex")*random_signed()),f32(number("sourcePositionVariancey")*random_signed()))
	var color: Color=random_color("start")
	var end: Color=random_color("finish")
	var size_value: float=maxf(0.0,varied("startParticleSize","startParticleSizeVariance"))
	var size_delta: float=0.0
	if number("finishParticleSize")!=-1.0:size_delta=f32((maxf(0.0,varied("finishParticleSize","finishParticleSizeVariance"))-size_value)/divisor)
	var rotation: float=varied("rotationStart","rotationStartVariance")
	var rotation_end: float=varied("rotationEnd","rotationEndVariance")
	var angle: float=f32(varied("angle","angleVariance")*f32(PI/180.0))
	var p: Dictionary={"life":life,"position":position,"color":color,"color_delta":(end-color)/divisor,"size":size_value,"size_delta":size_delta,"rotation":rotation,"rotation_delta":f32((rotation_end-rotation)/divisor)}
	if mode==0:
		p.velocity=Vector2(cos(angle),sin(angle))*varied("speed","speedVariance")
		p.radial=varied("radialAcceleration","radialAccelVariance")
		p.tangential=varied("tangentialAcceleration","tangentialAccelVariance")
		if bool(config.get("rotationIsDir",false)):p.rotation=f32(-rad_to_deg(p.velocity.angle()))
	else:
		p.radius=varied("maxRadius","maxRadiusVariance")
		var end_radius: float=varied("minRadius","minRadiusVariance")
		p.radius_delta=0.0 if number("minRadius")==-1.0 else f32((end_radius-float(p.radius))/divisor)
		p.angle=angle
		p.angular_velocity=f32(varied("rotatePerSecond","rotatePerSecondVariance")*f32(PI/180.0))
	particles.append(p)
func step(delta: float) -> void:
	var dt: float=f32(delta)
	if active and emission_rate!=0.0:
		var rate: float=f32(1.0/emission_rate)
		if particles.size()<maximum:emit_counter=f32(emit_counter+dt)
		while particles.size()<maximum and emit_counter>rate:
			add_particle();emit_counter=f32(emit_counter-rate)
		elapsed=f32(elapsed+dt)
		if number("duration")!=-1.0 and number("duration")<elapsed:
			active=false;elapsed=number("duration");emit_counter=0.0
	var index: int=0
	while index<particles.size():
		var p: Dictionary=particles[index]
		p.life=f32(float(p.life)-dt)
		if float(p.life)<=0.0:
			particles[index]=particles.back();particles.pop_back();continue
		if mode==0:
			var position: Vector2=p.position
			var radial: Vector2=position.normalized() if position!=Vector2.ZERO else Vector2.ZERO
			var tangential:=Vector2(-radial.y,radial.x)*float(p.tangential)
			var gravity:=Vector2(number("gravityx"),number("gravityy"))
			p.velocity+=((radial*float(p.radial))+tangential+gravity)*dt
			p.position+=p.velocity*dt
		else:
			p.angle=f32(float(p.angle)+f32(float(p.angular_velocity)*dt))
			p.radius=f32(float(p.radius)+f32(float(p.radius_delta)*dt))
			p.position=Vector2(-cos(p.angle)*p.radius,-sin(p.angle)*p.radius)
		p.color+=p.color_delta*dt
		p.size=maxf(0.0,f32(float(p.size)+f32(float(p.size_delta)*dt)))
		p.rotation=f32(float(p.rotation)+f32(float(p.rotation_delta)*dt))
		index+=1
