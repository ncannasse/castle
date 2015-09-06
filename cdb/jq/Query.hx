package cdb.jq;

class Query {

	var id : Null<String>;

	public function new( q : String ) {
		if( !~/^#[A-Za-z0-9]+$/.match(q) )
			throw "Unsupported query " + q;
		this.id = q.substr(1);
	}

	public function match( d : Dom ) {
		if( id != null ) {
			var ok = false;
			for( a in d.attributes )
				if( a.name == "id" && a.value == id ) {
					ok = true;
					break;
				}
			if( !ok ) return false;
		}
		return true;
	}

}