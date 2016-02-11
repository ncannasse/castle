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

	public static function parse( content : String ) : Data {
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
		return data;
	}

	public static function save( data : Data ) : String {
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
		var str = haxe.Json.stringify(data, null, "\t");
		for( s in data.sheets )
			for( c in s.columns )
				c.type = save.shift();
		for( t in data.customTypes )
			for( c in t.cases )
				for( a in c.args )
					a.type = save.shift();
		return str;
	}

}