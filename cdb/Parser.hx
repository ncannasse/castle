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

class Parser {

	public static function saveType( t : Data.ColumnType ) : String {
		return switch( t ) {
		case TRef(_), TCustom(_), TLayer(_):
			Type.enumIndex(t) + ":" + Type.enumParameters(t)[0];
		case TEnum(values), TFlags(values):
			Type.enumIndex(t) + ":" + values.join(",");
		case TId, TString, TList, TInt, TImage, TFloat, TBool, TColor, TFile, TTilePos, TTileLayer, TDynamic, TProperties:
			Std.string(Type.enumIndex(t));
		};
	}

	public static function getType( str : String ) : Data.ColumnType {
		return switch( Std.parseInt(str) ) {
		case 0: TId;
		case 1: TString;
		case 2: TBool;
		case 3: TInt;
		case 4: TFloat;
		case 5: TEnum(str.substr(str.indexOf(":") + 1).split(","));
		case 6: TRef(str.substr(str.indexOf(":") + 1));
		case 7: TImage;
		case 8: TList;
		case 9: TCustom(str.substr(str.indexOf(":") + 1));
		case 10: TFlags(str.substr(str.indexOf(":") + 1).split(","));
		case 11: TColor;
		case 12: TLayer(str.substr(str.indexOf(":") + 1));
		case 13: TFile;
		case 14: TTilePos;
		case 15: TTileLayer;
		case 16: TDynamic;
		case 17: TProperties;
		default: throw "Unknown type " + str;
		}
	}

	public static function parse( content : String, editMode : Bool ) : Data {
		if( content == null ) throw "CDB content is null";
		var data : Data = haxe.Json.parse(content);
		for( s in data.sheets )
			for( c in s.columns ) {
				c.type = getType(c.typeStr);
				c.typeStr = null;
			}
		for( t in data.customTypes )
			for( c in t.cases )
				for( a in c.args ) {
					a.type = getType(a.typeStr);
					a.typeStr = null;
				}

		// resolve separators
		for( s in data.sheets ) {
			if( !(editMode || s.props.hasGroup) ) continue;

			if( s.separators == null ) {
				var ids : Array<Dynamic> = Reflect.field(s,"separatorIds");
				s.separators = [for( i in ids ) if( Std.isOfType(i,Int) ) { index : (i:Int) } else { id : (i:String) }];
				Reflect.deleteField(s, "separatorIds");
			}

			var indexMap = null;
			for( i in 0...s.separators.length ) {
				var sep = s.separators[i];
				if( Std.isOfType(sep,Int) )
					s.separators[i] = { index : (cast sep:Int) };
				else if( sep.id != null ) {
					if( indexMap == null ) {
						var idField = null;
						for( c in s.columns )
							if( c.type == TId ) {
								idField = c.name;
								break;
							}
						indexMap = new Map();
						for( i in 0...s.lines.length ) {
							var l = s.lines[i];
							var id : String = Reflect.field(l, idField);
							if( id != null ) indexMap.set(id, i);
						}
					}
					sep.index = indexMap.get(sep.id);
					Reflect.deleteField(sep,"id");
				}
			}

			var titles : Array<String> = Reflect.field(s.props,"separatorTitles");
			if( titles != null ) {
				Reflect.deleteField(s.props,"separatorTitles");
				for( i in 0...titles.length )
					if( titles[i] != null )
						s.separators[i].title = titles[i];
			}
		}
		return data;
	}

	public static function save( data : Data ) : String {
		var save = [];
		var seps = [];
		for( s in data.sheets ) {
			var idField = null;
			for( c in s.columns ) {
				if( c.type == TId && idField == null ) idField = c.name;
				save.push(c.type);
				if( c.typeStr == null ) c.typeStr = cdb.Parser.saveType(c.type);
				Reflect.deleteField(c, "type");
			}
			// remap separators based on indexes
			var oldSeps = null;
			if( idField != null && s.separators.length > 0 ) {
				var uniqueIDs = true;
				var uids = new Map();
				for( l in s.lines ) {
					var id : String = Reflect.field(l, idField);
					if( id != null ) {
						if( uids.get(id) ) {
							uniqueIDs = false;
							break;
						}
						uids.set(id, true);
					}
				}
				if( uniqueIDs ) {
					oldSeps = s.separators;
					s.separators = [];
					for( sep in oldSeps ) {
						var obj = s.lines[sep.index];
						var id = obj != null ? Reflect.field(obj, idField) : null;
						var sep = sep;
						if( id != null ) {
							sep = Reflect.copy(sep);
							Reflect.deleteField(sep,"index");
							sep.id = id;
						}
						s.separators.push(sep);
					}
				}
			}
			seps.push(oldSeps);
		}
		for( t in data.customTypes )
			for( c in t.cases )
				for( a in c.args ) {
					save.push(a.type);
					if( a.typeStr == null ) a.typeStr = cdb.Parser.saveType(a.type);
					Reflect.deleteField(a, "type");
				}
		var str = haxe.Json.stringify(data, null, "\t");
		for( s in data.sheets ) {
			for( c in s.columns )
				c.type = save.shift();
			var oldSeps = seps.shift();
			if( oldSeps != null )
				s.separators = oldSeps;
		}
		for( t in data.customTypes )
			for( c in t.cases )
				for( a in c.args )
					a.type = save.shift();
		return str;
	}

}