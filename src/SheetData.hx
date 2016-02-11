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
import cdb.Data;
using SheetData;

class SheetData {

	static var model : Model;

	static inline function getSheet(name:String) {
		return model.getSheet(name);
	}

	public static inline function isLevel( sheet : Sheet ) {
		return sheet.props.level != null;
	}

	public static inline function getSub( sheet : Sheet, c : Column ) {
		return getSheet(sheet.name + "@" + c.name);
	}

	public static function getParent( sheet : Sheet ) {
		if( !sheet.props.hide )
			return null;
		var parts = sheet.name.split("@");
		var colName = parts.pop();
		return { s : getSheet(parts.join("@")), c : colName };
	}

	public static function getLines( sheet : Sheet ) : Array<Dynamic> {
		var p = getParent(sheet);
		if( p == null ) return sheet.lines;

		if( p.s.isLevel() && p.c == "tileProps" ) {
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
		if( sheet.props.isProps ) {
			// properties
			for( obj in getLines(p.s) ) {
				var v : Dynamic = Reflect.field(obj, p.c);
				if( v != null )
					all.push(v);
			}
		} else {
			// lists
			for( obj in getLines(p.s) ) {
				var v : Array<Dynamic> = Reflect.field(obj, p.c);
				if( v != null )
					for( v in v )
						all.push(v);
			}
		}
		return all;
	}

	public static function getObjects( sheet : Sheet ) : Array<{ path : Array<Dynamic>, indexes : Array<Int> }> {
		var p = getParent(sheet);
		if( p == null )
			return [for( i in 0...sheet.lines.length ) { path : [sheet.lines[i]], indexes : [i] }];
		var all = [];
		for( obj in getObjects(p.s) ) {
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

	public static function newLine( sheet : Sheet, ?index : Int ) {
		var o = {
		};
		for( c in sheet.columns ) {
			var d = model.getDefault(c);
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
		return o;
	}

	public static function getPath( sheet : Sheet ) {
		return sheet.path == null ? sheet.name : sheet.path;
	}

	public static function hasColumn( s : Sheet, name : String, ?types : Array<ColumnType> ) {
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

	public static function moveLine( sheet : Sheet, index : Int, delta : Int ) : Null<Int> {
		if( delta < 0 && index > 0 ) {

			for( i in 0...sheet.separators.length )
				if( sheet.separators[i] == index ) {
					var i = i;
					while( i < sheet.separators.length - 1 && sheet.separators[i+1] == index )
						i++;
					sheet.separators[i]++;
					return index;
				}

			var l = sheet.lines[index];
			sheet.lines.splice(index, 1);
			sheet.lines.insert(index - 1, l);

			var arr = [for( i in 0...sheet.lines.length ) i];
			arr[index] = index - 1;
			arr[index - 1] = index;
			changeLineOrder(sheet, arr);

			return index - 1;
		} else if( delta > 0 && sheet != null && index < sheet.lines.length - 1 ) {


			for( i in 0...sheet.separators.length )
				if( sheet.separators[i] == index + 1 ) {
					sheet.separators[i]--;
					return index;
				}

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

	public static function deleteLine( sheet : Sheet, index : Int ) {

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

	public static function deleteColumn( sheet : Sheet, ?cname : String ) {
		for( c in sheet.columns )
			if( c.name == cname ) {
				sheet.columns.remove(c);
				for( o in getLines(sheet) )
					Reflect.deleteField(o, c.name);
				if( sheet.props.displayColumn == c.name ) {
					sheet.props.displayColumn = null;
					model.makeSheet(sheet);
				}
				if( sheet.props.displayIcon == c.name ) {
					sheet.props.displayIcon = null;
					model.makeSheet(sheet);
				}
				if( c.type == TList || c.type == TProperties )
					model.deleteSheet(sheet.getSub(c));
				return true;
			}
		return false;
	}

	public static function addColumn( sheet : Sheet, c : Column, ?index : Int ) {
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
		for( i in sheet.getLines() ) {
			var def = model.getDefault(c);
			if( def != null ) Reflect.setField(i, c.name, def);
		}
		if( c.type == TList || c.type == TProperties ) {
			// create an hidden sheet for the model
			var s : Sheet = {
				name : sheet.name + "@" + c.name,
				props : { hide : true },
				separators : [],
				lines : [],
				columns : [],
			};
			if( c.type == TProperties ) s.props.isProps = true;
			model.data.sheets.push(s);
			model.makeSheet(s);
		}
		return null;
	}

	public static function objToString( sheet : Sheet, obj : Dynamic, esc = false ) {
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

	public static function colToString( sheet : Sheet, c : Column, v : Dynamic, esc = false ) {
		if( v == null )
			return "null";
		switch( c.type ) {
		case TList:
			var a : Array<Dynamic> = v;
			if( a.length == 0 ) return "[]";
			var s = getSub(sheet, c);
			return "[ " + [for( v in a ) objToString(s, v, esc)].join(", ") + " ]";
		default:
			return model.valToString(c.type, v, esc);
		}
	}

	static function changeLineOrder( sheet : Sheet, remap : Array<Int> ) {
		for( s in model.data.sheets )
			for( c in s.columns )
				switch( c.type ) {
				case TLayer(t) if( t == sheet.name ):
					for( obj in getLines(s) ) {
						var ldat : cdb.Types.Layer<Int> = Reflect.field(obj, c.name);
						if( ldat == null || ldat == cast "" ) continue;
						var d = ldat.decode([for( i in 0...256 ) i]);
						for( i in 0...d.length ) {
							var r = remap[d[i]];
							if( r < 0 ) r = 0; // removed
							d[i] = r;
						}
						ldat = cdb.Types.Layer.encode(d, model.data.compress);
						Reflect.setField(obj, c.name, ldat);
					}
				default:
				}
	}

	public static function getReferences( sheet : Sheet, index : Int ) {
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

		var results = [];
		for( s in model.data.sheets ) {
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

	public static function updateValue( sheet : Sheet, c : Column, index : Int, old : Dynamic ) {
		switch( c.type ) {
		case TId:
			model.makeSheet(sheet);
		case TInt if( sheet.isLevel() && (c.name == "width" || c.name == "height") ):
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
				return { file : v.file, size : v.size, stride : v.stride, data : cdb.Types.TileLayerData.encode(ndat, model.data.compress) };
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
					v = cdb.Types.Layer.encode(ndat, model.data.compress);
					Reflect.setField(obj, c.name, v);
				case TList:
					var s = sheet.getSub(c);
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
				var s = @:privateAccess model.smap.get(sheet.name);
				for( cid in sheet.columns )
					if( cid.type == TId ) {
						var id = Reflect.field(obj, cid.name);
						if( id != null ) {
							var disp = Reflect.field(obj, c.name);
							if( disp == null ) disp = "#" + id;
							s.index.get(id).disp = disp;
						}
					}
			}
			if( sheet.props.displayIcon == c.name ) {
				var obj = sheet.lines[index];
				var s = @:privateAccess model.smap.get(sheet.name);
				for( cid in sheet.columns )
					if( cid.type == TId ) {
						var id = Reflect.field(obj, cid.name);
						if( id != null )
							s.index.get(id).ico = Reflect.field(obj, c.name);
					}
			}
		}
	}

}