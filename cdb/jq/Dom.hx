package cdb.jq;

class Dom {

	static var UID = 0;

	public var id : Int;
	public var name : String;
	public var attributes : Array<{ name : String, value : String }>;
	public var classes : Array<String>;
	public var parent(default,set) : Null<Dom>;
	public var childs : Array<Dom>;
	public var text : String;

	public function new() {
		id = UID++;
		attributes = [];
		classes = [];
		childs = [];
	}

	function set_parent(p:Dom) {
		if( parent != null ) parent.childs.remove(this);
		if( p != null ) p.childs.push(this);
		return parent = p;
	}

}