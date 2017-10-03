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
import js.jquery.Helper.*;

extern class DockNode {
	var elementPanel : js.html.HtmlElement;
}

@:native("dockspawn.DockManager") extern class DockManager {
	function new( e : js.html.Element ) : Void;
	function initialize() : Void;
	function resize( width : Float, height : Float ) : Void;
	var context : {
		var model : {
			var documentManagerNode : DockNode;
		};
	};
	function dockLeft( node : DockNode, p : Panel, v : Float ) : DockNode;
	function dockRight( node : DockNode, p : Panel, v : Float ) : DockNode;
	function dockDown( node : DockNode, p : Panel, v : Float ) : DockNode;
	function dockUp( node : DockNode, p : Panel, v : Float ) : DockNode;
	function dockFill( node : DockNode, p : Panel ) : DockNode;
}

@:native("dockspawn.EventListener") extern class EventListener {
	var source : js.html.Element;
	var eventName : String;
	function cancel() : Void;
}

@:native("dockspawn.PanelContainer") extern class Panel {
	function new( e : js.html.Element, m : DockManager ) : Void;
	dynamic function __onDestroy() : Void;
	function onCloseButtonClicked() : Void; // force close
}

class JqPage extends vdom.Server {

	public var page : js.html.Element;
	public var name : String;
	public var tab : js.jquery.JQuery;
	var sock : js.node.net.Socket;
	var pages : JqPages;
	var dockManager : DockManager;
	var panels : Map<js.html.Element, Panel>;
	var dnodes : Map<js.html.Element, DockNode>;
	var prevSelectEvent : String -> Void;

	public function new(sock) {
		super(js.Browser.document.createElement("div"));
		this.sock = sock;
		page = js.Browser.document.createElement("div");
		page.setAttribute("class", "jqpage");
		page.appendChild(root);

		// if our page is not in the DOM, it will have clientWidth/Height=0, breaking the dock manager
		js.Browser.document.body.appendChild(page);
		page.style.visibility = "hidden";

		name = "";
		panels = new Map();
		dnodes = new Map();
		dockManager = new DockManager(page);
		dockManager.initialize();
		dockManager.resize(800, 600); // TODO
		dnodes.set(root, dockManager.context.model.documentManagerNode);
	}

	override function send( msg : vdom.Answer ) {
		var bytes = encodeAnswer(msg);
		var buf = new js.node.Buffer(bytes.length + 2);
		buf[0] = bytes.length & 0xFF;
		buf[1] = bytes.length >> 8;
		for( i in 0...buf.length )
			buf[i + 2] = bytes.get(i);
		sock.write(buf);
	}

	override function onMessage(msg) {
		super.onMessage(msg);
		switch( msg ) {
		case SetAttr(0, "title", val):
			tab.text(val);
		default:
		}
	}

	override function bindEvent( n : js.html.Element, id : Int, name : String, eid : Int ) {
		switch( name ) {
		case "paneldock":
			var p = panels.get(n);
			if( p == null )
				return;
			p.__onDestroy = function() send(Event(eid, {}));
		default:
			super.bindEvent(n, id, name, eid);
		}
	}

	override function handleSpecial( e : js.html.Element, name : String, args : Array<Dynamic>, result : Dynamic -> Void ) {
		switch( name ) {
		case "colorPick":
			var id = Std.random(0x1);
			e.innerHTML = '<div class="modal" onclick="$(\'#_c$id\').spectrum(\'toggle\')"></div><input type="text" id="_c${id}"/>';
			var spect : Dynamic = J('#_c$id');
			var val = args[0];
			function getColor(vcol:Dynamic) {
				return Std.parseInt("0x" + vcol.toHex()) | (Std.int(vcol.getAlpha() * 255) << 24);
			}
			spect.spectrum( {
				color : "rgba(" + [(val >> 16) & 0xFF, (val >> 8) & 0xFF, val & 0xFF, (val >>> 24) / 255].join(",") + ")",
				showInput: true,
				showButtons: false,
				showAlpha: args[1],
				clickoutFiresChange: true,
				move : function(vcol:Dynamic) {
					result({ color : getColor(vcol), done : false });
				},
				change : function(vcol:Dynamic) {
					spect.spectrum('hide');
					result({ color : getColor(vcol), done : true });
				},
				hide : function(vcol:Dynamic) {
					result({ color : getColor(vcol), done : true });
				},
			}).spectrum("show");
		case "fileSelect", "fileSave":

			var path : String = args[0];
			var ext = args[1] == null ? [] : args[1].split(",");
			var data : Dynamic = args[2];
			var saveAs = name == "fileSave";
			var fs = J("#fileSelect");
			if( path != null && StringTools.startsWith(js.Browser.navigator.platform, "Win") )
				path = path.split("/").join("\\"); // required for nwworkingdir
			var fpath = new haxe.io.Path(path == null ? "" : path);
			fs.removeAttr("nwworkingdir");
			fs.removeAttr("nwsaveas");
			fs.attr("nwworkingdir", fpath.dir);
			if( saveAs && path != null )
				fs.attr("nwsaveas", path);
			// Chrome will not consider the value changed if we cancel.
			// there is no known way to detect cancel... (;_;)
			if( prevSelectEvent != null )
				prevSelectEvent(null);
			prevSelectEvent = result;
			fs.val("");
			fs.off("change");
			fs.change(function(_) {
				prevSelectEvent = null;
				fs.off("change");
				var path = fs.val().split("\\").join("/");
				fs.val("");
				if( path == "" ) {
					result(null);
					return;
				}
				if( saveAs ) {
					if( Std.is(data, haxe.io.Bytes) ) {
						// NWJS is not Node 4.0+ compatible yet
						var data : haxe.io.Bytes = data;
						var buf = new js.node.Buffer([for( i in 0...data.length ) data.get(i)]);
						js.node.Fs.writeFileSync(path, buf);
					} else
						sys.io.File.saveContent(path, data);
				}
				fs.attr("nwworkingdir", "");
				result(path);
			}).click();

		case "animate":

			var j = J(e);
			Reflect.callMethod(j,Reflect.field(j,args[0]),[args[1]]);

		case "setName":

			name = args[0];
			if( tab != null ) tab.text(name);

		case "popupMenu":

			var args : Array<String> = cast args;
			var n = new js.node.webkit.Menu();
			for( i in 0...args.length ) {
				var mit = new js.node.webkit.MenuItem( { label : args[i] } );
				n.append(mit);
				mit.click = function() result(i);
			}
			@:privateAccess n.popup(Main.inst.mousePos.x, Main.inst.mousePos.y);

		case "startDrag":

			var document = js.Browser.document;

			function onMove(event:Dynamic) {
				if( document.pointerLockElement != e )
					return;
				result( { dx : event.movementX, dy : event.movementY } );
			}

			function onUp() {
				document.exitPointerLock();
			}

			function onChange() {
				if( document.pointerLockElement == e ) {
					document.addEventListener("mousemove", onMove,false);
					document.addEventListener("mouseup", onUp, false);
				} else {
					result( { dx : 0, dy : 0, done : true } );
					document.removeEventListener("pointerlockchange", onChange, false);
					document.removeEventListener("mousemove", onMove, false);
					document.removeEventListener("mouseup", onUp, false);
				}
			}

			document.addEventListener("pointerlockchange",onChange,false);
			e.requestPointerLock();

		case "dock":
			var dir = e.getAttribute("dock");

			if( dir == null ) {
				var p = panels.get(e);
				if( p == null )
					return;
				panels.remove(e);
				dnodes.remove(e);
				try p.onCloseButtonClicked() catch( e : Dynamic ) {};
				return;
			}

			var parent = e.parentElement;
			var n = dnodes.get(parent);
			if( n == null ) {
				trace("Could not dock:");
				trace(e);
				trace("to:");
				trace(parent);
				return;
			}
			var p = panels.get(e);
			if( p == null ) {
				e.remove();
				p = new Panel(e, dockManager);
				panels.set(e, p);
			}

			var size = e.getAttribute("docksize");
			var size = size == null ? null : Std.parseFloat(size);
			var n = switch( dir.toLowerCase() ) {
			case "left":
				dockManager.dockLeft(n, p, size);
			case "right":
				dockManager.dockRight(n, p, size);
			case "up":
				dockManager.dockUp(n, p, size);
			case "down":
				dockManager.dockDown(n, p, size);
			default:
				dockManager.dockFill(n, p);
			}
			dnodes.set(e, n);

		case "scrollIntoView":
			e.scrollIntoView();

		default:
			throw "Don't know how to handle " + name+"(" + args.join(",") + ")";
		}
	}

}

class JqPages {

	var main : Main;
	public var pages : Array<JqPage>;
	public var curPage : Int = -1;

	public function new(main) {
		this.main = main;
		pages = [];
		js.node.Net.createServer(onClient).listen(6669, "127.0.0.1");
	}

	public function updateTabs() {
		var sheets = J("ul#sheets");
		sheets.find("li.client").remove();
		for( p in pages ) {
			var jc = J("<li>").addClass("client").text(p.name == "" ? "???" : p.name).appendTo(sheets);
			p.tab = jc;
			jc.click(function(e) {
				curPage = Lambda.indexOf(pages, p);
				J("#sheets li").removeClass("active");
				jc.addClass("active");
				select();
			});
			if( Lambda.indexOf(pages, p) == curPage ) jc.addClass("active");
		}
	}

	public function onKey( e : js.html.KeyboardEvent ) {
		pages[curPage].send(Event( -1, { keyCode : e.keyCode, shiftKey : e.shiftKey, ctrlKey : e.ctrlKey } ));
	}

	public function select() {
		var p = pages[curPage];
		J("#content").html("").append(p.page);
		p.page.style.visibility = "";
		onResize();
	}

	public function onResize() {
		if( curPage >= 0 ) {
			var p = pages[curPage];
			p.page.style.width = "100%";
			p.page.style.height = "100%";
			@:privateAccess p.dockManager.resize(p.page.clientWidth, p.page.clientHeight - (30 + p.root.clientHeight));
		}
	}

	function onClient( sock : js.node.net.Socket ) {
		var p = new JqPage(sock);
		pages.push(p);
		updateTabs();
		sock.setNoDelay(true);
		sock.on("error", function() sock.end());
		sock.on("close", function() {
			var cur = curPage == Lambda.indexOf(pages, p);
			p.page.remove();
			pages.remove(p);
			updateTabs();
			if( cur ) {
				curPage--;
				main.initContent();
			}
		});
		var curBuffer : haxe.io.Bytes = null;
		var curPos = 0;
		var size = 0;
		var sizeCount = 0;
		sock.on("data", function(e:js.node.Buffer) {
			var pos = 0;
			while( pos < e.length ) {
				if( curBuffer == null ) {
					size |= e.readUInt8(pos++) << (sizeCount * 8);
					sizeCount++;
					if( sizeCount == 4 ) {
						curBuffer = haxe.io.Bytes.alloc(size);
						curPos = 0;
					}
				} else {
					var max = e.length - pos;
					if( max > curBuffer.length - curPos )
						max = curBuffer.length - curPos;
					for( i in 0...max )
						curBuffer.set(curPos++, e.readUInt8(pos++));
					if( curPos == curBuffer.length ) {
						p.onMessage(@:privateAccess p.decodeMessage(curBuffer));
						curBuffer = null;
						sizeCount = 0;
						size = 0;
					}
				}
			}
		});
	}

}