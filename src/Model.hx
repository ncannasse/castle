import cdb.Data;

typedef Prefs = {
	windowPos : { x : Int, y : Int, w : Int, h : Int, max : Bool },
	curFile : String,
	curSheet : Int,
}

typedef Index = { id : String, disp : String, obj : Dynamic }

class Model {

	var prefs : Prefs;
	var data : Data;
	var imageBank : Dynamic<String>;
	var smap : Map< String, { s : Sheet, index : Map<String,Index> , all : Array<Index> } >;
	var tmap : Map< String, CustomType >;
	var openedList : Map<String,Bool>;

	var curSavedData : String;
	var history : Array<String>;
	var redo : Array<String>;
	var r_ident : EReg;

	function new() {
		openedList = new Map();
		r_ident = ~/^[A-Za-z_][A-Za-z0-9_]*$/;
		prefs = {
			windowPos : { x : 50, y : 50, w : 800, h : 600, max : false },
			curFile : null,
			curSheet : 0,
		};
		try {
			prefs = haxe.Unserializer.run(js.Browser.getLocalStorage().getItem("prefs"));
		} catch( e : Dynamic ) {
		}
	}

	public function getImageData( key : String ) : String {
		return Reflect.field(imageBank, key);
	}

	public inline function getSheet( name : String ) {
		return smap.get(name).s;
	}

	public inline function getPseudoSheet( sheet : Sheet, c : Column ) {
		return getSheet(sheet.name + "@" + c.name);
	}

	function getParentSheet( sheet : Sheet ) {
		if( !sheet.props.hide )
			return null;
		var parts = sheet.name.split("@");
		var colName = parts.pop();
		return { s : getSheet(parts.join("@")), c : colName };
	}

	function getSheetLines( sheet : Sheet ) : Array<Dynamic> {
		var p = getParentSheet(sheet);
		if( p == null ) return sheet.lines;
		var all = [];
		for( obj in getSheetLines(p.s) ) {
			var v : Array<Dynamic> = Reflect.field(obj, p.c);
			if( v != null )
				for( v in v )
					all.push(v);
		}
		return all;
	}

	function getSheetObjects( sheet : Sheet ) : Array<{ path : Array<Dynamic>, indexes : Array<Int> }> {
		var p = getParentSheet(sheet);
		if( p == null )
			return [for( i in 0...sheet.lines.length ) { path : [sheet.lines[i]], indexes : [i] }];
		var all = [];
		for( obj in getSheetObjects(p.s) ) {
			var v : Array<Dynamic> = Reflect.field(obj.path[obj.path.length-1], p.c);
			if( v != null )
				for( i in 0...v.length ) {
					var sobj = v[i];
					var p = obj.path.copy();
					var idx = obj.indexes.copy();
					p.push(sobj);
					idx.push(i);
					all.push({ path : p, indexes : idx });
				}
		}
		return all;
	}

	function newLine( sheet : Sheet, ?index : Int ) {
		var o = {
		};
		for( c in sheet.columns ) {
			var d = getDefault(c);
			if( d != null )
				Reflect.setField(o, c.name, d);
		}
		if( index == null )
			sheet.lines.push(o);
		else {
			for( i in 0...sheet.separators.length ) {
				var s = sheet.separators[i];
				if( s > index ) sheet.separators[i] = s + 1;
			}
			sheet.lines.insert(index + 1, o);
			changeLineOrder(sheet, [for( i in 0...sheet.lines.length ) i <= index ? i : i + 1]);
		}
	}

	public function getPath( sheet : Sheet ) {
		return sheet.path == null ? sheet.name : sheet.path;
	}

	public function getDefault( c : Column ) : Dynamic {
		if( c.opt )
			return null;
		return switch( c.type ) {
		case TInt, TFloat, TEnum(_), TFlags(_), TColor: 0;
		case TString, TId, TRef(_), TImage, TLayer(_), TFile: "";
		case TBool: false;
		case TList: [];
		case TCustom(_): null;
		}
	}

	public function hasColumn( s : Sheet, name : String, ?types : Array<ColumnType> ) {
		for( c in s.columns )
			if( c.name == name ) {
				if( types != null ) {
					for( t in types )
						if( c.type.equals(t) )
							return true;
					return false;
				}
				return true;
			}
		return false;
	}

	public function save( history = true ) {

		// process
		for( s in data.sheets ) {
			// clean props
			for( p in Reflect.fields(s.props) ) {
				var v : Dynamic = Reflect.field(s.props, p);
				if( v == null || v == false ) Reflect.deleteField(s.props, p);
			}
			if( s.props.hasIndex ) {
				var lines = getSheetLines(s);
				for( i in 0...lines.length )
					lines[i].index = i;
			}
			if( s.props.hasGroup ) {
				var lines = getSheetLines(s);
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

		if( history ) {
			var sdata = quickSave();
			if( sdata != curSavedData ) {
				if( curSavedData != null ) {
					this.history.push(curSavedData);
					this.redo = [];
				}
				curSavedData = sdata;
			}
		}
		if( prefs.curFile == null )
			return;
		var save = [];
		for( s in data.sheets ) {
			for( c in s.columns ) {
				save.push(c.type);
				if( c.typeStr == null ) c.typeStr = cdb.Parser.saveType(c.type);
				Reflect.deleteField(c, "type");
			}
		}
		for( t in data.customTypes )
			for( c in t.cases )
				for( a in c.args ) {
					save.push(a.type);
					if( a.typeStr == null ) a.typeStr = cdb.Parser.saveType(a.type);
					Reflect.deleteField(a, "type");
				}
		sys.io.File.saveContent(prefs.curFile, untyped haxe.Json.stringify(data, null, "\t"));
		for( s in this.data.sheets )
			for( c in s.columns )
				c.type = save.shift();
		for( t in data.customTypes )
			for( c in t.cases )
				for( a in c.args )
					a.type = save.shift();
	}

	function saveImages() {
		if( prefs.curFile == null )
			return;
		var img = prefs.curFile.split(".");
		img.pop();
		var path = img.join(".") + ".img";
		if( imageBank == null )
			sys.FileSystem.deleteFile(path);
		else
			sys.io.File.saveContent(path, untyped haxe.Json.stringify(imageBank, null, "\t"));
	}

	function quickSave() {
		return haxe.Serializer.run({ d : data, o : openedList });
	}

	function quickLoad(sdata) {
		var t = haxe.Unserializer.run(sdata);
		data = t.d;
		openedList = t.o;
	}

	function moveLine( sheet : Sheet, index : Int, delta : Int ) : Null<Int> {
		if( delta < 0 && index > 0 ) {
			var l = sheet.lines[index];
			sheet.lines.splice(index, 1);
			sheet.lines.insert(index - 1, l);

			var arr = [for( i in 0...sheet.lines.length ) i];
			arr[index] = index - 1;
			arr[index - 1] = index;
			changeLineOrder(sheet, arr);

			return index - 1;
		} else if( delta > 0 && sheet != null && index < sheet.lines.length-1 ) {
			var l = sheet.lines[index];
			sheet.lines.splice(index, 1);
			sheet.lines.insert(index + 1, l);

			var arr = [for( i in 0...sheet.lines.length ) i];
			arr[index] = index + 1;
			arr[index + 1] = index;
			changeLineOrder(sheet, arr);

			return index + 1;
		}
		return null;
	}

	function deleteLine( sheet : Sheet, index : Int ) {

		var arr = [for( i in 0...sheet.lines.length ) if( i < index ) i else i - 1];
		arr[index] = -1;
		changeLineOrder(sheet, arr);

		sheet.lines.splice(index, 1);

		var prev = -1, toRemove = null;
		for( i in 0...sheet.separators.length ) {
			var s = sheet.separators[i];
			if( s > index ) {
				if( prev == s ) toRemove = i;
				sheet.separators[i] = s - 1;
			} else
				prev = s;
		}
		// prevent duplicates
		if( toRemove != null ) {
			sheet.separators.splice(toRemove, 1);
			if( sheet.props.separatorTitles != null ) sheet.props.separatorTitles.splice(toRemove, 1);
		}
	}

	function deleteColumn( sheet : Sheet, ?cname : String ) {
		for( c in sheet.columns )
			if( c.name == cname ) {
				sheet.columns.remove(c);
				for( o in getSheetLines(sheet) )
					Reflect.deleteField(o, c.name);
				if( sheet.props.displayColumn == c.name ) {
					sheet.props.displayColumn = null;
					makeSheet(sheet);
				}
				if( c.type == TList )
					deleteSheet(getPseudoSheet(sheet, c));
				return true;
			}
		return false;
	}

	function deleteSheet( sheet : Sheet ) {
		data.sheets.remove(sheet);
		smap.remove(sheet.name);
		for( c in sheet.columns )
			switch( c.type ) {
			case TList:
				deleteSheet(getPseudoSheet(sheet, c));
			default:
			}
		mapType(function(t) {
			return switch( t ) {
			case TRef(r), TLayer(r) if( r == sheet.name ): TString;
			default: t;
			}
		});
	}

	function addColumn( sheet : Sheet, c : Column, ?index : Int ) {
		// create
		for( c2 in sheet.columns )
			if( c2.name == c.name )
				return "Column already exists";
			else if( c2.type == TId && c.type == TId )
				return "Only one ID allowed";
		if( c.name == "index" && sheet.props.hasIndex )
			return "Sheet already has an index";
		if( c.name == "group" && sheet.props.hasGroup )
			return "Sheet already has a group";
		if( index == null )
			sheet.columns.push(c);
		else
			sheet.columns.insert(index, c);
		for( i in getSheetLines(sheet) ) {
			var def = getDefault(c);
			if( def != null ) Reflect.setField(i, c.name, def);
		}
		if( c.type == TList ) {
			// create an hidden sheet for the model
			var s : Sheet = {
				name : sheet.name + "@" + c.name,
				props : { hide : true },
				separators : [],
				lines : [],
				columns : [],
			};
			data.sheets.push(s);
			makeSheet(s);
		}
		return null;
	}

	function getConvFunction( old : ColumnType, t : ColumnType ) {
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
			conv = Std.int;
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
			var map = [];
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
		default:
			return null;
		}
		return { f : conv };
	}

	function updateColumn( sheet : Sheet, old : Column, c : Column ) {
		if( old.name != c.name ) {

			for( c2 in sheet.columns )
				if( c2.name == c.name )
					return "Column name already used";
			if( c.name == "index" && sheet.props.hasIndex )
				return "Sheet already has an index";
			if( c.name == "group" && sheet.props.hasGroup )
				return "Sheet already has a group";

			for( o in getSheetLines(sheet) ) {
				var v = Reflect.field(o, old.name);
				Reflect.deleteField(o, old.name);
				if( v != null )
					Reflect.setField(o, c.name, v);
			}

			function renameRec(sheet, col) {
				var s = getPseudoSheet(sheet, col);
				s.name = sheet.name + "@" + c.name;
				for( c in s.columns )
					if( c.type == TList )
						renameRec(s, c);
				makeSheet(s);
			}
			if( old.type == TList ) renameRec(sheet, old);
			old.name = c.name;
		}

		if( !old.type.equals(c.type) ) {
			var conv = getConvFunction(old.type, c.type);
			if( conv == null )
				return "Cannot convert " + typeStr(old.type) + " to " + typeStr(c.type);
			var conv = conv.f;
			if( conv != null )
				for( o in getSheetLines(sheet) ) {
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
				for( o in getSheetLines(sheet) ) {
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
					for( o in getSheetLines(sheet) ) {
						var v = Reflect.field(o, c.name);
						switch( c.type ) {
						case TList:
							var v : Array<Dynamic> = v;
							if( v.length == 0 )
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

		makeSheet(sheet);
		return null;
	}

	function load(noError = false) {
		history = [];
		redo = [];
		try {
			data = cdb.Parser.parse(sys.io.File.getContent(prefs.curFile));
		} catch( e : Dynamic ) {
			if( !noError ) js.Lib.alert(e);
			prefs.curFile = null;
			prefs.curSheet = 0;
			data = {
				sheets : [],
				customTypes : [],
			};
		}
		try {
			var img = prefs.curFile.split(".");
			img.pop();
			imageBank = haxe.Json.parse(sys.io.File.getContent(img.join(".") + ".img"));
		} catch( e : Dynamic ) {
			imageBank = null;
		}
		curSavedData = quickSave();
		initContent();
	}

	function initContent() {
		smap = new Map();
		for( s in data.sheets )
			makeSheet(s);
		tmap = new Map();
		for( t in data.customTypes )
			tmap.set(t.name, t);
	}

	function sortById( a : Index, b : Index ) {
		return if( a.disp > b.disp ) 1 else -1;
	}

	function makeSheet( s : Sheet ) {
		var sdat = {
			s : s,
			index : new Map(),
			all : [],
		};
		var cid = null;
		var lines = getSheetLines(s);
		for( c in s.columns )
			if( c.type == TId ) {
				for( l in lines ) {
					var v = Reflect.field(l, c.name);
					if( v != null && v != "" ) {
						var disp = v;
						if( s.props.displayColumn != null ) {
							disp = Reflect.field(l, s.props.displayColumn);
							if( disp == null || disp == "" ) disp = "#"+v;
						}
						var o = { id : v, disp:disp, obj : l };
						if( sdat.index.get(v) == null )
							sdat.index.set(v, o);
						sdat.all.push(o);
					}
				}
				sdat.all.sort(sortById);
				break;
			}
		this.smap.set(s.name, sdat);
	}

	function cleanImages() {
		if( imageBank == null )
			return;
		var used = new Map();
		for( s in data.sheets )
			for( c in s.columns ) {
				switch( c.type ) {
				case TImage:
					for( obj in getSheetLines(s) ) {
						var v = Reflect.field(obj, c.name);
						if( v != null ) used.set(v, true);
					}
				default:
				}
			}
		for( f in Reflect.fields(imageBank) )
			if( !used.get(f) )
				Reflect.deleteField(imageBank, f);
	}

	function savePrefs() {
		js.Browser.getLocalStorage().setItem("prefs", haxe.Serializer.run(prefs));
	}

	function objToString( sheet : Sheet, obj : Dynamic, esc = false ) {
		if( obj == null )
			return "null";
		var fl = [];
		for( c in sheet.columns ) {
			var v = Reflect.field(obj, c.name);
			if( v == null ) continue;
			fl.push(c.name + " : " + colToString(sheet, c, v, esc));
		}
		if( fl.length == 0 )
			return "{}";
		return "{ " + fl.join(", ") + " }";
	}

	function colToString( sheet : Sheet, c : Column, v : Dynamic, esc = false ) {
		if( v == null )
			return "null";
		switch( c.type ) {
		case TList:
			var a : Array<Dynamic> = v;
			if( a.length == 0 ) return "[]";
			var s = getPseudoSheet(sheet, c);
			return "[ " + [for( v in a ) objToString(s, v, esc)].join(", ") + " ]";
		default:
			return valToString(c.type, v, esc);
		}
	}

	function valToString( t : ColumnType, val : Dynamic, esc = false ) {
		if( val == null )
			return "null";
		return switch( t ) {
		case TInt, TFloat, TBool, TImage: Std.string(val);
		case TId, TRef(_), TLayer(_), TFile: esc ? '"'+val+'"' : val;
		case TString:
			var val : String = val;
			if( ~/^[A-Za-z0-9_]+$/g.match(val) && !esc )
				val;
			else
				'"' + val.split("\\").join("\\\\").split('"').join("\\\"") + '"';
		case TEnum(values):
			valToString(TString, values[val], esc);
		case TList:
			"????";
		case TCustom(t):
			typeValToString(tmap.get(t), val, esc);
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
		}
	}

	function typeValToString( t : CustomType, val : Array<Dynamic>, esc = false ) {
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

	function typeStr( t : ColumnType ) {
		return switch( t ) {
		case TRef(n), TCustom(n): n;
		default: Std.string(t).substr(1);
		}
	}

	function parseVal( t : ColumnType, val : String ) : Dynamic {
		switch( t ) {
		case TInt:
			if( ~/^-?[0-9]+$/.match(val) )
				return Std.parseInt(val);
		case TString:
			if( val.charCodeAt(0) == '"'.code ) {
				var esc = false;
				var p = 0;
				while( true ) {
					if( p == val.length ) throw "Unclosed \"";
					var c = val.charCodeAt(p++);
					if( esc )
						esc = false;
					else switch( c ) {
						case '"'.code:
							if( p < val.length ) throw "Invalid content after string '" + val + "'";
							break;
						case '/'.code:
							esc = true;
					}
				}
			} else if( ~/^[A-Za-z0-9_]+$/.match(val) )
				return val;
			throw "String requires quotes '" + val + "'";
		case TBool:
			if( val == "true" ) return true;
			if( val == "false" ) return false;
		case TFloat:
			var f = Std.parseFloat(val);
			if( !Math.isNaN(f) )
				return f;
		case TCustom(t):
			return parseTypeVal(tmap.get(t), val);
		case TRef(t):
			var r = smap.get(t).index.get(val);
			if( r == null ) throw val + " is not a known " + t + " id";
			return r.id;
		case TColor:
			if( val.charAt(0) == "#" )
				val = "0x" + val.substr(1);
			if( ~/^-?[0-9]+$/.match(val) || ~/^0x[0-9A-Fa-f]+$/.match(val) )
				return Std.parseInt(val);
		default:
		}
		throw "'" + val + "' should be "+typeStr(t);
	}

	function parseTypeVal( t : CustomType, val : String ) : Dynamic {
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
							case '/'.code: esc = true;
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
				var vals = [i];
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
						var val = try parseVal(a.type, v) catch( e : String ) throw e + " for " + a.name;
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
			if( tmap.exists(tstr) )
				TCustom(tstr);
			else if( smap.exists(tstr) )
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

	function typeCasesToString( t : CustomType, prefix = "" ) {
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

	function parseTypeCases( def : String ) : Array<CustomTypeCase> {
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

	function makePairs < T: { name:String } > ( oldA : Array<T>, newA : Array<T> ) : Array<{ a : T, b : T }> {
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

	function mapType( callb ) {
		for( s in data.sheets )
			for( c in s.columns ) {
				var t = callb(c.type);
				if( t != c.type ) {
					c.type = t;
					c.typeStr = null;
				}
			}
		for( t in data.customTypes )
			for( c in t.cases )
				for( a in c.args ) {
					var t = callb(a.type);
					if( t != a.type ) {
						a.type = t;
						a.typeStr = null;
					}
				}
	}

	function changeLineOrder( sheet : Sheet, remap : Array<Int> ) {
		for( s in data.sheets )
			for( c in s.columns )
				switch( c.type ) {
				case TLayer(t) if( t == sheet.name ):
					for( obj in getSheetLines(s) ) {
						var ldat = Reflect.field(obj, c.name);
						if( ldat == null || ldat == "" ) continue;
						var d = haxe.crypto.Base64.decode(ldat);
						for( i in 0...d.length ) {
							var r = remap[d.get(i)];
							if( r < 0 ) r = 0; // removed
							d.set(i, r);
						}
						ldat = haxe.crypto.Base64.encode(d);
						Reflect.setField(obj, c.name, ldat);
					}
				default:
				}
	}

	function updateRefs( sheet : Sheet, refMap : Map < String, String > ) {

		function convertTypeRec( t : CustomType, o : Array<Dynamic> ) {
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
					convertTypeRec(tmap.get(name), v);
				default:
				}
			}
		}

		for( s in data.sheets )
			for( c in s.columns )
				switch( c.type ) {
				case TRef(n) if( n == sheet.name ):
					for( obj in getSheetLines(s) ) {
						var id = Reflect.field(obj, c.name);
						if( id == null ) continue;
						id = refMap.get(id);
						if( id == null ) continue;
						Reflect.setField(obj, c.name, id);
					}
				case TCustom(t):
					for( obj in getSheetLines(s) ) {
						var o = Reflect.field(obj, c.name);
						if( o == null ) continue;
						convertTypeRec(tmap.get(t), o);
					}
				default:
				}
	}

	function updateType( old : CustomType, t : CustomType ) {
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
						v[i+1] = convertTypeRec(tmap.get(tname), av);
				default:
				}
			}
			return v;
		}

		// apply convert
		for( s in data.sheets )
			for( c in s.columns )
				switch( c.type ) {
				case TCustom(tname):
					var t2 = tmap.get(tname);
					for( obj in getSheetLines(s) ) {
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
			for( t2 in data.customTypes )
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

}