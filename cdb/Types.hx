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

abstract ArrayRead<T>(Array<T>) {

	public var length(get, never) : Int;

	public inline function new(a : Array<T>) {
		this = a;
	}

	inline function get_length() {
		return this.length;
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
		var k = haxe.crypto.Base64.decode(this);
		return [for( i in 0...k.length ) all[k.get(i)]];
	}

}

abstract TileLayerData(String) {

	function new(v) {
		this = v;
	}

	public function decode() {
		var k = haxe.crypto.Base64.decode(this);
		return [for( i in 0...k.length>>1 ) k.get(i<<1) | (k.get((i<<1)+1) << 8)];
	}

	public static function encode( a : Array<Int> ) : TileLayerData {
		var b = haxe.io.Bytes.alloc(a.length * 2);
		for( i in 0...a.length ) {
			var v = a[i];
			b.set(i << 1, v & 0xFF);
			b.set((i << 1) + 1 , (v>>8) & 0xFF);
		}
		return new TileLayerData(haxe.crypto.Base64.encode(b));
	}

}

abstract LevelPropsAccess<T>(Data.LevelProps) {

	public var tileSize(get, never) : Int;

	function get_tileSize() {
		return this.tileSize;
	}

	public function getTileset( i : Index<T,Dynamic>, name : String ) : Data.TilesetProps {
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

class IndexNoId<T> {

	var name : String;
	public var all(default,null) : ArrayRead<T>;

	public function new( data : Data, sheet : String ) {
		this.name = sheet;
		for( s in data.sheets )
			if( s.name == sheet ) {
				all = cast s.lines;
				return;
			}
		throw "'" + sheet + "' not found in CDB data";
	}

}

class Index<T,Kind> {

	public var all(default,null) : ArrayRead<T>;
	var byIndex : Array<T>;
	var byId : Map<String,T>;
	var name : String;
	var sheet : Data.Sheet;

	public function new( data : Data, sheet : String ) {
		this.name = sheet;
		for( s in data.sheets )
			if( s.name == sheet ) {
				this.sheet = s;
				all = cast s.lines;
				byId = new Map();
				byIndex = [];
				for( c in s.columns )
					switch( c.type ) {
					case TId:
						var cname = c.name;
						for( a in s.lines ) {
							var id = Reflect.field(a, cname);
							if( id != null && id != "" ) {
								byId.set(id, a);
								byIndex.push(a);
							}
						}
						break;
					default:
					}
				return;
			}
		throw "'" + sheet + "' not found in CDB data";
	}

	public inline function get( k : Kind ) {
		return byId.get(cast k);
	}

	public function resolve( id : String, ?opt : Bool ) : T {
		if( id == null ) return null;
		var v = byId.get(id);
		return v == null && !opt ? throw "Missing " + name + "." + id : v;
	}

}
