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

import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;

typedef GADT<E,T> = T;

private enum SchemaKind {
	SEnum( e : Array<Null<Array<SData>>> );
	SAnon( e : Array<{ n : String, d : SData }> );
	SMulti( a : Array<SData> );
}

private enum SData {
	DInt;
	DBool;
	DString;
	DFloat;
	DBytes;
	DDynamic;
	DNull( d : SData );
	DArray( d : SData );
	DSchema( id : Int );
	DAnon( a : Array<{ n : String, d : SData }> );
	DIntMap( d : SData );
	DStringMap( d : SData );
	DEnumMap( e : Schema, d : SData );
}

class NullError {
	public var msg : String;
	public function new(msg) {
		this.msg = msg;
	}
	function toString() {
		return msg;
	}
}

class SchemaError {
	public var s : Schema;
	public function new(s) {
		this.s = s;
	}
	function toString() {
		return "Schema " + s.name + " version differs";
	}
}

class SchemaSerializer extends haxe.Serializer {
	override function serializeRef( v : Dynamic ) {
		if( Std.is(v, Schema) ) {
			var s : Schema = cast v;
			serializeString(s.name);
			return true;
		}
		return super.serializeRef(v);
	}
}

@:keep
private class Schema {
	public var id : Int;
	public var tag : Int;
	public var hash : Int;
	public var name : String;
	public var kind : SchemaKind;
	public var enumValue : Enum<Dynamic>;

	public function new( name ) {
		this.name = name;
		this.id = DO_HASH(name);
	}

	public function finalize() {
		hash = 0;
		var s = new SchemaSerializer();
		s.useCache = true;
		s.useEnumIndex = true;
		s.serialize(kind);
		hash = DO_HASH(name + s.toString());
	}

	public static function DO_HASH( data : String ) {
		var b = haxe.crypto.Md5.make(haxe.io.Bytes.ofString(data));
		return b.get(0) | (b.get(1) << 8) | (b.get(2) << 16) | (b.get(3) << 24);
	}

}

class BinSerializer {

	public static var VERSION_CHECK = false;

	#if macro
	static var schemas = new Map();
	static var schemasById = new Map();
	static var deps = new Map();

	static function makeSchema( t : BaseType, ?extra : String ) {
		if( !deps.exists(t.module) ) {
			var f = sys.FileSystem.fullPath(Context.resolvePath(t.module.split(".").join("/") + ".hx"));
			// TODO : this adds dependency on the main context one while we want to add it to the macro one (:')
			Context.registerModuleDependency("cdb.BinSerializer", f);
			deps.set(t.module, true);
		}
		var path = t.pack.copy();
		path.push(t.name);
		if( extra != null ) path.push(extra);
		var s = new Schema(path.join("."));
		schemas.set(s.name, s);
		schemasById.set(s.id, s);
		return s;
	}

	static function makeEnumSchema( e : EnumType ) {
		var s = makeSchema(e);
		var constructs = [];
		for( c in e.names ) {
			var c = e.constructs.get(c);
			switch( c.type ) {
			case TFun(args, _):
				var dt = [];
				for( a in args ) {
					var d = getData(a.t, c.pos);
					if( a.opt )
						switch( d ) {
						case DNull(_):
						default: d = DNull(d);
						}
					dt.push(d);
				}
				constructs.push(dt);
			default:
				constructs.push(null);
			}
		}
		if( constructs.length > 255 ) throw "Too many constructors for " + s.name;
		s.kind = SEnum(constructs);
		s.finalize();
		save();
		return s;
	}

	static function makeAnonSchema( td : DefType, anon : AnonType ) {
		var s = makeSchema(td);
		var fields = [];
		for( f in anon.fields )
			fields.push( { n : f.name, d : getData(f.type, f.pos) } );
		s.kind = SAnon(fields);
		s.finalize();
		save();
		return s;
	}

	static function makeGADTSchema( e : EnumType ) {
		var s = makeSchema(e, "ret");
		var retValues = [];
		for( n in e.names ) {
			var c = e.constructs.get(n);
			var r = switch( c.type ) {
			case TFun(_, r): r;
			case r: r;
			}
			switch( r ) {
			case TEnum(_, [r]):
				retValues.push(getData(r, c.pos));
			default:
				throw "assert";
			}
		}
		s.kind = SMulti(retValues);
		s.finalize();
		if( retValues.length > 255 ) throw "Too many constructors for " + s.name;
		save();
		return s;
	}

	static function getData( t : haxe.macro.Type, pos : Position ) {
		switch( t ) {
		case TType(tn, pl):
			switch( tn.toString() ) {
			case "Null":
				return DNull(getData(pl[0], pos));
			default:
				var td = tn.get();
				switch( td.type ) {
				case TAnonymous(_):
					return DSchema(getSchema(t, pos).id);
				default:
					return getData(Context.follow(t, true), pos);
				}
			}
		case TAbstract(a, pl):
			switch( a.toString() ) {
			case "Int":
				return DInt;
			case "Float":
				return DFloat;
			case "Bool":
				return DBool;
			case "Map":
				switch( getData(pl[0], pos) ) {
				case DSchema(sid):
					var s = schemasById.get(sid);
					switch( s.kind ) {
					case SEnum(_):
						return DEnumMap(s, getData(pl[1], pos));
					default:
					}
				case DInt:
					return DIntMap(getData(pl[1], pos));
				case DString:
					return DStringMap(getData(pl[1], pos));
				default:
				}
				Context.error("Unsupported map key " + pl[0], pos);
			case name:
				var a = a.get();
				switch( a.type ) {
				case TAbstract(a2, _) if( a2.toString() == name ):
					// core type
				default:
					// loop into subtype
					return getData(a.type, pos);
				}
			}
		case TInst(c, pl):
			switch( c.toString() ) {
			case "Array":
				return DArray(getData(pl[0], pos));
			case "String":
				return DString;
			case "haxe.io.Bytes":
				return DBytes;
			default:
				return DSchema(getSchema(t,pos).id);
			}
		case TAnonymous(a):
			var a = a.get();
			var out = [];
			for( f in a.fields ) {
				var d = getData(f.type, f.pos);
				out.push({ n : f.name, d : d });
			}
			return DAnon(out);
		case TEnum(_):
			return DSchema(getSchema(t, pos).id);
		case TDynamic(_):
			return DDynamic;
		default:
		}
		Context.error("Unsupported data type " + t, pos);
		return null;
	}

	static function getSchema( t : haxe.macro.Type, pos : Position ) {
		switch( t ) {
		case TEnum(e, _):
			var s = schemas.get(e.toString());
			if( s != null ) return s;
			return makeEnumSchema(e.get());
		case TType(td, pl):
			switch( td.toString() ) {
			case "GADT":
				switch( pl[0] ) {
				case TEnum(e, _):
					var s = schemas.get(e.toString() + ".ret");
					if( s != null ) return s;
					return makeGADTSchema(e.get());
				default:
				}
			default:
				var tf = Context.follow(t, true);
				switch( tf ) {
				case TAnonymous(a):
					var s = schemas.get(td.toString());
					if( s != null ) return s;
					return makeAnonSchema(td.get(), a.get());
				default:
				}
				return getSchema(tf, pos);
			}
		default:
		}
		Context.error("Unsupported schema type " + t, pos);
		return null;
	}

	static function makeType( e : Expr ) {
		switch( e.expr ) {
		case EField(e, f):
			return makeType(e) + "." + f;
		case EConst(CIdent(i)):
			return i;
		default:
			Context.error("Invalid type identified", e.pos);
			return null;
		}
	}

	static function save() {
		switch( Context.getType("cdb.BinSerializer") ) {
		case TInst(c,_):
			var c = c.get();
			for( s in schemas )
				if( s.kind != null && !c.meta.has("s_" + s.id) )
					c.meta.add("s_" + s.id, [ { expr : EConst(CString(haxe.Serializer.run(s))), pos : c.pos } ], c.pos);
		default:
			throw "assert";
		}
	}

	#else

	static var schemas : Map<Int,Schema>;
	static var TAG = 0;
	static var inst : BinSerializer;
	static var gadtTip = -1;

	static function init() {
		if( schemas == null ) {
			var metas : Dynamic = haxe.rtti.Meta.getType(BinSerializer);
			schemas = new Map();
			for( m in Reflect.fields(metas) ) {
				var s : Schema = haxe.Unserializer.run(Reflect.field(metas,m)[0]);
				s.tag = 0;
				schemas.set(s.id, s);
				switch( s.kind ) {
				case SEnum(_):
					s.enumValue = std.Type.resolveEnum(s.name);
					if( s.enumValue == null ) throw "Missing enum " + s.name;
				default:
				}
			}
			inst = new BinSerializer();
		}
	}

	var position : Int;
	var bytes : haxe.io.Bytes;
	var out : haxe.io.BytesBuffer;
	var tag : Int;

	function new() {
	}

	inline function fastField( v : Dynamic, n : String ) : Dynamic {
		return #if (flash || js) untyped v[n] #elseif neko untyped $objget(v,$hash(n.__s)) #else Reflect.field(v, f.n) #end;
	}

	inline function fastSetField( o : { }, n : String, v : Dynamic ) {
		#if (flash || js)
		untyped o[n] = v;
		#elseif neko
		untyped $objset(o, $hash(n.__s), v);
		#else
		Reflect.setField(o, n, v);
		#end
	}

	function serializeInt( v : Int ) {
		if( v >= 0 && v < 0x40 ) {
			out.addByte(v);
		} else if( v >= 0 && v < 0x4000 ) {
			out.addByte((v & 0x3F) | 0x40);
			out.addByte(v >> 6);
		} else if( v >= 0 && v < 0x400000 ) {
			out.addByte((v & 0x3F) | 0x80);
			out.addByte(v >> 6);
			out.addByte(v >> 14);
		} else {
			out.addByte(0xC0);
			out.addByte(v & 0xFF);
			out.addByte((v >> 8) & 0xFF);
			out.addByte((v >> 16) & 0xFF);
			out.addByte(v >>> 24);
		}
	}

	function serializeData( d : SData, v : Dynamic ) {
		#if serializeDebug
		if( v == null && !d.match(DNull(_)) && d != DDynamic )
			throw new NullError(Std.string(d));
		#end
		switch( d ) {
		case DNull(d):
			if( v == null )
				out.addByte(0);
			else {
				out.addByte(1);
				serializeData(d, v);
			}
		case DInt:
			serializeInt(v);
		case DFloat:
			out.addDouble(v);
		case DBool:
			out.addByte(v ? 1 : 0);
		case DString:
			var s : String = v;
			serializeInt(s.length);
			out.addString(s);
		case DArray(d):
			var a : Array<Dynamic> = v;
			serializeInt(a.length);
			for( v in a )
				serializeData(d, v);
		case DSchema(sid):
			serializeSchema(schemas.get(sid), v);
		case DStringMap(d):
			var m : haxe.ds.StringMap<Dynamic> = v;
			for( k in m.keys() ) {
				serializeInt(k.length);
				out.addString(k);
				serializeData(d, m.get(k));
			}
			out.addByte(0xFF);
		case DIntMap(d):
			var m : haxe.ds.IntMap<Dynamic> = v;
			for( k in m.keys() ) {
				serializeInt(k);
				serializeData(d, m.get(k));
			}
			out.addByte(0xFF);
		case DEnumMap(s, d):
			var m : haxe.ds.EnumValueMap<Dynamic,Dynamic> = v;
			for( k in m.keys() ) {
				serializeSchema(s, k);
				serializeData(d, m.get(k));
			}
			out.addByte(0xFF);
		case DAnon(fields):
			for( f in fields ) {
				#if serializeDebug
				try {
				#end
				serializeData(f.d, fastField(v,f.n));
				#if serializeDebug
				} catch( e : NullError ) {
					e.msg = f.n + "." + e.msg;
					throw e;
				}
				#end
			}
		case DDynamic:
			var str = haxe.Serializer.run(v);
			serializeInt(str.length);
			out.addString(str);
		case DBytes:
			var b : haxe.io.Bytes = v;
			serializeInt(b.length);
			out.add(b);
		}
	}

	function serializeSchema( s : Schema, v : Dynamic ) {
		if( VERSION_CHECK && s.tag != tag ) {
			out.addByte(s.hash & 0xFF);
			out.addByte((s.hash >> 8) & 0xFF);
			out.addByte((s.hash >> 16) & 0xFF);
			out.addByte(s.hash >>> 24);
			s.tag = tag;
		}
		switch( s.kind ) {
		case SEnum(constructs):
			#if serializeDebug
			if( v == null || !Reflect.isEnumValue(v) ) throw new NullError(s.name);
			#end
			var id = std.Type.enumIndex(v);
			out.addByte(id);
			var c = constructs[id];
			if( c == null ) return;
			var p = std.Type.enumParameters(v);
			#if serializeDebug
			try {
			#end
			for( i in 0...c.length )
				serializeData(c[i], p[i]);
			#if serializeDebug
			} catch( e : NullError ) {
				e.msg = s.name+"."+std.Type.enumConstructor(v) + "." + e.msg;
				throw e;
			}
			#end

		case SAnon(fields):
			#if serializeDebug
			if( v == null ) throw new NullError(s.name);
			#end
			for( f in fields ) {
				#if serializeDebug
				try {
				#end
				serializeData(f.d, fastField(v,f.n));
				#if serializeDebug
				} catch( e : NullError ) {
					e.msg = s.name + "." + f.n + "." + e.msg;
					throw e;
				}
				#end
			}
		case SMulti(choices):
			if( v == null ) {
				out.addByte(0xFF);
				gadtTip = -1;
				return;
			}
			var t = gadtTip;
			if( t == -1 ) throw "Missing GADT Tip";
			gadtTip = -1;
			out.addByte(t);
			serializeData(choices[t], v);
		}

	}

	inline function readByte() {
		return bytes.get(position++);
	}

	function readInt() {
		var b = readByte();
		if( b < 0x40 )
			return b;
		if( b < 0x80 )
			return (b & 0x3F) | (readByte() << 6);
		if( b < 0xC0 ) {
			var b2 = readByte();
			var b3 = readByte();
			return (b & 0x3F) | (b2 << 6) | (b3 << 14);
		}
		var b1 = readByte();
		var b2 = readByte();
		var b3 = readByte();
		var b4 = readByte();
		return b1 | (b2 << 8) | (b3 << 16) | (b4 << 24);
	}

	function unserializeData( d : SData ) : Dynamic {
		switch( d ) {
		case DInt:
			return readInt();
		case DBool:
			return readByte() != 0 ? true : false;
		case DNull(d):
			if( readByte() == 0 ) return null;
			return unserializeData(d);
		case DString:
			var len = readInt();
			var str = bytes.getString(position, len);
			position += len;
			return str;
		case DFloat:
			var f = bytes.getDouble(position);
			position += 8;
			return f;
		case DDynamic:
			var len = readInt();
			var str = bytes.getString(position, len);
			position += len;
			return haxe.Unserializer.run(str);
		case DBytes:
			var len = readInt();
			var b = bytes.sub(position, len);
			position += len;
			return b;
		case DArray(d):
			var len = readInt();
			return [for( i in 0...len ) unserializeData(d)];
		case DAnon(fields):
			var o = {};
			for( f in fields )
				fastSetField(o, f.n, unserializeData(f.d));
			return o;
		case DSchema(sid):
			return unserializeSchema(schemas.get(sid));
		case DIntMap(d):
			var m = new haxe.ds.IntMap();
			while( true ) {
				var i = readByte();
				if( i == 0xFF ) break;
				position--;
				var key = readInt();
				m.set(key, unserializeData(d));
			}
			return m;
		case DStringMap(d):
			var m = new haxe.ds.StringMap();
			while( true ) {
				var i = readByte();
				if( i == 0xFF ) break;
				position--;
				var len = readInt();
				var key = bytes.getString(position, len);
				position += len;
				m.set(key, unserializeData(d));
			}
			return m;
		case DEnumMap(s, d):
			var m = new haxe.ds.EnumValueMap();
			while( true ) {
				var i = readByte();
				if( i == 0xFF ) break;
				position--;
				var key = unserializeSchema(s);
				m.set(key, unserializeData(d));
			}
			return m;
		}
	}

	function unserializeSchema( s : Schema ) : Dynamic {
		if( VERSION_CHECK && s.tag != tag ) {
			var h = readByte();
			h |= readByte() << 8;
			h |= readByte() << 16;
			h |= readByte() << 24;
			if( h != s.hash )
				throw new SchemaError(s);
			s.tag = tag;
		}
		switch( s.kind ) {
		case SEnum(constructs):
			var id = readByte();
			var c = constructs[id];
			if( c == null ) return std.Type.createEnumIndex(s.enumValue, id);
			var args = [for( d in c ) unserializeData(d)];
			return std.Type.createEnumIndex(s.enumValue, id, args);
		case SMulti(choices):
			var c = choices[readByte()];
			if( c == null ) return null;
			return unserializeData(c);
		case SAnon(fields):
			var o = {};
			for( f in fields )
				fastSetField(o, f.n, unserializeData(f.d));
			return o;
		}
	}


	static function doSerialize( v : Dynamic, sid : Int ) : haxe.io.Bytes {
		init();
		inst.tag = ++TAG;
		inst.out = new haxe.io.BytesBuffer();
		inst.serializeSchema(schemas.get(sid), v);
		var b = inst.out.getBytes();
		inst.out = null;
		return b;
	}

	static function doUnserialize( v : haxe.io.Bytes, sid : Int ) : Dynamic {
		init();
		inst.tag = ++TAG;
		inst.bytes = v;
		inst.position = 0;
		var v = inst.unserializeSchema(schemas.get(sid));
		inst.bytes = null;
		return v;
	}

	public static function setGADTTip( e : EnumValue ) {
		gadtTip = e.getIndex();
	}

	public static function checkSchemasData( b : haxe.io.Bytes ) {
		init();
		var pos = 0;
		var out = [];
		while( pos < b.length ) {
			var len = b.get(pos++);
			var name = b.getString(pos, len);
			pos += len;
			var hash = b.get(pos++);
			hash |= b.get(pos++) << 8;
			hash |= b.get(pos++) << 16;
			hash |= b.get(pos++) << 24;
			for( s in schemas )
				if( s.name == name ) {
					if( s.hash != hash ) out.push(s);
					break;
				}
		}
		return out;
	}

	public static function getSchemasData() {
		init();
		var b = new haxe.io.BytesBuffer();
		for( s in schemas ) {
			b.addByte(s.name.length);
			b.addString(s.name);
			b.addByte(s.hash & 0xFF);
			b.addByte((s.hash >> 8) & 0xFF);
			b.addByte((s.hash >> 16) & 0xFF);
			b.addByte(s.hash >>> 24);
		}
		return b.getBytes();
	}

	#end


	public static macro function unserialize( e : Expr ) {
		var t = Context.getExpectedType();
		switch( t ) {
		case TMono(_):
			Context.error("Please strictly type left value", e.pos);
		default:
		}
		var schema = getSchema(t, e.pos);
		return macro @:privateAccess cdb.BinSerializer.doUnserialize($e,$v{ schema.id });
	}

	public static macro function serialize( e : Expr ) {
		var schema = getSchema(Context.typeof(e), e.pos);
		var eb = macro cdb.BinSerializer.doSerialize($e, $v { schema.id } );
		eb.pos = Context.currentPos();
		return macro @:privateAccess $eb;
	}

}