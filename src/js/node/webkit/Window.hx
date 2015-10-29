package js.node.webkit;

@:jsRequire("nw.gui", "Window")
extern class Window {
	public var window : #if (haxe_ver >= 3.2) js.html.Window #else js.html.DOMWindow #end;
	public var x : Int;
	public var y : Int;
	public var width : Int;
	public var height : Int;
	public var title : String;
	public var isFullScreen : Bool;
	public var isKioskMode : Bool;
	public var zoomLevel : Int;
	public var menu : Menu;
	public function moveTo( x : Int, y : Int ) : Void;
	public function moveBy( x : Int, y : Int ) : Void;
	public function resizeTo( w : Int, h : Int ) : Void;
	public function resizeBy( w : Int, h : Int ) : Void;
	public function focus() : Void;
	public function blur() : Void;
	public function show() : Void;
	public function hide() : Void;
	public function close( ?force : Bool ) : Void;
	public function reload() : Void;
	public function reloadIgnoringCache() : Void;
	public function maximize() : Void;
	public function unmaximize() : Void;
	public function minimize() : Void;
	public function restore() : Void;
	public function enterFullscreen() : Void;
	public function leavFullscreen() : Void;
	public function showDevTools( ?id : String, ?headless : Bool ) : Void;
	public function closeDevTools() : Void;

	@:overload(function( event : String, callb : Dynamic -> Dynamic ) : Void {})
	@:overload(function( event : String, callb : Void -> Dynamic ) : Void {})
	@:overload(function( event : String, callb : Dynamic -> Void ) : Void {})
	public function on( event : String, callb : Void -> Void ) : Void;

	public static function get() : Window;
	public static function open( url : String, ?options : { } ) : Window;

}
