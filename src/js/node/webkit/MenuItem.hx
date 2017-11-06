package js.node.webkit;

@:jsRequire("nw.gui", "MenuItem")
extern class MenuItem {

	var type(default, null) : MenuItemType;
	var label : String;
	var icon : String;
	var tooltip : String;
	var checked : Bool;
	var enabled : Bool;
	var submenu : Menu;

	function new( ?t : { ?label : String, ?icon : String, ?type : MenuItemType, ?key : String, ?modifiers : String } ) : Void;

	dynamic function click() : Void;
	function on( event : String, callb : Void -> Void ) : Void;

}