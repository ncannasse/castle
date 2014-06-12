package cdb;

enum ColumnType {
	TId;
	TString;
	TBool;
	TInt;
	TFloat;
	TEnum( values : Array<String> );
	TRef( sheet : String );
	TImage;
	TList;
	TCustom( name : String );
	TFlags( values : Array<String> );
	TColor;
	TLayer( type : String );
	TFile;
	TTilePos;
	TTileLayer;
	TDynamic;
}

#if macro
typedef DisplayType = Int;
#else
@:enum
abstract DisplayType(Int) {
	var Default = 0;
	var Percent = 1;
}
#end

typedef Column = {
	var name : String;
	var type : ColumnType;
	var typeStr : String;
	@:optional var opt : Bool;
	@:optional var display : DisplayType;
}

@:enum abstract LayerMode(String) {
	var Tiles = "tiles";
	var Ground = "ground";
	var Objects = "objects";
}

typedef LayerProps = {
	var alpha : Float;
	@:optional var mode : LayerMode;
	@:optional var color : Int;
}

@:enum abstract TileMode(String) {
	var Tile = "tile";
	var Ground = "ground";
	var Border = "border";
	var Object = "object";
	function new(s) {
		this = s;
	}
	public static function ofString( s : String ) {
		return new TileMode(s);
	}
	public function toString() {
		return this;
	}
}

typedef TileModeOptions = {
	?name : String,
	?priority : Int,
	?borderIn : Null<String>,
	?borderOut : Null<String>,
	?borderMode : Null<String>,
};

typedef TileProps = {
	var stride : Int;
	var sets : Array<{ x : Int, y : Int, w : Int, h : Int, t : TileMode, opts : TileModeOptions }>;
	var tags : Array<{ name : String, flags : Array<Bool> }>;
}

typedef LevelProps = {
	@:optional var tileSize : Int;
	@:optional var layers : Array<{ l : String, p : LayerProps }>;
	@:optional var tileSets : Dynamic<TileProps>;
}

typedef SheetProps = {
	@:optional var displayColumn : Null<String>;
	@:optional var separatorTitles : Array<String>;
	@:optional var hide : Bool;
	@:optional var hasIndex : Bool;
	@:optional var hasGroup : Bool;
	@:optional var isLevel : Bool;
}

typedef Sheet = {
	var name : String;
	var columns : Array<Column>;
	var lines : Array<Dynamic>;
	var props : SheetProps;
	var separators : Array<Int>;
	// used by editor only
	@:optional var path : String;
	@:optional var parent : { sheet : Sheet, column : Int, line : Int };
}

typedef CustomTypeCase = {
	var name : String;
	var args : Array<Column>;
}

typedef CustomType = {
	var name : String;
	var cases : Array<CustomTypeCase>;
}

typedef Data = {
	sheets : Array<Sheet>,
	customTypes : Array<CustomType>,
}
