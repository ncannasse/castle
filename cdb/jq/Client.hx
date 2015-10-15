package cdb.jq;

class Client {

	var j : JQuery;
	var doms : Map<Int,Dom>;
	var root : Dom;
	var eventID : Int = 0;
	var events : Map<Int,Event -> Void>;

	function new() {
		doms = new Map();
		root = new Dom(this);
		doms.remove(root.id);
		root.id = 0;
		doms.set(root.id, root);
		events = new Map();
		j = new JQuery(this,root);
	}

	public function getRoot() {
		return root;
	}

	public inline function J( ?elt : Dom, ?query : String ) {
		return new JQuery(this, elt, query);
	}

	public function send( msg : Message ) {
		sendBytes(BinSerializer.serialize(msg));
	}

	function sendBytes( b : haxe.io.Bytes ) {
	}

	public function allocEvent( e : Event -> Void ) {
		var id = eventID++;
		events.set(id, e);
		return id;
	}

	public function onKey( e : Event ) {
	}

	function handle( msg : Message.Answer ) {
		switch( msg ) {
		case Event(id, props):
			var e = new Event();
			if( props != null )
				for( f in Reflect.fields(props) )
					Reflect.setField(e, f, Reflect.field(props, f));
			if( id < 0 )
				onKey(e);
			else
				events.get(id)(e);
		case SetValue(id, v):
			doms.get(id).value = v;
		}
	}

}
