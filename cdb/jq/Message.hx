package cdb.jq;

enum Message {
	Create( id : Int, name : String, ?attr : Array<{ name : String, value : String }> );
	AddClass( id : Int, name : String );
	Append( id : Int, to : Int );
	CreateText( id : Int, text : String, ?pid : Int );
	SetCSS( css : String );
	Reset( id : Int );
	Dock( pid : Int, id : Int, dir : DockDirection, size : Null<Float> );
}

enum DockDirection {
	Left;
	Right;
	Up;
	Down;
	Fill;
}
