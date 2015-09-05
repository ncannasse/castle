import js.JQuery.JQueryHelper.*;

class JqPages {

	var main : Main;
	public var pages : Array<{ root : js.html.Element, name : String, j : cdb.jq.Server }>;
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
		J("#content").html("").append(pages[curPage].root);
	}

	function onClient( sock : js.node.net.Socket ) {
		var p = { root : js.Browser.document.createElement("div"), name : "", j : null };
		p.j = new cdb.jq.Server(p.root);
		pages.push(p);
		updateTabs();
		sock.setNoDelay(true);
		sock.on("error", function() sock.end());
		sock.on("close", function() {
			var cur = curPage == Lambda.indexOf(pages, p);
			pages.remove(p);
			updateTabs();
			if( cur ) {
				curPage--;
				main.initContent();
			}
		});
		sock.on("data", function(e:js.node.Buffer) {
			var pos = 0;
			while( pos < e.length ) {
				var size = e.readInt32LE(pos);
				pos += 4;
				trace(pos, size, e.length);
				var msg = haxe.io.Bytes.alloc(size);
				for( i in 0...size )
					msg.set(i, e.readUInt8(pos++));
				var msg : cdb.jq.Message = cdb.BinSerializer.unserialize(msg);
				trace(msg);
				p.j.onMessage(msg);
			}
		});
	}

}