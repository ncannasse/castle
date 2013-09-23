package nw;

@:native('nw.$ui')
class UI {
	
	static function __init__() : Void untyped {
		__js__("nw.$ui = require('nw.gui')");
	}
}
