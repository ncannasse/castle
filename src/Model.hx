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
	var smap : Map< String, { s : Data.Sheet, index : Map<String,Index> , all : Array<Index> } >;
	var tmap : Map< String, Data.CustomType >;
	var openedList : Map<String,Bool>;
	
	var curSavedData : String;
	var history : Array<String>;
	var redo : Array<String>;

	function new() {
		openedList = new Map();
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

	inline function getSheet( name : String ) {
		return smap.get(name).s;
	}
	
	inline function getPseudoSheet( sheet : Data.Sheet, c : Data.Column ) {
		return getSheet(sheet.name + "@" + c.name);
	}
	
	function getSheetLines( sheet : Data.Sheet ) : Array<Dynamic> {
		if( sheet.props.hide ) {
			var parts = sheet.name.split("@");
			var colName = parts.pop();
			var parent = getSheet(parts.join("@"));
			var all = [];
			for( obj in getSheetLines(parent) ) {
				var v : Array<Dynamic> = Reflect.field(obj, colName);
				if( v != null )
					for( v in v )
						all.push(v);
			}
			return all;
		}
		return sheet.lines;
	}
	
	function newLine( sheet : Data.Sheet, ?index : Int ) {
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
				if( s >= index ) sheet.separators[i] = s + 1;
			}
			sheet.lines.insert(index + 1, o);
		}
	}

	function getPath( sheet : Data.Sheet ) {
		return sheet.path == null ? sheet.name : sheet.path;
	}

	function getDefault( c : Data.Column ) : Dynamic {
		if( c.opt )
			return null;
		return switch( c.type ) {
		case TInt, TFloat, TEnum(_): 0;
		case TString, TId, TRef(_), TImage: "";
		case TBool: false;
		case TList: [];
		case TCustom(_): null;
		}
	}
	
	function save( history = true ) {
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
				if( c.typeStr == null ) c.typeStr = haxe.Serializer.run(c.type);
				c.type = null;
			}
		}
		for( t in data.customTypes )
			for( c in t.cases )
				for( a in c.args ) {
					save.push(a.type);
					if( a.typeStr == null ) a.typeStr = haxe.Serializer.run(a.type);
					a.type = null;
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

	function moveLine( sheet : Data.Sheet, index : Int, delta : Int ) : Null<Int> {
		if( delta < 0 && index > 0 ) {
			var l = sheet.lines[index];
			sheet.lines.splice(index, 1);
			sheet.lines.insert(index - 1, l);
			return index - 1;
		} else if( delta > 0 && sheet != null && index < sheet.lines.length-1 ) {
			var l = sheet.lines[index];
			sheet.lines.splice(index, 1);
			sheet.lines.insert(index + 1, l);
			return index + 1;
		}
		return null;
	}
	
	function deleteLine( sheet : Data.Sheet, index : Int ) {
		sheet.lines.splice(index, 1);
		var prev = -1, toRemove = null;
		for( i in 0...sheet.separators.length ) {
			var s = sheet.separators[i];
			if( s >= index ) {
				if( prev == s - 1 ) toRemove = prev;
				sheet.separators[i] = s - 1;
			} else
				prev = s;
		}
		// prevent duplicates
		if( toRemove != null )
			sheet.separators.remove(toRemove);
	}
	
	function deleteColumn( sheet : Data.Sheet, ?cname : String ) {
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
					data.sheets.remove(getPseudoSheet(sheet, c));
				return true;
			}
		return false;
	}
	
	function addColumn( sheet : Data.Sheet, c : Data.Column ) {
		// create
		for( c2 in sheet.columns )
			if( c2.name == c.name )
				return "Column already exists";
			else if( c2.type == TId && c.type == TId )
				return "Only one ID allowed";
		sheet.columns.push(c);
		for( i in getSheetLines(sheet) ) {
			var def = getDefault(c);
			if( def != null ) Reflect.setField(i, c.name, def);
		}
		if( c.type == TList ) {
			// create an hidden sheet for the model
			var s : Data.Sheet = {
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
	
	function updateColumn( sheet : Data.Sheet, old : Data.Column, c : Data.Column ) {
		if( old.name != c.name ) {
			for( o in getSheetLines(sheet) ) {
				var v = Reflect.field(o, old.name);
				Reflect.deleteField(o, old.name);
				if( v != null )
					Reflect.setField(o, c.name, v);
			}
			if( old.type == TList ) {
				var s = getPseudoSheet(sheet, old);
				s.name = sheet.name + "@" + c.name;
			}
			old.name = c.name;
		}
		
		if( !old.type.equals(c.type) ) {
			var conv : Dynamic -> Dynamic = null;
			switch( [old.type, c.type] ) {
			case [TInt, TFloat]:
				// nothing
			case [TId | TRef(_), TString]:
				// nothing
			case [TString, (TId | TRef(_))]:
				var r_invalid = ~/[^A-Za-z0-9_]/g;
				conv = function(r:String) return r_invalid.replace(r, "_");
			case [TBool, (TInt | TFloat)]:
				conv = function(b) return b ? 1 : 0;
			case [TString, TInt]:
				conv = Std.parseInt;
			case [TString, TFloat]:
				conv = Std.parseFloat;
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
				if( values1.length != values2.length ) {
					var map = [];
					for( v in values1 ) {
						var pos = Lambda.indexOf(values2, v);
						if( pos < 0 ) map.push(null) else map.push(pos);
					}
					conv = function(i) return map[i];
				} else
					conv = null; // assume rename
			case [TInt, TEnum(values)]:
				conv = function(i) return if( i < 0 || i >= values.length ) null else i;
			case [TEnum(values), TInt]:
				// nothing
			default:
				return "Cannot convert " + old.type.getName().substr(1) + " to " + c.type.getName().substr(1);
			}
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
						if( v == def )
							Reflect.deleteField(o, c.name);
					}
				}
			}
			old.opt = c.opt;
		}
		makeSheet(sheet);
		return null;
	}
	
	function load(noError = false) {
		history = [];
		redo = [];
		try {
			data = haxe.Json.parse(sys.io.File.getContent(prefs.curFile));
			for( s in data.sheets )
				for( c in s.columns )
					c.type = haxe.Unserializer.run(c.typeStr);
			for( t in data.customTypes )
				for( c in t.cases )
					for( a in c.args )
						a.type = haxe.Unserializer.run(a.typeStr);
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
	
	function makeSheet( s : Data.Sheet ) {
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
	
	
}