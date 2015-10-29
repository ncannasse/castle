package js.node.webkit;

@:jsRequire("nw.gui", "Clipboard")
extern class Clipboard {

	public static inline function getInstance() : Clipboard {
		return untyped Clipboard.get();
	}

	public function get( ?type : String ) : Dynamic;
	public function set( data : Dynamic, ?type : String ) : Void;
	public function clear() : Void;

}