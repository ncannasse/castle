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
import cdb.Data;

typedef SheetIndex = { id : String, disp : String, ico : cdb.Types.TilePos, obj : Dynamic }

class Sheet {

	static var _UID = 0;
	var uid = _UID++;

	public var base(default,null) : Database;
	var sheet : cdb.Data.SheetData;

	public var duplicateIds : Map<String, Bool>;
	public var index : Map<String,SheetIndex>;
	public var all : Array<SheetIndex>;
	public var name(get, never) : String;
	public var columns(get, never) : Array<cdb.Data.Column>;
	public var props(get, never) : cdb.Data.SheetProps;
	public var lines(get, never) : Array<Dynamic>;
	public var separators(get, never) : Array<Separator>;

	public var idCol : cdb.Data.Column;
	public var realSheet : Sheet;

	var path : String;
	public var parent : { sheet : Sheet, column : Int, line : Int };

	public function new(base, sheet, ?path, ?parent) {
		this.base = base;
		this.sheet = sheet;
		this.path = path;
		this.parent = parent;
		realSheet = this;
	}

	inline function get_lines() return sheet.lines;
	inline function get_props() return sheet.props;
	inline function get_columns() return sheet.columns;
	inline function get_name() return sheet.name;
	inline function get_separators() return sheet.separators;

	public inline function isLevel() {
		return sheet.props.level != null;
	}

	public inline function getSub( c : Column ) {
		return base.getSheet(name + "@" + c.name);
	}

	public function getParent() {
		if( !sheet.props.hide )
			return null;
		var parts = sheet.name.split("@");
		var colName = parts.pop();
		return { s : base.getSheet(parts.join("@")), c : colName };
	}

	public function getLines( scope = -1 ) : Array<Dynamic> {
		var p = getParent();
		if( p == null ) {
			if( sheet.lines == null && sheet.props.dataFiles != null )
				return [];
			if( scope == 0 ) {
				var cname = idCol == null ? "" : idCol.name;
				return [for( l in sheet.lines ) { id : Reflect.field(l,cname), obj : l }];
			}
			return sheet.lines;
		}

		if( p.s.isLevel() && p.c == "tileProps" ) {
			if( scope == 0 ) throw "TODO";
			// level tileprops
			var all = [];
			var sets = p.s.props.level.tileSets;
			for( f in Reflect.fields(sets) ) {
				var t : cdb.Data.TilesetProps = Reflect.field(sets, f);
				if( t.props == null ) continue;
				for( p in t.props )
					if( p != null )
						all.push(p);
			}
			return all;
		}

		var all = [];
		var parentScope = scope - 1;
		if( scope == 0 && idCol.scope != null ) parentScope = idCol.scope - 1;

		inline function makeId(obj:Dynamic,v:Dynamic) {
			var id = parentScope >= 0 ? obj.id : null;
			if( scope == 0 ) {
				var locId = idCol != null ? Reflect.field(v, idCol.name) : null;
				if( locId == null ) id = null else if( parentScope >= 0 ) { if( id != null ) id = id +":"+locId; } else id = locId;
			}
			return id;
		}

		if( sheet.props.isProps ) {
			// properties
			for( obj in p.s.getLines(parentScope) ) {
				var v : Dynamic = Reflect.field(parentScope >= 0 ? obj.obj : obj, p.c);
				if( v != null )
					all.push(scope >= 0 ? { id : makeId(obj,v), obj : v } : v);
			}
		} else {
			// lists
			for( obj in p.s.getLines(parentScope) ) {
				var arr : Array<Dynamic> = Reflect.field(parentScope >= 0 ? obj.obj : obj, p.c);
				if( arr != null )
					for( v in arr )
						all.push(scope >= 0 ? { id : makeId(obj,v), obj : v } : v);
			}
		}
		return all;
	}

	public function getObjects() : Array<{ path : Array<Dynamic>, indexes : Array<Int> }> {
		var p = getParent();
		if( p == null )
			return [for( i in 0...sheet.lines.length ) { path : [sheet.lines[i]], indexes : [i] }];
		var all = [];
		for( obj in p.s.getObjects() ) {
			var v : Dynamic = Reflect.field(obj.path[obj.path.length-1], p.c);
			if( v == null ) continue;
			if( Std.is(v, Array) ) {
				// list
				var v : Array<Dynamic> = v;
				for( i in 0...v.length ) {
					var sobj = v[i];
					var p = obj.path.copy();
					var idx = obj.indexes.copy();
					p.push(sobj);
					idx.push(i);
					all.push({ path : p, indexes : idx });
				}
			} else {
				// props
				var p = obj.path.copy();
				var idx = obj.indexes.copy();
				p.push(v);
				idx.push(-1);
				all.push({ path : p, indexes : idx });
			}
		}
		return all;
	}

	public function newLine( ?index : Int ) {
		var o = {
		};
		for( c in sheet.columns ) {
			var d = base.getDefault(c, this);
			if( d != null )
				Reflect.setField(o, c.name, d);
		}
		if( index == null )
			sheet.lines.push(o);
		else {
			for( s in sheet.separators ) {
				if( s.index > index ) s.index++;
			}
			sheet.lines.insert(index + 1, o);
			changeLineOrder([for( i in 0...sheet.lines.length ) i <= index ? i : i + 1]);
		}
		return o;
	}

	public function getPath() {
		return path == null ? sheet.name : path;
	}

	public function hasColumn( name : String, ?types : Array<ColumnType> ) {
		for( c in columns )
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

	public function moveLine( index : Int, delta : Int ) : Null<Int> {
		if( delta < 0 ) {

			for( i in 0...sheet.separators.length ) {
				var sep = sheet.separators[sheet.separators.length - 1 - i];
				if( sep.index == index ) {
					sep.index++;
					return index;
				}
			}

			if( index <= 0 )
				return null;

			var l = sheet.lines[index];
			sheet.lines.splice(index, 1);
			sheet.lines.insert(index - 1, l);

			var arr = [for( i in 0...sheet.lines.length ) i];
			arr[index] = index - 1;
			arr[index - 1] = index;
			changeLineOrder(arr);

			return index - 1;
		} else if( delta > 0 ) {


			for( sep in sheet.separators )
				if( sep.index == index + 1 ) {
					sep.index--;
					return index;
				}

			if( index < sheet.lines.length - 1 ) {
				var l = sheet.lines[index];
				sheet.lines.splice(index, 1);
				sheet.lines.insert(index + 1, l);

				var arr = [for( i in 0...sheet.lines.length ) i];
				arr[index] = index + 1;
				arr[index + 1] = index;
				changeLineOrder(arr);

				return index + 1;
			}
		}
		return null;
	}

	public function deleteLine( index : Int ) {

		var arr = [for( i in 0...sheet.lines.length ) if( i < index ) i else i - 1];
		arr[index] = -1;
		changeLineOrder(arr);

		sheet.lines.splice(index, 1);

		for( i in 0...sheet.separators.length ) {
			var s = sheet.separators[i];
			if( s.index > index ) s.index--;
		}
	}

	public function deleteColumn( cname : String ) {
		for( c in sheet.columns )
			if( c.name == cname ) {
				sheet.columns.remove(c);
				for( o in getLines() )
					Reflect.deleteField(o, c.name);
				if( sheet.props.displayColumn == c.name ) {
					sheet.props.displayColumn = null;
					sync();
				}
				if( sheet.props.displayIcon == c.name ) {
					sheet.props.displayIcon = null;
					sync();
				}
				if( c.type == TList || c.type == TProperties )
					base.deleteSheet(getSub(c));
				return true;
			}
		return false;
	}

	public function addColumn( c : Column, ?index : Int ) {
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
		if( c.type == TList || c.type == TProperties ) {
			// create an hidden sheet for the model
			base.createSubSheet(this, c);
		}
		for( i in getLines() ) {
			var def = base.getDefault(c, this);
			if( def != null ) Reflect.setField(i, c.name, def);
		}
		return null;
	}

	public function getDefaults() {
		var props = {};
		for( c in columns ) {
			var d = base.getDefault(c, this);
			if( d != null )
				Reflect.setField(props, c.name, d);
		}
		return props;
	}

	public function objToString( obj : Dynamic, esc = false ) {
		if( obj == null )
			return "null";
		var fl = [];
		for( c in sheet.columns ) {
			var v = Reflect.field(obj, c.name);
			if( v == null ) continue;
			fl.push(c.name + " : " + colToString(c, v, esc));
		}
		if( fl.length == 0 )
			return "{}";
		return "{ " + fl.join(", ") + " }";
	}

	public function colToString( c : Column, v : Dynamic, esc = false ) {
		if( v == null )
			return "null";
		switch( c.type ) {
		case TList:
			var a : Array<Dynamic> = v;
			if( a.length == 0 ) return "[]";
			var s = getSub(c);
			return "[ " + [for( v in a ) s.objToString(v, esc)].join(", ") + " ]";
		default:
			return base.valToString(c.type, v, esc);
		}
	}

	function changeLineOrder( remap : Array<Int> ) {
		for( s in base.sheets )
			for( c in s.columns )
				switch( c.type ) {
				case TLayer(t) if( t == sheet.name ):
					for( obj in s.getLines() ) {
						var ldat : cdb.Types.Layer<Int> = Reflect.field(obj, c.name);
						if( ldat == null || ldat == cast "" ) continue;
						var d = ldat.decode([for( i in 0...256 ) i]);
						for( i in 0...d.length ) {
							var r = remap[d[i]];
							if( r < 0 ) r = 0; // removed
							d[i] = r;
						}
						ldat = cdb.Types.Layer.encode(d, base.compress);
						Reflect.setField(obj, c.name, ldat);
					}
				default:
				}
	}

	public function getReferences( index : Int ) {
		var id = null;
		for( c in sheet.columns ) {
			switch( c.type ) {
			case TId:
				id = Reflect.field(sheet.lines[index], c.name);
				break;
			default:
			}
		}
		if( id == "" || id == null )
			return null;
		return getReferencesFromId(id);
	}

	public function getReferencesFromId( id : String ) {
		var scopeObj = null;
		var depth = 0;
		var ourIdCol = idCol;
		if (ourIdCol == null) {
			for (c in columns) {
				if (c.type == TId) {
					ourIdCol = c;
					break;
				}
			}
		}

		if (ourIdCol != null && ourIdCol.scope != null && ourIdCol.scope >= 0) {
			var cur = this;
			for (i in 0...ourIdCol.scope-1) {
				cur = cur.parent.sheet;
			}
			var cur2 = cur;
			while(cur2 != null && cur2.parent != null){
				cur2 = cur2.parent.sheet;
				depth++;
			}
			depth--;
			scopeObj = cur.parent.sheet.getLines()[cur.parent.line];
		}

		var results = [];
		for( s in base.sheets ) {
			for( c in s.columns )
				switch( c.type ) {
				case TRef(sname) if( sname == sheet.name ):
					var sheets = [];
					var p = { s : s, c : c.name, id : null };
					while( true ) {
						for( c in p.s.columns )
							switch( c.type ) {
							case TId: p.id = c.name; break;
							default:
							}
						sheets.unshift(p);
						var p2 = p.s.getParent();
						if( p2 == null ) break;
						p = { s : p2.s, c : p2.c, id : null };
					}
					for( o in s.getObjects() ) {
						var obj = o.path[o.path.length - 1];
						if (scopeObj != null && o.path[depth] != scopeObj)
							continue;
						if( Reflect.field(obj, c.name) == id )
							results.push({ s : sheets, o : o });
					}
				case TCustom(tname):
					// todo : lookup in custom types
				default:
				}
		}
		return results;
	}

	public function updateValue( c : Column, index : Int, old : Dynamic ) {
		switch( c.type ) {
		case TId:
			sync();
		case TInt if( isLevel() && (c.name == "width" || c.name == "height") ):
			var obj = sheet.lines[index];
			var newW : Int = Reflect.field(obj, "width");
			var newH : Int = Reflect.field(obj, "height");
			var oldW = newW;
			var oldH = newH;
			if( c.name == "width" )
				oldW = old;
			else
				oldH = old;

			function remapTileLayer( v : cdb.Types.TileLayer ) {

				if( v == null ) return null;

				var odat = v.data.decode();
				var ndat = [];

				// object layer
				if( odat[0] == 0xFFFF )
					ndat = odat;
				else {
					var pos = 0;
					for( y in 0...newH ) {
						if( y >= oldH ) {
							for( x in 0...newW )
								ndat.push(0);
						} else if( newW <= oldW ) {
							for( x in 0...newW )
								ndat.push(odat[pos++]);
							pos += oldW - newW;
						} else {
							for( x in 0...oldW )
								ndat.push(odat[pos++]);
							for( x in oldW...newW )
								ndat.push(0);
						}
					}
				}
				return { file : v.file, size : v.size, stride : v.stride, data : cdb.Types.TileLayerData.encode(ndat, base.compress) };
			}

			for( c in sheet.columns ) {
				var v : Dynamic = Reflect.field(obj, c.name);
				if( v == null ) continue;
				switch( c.type ) {
				case TLayer(_):
					var v : cdb.Types.Layer<Int> = v;
					var odat = v.decode([for( i in 0...256 ) i]);
					var ndat = [];
					for( y in 0...newH )
						for( x in 0...newW ) {
							var k = y < oldH && x < oldW ? odat[x + y * oldW] : 0;
							ndat.push(k);
						}
					v = cdb.Types.Layer.encode(ndat, base.compress);
					Reflect.setField(obj, c.name, v);
				case TList:
					var s = getSub(c);
					if( s.hasColumn("x", [TInt,TFloat]) && s.hasColumn("y", [TInt,TFloat]) ) {
						var elts : Array<{ x : Float, y : Float }> = Reflect.field(obj, c.name);
						for( e in elts.copy() )
							if( e.x >= newW || e.y >= newH )
								elts.remove(e);
					} else if( s.hasColumn("data", [TTileLayer]) ) {
						var a : Array<{ data : cdb.Types.TileLayer }> = v;
						for( o in a )
							o.data = remapTileLayer(o.data);
					}
				case TTileLayer:
					Reflect.setField(obj, c.name, remapTileLayer(v));
				default:
				}
			}
		default:
			if( sheet.props.displayColumn == c.name ) {
				var obj = sheet.lines[index];
				for( cid in sheet.columns )
					if( cid.type == TId ) {
						var id = Reflect.field(obj, cid.name);
						if( id != null ) {
							var disp = Reflect.field(obj, c.name);
							if( disp == null ) disp = "#" + id;
							this.index.get(id).disp = disp;
						}
					}
			}
			if( sheet.props.displayIcon == c.name ) {
				var obj = sheet.lines[index];
				for( cid in sheet.columns )
					if( cid.type == TId ) {
						var id = Reflect.field(obj, cid.name);
						if( id != null && id != "" )
							this.index.get(id).ico = Reflect.field(obj, c.name);
					}
			}
		}
	}

	function sortById( a : SheetIndex, b : SheetIndex ) {
		return if( a.disp > b.disp ) 1 else -1;
	}

	public function rename( name : String ) {
		@:privateAccess base.smap.remove(this.name);
		sheet.name = name;
		@:privateAccess base.smap.set(name, this);
	}

	public function sync() {
		if( parent != null )
			throw "assert";
		index = new Map();
		duplicateIds = new Map();
		all = [];
		idCol = null;
		for( c in columns )
			if( c.type == TId ) {
				var isLocal = c.scope != null;
				idCol = c;
				if( lines == null && sheet.props.dataFiles != null ) continue;
				for( l in getLines(c.scope) ) {
					var obj = isLocal ? l.obj : l;
					var v = Reflect.field(obj, c.name);
					if( v == null || v == "" ) continue;
					var disp = v;
					if( isLocal ) {
						if( l.id == null || l.id == "" ) continue;
						v = l.id+":"+v;
					}
					var ico = null;
					if( props.displayColumn != null ) {
						disp = Reflect.field(obj, props.displayColumn);
						if( disp == null || disp == "" ) disp = "#"+v;
					}
					if( props.displayIcon != null )
						ico = Reflect.field(obj, props.displayIcon);
					var o = { id : v, disp:disp, ico:ico, obj : obj };
					if( index.get(v) == null )
						index.set(v, o);
					else
						duplicateIds.set(v, true);
					all.push(o);
				}
				all.sort(sortById);
				break;
			}
		@:privateAccess base.smap.set(name, this);
	}

}