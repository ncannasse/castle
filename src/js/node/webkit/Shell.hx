package js.node.webkit;

@:jsRequire("nw.gui", "Shell")
extern class Shell {

	static function openExternal( url : String ) : Void;
	static function openItem( filePath : String ) : Void;
	static function showItemInFolder( filePath : String ) : Void;

}
