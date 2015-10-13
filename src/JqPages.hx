import js.jquery.Helper.*;

extern class DockNode {
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

@:native("dockspawn.PanelContainer") extern class Panel {
	function new( e : js.html.Element, m : DockManager ) : Void;
}

class JqPage extends cdb.jq.Server {

	public var page : js.html.Element;
	public var name : String;
	var sock : js.node.net.Socket;
	var pages : JqPages;
	var dockManager : DockManager;
	var panels : Map<js.html.Element, Panel>;
	var dnodes : Map<js.html.Element, DockNode>;

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

	override function send( msg : cdb.jq.Message.Answer ) {
		var bytes = cdb.BinSerializer.serialize(msg);
		var buf = new js.node.Buffer(bytes.length + 2);
		buf[0] = bytes.length & 0xFF;
		buf[1] = bytes.length >> 8;
		for( i in 0...buf.length )
			buf[i + 2] = bytes.get(i);
		sock.write(buf);
	}

	override function dock( parent : js.html.Element, e : js.html.Element, dir : cdb.jq.Message.DockDirection, size : Null<Float> ) {
		var p = panels.get(e);
		if( p == null ) {
			p = new Panel(e, dockManager);
			panels.set(e, p);
		}
		var n = dnodes.get(parent);
		if( n == null )
			return;
		var n = switch( dir ) {
		case Left:
			dockManager.dockLeft(n, p, size);
		case Right:
			dockManager.dockRight(n, p, size);
		case Up:
			dockManager.dockUp(n, p, size);
		case Down:
			dockManager.dockDown(n, p, size);
		case Fill:
			dockManager.dockFill(n, p);
		}
		dnodes.set(e, n);
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
			jc.click(function(e) {
				curPage = Lambda.indexOf(pages, p);
				J("#sheets li").removeClass("active");
				jc.addClass("active");
				select();
			});
			if( Lambda.indexOf(pages, p) == curPage ) jc.addClass("active");
		}
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
			@:privateAccess p.dockManager.resize(p.page.clientWidth, p.page.clientHeight - 30);
		}
	}

	function onClient( sock : js.node.net.Socket ) {
		var p = new JqPage(sock);
		pages.push(p);
		updateTabs();
		sock.setNoDelay(true);
		sock.on("error", function() sock.end());
		sock.on("close", function() {
			/*
			var cur = curPage == Lambda.indexOf(pages, p);
			pages.remove(p);
			updateTabs();
			if( cur ) {
				curPage--;
				main.initContent();
			}*/
		});
		sock.on("data", function(e:js.node.Buffer) {
			var pos = 0;
			while( pos < e.length ) {
				var size = e.readInt32LE(pos);
				pos += 4;
				var msg = haxe.io.Bytes.alloc(size);
				for( i in 0...size )
					msg.set(i, e.readUInt8(pos++));
				var msg : cdb.jq.Message = cdb.BinSerializer.unserialize(msg);
				p.onMessage(msg);
			}
		});
	}

}