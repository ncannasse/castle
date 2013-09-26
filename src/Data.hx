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

typedef Column = {
	var name : String;
	var type : ColumnType;
	var typeStr : String;
	var opt : Bool;
	var size : Null<Float>;
}

typedef SheetProps = {
	@:optional var displayColumn : Null<String>;
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
