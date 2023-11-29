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

	public function createSheet( name : String, ?index : Int ) {
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
		return addSheet(s, index);
	}

	public function moveSheet( s : Sheet, delta : Int ) {
		var fsheets = [for( s in sheets ) if( !s.props.hide ) s];
		var index = fsheets.indexOf(s);
		var other = fsheets[index+delta];
		if( index < 0 || other == null ) return false;

		// move to new index
		sheets.remove(s);
		index = sheets.indexOf(other);
		if( delta > 0 ) index++;
		sheets.insert(index, s);

		// move sub sheets as well !
		var moved = [s];
		var delta = 0;
		for( ssub in sheets.copy() ) {
			var parent = ssub.getParent();
			if( parent != null && moved.indexOf(parent.s) >= 0 ) {
				sheets.remove(ssub);
				var idx = sheets.indexOf(s) + (++delta);
				sheets.insert(idx, ssub);
				moved.push(ssub);
			}
		}
		updateSheets();
		return true;
	}

	function addSheet( s : cdb.Data.SheetData, ?index : Int ) : Sheet {
		var sobj = new Sheet(this, s);
		if( index != null )
			data.sheets.insert(index, s);
		else
			data.sheets.push(s);
		sobj.sync();
		if( index != null )
			sheets.insert(index, sobj);
		else
			sheets.push(sobj);
		return sobj;
	}

	public function createSubSheet( parent : Sheet, c : Column ) {
		var s : cdb.Data.SheetData = {
			name : parent.name + "@" + c.name,
			props : { hide : true },
			separators : [],
			lines : [],
			columns : [],
		};
		if( c.type == TProperties ) s.props.isProps = true;
		// our parent might be a virtual sheet
		var index = data.sheets.indexOf(Lambda.find(data.sheets, function(s) return s.name == parent.name));
		for( c2 in parent.columns ) {
			if( c == c2 ) break;
			if( c2.type.match(TProperties|TList) ) {
				var sub = parent.getSub(c2);
				index = data.sheets.indexOf(@:privateAccess sub.sheet);
			}
		}
		return addSheet(s, index < 0 ? null : index + 1);
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
		var data = cdb.Parser.parse(content, true);
		loadData(data);
	}

	public function loadData( data : cdb.Data ) {
		this.data = data;
		if( sheets != null ) {
			// reset old sheets (should not be used)
			for( s in sheets ) @:privateAccess {
				s.base = null;
				s.index = null;
				s.sheet = null;
			}
		}
		sheets = [for( s in data.sheets ) new Sheet(this, s)];
		#if cdb_old_compat
		for( s in sheets )
			if( s.props.hasIndex ) {
				// delete old index data, if present
				var lines = s.getLines();
				for( i in 0...lines.length )
					Reflect.deleteField(lines[i],"index");
			}
		#end
		sync();
	}

	public function cleanup() {
		cleanLayers();
	}

	function cleanLayers() {
		var count = 0;
		for( s in sheets ) {
			if( s.props.level == null ) continue;
			var ts = s.props.level.tileSets;
			var usedLayers = new Map();
			for( c in s.columns ) {
				switch( c.type ) {
				case TList:
					var sub = s.getSub(c);
					if( !sub.hasColumn("data", [TTileLayer]) ) continue;
					for( obj in sub.getLines() ) {
						var v : cdb.Types.TileLayer = obj.data;
						if( v == null || v.file == null ) continue;
						usedLayers.set(v.file, true);
					}
				default:
				}
			}
			for( f in Reflect.fields(ts) )
				if( !usedLayers.get(f) ) {
					Reflect.deleteField(ts, f);
					count++;
				}
		}
		return count;
	}

	public function save() {
		// process
		for( s in sheets ) {
			// clean props
			if( s.props.hasGroup ) {
				var lines = s.getLines();
				for( l in lines )
					if( l.group != null )
						Reflect.deleteField(l,"group");
			}
			for( p in Reflect.fields(s.props) ) {
				var v : Dynamic = Reflect.field(s.props, p);
				if( v == null || v == false ) Reflect.deleteField(s.props, p);
			}
		}
		return cdb.Parser.save(data);
	}

	public function getDefault( c : Column, ?ignoreOpt = false, ?sheet : Sheet ) : Dynamic {
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
		case TProperties:
			var obj = {};
			if( sheet != null ) {
				var s = sheet.getSub(c);
				for( c in s.columns )
					if( !c.opt ) {
						var def = getDefault(c, s);
						if( def != null ) Reflect.setField(obj, c.name, def);
					}
			}
			obj;
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
			var renames = [];
			function renameRec(sheet:Sheet, col, newName) {
				var s = sheet.getSub(col);
				renames.push(function() {
					s.rename(sheet.name + "@" + newName);
					s.sync();
				});
				for( c in s.columns )
					if( c.type == TList || c.type == TProperties )
						renameRec(s, c, c.name);
			}
			if( old.type == TList || old.type == TProperties ) {
				renameRec(sheet, old, c.name);
				for( f in renames ) f();
			}
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
			switch( [old.type, c.type] ) {
				case [TList, TProperties]:
					sheet.getSub(old).props.isProps = true;
				case [TProperties, TList]:
					sheet.getSub(old).props.isProps = false;
				default:
			}

			old.type = c.type;
			old.typeStr = null;
		}

		if( old.opt != c.opt ) {
			if( old.opt ) {
				for( o in sheet.getLines() ) {
					var v = Reflect.field(o, c.name);
					if( v == null ) {
						v = getDefault(c, sheet);
						if( v != null ) Reflect.setField(o, c.name, v);
					}
				}
			} else {
				switch( old.type ) {
				case TEnum(_):
					// first choice should not be removed
				default:
					var def = getDefault(old, sheet);
					for( o in sheet.getLines() ) {
						var v = Reflect.field(o, c.name);
						switch( c.type ) {
						case TList:
							var v : Array<Dynamic> = v;
							if( v != null && v.length == 0 )
								Reflect.deleteField(o, c.name);
						case TProperties:
							if( Reflect.fields(v).length == 0 || haxe.Json.stringify(v) == haxe.Json.stringify(def) )
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

		for( f in ["display","kind","scope","documentation", "editor"] ) {
			var v : Dynamic = Reflect.field(c,f);
			if( v == null )
				Reflect.deleteField(old, f);
			else
				Reflect.setField(old,f,v);
		}

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
		case [TEnum(values), TString]:
			conv = function(i) return values[i];
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
		var convMap : Array<{ def : Array<Dynamic>, args : Array<Dynamic -> Dynamic> }> = [];

		function convertTypeRec( t : CustomType, v : Array<Dynamic> ) : Array<Dynamic> {
			if( t == null || v == null )
				return null;
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
			return v;
		}

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
				if( a.kind != b.kind ) {
					a.kind = b.kind;
					if( a.kind == null ) Reflect.deleteField(a,"kind");
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
					if( a.kind == TypeKind ) k += "Kind";
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
					var opt = false, isKind = false;
					var id = StringTools.trim(tname[0]);
					if( id.charAt(0) == "?" ) {
						opt = true;
						id = StringTools.trim(id.substr(1));
					}
					var t = StringTools.trim(tname[1]);
					if( StringTools.endsWith(t,"Kind") && getSheet(t.substr(0,-4)) != null ) {
						isKind = true;
						t = t.substr(0,-4);
					}
					if( !r_ident.match(id) )
						throw "Invalid identifier " + id;
					var c : Column = {
						name : id,
						type : parseType(t),
						typeStr : null,
					};
					if( opt ) c.opt = true;
					if( isKind ) c.kind = TypeKind;
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

	function convertTypeRec( sheet : Sheet, refMap : Map<String, String>, t : CustomType, o : Array<Dynamic> ) {
		var c = t.cases[o[0]];
		for( i in 0...o.length - 1 ) {
			var v : Dynamic = o[i + 1];
			if( v == null ) continue;
			switch( c.args[i].type ) {
			case TRef(n) if( n == sheet.name ):
				var v = refMap.get(v);
				if( v == null ) continue;
				o[i + 1] = v;
			case TCustom(name):
				convertTypeRec(sheet, refMap, getCustomType(name), v);
			default:
			}
		}
	}

	function replaceScriptIdent( v : String, oldId : String, newId : String ) {
		return new EReg("\\b"+oldId.split(".").join("\\.")+"\\b","").replace(v, newId);
	}

	public function updateLocalRefs( sheet : Sheet, refMap : Map<String, String>, obj : Dynamic, objSheet : Sheet ) {
		for( c in objSheet.columns ) {
			var v : Dynamic = Reflect.field(obj, c.name);
			if( v == null ) continue;
			switch( c.type ) {
			case TRef(n) if( n == sheet.name ):
				v = refMap.get(v);
				if( v == null ) continue;
				Reflect.setField(obj, c.name, v);
			case TCustom(t):
				convertTypeRec(sheet, refMap, getCustomType(t), v);
			case TList:
				var sub = objSheet.getSub(c);
				for( obj in (v:Array<Dynamic>) )
					updateLocalRefs(sheet, refMap, obj, sub);
			case TProperties:
				updateLocalRefs(sheet, refMap, v, objSheet.getSub(c));
			case TString if( c.kind == Script ):
				var prefix = sheet.name.split("@").pop();
				prefix = prefix.charAt(0).toUpperCase() + prefix.substr(1);
				for( oldId => newId in refMap )
					if( oldId != "" && newId != "" )
						v = replaceScriptIdent(v,prefix+"."+oldId,prefix+"."+newId);
				Reflect.setField(obj, c.name, v);
			default:
			}
		}
	}

	public function updateRefs( sheet : Sheet, refMap : Map<String, String> ) {
		for( s in sheets )
			for( c in s.columns )
				switch( c.type ) {
				case TRef(n) if( n == sheet.name ):
					for( obj in s.getLines() ) {
						var id = Reflect.field(obj, c.name);
						if( id == null ) continue;
						id = refMap.get(id);
						if( id == null ) continue;
						Reflect.setField(obj, c.name, id);
					}
				case TCustom(t):
					for( obj in s.getLines() ) {
						var o = Reflect.field(obj, c.name);
						if( o == null ) continue;
						convertTypeRec(sheet, refMap, getCustomType(t), o);
					}
				case TString if( c.kind == Script ):
					var prefix = sheet.name.split("@").pop();
					prefix = prefix.charAt(0).toUpperCase() + prefix.substr(1);
					for( obj in s.getLines() ) {
						var v : String = Reflect.field(obj, c.name);
						if( v != null ) {
							for( oldId => newId in refMap )
								if( oldId != "" && newId != "" )
									v = replaceScriptIdent(v,prefix+"."+oldId,prefix+"."+newId);
							Reflect.setField(obj, c.name, v);
						}
					}
				default:
				}
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
