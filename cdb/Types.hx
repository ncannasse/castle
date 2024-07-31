/*
 * Copyright (c) 2015, Nicolas Cannasse
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
 * IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
package cdb;

private class ArrayIterator<T> {
	var a : Array<T>;
	var pos : Int;
	public inline function new(a) {
		this.a = a;
		this.pos = 0;
	}
	public inline function hasNext() {
		return pos < a.length;
	}
	public inline function next() {
		return a[pos++];
	}
}

private class FlagsIterator<T> {
	var flags : Flags<T>;
	var k : Int;
	public inline function new(flags) {
		this.flags = flags;
		k = 0;
	}
	public inline function hasNext() {
		return flags.toInt() >= 1<<k;
	}
	public inline function next() : T {
		while( flags.toInt() & (1<<k) == 0 )
			k++;
		return cast k++;
	}

}

@:forward(map, filter, indexOf, exists, find, keyValueIterator)
abstract ArrayRead<T>(Array<T>) from Array<T> {

	public var length(get, never) : Int;

	public inline function new(a : Array<T>) {
		this = a;
	}

	inline function get_length() {
		return this.length;
	}

	@:to inline function toIterable() : Iterable<T> {
		return this;
	}

	public inline function iterator() : ArrayIterator<T> {
		return new ArrayIterator(castArray());
	}

	inline function castArray() : Array<T> {
		return this;
	}

	public inline function toArrayCopy() {
		return this.copy();
	}

	@:arrayAccess inline function getIndex( v : Int ) {
		return this[v];
	}

}

abstract Flags<T>(Int) {

	inline function new(x:Int) {
		this = x;
	}

	public inline function has( t : T ) {
		return this & (1 << (cast t)) != 0;
	}

	public inline function set( t : T ) {
		this |= 1 << (cast t);
	}

	public inline function unset( t : T ) {
		this &= ~(1 << (cast t));
	}

	public inline function iterator() {
		return new FlagsIterator<T>(new Flags(this));
	}

	public inline function toInt() : Int {
		return this;
	}

}

abstract Layer<T>(String) {

	inline function new(x:String) {
		this = x;
	}

	public function decode( all : ArrayRead<T> ) : Array<T> {
		var k = Lz4Reader.decodeString(this);
		return [for( i in 0...k.length ) all[k.get(i)]];
	}

	public static function encode<T>( a : Array<Int>, compress : Bool ) : Layer<T> {
		var b = haxe.io.Bytes.alloc(a.length);
		for( i in 0...a.length )
			b.set(i, a[i]);
		return new Layer(cdb.Lz4Reader.encodeBytes(b, compress));
	}

}

abstract TileLayerData(String) {

	function new(v) {
		this = v;
	}

	public function decode() {
		var k = Lz4Reader.decodeString(this);
		return [for( i in 0...k.length>>1 ) k.get(i<<1) | (k.get((i<<1)+1) << 8)];
	}

	public static function encode( a : Array<Int>, compress ) : TileLayerData {
		var b = haxe.io.Bytes.alloc(a.length * 2);
		for( i in 0...a.length ) {
			var v = a[i];
			b.set(i << 1, v & 0xFF);
			b.set((i << 1) + 1 , (v>>8) & 0xFF);
		}
		return new TileLayerData(Lz4Reader.encodeBytes(b, compress));
	}

}

abstract LevelPropsAccess<T>(Data.LevelProps) {

	public var tileSize(get, never) : Int;

	function get_tileSize() {
		return this.tileSize;
	}

	public function getTileset( i : Index<T>, name : String ) : Data.TilesetProps {
		return Reflect.field(@:privateAccess i.sheet.props.level.tileSets, name);
	}

	public function getLayer( name : String ) : Data.LayerProps {
		if( this == null || this.layers == null ) return null;
		for( l in this.layers )
			if( l.l == name )
				return l.p;
		return null;
	}
}

typedef TilePos = {
	var file(default, never) : String;
	var size(default, never) : Int;
	var x(default, never) : Int;
	var y(default, never) : Int;
	var width(default, never) : Null<Int>;
	var height(default, never) : Null<Int>;
}

typedef TileLayer = {
	var file(default, never) : String;
	var stride(default, never) : Int;
	var size(default, never) : Int;
	var data(default, never) : TileLayerData;
}

typedef GradientData = {
	var colors: Array<Int>;
	var positions: Array<Float>;
}

abstract Gradient(GradientData) from GradientData {
	public var data(get, never) : GradientData;

	public function get_data() : GradientData {
		return this;
	}

	inline public function new(g:GradientData) {
		this = g;
	}

	public function generate(count: Int) : Array<Int> {
		var r0 : Float = 0;
		var g0 : Float = 0;
		var b0 : Float = 0;
		var a0 : Float = 0;
		var r1 : Float = 0;
		var g1 : Float = 0;
		var b1 : Float = 0;
		var a1 : Float = 0;

		var currentStop = 0;

		var stop0 = this.positions[currentStop] ?? 0.0;
		var c = this.colors[currentStop];
		a0 = a1 = (c >> 24 & 0xFF) / 255.0;
		r0 = r1 = (c >> 16 & 0xFF) / 255.0;
		g0 = g1 = (c >> 8 & 0xFF) / 255.0;
		b0 = b1 = (c >> 0 & 0xFF) / 255.0;

		var stop1 = stop0;

		var outColors : Array<Int> = [];

		for (current in 0...count) {
			var currentPos = current / (count-1);
			if (currentPos > stop1) {
				stop0 = stop1;
				a0 = a1;
				r0 = r1;
				g0 = g1;
				b0 = b1;

				currentStop += 1;
				if (currentStop < this.positions.length) {
					stop1 = this.positions[currentStop];
					var c = this.colors[currentStop];
					a1 = (c >> 24 & 0xFF) / 255.0;
					r1 = (c >> 16 & 0xFF) / 255.0;
					g1 = (c >> 8 & 0xFF) / 255.0;
					b1 = (c >> 0 & 0xFF) / 255.0;
				} else {
					stop1 = 1.0;
				}
			}
			var r = r0;
			var b = b0;
			var g = g0;
			var a = a0;

			// avoid division by 0 if stop1 == stop0
			if (stop1 > stop0) {
				inline function lerp(from:Float,to: Float, blend: Float) {
					return (to - from) * blend + from;
				}
				inline function saturate(a:Float) {
					return Math.min(Math.max(0.0, a), 1.0);
				}
				var blend = (currentPos - stop0) / (stop1 - stop0);
				blend = saturate(blend);

				r = saturate(lerp(r0, r1, blend));
				g = saturate(lerp(g0, g1, blend));
				b = saturate(lerp(b0, b1, blend));
				a = saturate(lerp(a0, a1, blend));
			}

			var cInt = Std.int(Math.round(a * 255.0)) << 24 | Std.int(Math.round(r * 255.0)) << 16 | Std.int(Math.round(g * 255.0)) << 8 | Std.int(Math.round(b * 255.0));
			outColors.push(cInt);
		}
		return outColors;
	}
}

typedef CurveData = Array<Float>;

enum abstract CurveKeyMode(Int) {
	var Aligned = 0; // for compat with hide curves
	var Free = 1;
	var Linear = 2;
	var Constant = 3;
}

abstract Curve(CurveData) from CurveData {
	public var data(get, never) : CurveData;

	function get_data() {
		return cast this;
	}

	public function new(d: CurveData) {
		this = d;
	}

	public function bake(resolution: Int) : BakedCurve {
		return new BakedCurve(this, resolution);
	}

	public function eval(t: Float) : Float {
		var numKeys = numKeys();
		switch(numKeys) {
			case 0: return 0;
			case 1: return value(0);
			default:
		}

		var idx = -1;
		for(ik in 0...numKeys) {
			if(t > time(ik))
				idx = ik;
		}

		if(idx < 0)
			return value(0);

		if (idx > numKeys-1 || keyMode(idx) == Constant)
			return value(idx);
		var cur = idx;
		var next = idx+1;

		var minT = 0.;
		var maxT = 1.;
		var maxDelta = 1./ 25.;

		inline function bezier(c0: Float, c1:Float, c2:Float, c3: Float, t:Float) {
			var u = 1 - t;
			return u * u * u * c0 + c1 * 3 * t * u * u + c2 * 3 * t * t * u + t * t * t * c3;
		}

		inline function sampleTime(t) {
			return bezier(
				time(cur),
				time(cur) + nextDt(cur),
				time(next) + prevDt(next),
				time(next), t);
		}

		inline function sampleVal(t) {
			return bezier(
				value(cur),
				value(cur) + nextDv(cur),
				value(next) + prevDv(next),
				value(next), t);
		}

		while( maxT - minT > maxDelta ) {
			var curT = (maxT + minT) * 0.5;
			var x = sampleTime(curT);
			if( x > t )
				maxT = curT;
			else
				minT = curT;
		}

		var x0 = sampleTime(minT);
		var x1 = sampleTime(maxT);
		var dx = x1 - x0;
		var xfactor = dx == 0 ? 0.5 : (t - x0) / dx;

		var y0 = sampleVal(minT);
		var y1 = sampleVal(maxT);
		var y = y0 + (y1 - y0) * xfactor;
		return y;
	}

	inline function numKeys() : Int {
		return Std.int(this.length / 6);
	}

	inline function time(idx: Int) : Float {
		return this[idx * 6];
	}

	inline function value(idx: Int) : Float {
		return this[idx * 6 + 1];
	}

	inline function prevDt(idx: Int) : Float {
		return keyMode(idx) == Free ? this[idx * 6 + 2] : 0.0;
	}

	inline function prevDv(idx: Int) : Float {
		return keyMode(idx) == Free ? this[idx * 6 + 3] : 0.0;
	}

	inline function nextDt(idx: Int) : Float {
		return keyMode(idx) == Free ? this[idx * 6 + 4] : 0.0;
	}

	inline function nextDv(idx: Int) : Float {
		return keyMode(idx) == Free ? this[idx * 6 + 5] : 0.0;
	}

	function keyMode(idx: Int) : CurveKeyMode {
		if (this[idx * 6 + 2] == HandleData) {
			return cast Std.int(this[idx * 6 + 3]);
		}
		return Free;
	}

	// If an handle value is set to this value, then it's not an handle
	// and the next value must be interpreted as something else
	public static final HandleData : Float = -10000000000;
}

class BakedCurve {
	var width : Float;
	var offset : Float;
	var points : Array<Float>;

	public function new(from: Curve, resolution: Int) {
		var numKeys = from.numKeys();
		if (numKeys == 0)
		{
			width = 0;
			return;
		}
		offset = from.time(0);
		width = from.time(numKeys-1) - offset;
		points = [];
		for (point in 0...resolution) {
			var t = (point / (resolution - 1))*width;
			points[point] = from.eval(t + offset);
		}
	}

	public function eval(t: Float) : Float {
		if (width == 0.0)
			return 0.0;
		t -= offset;
		var pointF = t / width * (points.length-1);
		var point = Math.floor(pointF);
		if (point < 0) point = 0;
		if (point > points.length - 2) point = points.length - 2;
		var blend = pointF - point;
		blend = Math.min(width, Math.max(0.0, blend));

		var a = points[point];
		var b = points[point+1];
		return (b - a) * blend + a;
	}
}

class Index<T> {

	public var all(default,null) : ArrayRead<T>;
	var name : String;
	var sheet : Data.SheetData;

	public function new(data:Data , name) {
		this.name = name;
		initSheet(data);
		if( sheet == null )
			throw "'" + name + "' not found in CDB data";
	}

	function initSheet(data:Data) {
		for( s in data.sheets )
			if( s.name == name ) {
				all = cast s.lines;
				this.sheet = s;
				if( s.props.hasIndex )
					for( i in 0...all.length )
						(all[i] : Dynamic).index = i;
				if( s.props.hasGroup ) {
					var gid = -1;
					var sindex = 0;
					// skip separators if at head
					while( true ) {
						var s = s.separators[sindex];
						if( s == null || s.index != 0 ) break;
						sindex++;
						if( s.title != null ) gid++;
					}
					if( gid < 0 ) gid++; // None insert
					for( i in 0...all.length ) {
						while( true ) {
							var s = s.separators[sindex];
							if( s == null || s.index != i ) break;
							if( s.title != null ) gid++;
							sindex++;
						}
						(all[i] : Dynamic).group = gid;
					}
				}
				break;
			}
	}

}

class IndexId<T,Kind> extends Index<T> {

	var byIndex : Array<T>;
	var byId : Map<String,T>;

	override function initSheet(data:Data) {
		super.initSheet(data);
		byId = new Map();
		byIndex = [];
		for( c in sheet.columns )
			switch( c.type ) {
			case TId:
				var cname = c.name;
				for( a in sheet.lines ) {
					var id = Reflect.field(a, cname);
					if( id != null && id != "" ) {
						byId.set(id, a);
						byIndex.push(a);
					}
				}
				break;
			default:
			}
	}

	function reload( data : Data ) {
		var oldId = byId;
		var oldIndex = byIndex;
		initSheet(data);
		for( id in byId.keys() ) {
			var oldObj = oldId.get(id);
			if( oldObj == null ) continue;
			var newObj = byId.get(id);
			// replace the whole object content inplace
			var fields = Reflect.fields(oldObj);
			for( f in Reflect.fields(newObj) ) {
				Reflect.setField(oldObj, f, Reflect.field(newObj,f));
				fields.remove(f);
			}
			for( f in fields )
				Reflect.deleteField(oldObj, f);
			// erase newObj
			var idx = byIndex.indexOf(newObj);
			if( idx >= 0 ) byIndex[idx] = oldObj;
			sheet.lines[sheet.lines.indexOf(newObj)] = oldObj;
			byId.set(id, oldObj);
		}
	}

	public inline function get( k : Kind #if castle_check_get , opt = false #end ) {
		#if castle_check_get
		var v : T = byId.get(cast k);
		if( v == null && !opt ) throw "Missing "+k;
		return v;
		#else
		return byId.get(cast k);
		#end
	}

	public function resolve( id : String, ?opt : Bool, ?approximate : Bool ) : T {
		if( id == null ) return null;
		var v = byId.get(id);
		if( v == null && approximate ) {
			id = id.toLowerCase();
			var best = 1000;
			for( k => value in byId ) {
				if( StringTools.startsWith(k.toLowerCase(),id) && k.length < best ) {
					v = value;
					best = k.length;
				}
			}
		}
		return v == null && !opt ? throw "Missing " + name + "." + id : v;
	}

}
