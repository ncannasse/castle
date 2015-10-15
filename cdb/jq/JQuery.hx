package cdb.jq;
import cdb.jq.Message;

class JQuery {

	var client : Client;
	var sel : Array<Dom>;

	public function new(client,?elt:Dom,?query:String) {
		this.client = client;
		if( elt != null )
			sel = [elt];
		else if( query == null ) {
			sel = [];
		} else if( query.charCodeAt(0) == "<".code ) {
			if( !~/^<[A-Za-z]+>$/.match(query) ) throw "Unsupported html creation query";
			var d = new Dom(client);
			d.name = query.substr(1, query.length - 2);
			send(Create(d.id, d.name));
			sel = [d];
		} else {
			sel = [@:privateAccess client.root];
			sel = find(query).sel;
		}
	}

	public inline function get( id = 0 ) {
		return sel[id];
	}

	public function hasClass( name : String ) {
		var d = get();
		return d == null ? false : d.classes.indexOf(name) >= 0;
	}

	public function addClass( name : String ) {
		for( s in sel )
			if( s.classes.indexOf(name) < 0 ) {
				s.classes.push(name);
				send(AddClass(s.id, name));
			}
		return this;
	}

	public function text( t : String ) {
		for( s in sel ) {
			s.childs = [];
			send(Reset(s.id));
			var d = new Dom(client);
			d.text = t;
			d.parent = s;
			send(CreateText(d.id, t, s.id));
		}
		return this;
	}

	public function html( html : String ) {
		var x = try Xml.parse(html) catch( e : Dynamic ) throw "Failed to parse " + html + "(" + e+")";
		for( s in sel ) {
			s.childs = [];
			s.text = null;
			send(Reset(s.id));
			htmlRec(s,x);
		}
		return this;
	}

	public function click( ?e : Event -> Void ) {
		if( e == null ) trigger("click") else bind("click", e);
		return this;
	}

	public function mousedown( ?e : Event -> Void ) {
		if( e == null ) trigger("mousedown") else bind("mousedown", e);
		return this;
	}

	public function mouseup( ?e : Event -> Void ) {
		if( e == null ) trigger("mouseup") else bind("mouseup", e);
		return this;
	}

	public function change( ?e : Event -> Void ) {
		if( e == null ) trigger("change") else bind("change", e);
		return this;
	}

	public function keydown( ?e : Event -> Void ) {
		if( e == null ) trigger("keydown") else bind("keydown", e);
		return this;
	}

	public function keyup( ?e : Event -> Void ) {
		if( e == null ) trigger("keyup") else bind("keyup", e);
		return this;
	}

	public function focus( ?e : Event -> Void ) {
		if( e == null ) trigger("focus") else bind("focus", e);
		return this;
	}

	public function blur( ?e : Event -> Void ) {
		if( e == null ) trigger("blur") else bind("blur", e);
		return this;
	}

	public function dblclick( ?e : Event -> Void ) {
		if( e == null ) trigger("dblclick") else bind("dblclick", e);
		return this;
	}

	public function trigger( event : String ) {
		for( s in sel )
			send(Trigger(s.id, event));
	}

	public function getValue() {
		if( sel.length == 0 )
			return null;
		return get().value;
	}

	public function special( name : String, args : Array<Dynamic>, ?result : Dynamic -> Void ) {
		for( s in sel ) {
			var id : Null<Int> = null;
			if( result != null )
				id = client.allocEvent(function(e) result(e.value));
			send(Special(s.id, name, args, id));
		}
		return this;
	}

	function bind( event : String, e : Event -> Void ) {
		for( s in sel ) {
			var id = client.allocEvent(e);
			s.events.push( { id : id, name : event, callb : e } );
			send(Event(s.id, event, id));
		}
	}

	function htmlRec( d : Dom, x : Xml ) {
		switch( x.nodeType ) {
		case Document:
			for( x in x )
				htmlRec(d, x);
		case Element:
			var de = new Dom(client);
			de.name = x.nodeName;
			for( a in x.attributes() )
				de.setAttr(a, x.get(a));
			send(Create(de.id, de.name, de.attributes));
			de.parent = d;
			send(Append(de.id, d.id));
			for( x in x )
				htmlRec(de, x);
		case PCData, CData:
			var dt = new Dom(client);
			dt.text = x.nodeValue;
			dt.parent = d;
			send(CreateText(dt.id, dt.text, d.id));
		case ProcessingInstruction, DocType, Comment:
			// nothing
		}
	}

	public function find( query : String ) {
		var j = new JQuery(client);
		var r = new Query(query);
		for( s in sel )
			j.addRec(r, s);
		return j;
	}

	function addRec( q : Query, d : Dom ) {
		if( q.match(d) )
			sel.push(d);
		for( d in d.childs )
			addRec(q, d);
	}

	public function appendTo( j : JQuery ) {
		var p = j.sel[0];
		if( p != null )
			for( s in sel ) {
				s.parent = p;
				send(Append(s.id, p.id));
			}
		return this;
	}

	inline function send( msg : Message ) {
		client.send(msg);
	}

	public function attr( a : String, ?val : String ) {
		for( s in sel ) {
			s.setAttr(a, val);
			send(SetAttr(s.id, a, val));
		}
		return this;
	}

	public function getAttr( a : String ) {
		if( sel.length == 0 )
			return null;
		return get().getAttr(a);
	}

	public function style( s : String, ?val : String ) {
		if( val == null ) {
			if( sel.length == 0 )
				return null;
			return get().getStyle(s);
		}
		for( d in sel ) {
			d.setStyle(s, val);
			send(SetStyle(d.id, s, val));
		}
		return val;
	}

	public function dock( parent : Dom, dir : DockDirection, ?size : Float ) {
		for( s in sel )
			send(Dock(parent.id, s.id, dir, size));
	}

	public function remove() {
		for( s in sel ) {
			send(Remove(s.id));
			if( s.parent != null ) {
				s.parent.childs.remove(s);
				s.parent = null;
			}
		}
	}

	public function removeClass( name : String ) {
		for( s in sel )
			if( s.classes.remove(name) )
				send(RemoveClass(s.id, name));
		return this;
	}

	public function slideToggle( ?duration : Float ) {
		for( s in sel )
			send(SlideToogle(s.id, duration));
		return this;
	}

	public function toggleClass( name : String, ?state ) {
		if( state != null ) {
			if( state )
				addClass(name);
			else
				removeClass(name);
		} else {
			for( s in sel )
				if( !s.classes.remove(name) ) {
					s.classes.push(name);
					send(AddClass(s.id, name));
				} else {
					send(RemoveClass(s.id, name));
				}
		}
		return this;
	}

	public function toggle() {
		for( s in sel ) {
			var d = s.getStyle("display") == "none" ? "" : "none";
			s.setStyle("display", d);
			send(SetStyle(s.id, "display", d));
		}
		return this;
	}

	public function elements() {
		return [for( s in sel ) new JQuery(client, s)].iterator();
	}

}