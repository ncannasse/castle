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
}

#if macro
typedef DisplayType = Int;
#else
@:fakeEnum
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

typedef SheetProps = {
	@:optional var displayColumn : Null<String>;
	@:optional var separatorTitles : Array<String>;
	@:optional var hide : Bool;
}

typedef Sheet = {
	var name : String;
	var columns : Array<Column>;
	var lines : Array<Dynamic>;
	var props : SheetProps;
	var separators : Array<Int>;
	@:optional var path : String;
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
