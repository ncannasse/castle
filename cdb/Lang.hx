package cdb;
import cdb.Data;

enum LocField {
	LName( c : Column );
	LSub( c : Column, s : Sheet, e : Array<LocField> );
	LSingle( c : Column, e : LocField );
}

class Lang {

	var root : Data;

	public function new(root) {
		this.root = root;
	}

	public dynamic function onMissing( s : String ) {
		trace(s);
	}

	public function getSub( s : Sheet, c : Column ) {
		return getSheet(s.name + "@" + c.name);
	}

	function getSheet( name : String ) {
		for( s in root.sheets )
			if( s.name == name )
				return s;
		return null;
	}

	function makeLocField(c:Column, s:Sheet) {
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

	function makeSheetFields(s:Sheet) : Array<LocField> {
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

	public function apply( xml : String ) {
		var x = Xml.parse(xml).firstElement();
		var xsheets = new Map();
		for( e in x.elements() )
			xsheets.set(e.get("name"), e);
		for( s in root.sheets ) {
			if( s.props.hide ) continue;
			var x = xsheets.get(s.name);
			if( x == null ) continue;

			var path = [s.name];
			applySheet(path, s, makeSheetFields(s), s.lines, x);
		}
	}

	function applySheet( path : Array<String>, s : Sheet, fields : Array<LocField>, objects : Array<Dynamic>, x : Xml ) {
		var idField = null;
		for( c in s.columns )
			if( c.type == TId ) {
				idField = c.name;
				break;
			}

		if( idField == null ) {

			var byIndex = [];
			if( x != null )
				for( e in x.elements() ) {
					var m = new Map();
					for( e in e.elements() )
						m.set(e.nodeName, e);
					byIndex[Std.parseInt(e.nodeName)] = m;
				}

			for( i in 0...objects.length )
				for( f in fields ) {
					path.push("["+i+"]");
					applyRec(path, f, objects[i], byIndex[i]);
					path.pop();
				}

		} else {

			var byID = new Map();
			if( x != null )
				for( e in x.elements() ) {
					var m = new Map();
					for( e in e.elements() )
						m.set(e.nodeName, e);
					byID.set(e.nodeName, m);
				}

			for( o in objects )
				for( f in fields ) {
					var id = Reflect.field(o, idField);
					path.push(id);
					applyRec(path, f, o, byID.get(id));
					path.pop();
				}
		}
	}

	function applyRec( path : Array<String>, f : LocField, o : Dynamic, data : Map<String,Xml> ) {
		switch( f ) {
		case LName(c):
			var v = data == null ? null : data.get(c.name);
			if( v != null )
				Reflect.setField(o, c.name, new haxe.xml.Fast(v).innerHTML);
			else {
				var v = Reflect.field(o, c.name);
				if( v != null && v != "" ) {
					path.push(c.name);
					onMissing("Missing " + path.join("."));
					path.pop();
				}
			}
		case LSingle(c, f):
			var v = Reflect.field(o, c.name);
			if( v == null )
				return;
			path.push(c.name);
			applyRec(path, f, v, [for( e in data.keys() ) if( StringTools.startsWith(e, c.name+".") ) e.substr(c.name.length + 1) => data.get(e)]);
			path.pop();
		case LSub(c, s, fl):
			var v : Array<Dynamic> = Reflect.field(o, c.name);
			if( v == null )
				return;
			path.push(c.name);
			applySheet(path,s,fl,v, data == null ? null : data.get(c.name));
			path.pop();
		}
	}

	public function buildXML() {
		var buf = new StringBuf();
		buf.add("<cdb>\n");
		for( s in root.sheets ) {
			if( s.props.hide ) continue;
			var locFields = makeSheetFields(s);
			if( locFields.length == 0 ) continue;
			buf.add('\t<sheet name="${s.name}">\n');
			buf.add(buildSheetXml(s, "\t\t", s.lines, locFields));
			buf.add('\t</sheet>\n');
		}
		buf.add("</cdb>\n");
		return buf.toString();
	}

	function getLocText( tabs : String, o : Dynamic, f : LocField ) {
		switch( f ) {
		case LName(c):
			var v = Reflect.field(o, c.name);
			return { name : c.name, value : v == null ? v : StringTools.htmlEscape(v) };
		case LSingle(c, f):
			var v = getLocText(tabs, Reflect.field(o, c.name), f);
			return { name : c.name+"." + v.name, value : v.value };
		case LSub(c, ssub, fl):
			var v : Array<Dynamic> = Reflect.field(o, c.name);
			var content = buildSheetXml(ssub, tabs+"\t\t", v, fl);
			return { name : c.name, value : content };
		}
	}

	function buildSheetXml(s:Sheet, tabs, values : Array<Dynamic>, locFields:Array<LocField>) {
		var id = null;
		for( c in s.columns )
			if( c.type == TId ) {
				id = c;
				break;
			}

		var buf = new StringBuf();
		var index = 0;
		for( o in values ) {
			var id = id == null ? ""+(index++) : Reflect.field(o, id.name);
			if( id == null || id == "" ) continue;

			var locs = [for( f in locFields ) getLocText(tabs, o, f)];
			var hasLoc = false;
			for( l in locs )
				if( l.value != null && l.value != "" ) {
					hasLoc = true;
					break;
				}
			if( !hasLoc ) continue;
			buf.add('$tabs<$id>\n');
			for( l in locs )
				if( l.value != null && l.value != "" ) {
					if( l.value.indexOf("<") < 0 )
						buf.add('$tabs\t<${l.name}>${l.value}</${l.name}>\n');
					else {
						buf.add('$tabs\t<${l.name}>\n');
						buf.add('$tabs\t\t${StringTools.trim(l.value)}\n');
						buf.add('$tabs\t</${l.name}>\n');
					}
				}
			buf.add('$tabs</$id>\n');
		}
		return buf.toString();
	}

}