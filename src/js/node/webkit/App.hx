package js.node.webkit;

@:jsRequire("nw.gui", "App")
extern class App {

	static var argv : Array<String>;
	static var fullArgv : Array<String>;
	static var dataPath : String;
	static var manifest : Dynamic;

	static function quit() : Void;
	static function clearCache() : Void;
	static function closeAllWindows() : Void;
	static function crashBrowser() : Void;
	static function crashRenderer() : Void;
	static function getProxyForURL( url : String ) : String;
	static function setProxyConfig( config : String ) : Void;

	static function on( event : String, callb : Dynamic -> Void ) : Void;

}