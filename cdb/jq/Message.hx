package cdb.jq;

enum Message {
	Create( id : Int, name : String, ?attr : Array<{ name : String, value : String }> );
	AddClass( id : Int, name : String );
	RemoveClass( id : Int, name : String );
	Append( id : Int, to : Int );
	CreateText( id : Int, text : String, ?pid : Int );
	SetCSS( css : String );
	Reset( id : Int );
	Dock( pid : Int, id : Int, dir : DockDirection, size : Null<Float> );
	Remove( id : Int );
	Event( id : Int, name : String, eid : Int );
	SetAttr( id : Int, att : String, ?val : String );
	SetStyle( id : Int, st : String, ?val : String );
	Trigger( id : Int, name : String );
	Special( id : Int, name : String, args : Array<Dynamic>, ?eid : Int );
	SlideToogle( id : Int, ?dur : Float );
}

typedef EventProps = { ?keyCode : Int, ?value : Dynamic, ?which : Int, ?ctrlKey : Bool, ?shiftKey : Bool };

enum Answer {
	Event( id : Int, ?props : EventProps );
	SetValue( id : Int, value : String );
}

enum DockDirection {
	Left;
	Right;
	Up;
	Down;
	Fill;
}
