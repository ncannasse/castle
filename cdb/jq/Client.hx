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

	function syncDom() {
		for( a in root.attributes )
			send(SetAttr(root.id, a.name, a.value));
		for( e in root.events )
			send(Event(root.id, e.name, e.id));
		for( d in doms )
			d.id = -d.id;
		for( d in doms )
			syncDomRec(d);
	}

	function syncDomRec( d : Dom ) {
		if( d.id >= 0 ) return;
		d.id = -d.id;
		if( d.parent != null ) syncDomRec(d.parent);
		if( d.nodeName == null ) {
			send(CreateText(d.id, d.nodeValue, d.parent == null ? null : d.parent.id));
			return;
		}
		send(Create(d.id, d.nodeName, d.attributes.length == 0 ? null : d.attributes));
		if( d.parent != null )
			send(Append(d.id, d.parent.id));
		for( e in d.events )
			send(Event(d.id, e.name, e.id));
		for( c in d.childs )
			syncDomRec(c);
		if( d.dock != null ) {
			syncDomRec(d.dock.parent);
			send(Dock(d.dock.parent.id, d.id, d.dock.dir, d.dock.size));
		}
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
			else {
				var f = events.get(id);
				if( f != null )
					f(e);
			}
		case SetValue(id, v):
			var d = doms.get(id);
			if( d != null ) d.setAttr("value", v);
		case Done(eid):
			events.remove(eid);
		}
	}

}
