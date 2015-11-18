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

class Server {

	var root : js.html.Element;
	var nodes : Array<js.html.Element>;
	var events : Map<Int,{ n : js.html.Element, name : String, callb : Dynamic -> Void }>;

	public function new(root) {
		this.root = root;
		nodes = [root];
		events = new Map();
	}

	public function send( msg : Message.Answer ) {
		throw "Not implemented";
	}

	function dock( parent : js.html.Element, e : js.html.Element, dir : Message.DockDirection, size : Null<Float> ) {
		throw "Not implemented";
	}

	function handleSpecial( e : js.html.Element, name : String, args : Array<Dynamic>, result : Dynamic -> Void ) {
	}

	public function onMessage( msg : Message ) {
		switch( msg ) {
		case Create(id, name, attr):
			var n = js.Browser.document.createElement(name);
			if( attr != null )
				for( a in attr )
					n.setAttribute(a.name, a.value);
			nodes[id] = n;
		case AddClass(id, name):
			nodes[id].classList.add(name);
		case RemoveClass(id, name):
			nodes[id].classList.remove(name);
		case Append(id, to):
			nodes[to].appendChild(nodes[id]);
		case CreateText(id, text, pid):
			var t = js.Browser.document.createTextNode(text);
			nodes[id] = cast t; // not an element
			if( pid != null ) nodes[pid].appendChild(t);
		case Reset(id):
			var n = nodes[id];
			while( n.firstChild != null )
				n.removeChild(n.firstChild);
		case Dock(p, e, dir, size):
			dock(nodes[p], nodes[e], dir, size);
		case Remove(id):
			nodes[id].remove();
		case Event(id, name, eid):
			var n = nodes[id];
			var callb = function(e) {
				var sendValue = false;
				var props : Message.EventProps = null;
				switch( name ) {
				case "change": sendValue = true;
				case "blur" if( n.tagName == "INPUT" ): sendValue = true;
				case "keydown":
					props = { keyCode : e.keyCode, shiftKey : e.shiftKey, ctrlKey : e.ctrlKey };
					if( n.tagName == "INPUT" ) sendValue = true;
				case "mousedown", "mouseup":
					props = { which : e.which };
				default:
				}
				if( sendValue )
					send(SetValue(id, ""+Reflect.field(n, "value")));
				send(Event(eid,props));
			};
			events.set(eid, { name : name, callb : callb, n : n } );
			n.addEventListener(name, callb);
		case SetAttr(id, att, val):
			nodes[id].setAttribute(att, val);
		case SetStyle(id, s, val):
			Reflect.setField(nodes[id].style, s, val);
		case Trigger(id, s):
			var n = nodes[id];
			var m : Dynamic = Reflect.field(n, s);
			if( m == null ) throw n + " has no method " + m;
			Reflect.callMethod(n, m, []);
			if( s == "focus" && n.tagName == "SELECT" ) {
				// force drop down
				var event : Dynamic = cast js.Browser.document.createEvent('MouseEvents');
				event.initMouseEvent('mousedown', true, true, js.Browser.window);
				n.dispatchEvent(event);
			}
		case Special(id, name, args, eid):
			handleSpecial(nodes[id], name, args, eid == null ? function(_) { } : function(v) send(Event(eid, { value : v })));
		case Anim(id, name, duration):
			handleSpecial(nodes[id], "animate", [name, duration], null);
		case Unbind(eids):
			for( eid in eids ) {
				var e = events.get(eid);
				if( e != null ) {
					events.remove(eid);
					e.n.removeEventListener(e.name, e.callb);
				}
			}
		case Dispose(id, eids):
			nodes[id].remove();
			nodes[id] = null;
			if( eids != null ) onMessage(Unbind(eids));
		}
	}

}
