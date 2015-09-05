package cdb.jq;

class Server {

	var root : js.html.Element;
	var nodes : Array<js.html.Element>;

	public function new(root) {
		this.root = root;
		nodes = [root];
	}

	public function onMessage( msg : Message ) {
		switch( msg ) {
		case Create(id, name):
			nodes[id] = js.Browser.document.createElement(name);
		case AddClass(id, name):
			nodes[id].classList.add(name);
		case Append(id, to):
			nodes[to].appendChild(nodes[id]);
		case SetText(id, text):
			nodes[id].innerText = text;
		case SetCSS(text):
			var curCss = js.Browser.document.getElementById("jqcss");
			if( curCss == null ) {
				curCss = js.Browser.document.createElement("style");
				root.insertBefore(curCss,root.firstChild);
			}
			curCss.innerText = text;
		}
	}

}
