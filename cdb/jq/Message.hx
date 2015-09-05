package cdb.jq;

enum Message {
	Create( id : Int, name : String );
	AddClass( id : Int, name : String );
	Append( id : Int, to : Int );
	SetText( id : Int, text : String );
	SetCSS( css : String );
}

