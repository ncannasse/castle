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
	TProperties;
}

enum abstract DisplayType(Int) {
	var Default = 0;
	var Percent = 1;
}

enum abstract ColumnKind(String) {
	var Localizable = "localizable";
	var Script = "script";
	var Hidden = "hidden";
	var TypeKind = "typekind";
}

typedef Column = {
	var name : String;
	var type : ColumnType;
	var typeStr : String;
	@:optional var opt : Bool;
	@:optional var display : DisplayType;
	@:optional var kind : ColumnKind;
	@:optional var scope : Int;
	@:optional var documentation : String;
	@:optional var editor : Any;
}

enum abstract LayerMode(String) {
	var Tiles = "tiles";
	var Ground = "ground";
	var Objects = "objects";
}

typedef LayerProps = {
	var alpha : Float;
	@:optional var mode : LayerMode;
	@:optional var color : Int;
}

enum abstract TileMode(String) {
	var Tile = "tile";
	var Ground = "ground";
	var Border = "border";
	var Object = "object";
	var Group = "group";
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
	?value : Dynamic,
	?priority : Int,
	?borderIn : Null<String>,
	?borderOut : Null<String>,
	?borderMode : Null<String>,
};

typedef TilesetProps = {
	var stride : Int;
	var sets : Array<{ x : Int, y : Int, w : Int, h : Int, t : TileMode, opts : TileModeOptions }>;
	var props : Array<Dynamic>;
}

typedef LevelProps = {
	@:optional var tileSize : Int;
	@:optional var layers : Array<{ l : String, p : LayerProps }>;
}

typedef LevelsProps = {
	var tileSets : Dynamic<TilesetProps>;
}

typedef SheetProps = {
	@:optional var displayColumn : Null<String>;
	@:optional var displayIcon : Null<String>;
	@:optional var hide : Bool;
	@:optional var isProps : Bool;
	@:optional var hasIndex : Bool;
	@:optional var hasGroup : Bool;
	@:optional var level : LevelsProps;
	@:optional var dataFiles : String;
	@:optional var editor : Any;
}

typedef Separator = {
	var ?index : Int;
	var ?id : String;
	var ?title : String;
	var ?level : Int;
	var ?path : String;
}

typedef SheetData = {
	var name : String;
	var columns : Array<Column>;
	var lines : Array<Dynamic>;
	var props : SheetProps;
	var separators : Array<Separator>;
	@:optional var linesData : Array<Dynamic>;
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
	sheets : Array<SheetData>,
	customTypes : Array<CustomType>,
	compress : Bool,
}
