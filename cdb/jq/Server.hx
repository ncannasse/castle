package cdb.jq;

class Server {

	var root : js.html.Element;
	var nodes : Array<js.html.Element>;

	public function new(root) {
		this.root = root;
		nodes = [root];
	}

	function send( msg : Message.Answer ) {
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
		case SetCSS(text):
			var curCss = js.Browser.document.getElementById("jqcss");
			if( curCss == null ) {
				curCss = js.Browser.document.createElement("style");
				root.insertBefore(curCss,root.firstChild);
			}
			curCss.innerText = text;
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
			n.addEventListener(name, function(e) {
				var sendValue = false;
				var props : Dynamic = null;
				switch( name ) {
				case "change": sendValue = true;
				case "blur" if( n.tagName == "INPUT" ): sendValue = true;
				case "keydown":
					props = { keyCode : e.keyCode };
					if( n.tagName == "INPUT" ) sendValue = true;
				case "mousedown", "mouseup":
					props = { which : e.which };
				default:
				}
				if( sendValue )
					send(SetValue(id, ""+Reflect.field(n, "value")));
				send(Event(eid,props));
			});
		case SetAttr(id, att, val):
			nodes[id].setAttribute(att, val);
		case SetStyle(id, s, val):
			Reflect.setField(nodes[id].style, s, val);
		case Trigger(id, s):
			var m : Dynamic = Reflect.field(nodes[id], s);
			if( m == null ) throw nodes[id] + " has no method " + m;
			Reflect.callMethod(nodes[id], m, []);
			if( s == "focus" && nodes[id].tagName == "SELECT" ) {
				// force drop down
				var event : Dynamic = cast js.Browser.document.createEvent('MouseEvents');
				event.initMouseEvent('mousedown', true, true, js.Browser.window);
				nodes[id].dispatchEvent(event);
			}
		case Special(id, name, args, eid):
			handleSpecial(nodes[id], name, args, eid == null ? function(_) { } : function(v) send(Event(eid, { value : v })));
		case SlideToogle(id, duration):
			handleSpecial(nodes[id], "slideToggle", [duration], null);
		}
	}

}
