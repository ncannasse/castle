package cdb;
import cdb.Data;

enum LocField {
	LName( c : Column );
	LSub( c : Column, s : SheetData, e : Array<LocField> );
	LSingle( c : Column, e : LocField );
}

typedef LangAttributes = haxe.DynamicAccess<String>;

typedef LangDiff = Map<String,Array<{}>>;

class LangXml {
	public var nodeName : String;
	public var _elements : Array<LangXml>;
	public var _html : String;
	public function new() { }
	public inline function unescape() { if( _html == null ) throw "assert"; return _html; }
	public inline function elements() return _elements;
}

class Ref {
	public var e : LangXml;
	public var ref : Null<LangXml>;
	public function new(e) {
		this.e = e;
	}
}

class Lang {

	public static var IGNORE_EXPORT_FIELD = "__ignoreLoc__";

	public static var LANG_CONFIG : haxe.DynamicAccess<LangAttributes> = null;

	var root : Data;
	var dataSheets : Map<String,{ sheet : SheetData, idField : String, fields : Array<LocField>, refs : Map<String,Map<String,Ref>> }>;
	var skipMissing : Bool;
	var currentLineData : Dynamic;
	public var missingSetLocKey : Bool;

	public function new(root) {
		this.root = root;
		dataSheets = new Map();
	}

	public dynamic function onMissing( s : String ) {
		trace(s);
	}

	public function getSub( s : SheetData, c : Column ) {
		return getSheet(s.name + "@" + c.name);
	}

	function getSheet( name : String ) {
		for( s in root.sheets )
			if( s.name == name )
				return s;
		return null;
	}

	function makeLocField(c:Column, s:SheetData) {
		switch( c.type ) {
		case TString if( c.kind == Localizable ):
			return LName(c);
		case TList, TProperties:
			var ssub = getSub(s,c);
			var fl = makeSheetFields(ssub);
			if( fl.length == 0 )
				return null;
			return LSub(c, ssub, fl);
		default:
			return null;
		}
	}

	function makeSheetFields(s:SheetData) : Array<LocField> {
		var fields = [];
		for( c in s.columns ) {
			var f = makeLocField(c, s);
			if( f != null )
				switch( f ) {
				case LSub(c, _, fl) if( c.type == TProperties ):
					for( f in fl )
						fields.push(LSingle(c, f));
				default:
					fields.push(f);
				}
		}
		return fields;
	}

	static var NODES : Map<String,String>;
	static var r_spaces = ~/^[ \t\r\n]+$/;
	static function toLangXml( xml : Xml ) : LangXml {
		var l = new LangXml();
		var name = xml.nodeName;
		l.nodeName = NODES.get(name);
		if( l.nodeName == null ) {
			l.nodeName = name;
			NODES.set(name, name);
		}
		var hasText = false;
		for( e in xml )
			if( e.nodeType == PCData && !r_spaces.match(e.nodeValue) ) {
				hasText = true;
				break;
			}
		if( hasText ) {
			var html = #if (haxe_ver < 4) new haxe.xml.Fast #else new haxe.xml.Access #end(xml).innerHTML;
			html = ~/<br\/>/gi.replace(html,"\n");
			l._html = StringTools.htmlUnescape(html);
		} else {
			l._elements = [];
			for( e in xml.elements() )
				l._elements.push(toLangXml(e));
		}
		return l;
	}

	public function apply( xml : String, ?reference : String ) : LangDiff {
		var x = Xml.parse(xml).firstElement();
		var ref = reference == null ? null : Xml.parse(reference).firstElement();
		var xsheets = new Map();
		NODES = new Map();
		for( e in x.elements() )
			xsheets.set(e.get("name"), new Ref(toLangXml(e)));
		if( ref != null )
			for( e in ref.elements() ) {
				var s = xsheets.get(e.get("name"));
				if( s != null ) s.ref = toLangXml(e);
			}
		NODES = null;
	 	var out = new Map();
		for( s in root.sheets ) {
			if( s.props.hide ) continue;
			var x = xsheets.get(s.name);
			if( s.props.dataFiles != null ) {
				var fields = makeSheetFields(s);
				if( fields.length > 0 ) {
					var idField = null;
					for( c in s.columns )
						if( c.type == TId ) {
							idField = c.name;
							break;
						}
					if( idField == null )
						continue; // sheet with no id not supported - should not have loc either
					if( x == null ) {
						onMissing("Missing sheet " + s.name);
						continue;
					}
					dataSheets.set(s.name, { sheet : s, idField : idField, fields : fields, refs : makeIdMap(x) });
				}
				continue;
			}
			if( x == null ) {
				if( s.lines.length > 0 && makeSheetFields(s).length > 0 )
					onMissing("Missing sheet " + s.name);
				continue;
			}
			var path = [s.name];
			var outLines = [];
			applySheet(path, s, makeSheetFields(s), s.lines, x, outLines);
			if( out.exists(s.name) )
				throw "assert";
			out.set(s.name, outLines);
		}
		return out;
	}

	public function delete( l : LangDiff ) {
		for( s in root.sheets ) {
			var sdel = l.get(s.name);
			if( sdel == null ) continue;
			deleteSheet(s, makeSheetFields(s), sdel, s.lines);
		}
	}

	#if hide
	public function applyPrefab( p : hrt.prefab.Prefab ) {
		var t = p.getCdbType();
		if( t != null ) {
			var data = dataSheets.get(t);
			if( data != null ) {
				var o = p.props;
				var id = Reflect.field(o, data.idField);
				var path = [data.sheet.name, id];
				var ref = data.refs.get(id);
				var outSub = {};
				for( f in data.fields )
					applyRec(path, f, o, ref, outSub);
			}
		}
		for( x in p )
			applyPrefab(x);
	}
	#end

	function deleteSheet( s : SheetData, loc : Array<LocField>, del : Array<{}>, lines : Array<Dynamic> ) {
		var inf = getSheetHelpers(s);
		if( inf.id == null ) {
			for( i in 0...lines.length )
				if( del[i] != null && lines[i] != null )
					deleteObj(loc, del[i], lines[i]);
		} else {
			var byID = new Map();
			for( d in del )
				byID.set((Reflect.field(d, inf.id) : String), d);
			for( o in lines ) {
				var id = Reflect.field(o, inf.id);
				if( id == null || !byID.exists(id) ) continue;
				deleteObj(loc, byID.get(id), o);
			}
		}
	}

	function deleteObj( loc : Array<LocField>, del : {}, obj : Dynamic ) {
		for( l in loc )
			switch( l ) {
			case LName(c):
				if( Reflect.hasField(del, c.name) )
					Reflect.setField(obj, c.name, "");
			case LSub(c, s, el):
				var ol : Array<Dynamic> = Reflect.field(obj, c.name);
				var dl : Array<{}> = Reflect.field(del, c.name);
				if( ol == null || dl == null ) continue;
				deleteSheet(s, el, dl, ol);
			case LSingle(c, e):
				var o = Reflect.field(obj, c.name);
				var d = Reflect.field(del, c.name);
				if( o == null || d == null ) continue;
				deleteObj([e], d, o);
			}
	}

	function applySheet( path : Array<String>, s : SheetData, fields : Array<LocField>, objects : Array<Dynamic>, x : Ref, out : Array<{}> ) {
		var inf = getSheetHelpers(s);

		if( inf.id == null ) {

			var byIndex = [];
			if( x != null ) {
				for( e in x.e.elements() ) {
					var m = new Map();
					for( e in e.elements() )
						m.set(e.nodeName, new Ref(e));
					var name = e.nodeName;
					if( StringTools.startsWith(name, "line") ) name = name.substr(4);
					byIndex[Std.parseInt(name)] = m;
				}
				if( x.ref != null )
					for( e in x.ref.elements() ) {
						var name = e.nodeName;
						if( StringTools.startsWith(name, "line") ) name = name.substr(4);
						var m = byIndex[Std.parseInt(name)];
						if( m != null )
							for( e in e.elements() ) {
								var r = m.get(e.nodeName);
								if( r != null ) r.ref = e;
							}
					}
			}

			for( i in 0...objects.length ) {
				var outSub = {};
				var o = objects[i];
				for( f in fields ) {
					path.push("[" + i + "]");
					applyRec(path, f, o, byIndex[i], outSub);
					path.pop();
				}
				if( Reflect.fields(outSub).length > 0 ) {
					// copy helpers to allow buildXML
					for( c in inf.helpers ) {
						var hid = Reflect.field(o, c.name);
						if( hid != null )
							Reflect.setField(outSub, c.name, hid);
					}
					out[i] = outSub;
				}
			}

		} else {

			var byID = makeIdMap(x);
			for( o in objects ) {
				var outSub = {};
				var id = Reflect.field(o, inf.id);
				if( id == null ) id = "null";
				path.push(id);
				for( f in fields )
					applyRec(path, f, o, byID.get(id), outSub);
				path.pop();
				if( Reflect.fields(outSub).length > 0 ) {
					Reflect.setField(outSub, inf.id, id);
					out.push(outSub);
				}
			}
		}
	}

	function makeIdMap( x : Ref ) {
		var byID = new Map();
		if( x == null )
			return byID;
		for( e in x.e.elements() ) {
			var m = new Map();
			for( e in e.elements() )
				m.set(e.nodeName, new Ref(e));
			byID.set(e.nodeName, m);
		}
		if( x.ref != null ) {
			for( e in x.ref.elements() ) {
				var m = byID.get(e.nodeName);
				if( m != null )
					for( e in e.elements() ) {
						var r = m.get(e.nodeName);
						if( r != null ) r.ref = e;
					}
			}
		}
		return byID;
	}

	function applyRec(path,f,o:Dynamic,data,out) {
		var prevMissing = skipMissing;
		if( Reflect.hasField(o, IGNORE_EXPORT_FIELD) )
			skipMissing = true;
		_applyRec(path,f,o,data,out);
		skipMissing = prevMissing;
	}

	function _applyRec( path : Array<String>, f : LocField, o : Dynamic, data : Map<String,Ref>, out : Dynamic ) {
		switch( f ) {
		case LName(c):
			var v = data == null ? null : data.get(c.name);
			if( v != null ) {
				var str = v.e.unescape();
				var ref = v.ref == null ? null : v.ref.unescape();
				var oname = Reflect.field(o,c.name);
				if( ref != null && (oname == null || StringTools.trim(ref) != StringTools.trim(oname)) ) {
					path.push(c.name);
					onMissing("Ignored since has changed "+path.join("."));
					path.pop();
				} else
					Reflect.setField(o, c.name, str);
			} else {
				var v = Reflect.field(o, c.name);
				if( v != null && v != "" ) {
					if( !skipMissing ) {
						path.push(c.name);
						Reflect.setField(out, c.name, v);
						onMissing("Missing " + path.join("."));
						path.pop();
					}
					if( missingSetLocKey ) {
						path.push(c.name);
						Reflect.setField(o, c.name, "#"+path.join("."));
						path.pop();
					}
				}
			}
		case LSingle(c, f):
			var v = Reflect.field(o, c.name);
			if( v == null )
				return;
			path.push(c.name);
			var outSub = {};
			applyRec(path, f, v, data == null ? null : [for( e in data.keys() ) if( StringTools.startsWith(e, c.name+".") ) e.substr(c.name.length + 1) => data.get(e)], outSub);
			path.pop();
			if( Reflect.fields(outSub).length > 0 )
				Reflect.setField(out, c.name, outSub);
		case LSub(c, s, fl):
			var v : Array<Dynamic> = Reflect.field(o, c.name);
			if( v == null )
				return;
			path.push(c.name);
			var outSub = [];
			applySheet(path, s, fl, v, data == null ? null : data.get(c.name), outSub);
			if( outSub.length > 0 )
				Reflect.setField(out, c.name, outSub);
			path.pop();
		}
	}

	public function buildXML( ?diff : LangDiff ) {
		var buf = new StringBuf();
		buf.add("<cdb>\n");
		for( s in root.sheets ) {
			if( s.props.hide ) continue;
			var locFields = makeSheetFields(s);
			if( locFields.length == 0 ) continue;
			var lines = getLines(s, diff);
			if( lines.length == 0 ) continue;
			buf.add('\t<sheet name="${s.name}">\n');
			buf.add(buildSheetXml(s, "\t\t", lines, s.linesData, locFields, diff));
			buf.add('\t</sheet>\n');
		}
		buf.add("</cdb>\n");
		return buf.toString();
	}

	function getLines( s : SheetData, diff : LangDiff ) : Array<Dynamic> {
		if( diff != null ) {
			var m = diff.get(s.name);
			if( m == null ) throw "Missing diff for " + s.name;
			return m;
		}
		return s.lines;
	}

	function getLocText( tabs : String, o : Dynamic, f : LocField, diff : LangDiff ) {
		switch( f ) {
		case LName(c):
			var v : String = Reflect.field(o, c.name);
			if( v != null )
				v = StringTools.htmlEscape(v).split("\n").join("<br/>").split("\r").join("");
			return { name : c.name, value : v };
		case LSingle(c, f):
			var v = getLocText(tabs, Reflect.field(o, c.name), f, diff);
			return { name : c.name+"." + v.name, value : v.value };
		case LSub(c, ssub, fl):
			var v : Array<Dynamic> = Reflect.field(o, c.name);
			var content = buildSheetXml(ssub, tabs+"\t\t", v == null ? [] : v, null, fl, diff);
			return { name : c.name, value : content };
		}
	}

	function getSheetHelpers(s:SheetData) {
		var id = null;
		var helpers = [];
		for( c in s.columns ) {
			switch( c.type ) {
			case TId if( id == null ):
				id = c;
			case TRef(sheet):
				var map = null;
				var s = getSheet(sheet);
				if( s.props.displayColumn != null ) {
					var idCol = null;
					for( c in s.columns )
						if( c.type == TId ) {
							idCol = c;
							break;
						}
					if( idCol != null ) {
						map = new Map();
						for( o in s.lines ) {
							var id : String = Reflect.field(o, idCol.name);
							var name : String = Reflect.field(o, s.props.displayColumn);
							if( id != null && id != "" && name != null && name != "" )
								map.set(id, name);
						}
					}
				}
				helpers.push({ label : c.name, name : c.name, map : map });
			case TString if( c.kind != Localizable ):
				helpers.push({ label : c.name, name : c.name, map : null });
			default:
			}
		}
		if( id != null ) helpers = [];
		return { id : id == null ? null : id.name, idOpt : id == null ? false : id.opt, helpers : helpers };
	}

	function resolveField(obj:Dynamic, path:String, linesData:Array<Dynamic>) {
		var o:Dynamic = obj;
		for( s in path.split(".") ) {
			if( s == "$root" ) {
				if( linesData == null )
					return null;
				var prefab : Dynamic = getObjParent(obj, linesData);
				if( prefab == null )
					return null;
				o = prefab;
			}
			else {
				if( !Reflect.hasField(o, s) )
					return null;
				o = Reflect.field(o, s);
			}
		}
		return o == null ? null : Std.string(o);
	}

	function buildSheetXml(s:SheetData, tabs, values : Array<Dynamic>, linesData:Array<Dynamic>, locFields:Array<LocField>, diff : Map<String,Array<{}>> ) {
		var inf = getSheetHelpers(s);
		var attr = LANG_CONFIG != null ? LANG_CONFIG[s.name] : null;
		if( attr != null )
			for( k => v in attr )
				inf.helpers.push({ label: k, name: v, map : null });
		var buf = new StringBuf();
		var index = 0;
		var prevData = currentLineData;
		for( i => o in values ) {

			if( Reflect.hasField(o, IGNORE_EXPORT_FIELD) ) continue;

			if( linesData != null )
				currentLineData = linesData[i];

			var id;
			if( inf.id == null )
				id = "line"+(index++);
			else {
				id = Reflect.field(o, inf.id);
				if( id == "" ) continue;
				if( id == null ) {
					if( !inf.idOpt ) continue;
					id = "null";
				}
			}
			var locs = [for( f in locFields ) { var l = getLocText(tabs, o, f, diff); { f : f, value : l.value, name : l.name }; }];
			var hasLoc = false;
			for( l in locs )
				if( l.value != null && l.value != "" ) {
					hasLoc = true;
					break;
				}
			if( !hasLoc ) continue;
			buf.add('$tabs<$id');
			for( c in inf.helpers ) {
				var hid = resolveField(o, c.name, s.linesData != null ? s.linesData[i] : null);
				if( hid != null ) {
					if( c.map != null ) {
						var v = c.map.get(hid);
						if( v != null ) hid = v;
					}
					var label = ~/\$/g.replace(c.label, "_");
					buf.add(' $label=\"${StringTools.htmlEscape(hid, true)}\"');
				}
			}
			buf.add('>\n');
			for( l in locs )
				if( l.value != null && l.value != "" ) {
					if( l.f.match(LName(_)) || l.value.indexOf("<") < 0 )
						buf.add('$tabs\t<${l.name}>${l.value}</${l.name}>\n');
					else {
						buf.add('$tabs\t<${l.name}>\n');
						buf.add('$tabs\t\t${StringTools.trim(l.value)}\n');
						buf.add('$tabs\t</${l.name}>\n');
					}
				}
			buf.add('$tabs</$id>\n');
		}
		currentLineData = prevData;
		return buf.toString();
	}

	static dynamic function getObjParent( obj : Dynamic, data : Dynamic ) return null;
}