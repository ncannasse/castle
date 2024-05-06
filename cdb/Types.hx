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
