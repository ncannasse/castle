package cdb.jq;

class Client {

	var j : JQuery;
	var root : Dom;

	function new() {
		root = new Dom();
		root.id = 0;
		j = new JQuery(this,root);
	}

	inline function J( ?elt : Dom, ?query : String ) {
		return new JQuery(this, elt, query);
	}

	public function send( msg : Message ) {
		sendBytes(BinSerializer.serialize(msg));
	}

	function sendBytes( b : haxe.io.Bytes ) {
	}

}
