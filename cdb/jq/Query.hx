package cdb.jq;

class Query {

	var query : String;
	var pos = 0;
	var id : Null<String>;
	var classes : Array<String>;

	public function new( q : String ) {
		this.query = q;
		while( true ) {
			var c = nextChar();
			if( StringTools.isEof(c) ) break;
			switch( c ) {
			case '#'.code:
				id = readIdent();
			//case ' '.code, '\r'.code, '\n'.code, '\t'.code:
				// skip
			case '.'.code:
				if( classes == null ) classes = [];
				classes.push(readIdent());
			default:
				throw "Unexpected '" + String.fromCharCode(c) + "' in '" + q + "'";
			}
		}
	}

	function nextChar() {
		return StringTools.fastCodeAt(query, pos++);
	}

	function readIdent() {
		var s = new StringBuf();
		while( true ) {
			var c = nextChar();
			if( (c >= 'A'.code && c <= 'Z'.code) || (c >= 'a'.code && c <= 'z'.code) || (c >= '0'.code && c <= '9'.code) || c == '_'.code || c == '-'.code )
				s.addChar(c);
			else {
				pos--;
				break;
			}
		}
		return s.toString();
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
		if( classes != null ) {
			for( c in classes ) {
				if( d.classes.indexOf(c) < 0 )
					return false;
			}
		}
		return true;
	}

}