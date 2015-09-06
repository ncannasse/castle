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
			var d = new Dom();
			d.name = query.substr(1, query.length - 2);
			send(Create(d.id, d.name));
			sel = [d];
		} else {
			sel = [@:privateAccess client.root];
			sel = find(query).sel;
		}
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
			var d = new Dom();
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

	function htmlRec( d : Dom, x : Xml ) {
		switch( x.nodeType ) {
		case Document:
			for( x in x )
				htmlRec(d, x);
		case Element:
			var de = new Dom();
			de.name = x.nodeName;
			for( a in x.attributes() )
				de.attributes.push( { name : a, value : x.get(a) } );
			send(Create(de.id, de.name, de.attributes));
			de.parent = d;
			send(Append(de.id, d.id));
			for( x in x )
				htmlRec(de, x);
		case PCData, CData:
			var dt = new Dom();
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

	public function dock( parent : Dom, dir : DockDirection, ?size : Float ) {
		for( s in sel )
			send(Dock(parent.id, s.id, dir, size));
	}

}
