/*
 * Copyright (c) 2015, Nicolas Cannasse
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
 * IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
package cdb.jq;

@:allow(cdb.jq.JQuery)
@:allow(cdb.jq.Query)
@:allow(cdb.jq.Client)
class Dom {

	static var UID = 0;

	public var nodeName(default, null) : String;
	public var nodeValue(default, null) : String;
	var id : Int;
	var client : Client;
	var attributes : Array<{ name : String, value : String }>;
	var classes : Array<String>;
	var parent(default,set) : Null<Dom>;
	var childs : Array<Dom>;
	var events : Array<{ id : Int, name : String, callb : Event -> Void }>;
	var style : Array<{ name : String, value : String }>;

	var dock : { parent : Dom, dir : Message.DockDirection, size : Null<Float> };

	public function new(c : Client) {
		id = UID++;
		client = c;
		@:privateAccess client.doms.set(id, this);
		events = [];
		attributes = [];
		classes = [];
		childs = [];
		style = [];
	}

	inline function send(msg) {
		if( id < 0 ) throw "Can't change disposed node";
		client.send(msg);
	}

	function set_parent(p:Dom) {

		var pchck = p;
		while( pchck != null ) {
			if( pchck == this ) throw "Recursive parent";
			pchck = pchck.parent;
		}

		if( parent != null ) parent.childs.remove(this);
		if( p != null ) {
			if( id < 0 ) throw "Can't add disposed node";
			if( p.id < 0 ) throw "Can't add to a disposed node";
			p.childs.push(this);
		}
		return parent = p;
	}

	public function reset() {
		if( (nodeName != null || nodeValue == "") && childs.length == 0 )
			return;
		send(Reset(id));
		if( nodeName == null )
			nodeValue = "";
		var cold = childs;
		childs = [];
		for( c in cold )
			c.dispose();
	}

	public function dispose() {
		if( id < 0 ) return;
		parent = null;
		if( nodeName != null ) nodeValue = "";
		@:privateAccess client.doms.remove(id);
		send(Dispose(id, events.length == 0 ? null : [for( e in events ) e.id]));
		id = -12345678;
		if( events.length > 0 ) events = [];
		var cold = childs;
		childs = [];
		for( c in cold )
			c.dispose();
	}

	public function remove() {
		send(Remove(id));
		if( parent != null ) {
			parent.childs.remove(this);
			parent = null;
		}
	}

	public function unbindEvents( rec = false ) {
		if( events.length > 0 ) {
			send(Unbind([for( e in events ) e.id]));
			events = [];
		}
		if( rec )
			for( e in childs )
				e.unbindEvents(true);
	}

	public function getStyle( name : String ) {
		for( s in style )
			if( s.name == name )
				return s.value;
		return null;
	}

	function updatedClasses() {
		var classAttr = classes.length == 0 ? null : classes.join(" ");
		for( a in attributes )
			if( a.name == "class" ) {
				if( classAttr == null )
					attributes.remove(a);
				else
					a.value = classAttr;
				return;
			}
		if( classAttr != null )
			attributes.push( { name : "class", value : classAttr } );
	}

	public function setStyle( name : String, value : String ) {
		for( s in style )
			if( s.name == name ) {
				if( value == null )
					style.remove(s);
				else
					s.value = value;
				value = null;
				break;
			}
		if( value != null )
			style.push( { name : name, value : value } );

		// sync attribute
		var styleAttr = [for( s in style ) s.name+" : " + s.value].join(";");
		for( a in attributes )
			if( a.name == "style" ) {
				a.value = styleAttr;
				return;
			}
		attributes.push( { name : "style", value : styleAttr } );
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
			style = [];
			if( value != null )
				for( pair in value.split(";") ) {
					var parts = pair.split(":");
					if( parts.length != 2 ) continue;
					style.push({ name : StringTools.trim(parts[0]), value : StringTools.trim(parts[1]) });
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