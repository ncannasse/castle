enum ColumnType {
	TId;
	TString;
	TBool;
	TInt;
	TFloat;
	TEnum( values : Array<String> );
	TRef( sheet : String );
}

typedef Column = {
	var name : String;
	var type : ColumnType;
	var opt : Bool;
	var size : Null<Float>;
}

typedef SheetProps = {
	var displayColumn : Null<String>;
}

typedef Sheet = {
	var name : String;
	var columns : Array<Column>;
	var lines : Array<Dynamic>;
	var props : SheetProps;
}

typedef Data = {
	sheets : Array<Sheet>,
}

typedef SavedSheet = {
	var name : String;
	var schema : String;
	var props : SheetProps;
}

typedef SavedData = {
	var sheets : Array<SavedSheet>;
	var lines : Array<Array<Dynamic>>;
}
