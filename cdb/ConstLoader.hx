package cdb;

import cdb.Data;

@:allow(cdb.Macros)
class ConstLoader {

	var root : cdb.Data;
	var resolveRef : String -> String -> Dynamic;
	var safeLoad : Bool;
	var sheets : Map<String, Data.SheetData>;

	public function new( root : cdb.Data, resolveRef : String -> String -> Dynamic, safeLoad : Bool ) {
		this.root = root;
		this.resolveRef = resolveRef;
		this.safeLoad = safeLoad;
		sheets = new Map();
		for( s in root.sheets )
			sheets.set(s.name, s);
	}

	inline function getSub( sheetName : String, col : Data.Column ) : Data.SheetData {
		var sub = col.structRef != null ? col.structRef : sheetName + "@" + col.name;
		return sheets.get(sub);
	}

	static inline function hasTextArgs( str : String ) : Bool {
		return str != null && str.indexOf("::") >= 0 && ~/::(.+?)::/.match(str);
	}

	static function getPolyVal( polySub : Data.SheetData, colVal : Dynamic ) : { col : Data.Column, val : Dynamic } {
		for( pc in polySub.columns ) {
			var pv = Reflect.field(colVal, pc.name);
			if( pv != null )
				return { col : pc, val : pv };
		}
		return null;
	}

	function load( col : Data.Column, raw : Dynamic, sheetName : String ) : Dynamic {
		if( raw == null )
			return null;
		switch( col.type ) {
		case TInt, TColor, TFloat, TBool:
			return raw;
		case TImage, TFile, TTilePos, TTileLayer, TDynamic:
			return raw;
		case TCurve:
			return new cdb.Types.Curve(raw);
		case TGradient:
			return new cdb.Types.Gradient(raw);
		case TString:
			if( hasTextArgs(raw) ) {
				var str : String = raw;
				return function(vars) return cdb.Macros.formatText(str, vars);
			}
			return raw;
		case TRef(table):
			return resolveRef(table, Std.string(raw));
		case TProperties:
			return raw;
		case TPolymorph:
			var polySub = getSub(sheetName, col);
			var pval = getPolyVal(polySub, raw);
			if( pval == null )
				return null;
			return load(pval.col, pval.val, polySub.name);
		case TList:
			return loadList(col, raw, sheetName);
		default:
			return raw;
		}
	}

	function loadList( col : Data.Column, raw : Dynamic, sheetName : String ) : Dynamic {
		var sub = getSub(sheetName, col);
		var subCols = [for( c in sub.columns ) if( c.kind != Hidden ) c];
		var arr : Array<Dynamic> = raw;

		var idCol = null;
		for( c in subCols ) if( c.type == TId ) { idCol = c; break; }

		if( subCols.length == 2 && idCol != null ) {
			var valCol = subCols[0] == idCol ? subCols[1] : subCols[0];
			var obj : Dynamic = {};
			var keys : Array<String> = [];
			for( row in arr ) {
				var sid : String = Reflect.field(row, idCol.name);
				if( sid == null || sid == "" ) continue;
				var v = load(valCol, Reflect.field(row, valCol.name), sub.name);
				Reflect.setField(obj, sid, v);
				keys.push(sid);
			}
			// iterator over values by key order
			var idName = idCol.name;
			var valName = valCol.name;
			Reflect.setField(obj, "iterator", function() {
				return [for( k in keys ) {
					var e : Dynamic = {};
					Reflect.setField(e, idName, k);
					Reflect.setField(e, valName, Reflect.field(obj, k));
					e;
				}].iterator();
			});
			return obj;
		} else if( subCols.length == 1 ) {
			var vcol = subCols[0];
			var vname = vcol.name;
			if( vcol.type == TPolymorph ) {
				// list of polymorphs of (possibly) identical type -> flatten to the variant value
				var polySub = getSub(sub.name, vcol);
				var out : Array<Dynamic> = [];
				for( row in arr ) {
					var cv = Reflect.field(row, vname);
					if( cv == null ) { out.push(null); continue; }
					var pval = getPolyVal(polySub, cv);
					out.push(pval == null ? null : load(pval.col, pval.val, polySub.name));
				}
				return out;
			}
			return [for( row in arr ) load(vcol, Reflect.field(row, vname), sub.name)];
		} else {
			// full sub-objects
			return arr;
		}
	}

	public function reloadConsts( target : Dynamic, sheetName : String, colPath : Array<String>, groupIds : Bool ) {
		var sheet = sheets.get(sheetName);
		if( sheet == null ) return;
		var idCol = null;
		for( c in sheet.columns ) if( c.type == TId ) { idCol = c; break; }
		if( idCol == null ) return;

		var colName = colPath[colPath.length - 1];
		// the built column lives on the sheet reached by walking colPath[0..n-1]
		var colSheet = sheet;
		for( i in 0...colPath.length - 1 )
			colSheet = getSub(colSheet.name, findCol(colSheet, colPath[i]));
		var buildCol = findCol(colSheet, colName);
		if( buildCol == null ) return;

		inline function loadLine( line : Dynamic ) : { id : String, value : Dynamic } {
			var id : String = Reflect.field(line, idCol.name);
			if( id == null || id == "" ) return null;
			var pobj : Dynamic = line;
			for( f in colPath ) {
				pobj = Reflect.field(pobj, f);
				if( pobj == null ) break;
			}
			if( pobj == null ) return null;
			var value = safeLoad ? safeLoadValue(buildCol, pobj, colSheet.name, sheetName, id) : load(buildCol, pobj, colSheet.name);
			return { id : id, value : value };
		}

		if( !groupIds ) {
			for( line in sheet.lines ) {
				var r = loadLine(line);
				if( r != null ) Reflect.setField(target, r.id, r.value);
			}
			return;
		}

		// grouped: one object per separator, assigned to target.<title>
		// (mirrors Macros.buildConsts grouped mode: every separator is a group)
		var seps = sheet.separators;
		if( seps == null ) return;
		var i = 0;
		for( sepi in 0...seps.length ) {
			var sep = seps[sepi];
			var nextSep = sepi < seps.length - 1 ? seps[sepi + 1] : null;
			var gobj : Dynamic = {};
			while( i < sheet.lines.length ) {
				if( nextSep != null && nextSep.index == i ) break;
				var r = loadLine(sheet.lines[i]);
				i++;
				if( r != null ) Reflect.setField(gobj, r.id, r.value);
			}
			Reflect.setField(target, sep.title, gobj);
		}
	}

	function safeLoadValue( col : Data.Column, raw : Dynamic, sheetName : String, path : String, id : String ) : Dynamic {
		try {
			return load(col, raw, sheetName);
		} catch( e : Dynamic ) {
			trace('Failed to load "$path.$id"');
			throw e;
		}
	}

	static function findCol( sheet : Data.SheetData, name : String ) : Data.Column {
		for( c in sheet.columns )
			if( c.name == name )
				return c;
		return null;
	}
}
