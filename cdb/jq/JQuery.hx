package cdb.jq;

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
			s.text = t;
			send(SetText(s.id, t));
		}
		return this;
	}

	public function find( query : String ) {
		var j = new JQuery(client);
		throw "TODO : " + query;
		return j;
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

}
