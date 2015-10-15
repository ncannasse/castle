package cdb.jq;

@:keep class Event {

	public var value : Dynamic;
	public var keyCode : Int;
	public var which : Int;
	public var shiftKey : Bool;
	public var ctrlKey : Bool;

	public function new() {
	}

}