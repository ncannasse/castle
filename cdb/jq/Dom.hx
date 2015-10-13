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
	public var events : Array<{ id : Int, name : String, callb : Event -> Void }>;
	public var style : Array<{ name : String, value : String }>;
	public var value : String;

	public function new(c : Client) {
		id = UID++;
		@:privateAccess c.doms.set(id, this);
		events = [];
		attributes = [];
		classes = [];
		childs = [];
		style = [];
	}

	function set_parent(p:Dom) {
		if( parent != null ) parent.childs.remove(this);
		if( p != null ) p.childs.push(this);
		return parent = p;
	}

	public function getStyle( name : String ) {
		for( s in style )
			if( s.name == name )
				return s.value;
		return null;
	}

	public function setStyle( name : String, value : String ) {
		for( s in style )
			if( s.name == name ) {
				if( value == null )
					style.remove(s);
				else
					s.value = value;
				return;
			}
		if( value != null )
			style.push( { name : name, value : value } );
	}


	public function getAttr( name : String ) {
		for( a in attributes )
			if( a.name == name )
				return a.value;
		return null;
	}

	public function setAttr( name : String, value : String)  {

		switch( name ) {
		case "class":
			classes = value == null ? [] : value.split(" ");
		case "style":
			for( pair in value.split(";") ) {
				var parts = pair.split(":");
				if( parts.length != 2 ) continue;
				setStyle(StringTools.trim(parts[0]), StringTools.trim(parts[1]));
			}
		default:
		}

		for( a in attributes )
			if( a.name == name ) {
				if( value == null )
					attributes.remove(a);
				else
					a.value = value;
				return;
			}
		if( value != null )
			attributes.push( { name: name, value:value } );
	}


}