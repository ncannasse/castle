/*
 * Copyright (c) 2015-2017, Nicolas Cannasse
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
import cdb.Data.Column;
import cdb.Data.ColumnType;
import cdb.Data.CustomType;
import cdb.Data.CustomTypeCase;

typedef Changes = Array<Change>;

typedef Change = { ref : ChangeRef, v : ChangeKind };

enum ChangeKind {
	SetField( o : Dynamic, field : String, v : Dynamic );
	SetIndex( o : Array<Dynamic>, index : Int, v : Dynamic );
	DeleteField( o : Dynamic, field : String );
	DeleteIndex( o : Array<Dynamic>, index : Int );
	InsertIndex( o : Array<Dynamic>, index : Int, v : Dynamic );
}

typedef ChangeRef = {
	var mainSheet : Sheet;
	var mainObj : Dynamic;
	var sheet : Sheet;
	var obj : Dynamic;
}

class Database {

	var smap : Map<String, Sheet>;
	var tmap : Map<String, CustomType>;
	var data : cdb.Data;

	public var sheets(default, null) : Array<Sheet>;
	public var compress(get, set) : Bool;
	public var r_ident : EReg;

	public function new() {
		r_ident = ~/^[A-Za-z_][A-Za-z0-9_]*$/;
		data = {
			sheets : [],
			customTypes : [],
			compress : false,
		};
		sheets = [];
		sync();
	}

	inline function get_compress() return data.compress;

	function set_compress(b) {
		if( data.compress == b )
			return b;
		data.compress = b;
		for( s in sheets )
			for( c in s.columns )
				switch( c.type ) {
				case TLayer(_):
					for( obj in s.getLines() ) {
						var ldat : cdb.Types.Layer<Int> = Reflect.field(obj, c.name);
						if( ldat == null || ldat == cast "" ) continue;
						var d = ldat.decode([for( i in 0...256 ) i]);
						ldat = cdb.Types.Layer.encode(d, data.compress);
						Reflect.setField(obj, c.name, ldat);
					}
				case TTileLayer:
					for( obj in s.getLines() ) {
						var ldat : cdb.Types.TileLayer = Reflect.field(obj, c.name);
						if( ldat == null || ldat == cast "" ) continue;
						var d = ldat.data.decode();
						Reflect.setField(ldat,"data",cdb.Types.TileLayerData.encode(d, data.compress));
					}
				default:
				}
		return b;
	}

	public function getCustomType( name : String ) {
		return tmap.get(name);
	}

	public function getSheet( name : String ) {
		return smap.get(name);
	}

	public function createSheet( name : String ) {
		// name already exists
		for( s in sheets )
			if( s.name == name )
				return null;
		var s : cdb.Data.SheetData = {
			name : name,
			columns : [],
			lines : [],
			separators : [],
			props : {
			},
		};
		return addSheet(s);
	}

	function addSheet( s : cdb.Data.SheetData ) : Sheet {
		var sobj = new Sheet(this, s);
		data.sheets.push(s);
		sobj.sync();
		sheets.push(sobj);
		return sobj;
	}

	public function createSubSheet( s : Sheet, c : Column ) {
		var s : cdb.Data.SheetData = {
			name : s.name + "@" + c.name,
			props : { hide : true },
			separators : [],
			lines : [],
			columns : [],
		};
		if( c.type == TProperties ) s.props.isProps = true;
		return addSheet(s);
	}

	public function sync() {
		smap = new Map();
		for( s in sheets )
			s.sync();
		tmap = new Map();
		for( t in data.customTypes )
			tmap.set(t.name, t);
	}

	public function getCustomTypes() {
		return data.customTypes;
	}

	public function load( content : String ) {
		data = cdb.Parser.parse(content);
		sheets = [for( s in data.sheets ) new Sheet(this, s)];
		sync();
	}

	public function save() {
		// process
		for( s in sheets ) {
			// clean props
			for( p in Reflect.fields(s.props) ) {
				var v : Dynamic = Reflect.field(s.props, p);
				if( v == null || v == false ) Reflect.deleteField(s.props, p);
			}
			if( s.props.hasIndex ) {
				var lines = s.getLines();
				for( i in 0...lines.length )
					lines[i].index = i;
			}
			if( s.props.hasGroup ) {
				var lines = s.getLines();
				var gid = 0;
				var sindex = 0;
				var titles = s.props.separatorTitles;
				if( titles != null ) {
					// skip first if at head
					if( s.separators[sindex] == 0 && titles[sindex] != null ) sindex++;
					for( i in 0...lines.length ) {
						if( s.separators[sindex] == i ) {
							if( titles[sindex] != null ) gid++;
							sindex++;
						}
						lines[i].group = gid;
					}
				}
			}
		}
		return cdb.Parser.save(data);
	}

	public function getDefault( c : Column, ignoreOpt = false ) : Dynamic {
		if( c.opt && !ignoreOpt )
			return null;
		return switch( c.type ) {
		case TInt, TFloat, TEnum(_), TFlags(_), TColor: 0;
		case TString, TId, TImage, TLayer(_), TFile: "";
		case TRef(s):
			var s = getSheet(s);
			var l = s.lines[0];
			var id = "";
			if( l != null )
				for( c in s.columns )
					if( c.type == TId ) {
						id = Reflect.field(l, c.name);
						break;
					}
			id;
		case TBool: c.opt ? true : false;
		case TList: [];
		case TProperties : {};
		case TCustom(_), TTilePos, TTileLayer, TDynamic: null;
		}
	}

	public function typeStr( t : ColumnType ) {
		return switch( t ) {
		case TRef(n), TCustom(n): n;
		default: Std.string(t).substr(1);
		}
	}

	public function updateColumn( sheet : Sheet, old : Column, c : Column ) {
		if( old.name != c.name ) {

			for( c2 in sheet.columns )
				if( c2.name == c.name )
					return "Column name already used";
			if( c.name == "index" && sheet.props.hasIndex )
				return "Sheet already has an index";
			if( c.name == "group" && sheet.props.hasGroup )
				return "Sheet already has a group";

			for( o in sheet.getLines() ) {
				var v = Reflect.field(o, old.name);
				Reflect.deleteField(o, old.name);
				if( v != null )
					Reflect.setField(o, c.name, v);
			}

			function renameRec(sheet:Sheet, col) {
				var s = sheet.getSub(col);
				s.rename(sheet.name + "@" + c.name);
				for( c in s.columns )
					if( c.type == TList || c.type == TProperties )
						renameRec(s, c);
				s.sync();
			}
			if( old.type == TList || old.type == TProperties ) renameRec(sheet, old);
			old.name = c.name;
		}

		if( !old.type.equals(c.type) ) {
			var conv = getConvFunction(old.type, c.type);
			if( conv == null )
				return "Cannot convert " + typeStr(old.type) + " to " + typeStr(c.type);
			var conv = conv.f;
			if( conv != null )
				for( o in sheet.getLines() ) {
					var v = Reflect.field(o, c.name);
					if( v != null ) {
						v = conv(v);
						if( v != null ) Reflect.setField(o, c.name, v) else Reflect.deleteField(o, c.name);
					}
				}
			old.type = c.type;
			old.typeStr = null;
		}

		if( old.opt != c.opt ) {
			if( old.opt ) {
				for( o in sheet.getLines() ) {
					var v = Reflect.field(o, c.name);
					if( v == null ) {
						v = getDefault(c);
						if( v != null ) Reflect.setField(o, c.name, v);
					}
				}
			} else {
				switch( old.type ) {
				case TEnum(_):
					// first choice should not be removed
				default:
					var def = getDefault(old);
					for( o in sheet.getLines() ) {
						var v = Reflect.field(o, c.name);
						switch( c.type ) {
						case TList:
							var v : Array<Dynamic> = v;
							if( v.length == 0 )
								Reflect.deleteField(o, c.name);
						case TProperties:
							if( Reflect.fields(v).length == 0 )
								Reflect.deleteField(o, c.name);
						default:
							if( v == def )
								Reflect.deleteField(o, c.name);
						}
					}
				}
			}
			old.opt = c.opt;
		}

		if( c.display == null )
			Reflect.deleteField(old,"display");
		else
			old.display = c.display;

		if( c.kind == null )
			Reflect.deleteField(old,"kind");
		else
			old.kind = c.kind;

		sheet.sync();
		return null;
	}

	public function makePairs < T: { name:String } > ( oldA : Array<T>, newA : Array<T> ) : Array<{ a : T, b : T }> {
		var pairs = [];
		var oldL = Lambda.list(oldA);
		var newL = Lambda.list(newA);
		// first pass, by name
		for( a in oldA ) {
			for( b in newL )
				if( a.name == b.name ) {
					pairs.push( { a : a, b : b } );
					oldL.remove(a);
					newL.remove(b);
					break;
				}
		}
		// second pass, by same-index (handle renames)
		for( a in oldL )
			for( b in newL )
				if( Lambda.indexOf(oldA, a) == Lambda.indexOf(newA, b) ) {
					pairs.push( { a : a, b : b } );
					oldL.remove(a);
					newL.remove(b);
					break;
				}
		// add nulls
		for( a in oldL )
			pairs.push({ a : a, b : null });
		return pairs;
	}

	public function getConvFunction( old : ColumnType, t : ColumnType ) {
		var conv : Dynamic -> Dynamic = null;
		if( Type.enumEq(old, t) )
			return { f : null };
		switch( [old, t] ) {
		case [TInt, TFloat]:
			// nothing
		case [TId | TRef(_) | TLayer(_), TString]:
			// nothing
		case [TString, (TId | TRef(_) | TLayer(_))]:
			var r_invalid = ~/[^A-Za-z0-9_]/g;
			conv = function(r:String) return r_invalid.replace(r, "_");
		case [TBool, (TInt | TFloat)]:
			conv = function(b) return b ? 1 : 0;
		case [TString, TInt]:
			conv = Std.parseInt;
		case [TString, TFloat]:
			conv = function(str) { var f = Std.parseFloat(str); return Math.isNaN(f) ? null : f; }
		case [TString, TBool]:
			conv = function(s) return s != "";
		case [TString, TEnum(values)]:
			var map = new Map();
			for( i in 0...values.length )
				map.set(values[i].toLowerCase(), i);
			conv = function(s:String) return map.get(s.toLowerCase());
		case [TFloat, TInt]:
			conv = function(v) return Std.int(v);
		case [(TInt | TFloat | TBool), TString]:
			conv = Std.string;
		case [(TFloat|TInt), TBool]:
			conv = function(v:Float) return v != 0;
		case [TEnum(values1), TEnum(values2)]:
			var map = [];
			for( p in makePairs([for( i in 0...values1.length ) { name : values1[i], i : i } ], [for( i in 0...values2.length ) { name : values2[i], i : i } ]) ) {
				if( p.b == null ) continue;
				map[p.a.i] = p.b.i;
			}
			conv = function(i) return map[i];
		case [TFlags(values1), TFlags(values2)]:
			var map : Array<Null<Int>> = [];
			for( p in makePairs([for( i in 0...values1.length ) { name : values1[i], i : i } ], [for( i in 0...values2.length ) { name : values2[i], i : i } ]) ) {
				if( p.b == null ) continue;
				map[p.a.i] = p.b.i;
			}
			conv = function(i) {
				var out = 0;
				var k = 0;
				while( i >= 1<<k ) {
					if( map[k] != null && i & (1 << k) != 0 )
						out |= 1 << map[k];
					k++;
				}
				return out;
			};
		case [TInt, TEnum(values)]:
			conv = function(i) return if( i < 0 || i >= values.length ) null else i;
		case [TEnum(values), TInt]:
			// nothing
		case [TFlags(values), TInt]:
			// nothing
		case [TEnum(val1), TFlags(val2)] if( Std.string(val1) == Std.string(val2) ):
			conv = function(i) return 1 << i;
		case [TInt, TColor] | [TColor, TInt]:
			conv =  function(i) return i;
		case [TList, TProperties]:
			conv = function(l) return l[0];
		case [TProperties, TList]:
			conv = function(p) return Reflect.fields(p).length == 0 ? [] : [p];
		default:
			return null;
		}
		return { f : conv };
	}

	public function updateType( old : CustomType, t : CustomType ) {
		var casesPairs = makePairs(old.cases, t.cases);

		// build convert map
		var convMap = [];
		for( p in casesPairs ) {

			if( p.b == null ) continue;

			var id = Lambda.indexOf(t.cases, p.b);
			var conv = {
				def : ([id] : Array<Dynamic>),
				args : [],
			};
			var args = makePairs(p.a.args, p.b.args);
			for( a in args ) {
				if( a.b == null ) {
					conv.args[Lambda.indexOf(p.a.args, a.a)] = function(_) return null; // discard
					continue;
				}
				var b = a.b, a = a.a;
				var c = getConvFunction(a.type, b.type);
				if( c == null )
					throw "Cannot convert " + p.a.name + "." + a.name + ":" + typeStr(a.type) + " to " + p.b.name + "." + b.name + ":" + typeStr(b.type);
				var f : Dynamic -> Dynamic = c.f;
				if( f == null ) f = function(x) return x;
				if( a.opt != b.opt ) {
					var oldf = f;
					if( a.opt ) {
						f = function(v) { v = oldf(v); return v == null ? getDefault(b) : v; };
					} else {
						var def = getDefault(a);
						f = function(v) return if( v == def ) null else oldf(v);
					}
				}
				var index = Lambda.indexOf(p.b.args, b);
				conv.args[Lambda.indexOf(p.a.args, a)] = function(v) return { v = f(v); return if( v == null && b.opt ) null else { index : index, v : v }; };
			}
			for( b in p.b.args )
				conv.def.push(getDefault(b));
			while( conv.def[conv.def.length - 1] == null )
				conv.def.pop();
			convMap[Lambda.indexOf(old.cases, p.a)] = conv;
		}

		function convertTypeRec( t : CustomType, v : Array<Dynamic> ) : Array<Dynamic> {
			if( t == null )
				return null;
			if( t == old ) {
				var conv = convMap[v[0]];
				if( conv == null )
					return null;
				var out = conv.def.copy();
				for( i in 0...conv.args.length ) {
					var v = conv.args[i](v[i + 1]);
					if( v == null ) continue;
					out[v.index+1] = v.v;
				}
				return out;
			}
			var c = t.cases[v[0]];
			for( i in 0...c.args.length ) {
				switch( c.args[i].type ) {
				case TCustom(tname):
					var av = v[i + 1];
					if( av != null )
						v[i+1] = convertTypeRec(getCustomType(tname), av);
				default:
				}
			}
			return v;
		}

		// apply convert
		for( s in sheets )
			for( c in s.columns )
				switch( c.type ) {
				case TCustom(tname):
					var t2 = getCustomType(tname);
					for( obj in s.getLines() ) {
						var v = Reflect.field(obj, c.name);
						if( v != null ) {
							v = convertTypeRec(t2, v);
							if( v == null )
								Reflect.deleteField(obj, c.name);
							else
								Reflect.setField(obj, c.name, v);
						}
					}
					// if renamed
					if( tname == old.name && t.name != old.name ) {
						c.type = TCustom(t.name);
						c.typeStr = null;
					}
				default:
				}


		if( t.name != old.name ) {
			for( t2 in getCustomTypes() )
				for( c in t2.cases )
					for( a in c.args ) {
						switch( a.type ) {
						case TCustom(n) if( n == old.name ):
							a.type = TCustom(t.name);
							a.typeStr = null;
						default:
						}
					}
			tmap.remove(old.name);
			old.name = t.name;
			tmap.set(old.name, old);
		}
		old.cases = t.cases;
	}

	public function valToString( t : ColumnType, val : Dynamic, esc = false ) {
		if( val == null )
			return "null";
		return switch( t ) {
		case TInt, TFloat, TBool, TImage: Std.string(val);
		case TId, TRef(_), TLayer(_), TFile: esc ? '"'+val+'"' : val;
		case TString:
			var val : String = val;
			if( !esc )
				val;
			else
				'"' + val.split("\\").join("\\\\").split('"').join("\\\"") + '"';
		case TEnum(values):
			valToString(TString, values[val], esc);
		case TCustom(t):
			typeValToString(getCustomType(t), val, esc);
		case TFlags(values):
			var v : Int = val;
			var flags = [];
			for( i in 0...values.length )
				if( v & (1 << i) != 0 )
					flags.push(valToString(TString, values[i], esc));
			Std.string(flags);
		case TColor:
			var s = "#" + StringTools.hex(val, 6);
			esc ? '"' + s + '"' : s;
		case TTileLayer, TDynamic, TTilePos:
			if( esc )
				return haxe.Json.stringify(val);
			return valueToString(val);
		case TProperties, TList:
			"???";
		}
	}

	function valueToString( v : Dynamic ) {
		switch (Type.typeof(v)) {
		case TNull:
			return "null";
		case TObject:
			var fl = [for( f in Reflect.fields(v) ) f+" : "+valueToString(Reflect.field(v,f))];
			return fl.length == 0 ? "{}" : "{ " + fl.join(", ") + " }";
		case TClass(c):
			switch( Type.getClassName(c) ) {
			case "Array":
				var arr : Array<Dynamic> = v;
				var vl = [for( v in arr ) valueToString(v)];
				return vl.length == 0 ? "[]" : "["+vl.join(", ")+"]";
			case "String":
				return valToString(TString,v,true); // escape ! (valid JSON)
			default:
			}
		default:
		}
		return Std.string(v);
	}

	public function typeValToString( t : CustomType, val : Array<Dynamic>, esc = false ) {
		var c = t.cases[val[0]];
		var str = c.name;
		if( c.args.length > 0 ) {
			str += "(";
			var out = [];
			for( i in 1...val.length )
				out.push(valToString(c.args[i - 1].type, val[i], esc));
			str += out.join(",");
			str += ")";
		}
		return str;
	}

	public function parseDynamic( s : String ) : Dynamic {
		s = ~/([{,])[ \t\n]*([a-zA-Z_][a-zA-Z0-9_]*)[ \t\n]*:/g.replace(s, "$1\"$2\":");
		return haxe.Json.parse(s);
	}

	public function parseValue( t : ColumnType, val : String, strictCheck = false ) : Dynamic {
		switch( t ) {
		case TInt:
			if( ~/^-?[0-9]+$/.match(val) )
				return Std.parseInt(val);
		case TString:
			if( !strictCheck )
				return val;
			if( val.charCodeAt(0) == '"'.code ) {
				var esc = false;
				var p = 1;
				var out = new StringBuf();
				while( true ) {
					if( p == val.length ) throw "Unclosed \"";
					var c = val.charCodeAt(p++);
					if( esc ) {
						out.addChar(c);
						esc = false;
					} else switch( c ) {
						case '"'.code:
							if( p < val.length ) throw "Invalid content after string '" + val;
							break;
						case '\\'.code:
							esc = true;
						default:
							out.addChar(c);
					}
				}
				return out.toString();
			}
			if( !~/^[A-Za-z0-9_]+$/.match(val) )
				throw "String requires quotes '" + val + "'";
			return val;
		case TBool:
			if( val == "true" ) return true;
			if( val == "false" ) return false;
		case TFloat:
			var f = Std.parseFloat(val);
			if( !Math.isNaN(f) )
				return f;
		case TCustom(t):
			return parseTypeVal(getCustomType(t), val);
		case TId:
			if( r_ident.match(val) )
				return val;
		case TRef(t):
			if( r_ident.match(val) ) {
				if( !strictCheck )
					return val;
				var r = getSheet(t).index.get(val);
				if( r == null ) throw val + " is not a known " + t + " id";
				return r.id;
			}
		case TColor:
			if( val.charAt(0) == "#" )
				val = "0x" + val.substr(1);
			if( ~/^-?[0-9]+$/.match(val) || ~/^0x[0-9A-Fa-f]+$/.match(val) )
				return Std.parseInt(val);
		case TDynamic:
			return parseDynamic(val);
		default:
		}
		throw "'" + val + "' should be "+typeStr(t);
	}

	public function parseTypeVal( t : CustomType, val : String ) : Dynamic {
		if( t == null || val == null )
			throw "Missing val/type";
		val = StringTools.trim(val);
		var missingCloseParent = false;
		var pos = val.indexOf("(");
		var id, args = null;
		if( pos < 0 ) {
			id = val;
			args = [];
		} else {
			id = val.substr(0, pos);
			val = val.substr(pos + 1);

			if( StringTools.endsWith(val, ")") )
				val = val.substr(0, val.length - 1);
			else
				missingCloseParent = true;
			args = [];
			var p = 0, start = 0, pc = 0;
			while( p < val.length ) {
				switch( val.charCodeAt(p++) ) {
				case '('.code:
					pc++;
				case ')'.code:
					if( pc == 0 ) throw "Extra )";
					pc--;
				case '"'.code:
					var esc = false;
					while( true ) {
						if( p == val.length ) throw "Unclosed \"";
						var c = val.charCodeAt(p++);
						if( esc )
							esc = false;
						else switch( c ) {
							case '"'.code: break;
							case '\\'.code: esc = true;
						}
					}
				case ','.code:
					if( pc == 0 ) {
						args.push(val.substr(start, p - start - 1));
						start = p;
					}
				default:
				}
			}
			if( pc > 0 ) missingCloseParent = true;
			if( p > start || (start > 0 && p == start) ) args.push(val.substr(start, p - start));
		}
		for( i in 0...t.cases.length ) {
			var c = t.cases[i];
			if( c.name == id ) {
				var vals : Array<Null<Int>> = [i];
				for( a in c.args ) {
					var v = args.shift();
					if( v == null ) {
						if( a.opt )
							vals.push(null);
						else
							throw "Missing argument " + a.name+" : "+typeStr(a.type);
					} else {
						v = StringTools.trim(v);
						if( a.opt && v == "null" ) {
							vals.push(null);
							continue;
						}
						var val = try parseValue(a.type, v, true) catch( e : String ) throw e + " for " + a.name;
						vals.push(val);
					}
				}
				if( args.length > 0 )
					throw "Extra argument '" + args.shift() + "'";
				if( missingCloseParent )
					throw "Missing )";
				while( vals[vals.length - 1] == null )
					vals.pop();
				return vals;
			}
		}
		throw "Unkown value '" + id + "'";
		return null;
	}

	function parseType( tstr : String ) : ColumnType {
		return switch( tstr ) {
		case "Int": TInt;
		case "Float": TFloat;
		case "Bool": TBool;
		case "String": TString;
		default:
			if( getCustomType(tstr) != null )
				TCustom(tstr);
			else if( getSheet(tstr) != null )
				TRef(tstr);
			else {
				if( StringTools.endsWith(tstr, ">") ) {
					var tname = tstr.split("<").shift();
					var tparam = tstr.substr(tname.length + 1).substr(0, -1);
				}
				throw "Unknown type "+tstr;
			}
		}
	}

	public function typeCasesToString( t : CustomType, prefix = "" ) {
		var arr = [];
		for( c in t.cases ) {
			var str = c.name;
			if( c.args.length > 0 ) {
				str += "( ";
				var out = [];
				for( a in c.args ) {
					var k = "";
					if( a.opt ) k += "?";
					k += a.name + " : " + typeStr(a.type);
					out.push(k);
				}
				str += out.join(", ");
				str += " )";
			}
			str += ";";
			arr.push(prefix+str);
		}
		return arr.join("\n");
	}

	public function parseTypeCases( def : String ) : Array<CustomTypeCase> {
		var cases = [];
		var cmap = new Map();
		for( line in ~/[\n;]/g.split(def) ) {
			var line = StringTools.trim(line);
			if( line == "" )
				continue;
			if( line.charCodeAt(line.length - 1) == ";".code )
				line = line.substr(1);
			var pos = line.indexOf("(");
			var name = null, args = [];
			if( pos < 0 )
				name = line;
			else {
				name = line.substr(0, pos);
				line = line.substr(pos + 1);
				if( line.charCodeAt(line.length - 1) != ")".code )
					throw "Missing closing parent in " + line;
				line = line.substr(0, line.length - 1);
				for( arg in line.split(",") ) {
					var tname = arg.split(":");
					if( tname.length != 2 ) throw "Required name:type in '" + arg + "'";
					var opt = false;
					var id = StringTools.trim(tname[0]);
					if( id.charAt(0) == "?" ) {
						opt = true;
						id = StringTools.trim(id.substr(1));
					}
					var t = StringTools.trim(tname[1]);
					if( !r_ident.match(id) )
						throw "Invalid identifier " + id;
					var c : Column = {
						name : id,
						type : parseType(t),
						typeStr : null,
					};
					if( opt ) c.opt = true;
					args.push(c);
				}
			}
			if( !r_ident.match(name) )
				throw "Invalid identifier " + line;
			if( cmap.exists(name) )
				throw "Duplicate identifier " + name;
			cmap.set(name, true);
			cases.push( { name : name, args:args } );
		}
		return cases;
	}

	public function mapType( callb ) {
		for( s in sheets )
			for( c in s.columns ) {
				var t = callb(c.type);
				if( t != c.type ) {
					c.type = t;
					c.typeStr = null;
				}
			}
		for( t in getCustomTypes() )
			for( c in t.cases )
				for( a in c.args ) {
					var t = callb(a.type);
					if( t != a.type ) {
						a.type = t;
						a.typeStr = null;
					}
				}
	}

	public function updateRefs( sheet : Sheet, refMap : Map<String,String> ) {
		var changes = [];
		browseObjects(function(ref) {
			for( c in ref.sheet.columns ) {
				switch( c.type ) {
				case TRef(n) if( n == sheet.name ):
					var id = Reflect.field(ref.obj, c.name);
					if( id == null ) continue;
					var nid = refMap.get(id);
					if( nid == null ) continue;
					changes.push({ ref : ref, v : SetField(ref.obj, c.name, nid) });
				case TCustom(t):
					var v = Reflect.field(ref.obj, c.name);
					if( v == null ) continue;
					function convertTypeRec( t : CustomType, arr : Array<Dynamic> ) {
						var c = t.cases[arr[0]];
						for( i in 0...arr.length - 1 ) {
							var v : Dynamic = arr[i + 1];
							if( v == null ) continue;
							switch( c.args[i].type ) {
							case TRef(n) if( n == sheet.name ):
								var nv = refMap.get(v);
								if( nv == null ) continue;
								changes.push({ ref : ref, v : SetIndex(arr, i+1, nv) });
							case TCustom(name):
								convertTypeRec(getCustomType(name), v);
							default:
							}
						}
					}
					convertTypeRec(getCustomType(t), v);
				default:
				}
			}
		});
		return applyChanges(changes);
	}

	function browseObjects( callb : ChangeRef -> Void ) {
		function browseRec(mainSheet:Sheet, mainObj:Dynamic, s:Sheet, o:Dynamic) {
			callb({ mainSheet : mainSheet, mainObj : mainSheet, sheet : s, obj : o });
			for( c in s.columns )
				switch( c.type ) {
				case TList:
					var arr : Array<Dynamic> = Reflect.field(o, c.name);
					if( arr != null ) {
						var ssub = s.getSub(c);
						for( o in arr )
							browseRec(mainSheet, mainObj, ssub, o);
					}
				case TProperties:
					var pr : Dynamic = Reflect.field(o, c.name);
					if( pr != null ) {
						var ssub = s.getSub(c);
						browseRec(mainSheet, mainObj, ssub, pr);
					}
				default:
				}
		}
		for( s in sheets ) {
			if( s.props.hide ) continue;
			for( o in s.getLines() )
				browseRec(s, o, s, o);
		}
	}

	public function applyChanges( changes : Changes ) : Changes {
		var undo = [];
		for( c in changes )
			switch( c.v ) {
			case SetField(o, f, v):
				var prev = Reflect.field(o, f);
				undo.push({ ref : c.ref, v : SetField(o, f, prev) });
				if( v == null )
					Reflect.deleteField(o, f);
				else
					Reflect.setField(o, f, v);
			case SetIndex(arr, index, v):
				undo.push({ ref : c.ref, v : SetIndex(arr, index, arr[index]) });
				arr[index] = v;
			case DeleteField(o, f):
				var prev = Reflect.field(o, f);
				if( prev != null )
					undo.push({ ref : c.ref, v : SetField(o, f, prev) });
				Reflect.deleteField(o, f);
			case InsertIndex(arr, index, v):
				undo.push({ ref : c.ref, v : DeleteIndex(arr,index) });
				arr.insert(index, v);
			case DeleteIndex(arr, index):
				var old = arr[index];
				undo.push({ ref : c.ref, v : InsertIndex(arr,index,old) });
				arr.splice(index, 1);
			}
		undo.reverse();
		return undo;
	}

	public function updateSheets() {
		data.sheets = [for( s in sheets ) @:privateAccess s.sheet];
	}

	public function deleteSheet( sheet : Sheet ) {
		sheets.remove(sheet);
		updateSheets();
		smap.remove(sheet.name);
		for( c in sheet.columns )
			switch( c.type ) {
			case TList, TProperties:
				deleteSheet(sheet.getSub(c));
			default:
			}
		mapType(function(t) {
			return switch( t ) {
			case TRef(r), TLayer(r) if( r == sheet.name ): TString;
			default: t;
			}
		});
	}

}
