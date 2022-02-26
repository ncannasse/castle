package cdb;
using Lambda;

class CurveHandle {
	public var dt: Float;
	public var dv: Float;
	public function new(t, v) {
		this.dt = t;
		this.dv = v;
	}
}

enum abstract CurveKeyMode(Int) {
	var Aligned = 0;
	var Free = 1;
	var Linear = 2;
	var Constant = 3;
}

class CurveKey {
	public var time: Float;
	public var value: Float;
	public var mode: CurveKeyMode;
	public var prevHandle: CurveHandle;
	public var nextHandle: CurveHandle;
	public function new() {}
}

typedef CurveKeys = Array<CurveKey>;

	
class Curve  {

	@:s public var keyMode : CurveKeyMode = Linear;
	@:c public var keys : CurveKeys = [];
	@:c public var previewKeys : CurveKeys = [];

	@:s public var loop : Bool = false;

	public var scale: Float = 1.;
	public var offset: Float = 0.;

	public var maxTime : Float;
	public var duration(get, never): Float;
	function get_duration() {
		if(keys.length == 0) return 0.0;
		return keys[keys.length-1].time;
	}

   	public function new() {
	}

	public static function fromDynamic(o:Dynamic) {
		var x = new Curve();
		x.load(o);
		return x;
	}
	
	public  function load(o:Dynamic) {
		keys = [];
		if(o.keys != null) {
			for(k in (o.keys: Array<Dynamic>)) {
				var nk = new CurveKey();
				nk.time = k.time;
				nk.value = k.value;
				nk.mode = k.mode;
				if(k.prevHandle != null)
					nk.prevHandle = new CurveHandle(k.prevHandle.dt, k.prevHandle.dv);
				if(k.nextHandle != null)
					nk.nextHandle = new CurveHandle(k.nextHandle.dt, k.nextHandle.dv);
				keys.push(nk);
			}

			if (o.scale != null) {
				scale = o.scale;
			}
			if (o.offset != null) {
				offset = o.offset;
			}
			
		}
		if( keys.length == 0 ) {
			addKey(0.0, 0.0);
			addKey(1.0, 1.0);
		}
	}

	public  function save(obj : Dynamic = null) {
		if (obj == null) {
			obj = {};
		}
		var keysDat = [];
		for(k in keys) {
			var o = {
				time: k.time,
				value: k.value,
				mode: k.mode
			};
			if(k.prevHandle != null) Reflect.setField(o, "prevHandle", { dv: k.prevHandle.dv, dt: k.prevHandle.dt });
			if(k.nextHandle != null) Reflect.setField(o, "nextHandle", { dv: k.nextHandle.dv, dt: k.nextHandle.dt });
			keysDat.push(o);
		}
		obj.keys = keysDat;
		obj.scale = this.scale;
		obj.offset = this.offset;
		return obj;
	}

	static inline function bezier(c0: Float, c1:Float, c2:Float, c3: Float, t:Float) {
		var u = 1 - t;
		return u * u * u * c0 + c1 * 3 * t * u * u + c2 * 3 * t * t * u + t * t * t * c3;
	}

	public function findKey(time: Float, tolerance: Float) {
		var minDist = tolerance;
		var closest = null;
		for(k in keys) {
			var d = Math.abs(k.time - time);
			if(d < minDist) {
				minDist = d;
				closest = k;
			}
		}
		return closest;
	}

	public function addKey(time: Float, ?val: Float, ?mode=null) {
		var index = 0;
		for(ik in 0...keys.length) {
			var key = keys[ik];
			if(time > key.time)
				index = ik + 1;
		}

		if(val == null)
			val = evaluate(time);

		var key = new Curve.CurveKey();
		key.time = time;
		key.value = val;
		key.mode = mode != null ? mode : (keys[index] != null ? keys[index].mode : keyMode);
		keys.insert(index, key);
		return key;
	}

	public function addPreviewKey(time: Float, val: Float) {
		var key = new Curve.CurveKey();
		key.time = time;
		key.value = val;
		previewKeys.push(key);
		return key;
	}

	inline function applyScaleOffset(v : Float) {
		return v * scale + offset;
	}
	public function evaluate(time: Float) : Float {
		switch(keys.length) {
			case 0: return applyScaleOffset(0);
			case 1: return applyScaleOffset(keys[0].value);
			default:
		}

		if (loop)
			time = time % keys[keys.length-1].time;

		var idx = -1;
		for(ik in 0...keys.length) {
			var key = keys[ik];
			if(time > key.time)
				idx = ik;
		}

		if(idx < 0)
			return applyScaleOffset(keys[0].value);

		var cur = keys[idx];
		var next = keys[idx + 1];
		if(next == null || cur.mode == Constant)
			return applyScaleOffset(cur.value);

		var minT = 0.;
		var maxT = 1.;
		var maxDelta = 1./ 25.;

		inline function sampleTime(t) {
			return bezier(
				cur.time,
				cur.time + (cur.nextHandle != null ? cur.nextHandle.dt : 0.),
				next.time + (next.prevHandle != null ? next.prevHandle.dt : 0.),
				next.time, t);
		}

		inline function sampleVal(t) {
			return bezier(
				cur.value,
				cur.value + (cur.nextHandle != null ? cur.nextHandle.dv : 0.),
				next.value + (next.prevHandle != null ? next.prevHandle.dv : 0.),
				next.value, t);
		}

		while( maxT - minT > maxDelta ) {
			var t = (maxT + minT) * 0.5;
			var x = sampleTime(t);
			if( x > time )
				maxT = t;
			else
				minT = t;
		}

		var x0 = sampleTime(minT);
		var x1 = sampleTime(maxT);
		var dx = x1 - x0;
		var xfactor = dx == 0 ? 0.5 : (time - x0) / dx;

		var y0 = sampleVal(minT);
		var y1 = sampleVal(maxT);
		var y = y0 + (y1 - y0) * xfactor;
		return applyScaleOffset(y);
	}

	function lerp( a : Float, b : Float, t : Float ) : Float {
		return a * (1.0 - t) + b * t;
	}
	public function getSum(time: Float) : Float {
		var duration = keys[keys.length-1].time;
		if(loop && time > duration) {
			var cycles = Math.floor(time / duration);
			return getSum(duration) * cycles + getSum(time - cycles);
		}

		var sum = 0.0;
		for(ik in 0...keys.length) {
			var key = keys[ik];
			if(time < key.time)
				break;

			if(ik == 0 && key.time > 0) {
				// Account for start of curve
				sum += key.time * key.value;
			}

			var nkey = keys[ik + 1];
			if(nkey != null) {
				if(time > nkey.time) {
					// Full interval
					sum += key.value * (nkey.time - key.time);
					if(key.mode != Constant)
						sum += 0.5 * (nkey.time - key.time) * (nkey.value - key.value);
				}
				else {
					// Split interval
					sum += key.value * (time - key.time);
					if(key.mode != Constant)
						sum += 0.5 * (time - key.time) *  lerp(key.value, nkey.value, (time - key.time) / (nkey.time - key.time));
				}
			}
			else {
				sum += key.value * (time - key.time);
			}
		}
		return sum;
	}

	public function sample(numPts: Int) {
		var vals = [];
		var duration = this.duration;
		for(i in 0...numPts) {
			var v = evaluate(duration * i/(numPts-1));
			vals.push(v);
		}
		return vals;
	}


	

	


	
}
