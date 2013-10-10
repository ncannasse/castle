package cdb;

class Parser {
	
	public static function saveType( t : Data.ColumnType ) : String {
		return switch( t ) {
		case TRef(_), TCustom(_):
			Type.enumIndex(t) + ":" + Type.enumParameters(t)[0];
		case TEnum(values), TFlags(values):
			Type.enumIndex(t) + ":" + values.join(",");
		case TId, TString, TList, TInt, TImage, TFloat, TBool:
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
		default: throw "Unknown type " + str;
		}
	}

	public static function parse( content : String ) : Data {
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
	
}