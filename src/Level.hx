import cdb.Data;
import js.JQuery.JQueryHelper.*;

typedef LevelState = {
	var curLayer : String;
	var zoomView : Float;
}

class Level {

	static var UID = 0;

	public var sheetPath : String;
	public var index : Int;
	public var width : Int;
	public var height : Int;
	public var model : Model;
	public var zoom : Int;

	var sheet : Sheet;
	var obj : Dynamic;
	var content : js.JQuery;
	var layers : Array<LayerData>;
	var props : LevelProps;

	var ctx : js.html.CanvasRenderingContext2D;
	var currentLayer : LayerData;
	var cursor : js.JQuery;
	var zoomView = 1.;
	var curPos : { x : Int, y : Int };
	var mouseDown : Bool;
	var needSave : Bool;

	public function new( model : Model, sheet : Sheet, index : Int ) {
		this.sheet = sheet;
		this.sheetPath = model.getPath(sheet);
		this.index = index;
		this.obj = sheet.lines[index];
		this.model = model;
		layers = [];
		props = sheet.props.levelProps;
		if( props.zoom == null ) props.zoom = 16;

		zoom = props.zoom;

		var lprops = new Map();
		if( props.layers == null ) props.layers = [];
		for( ld in props.layers )
			lprops.set(ld.l, ld);

		var title = "";
		for( c in sheet.columns ) {
			var val : Dynamic = Reflect.field(obj, c.name);
			switch( c.name ) {
			case "width": width = val;
			case "height": height = val;
			default:
			}
			switch( c.type ) {
			case TId: title = val;
			case TLayer(type):
				var p = lprops.get(c.name);
				if( p == null ) {
					p = { l : c.name, p : { alpha : 1. } };
					props.layers.push(p);
				}
				lprops.remove(c.name);
				var l = new LayerData(this, c.name, model.getSheet(type), val, p.p);
				layers.push(l);
			default:
			}
		}

		// cleanup unused
		for( c in lprops ) props.layers.remove(c);

		if( sheet.props.displayColumn != null ) {
			var t = Reflect.field(obj, sheet.props.displayColumn);
			if( t != null ) title = t;
		}
		setup();
		draw();

		var layer = layers[0];
		var state : LevelState = try haxe.Unserializer.run(js.Browser.getLocalStorage().getItem(sheetPath)) catch( e : Dynamic ) null;
		if( state != null ) {
			for( l in layers )
				if( l.name == state.curLayer ) {
					layer = l;
					break;
				}
			zoomView = state.zoomView;
		}
		setCursor(layer);
		updateZoom();
	}

	function toColor( v : Int ) {
		return "#" + StringTools.hex(v, 6);
	}

	function setup() {
		var page = J("#content");
		page.html("");
		content = J(J("#levelContent").html()).appendTo(page);

		var menu = content.find(".menu");
		for( l in layers ) {
			var td = J("<div class='item layer'>").appendTo(menu);
			l.comp = td;
			if( !l.visible ) td.addClass("hidden");
			td.click(function(_) setCursor(l));
			J("<span>").text(l.name).appendTo(td);
			if( l.images != null ) {
				var isel = J("<div class='img'>").appendTo(td);
				isel.append(J(l.images[l.current]));
				isel.click(function(e) {
					var list = J("<div class='imglist'>");
					for( i in 0...l.images.length )
						list.append(J("<img>").attr("src", l.images[i].src).click(function(_) {
							isel.html("");
							isel.append(J(l.images[i]));
							l.current = i;
							setCursor(l);
						}));
					td.append(list);
					function remove() {
						list.detach();
						J(js.Browser.window).unbind("click");
					}
					J(js.Browser.window).bind("click", function(_) remove());
					e.stopPropagation();
				});
				continue;
			}
			var id = UID++;
			var t = J('<input type="text" id="_${UID++}">').appendTo(td);
			(untyped t.spectrum)({
				color : toColor(l.colors[l.current]),
				clickoutFiresChange : true,
				showButtons : false,
				showPaletteOnly : true,
				showPalette : true,
				palette : [for( c in l.colors ) toColor(c)],
				change : function(e) {
					var color = Std.parseInt("0x" + e.toHex());
					for( i in 0...l.colors.length )
						if( l.colors[i] == color ) {
							l.current = i;
							setCursor(l);
							return;
						}
					setCursor(l);
				},
			});
		}


		var canvas = content.find("canvas");
		canvas.attr("width", (width * zoom) + "px");
		canvas.attr("height", (height * zoom) + "px");
		var scroll = content.find(".scroll");
		var scont = J(".scrollContent");

		var win = nodejs.webkit.Window.get();
		function onResize(_) {
			scroll.css("height", (win.height - 195) + "px");
		}
		win.on("resize", onResize);
		onResize(null);


		scroll.bind('mousewheel', function(e) {
			var d = untyped e.originalEvent.wheelDelta;
			if( d > 0 ) {
				zoomView *= 1.2;
			} else {
				zoomView /= 1.2;
			}
			savePrefs();
			e.preventDefault();
			e.stopPropagation();
			updateZoom();
		});

		cursor = content.find("#cursor");
		cursor.hide();

		ctx = Std.instance(canvas[0],js.html.CanvasElement).getContext2d();

		scont.mouseleave(function(_) { curPos = null; cursor.hide(); } );
		scont.mousemove(function(e) {
			var off = canvas.parent().offset();
			var cx = Std.int((e.pageX - off.left) / (zoom * zoomView));
			var cy = Std.int((e.pageY - off.top) / (zoom * zoomView));
			var delta = currentLayer.images != null ? 0 : -1;
			if( cx < width && cy < height ) {
				cursor.show();
				cursor.css( { marginLeft : Std.int(cx * zoom * zoomView + delta) + "px", marginTop : Std.int(cy * zoom * zoomView + delta) + "px" } );
				curPos = { x : cx, y : cy };
				if( mouseDown ) set(cx, cy);
			} else {
				cursor.hide();
				curPos = null;
			}
		});
		function onMouseUp(_) {
			mouseDown = false;
			if( needSave ) save();
		}
		scroll.mousedown(function(e) {
			switch( e.which ) {
			case 1:
				mouseDown = true; if( curPos != null ) set(curPos.x, curPos.y);
			case 3:
				if( curPos == null ) return;
				var i = layers.length - 1;
				while( i >= 0 ) {
					var l = layers[i--];
					var k = l.data[curPos.x + curPos.y * width];
					if( k == 0 && i >= 0 ) continue;
					l.current = k;
					setCursor(l);
					break;
				}
			}
		});
		scroll.mouseleave(onMouseUp);
		scroll.mouseup(onMouseUp);
	}

	function updateZoom() {
		content.find("canvas").css( { width : Std.int(width * zoom * zoomView)+"px", height : Std.int(height * zoom * zoomView)+"px" } );
		setCursor(currentLayer);
	}

	public function onKey( e : js.html.KeyboardEvent ) {
		if( e.ctrlKey || curPos == null ) return;
		switch( e.keyCode ) {
		case "P".code:
			var x = curPos.x;
			var y = curPos.y;
			if( currentLayer.data[x + y * width] == currentLayer.current ) return;
			function fillRec(x, y, k) {
				if( currentLayer.data[x + y * width] != k ) return;
				currentLayer.data[x + y * width] = currentLayer.current;
				if( x > 0 ) fillRec(x - 1, y, k);
				if( y > 0 ) fillRec(x, y - 1, k);
				if( x < width - 1 ) fillRec(x + 1, y, k);
				if( y < height - 1 ) fillRec(x, y + 1, k);
			}
			fillRec(x, y, currentLayer.data[x + y * width]);
			save();
			draw();
		default:
		}
	}

	function set( x, y ) {
		if( currentLayer.data[x + y * width] == currentLayer.current ) return;
		currentLayer.data[x + y * width] = currentLayer.current;
		currentLayer.dirty = true;
		save();
		draw();
	}

	function draw() {
		ctx.fillStyle = "black";
		ctx.fillRect(0, 0, width * zoom, height * zoom);
		var first = true;
		for( l in layers ) {
			ctx.globalAlpha = l.props.alpha;
			if( l.visible )
			for( y in 0...width )
				for( x in 0...height ) {
					var k = l.data[x + y * width];
					if( k == 0 && !first ) continue;
					if( l.images != null ) {
						ctx.drawImage(l.images[k], x * zoom, y * zoom);
						continue;
					}
					ctx.fillStyle = toColor(l.colors[k]);
					ctx.fillRect(x * zoom, y * zoom, zoom, zoom);
				}
			first = false;
		}
	}

	function save() {
		if( mouseDown ) {
			needSave = true;
			return;
		}
		needSave = false;
		var changed = false;
		for( l in layers )
			if( l.dirty ) {
				l.dirty = false;
				Reflect.setField(obj, l.name, l.getData());
			}
		model.save();
	}

	function savePrefs() {
		var state : LevelState = {
			zoomView : zoomView,
			curLayer : currentLayer.name,
		};
		js.Browser.getLocalStorage().setItem(sheetPath, haxe.Serializer.run(state));
	}

	@:keep function setVisible(b:Bool) {
		currentLayer.visible = b;
		draw();
	}

	@:keep function setAlpha(v:String) {
		currentLayer.props.alpha = Std.parseInt(v) / 100;
		model.save(false);
		draw();
	}

	function setCursor( l : LayerData ) {
		J(".menu .item.selected").removeClass("selected");
		l.comp.addClass("selected");
		var old = currentLayer;
		currentLayer = l;
		if( old != l ) {
			savePrefs();
			J("[name=alpha]").val(Std.string(Std.int(l.props.alpha * 100)));
			J("[name=visible]").prop("checked", l.visible);
		}
		var size = Std.int(zoom * zoomView);
		if( l.images != null ) {
			cursor.css( { background : "url('" + l.images[l.current].src+"')", backgroundSize : "cover", width : size+"px", height : size+"px", border : "none" } );
		} else {
			var c = l.colors[l.current];
			var lum = ((c & 0xFF) + ((c >> 8) & 0xFF) + ((c >> 16) & 0xFF)) / (255 * 3);
			cursor.css( { background : '#' + StringTools.hex(c, 6), width : (size+2)+"px", height : (size+2)+"px", border : "1px solid " + (lum < 0.25 ? "white":"black") } );
		}
	}

}

typedef LayerState = {
	var current : Int;
	var visible : Bool;
}


class LayerData {

	var level : Level;
	public var name : String;
	public var sheet : Sheet;
	public var names : Array<String>;
	public var colors : Array<Int>;
	public var images : Array<js.html.ImageElement>;
	public var data : Array<Int>;
	public var props : LayerProps;

	public var visible(default,set) : Bool = false;
	public var dirty : Bool;

	public var current(default,set) : Int = 0;
	public var comp : js.JQuery;

	public function new(level, name, s, val : String, p) {
		this.level = level;
		this.name = name;
		sheet = s;
		props = p;
		if( s.lines.length > 256 ) throw "Too many lines";
		if( val == null || val == "" )
			data = [for( x in 0...level.width * level.height ) 0];
		else {
			var a = haxe.crypto.Base64.decode(val);
			if( a.length != level.width * level.height ) throw "Invalid layer data";
			data = [for( i in 0...level.width * level.height ) a.get(i)];
		}
		var idCol = null;
		for( c in s.columns )
			switch( c.type ) {
			case TColor:
				colors = [for( o in s.lines ) { var c = Reflect.field(o, c.name); c == null ? 0 : c; } ];
			case TImage:
				images = [];
				var canvas = js.Browser.document.createCanvasElement();
				var size = level.zoom;
				canvas.setAttribute("width", size+"px");
				canvas.setAttribute("height", size+"px");
				var ctx = canvas.getContext2d();

				for( idx in 0...s.lines.length ) {
					var key = Reflect.field(s.lines[idx], c.name);
					var idat = level.model.getImageData(key);
					var i = js.Browser.document.createImageElement();
					images[idx] = i;
					if( idat == null ) {
						ctx.fillStyle = "rgba(0,0,0,0)";
						ctx.fillRect(0, 0, size, size);
						ctx.fillStyle = "white";
						ctx.fillText("#" + idx, 2, 4);
						i.src = ctx.canvas.toDataURL();
						continue;
					}
					i.src = idat;
					i.onload = function(_) {
						if( i.parentNode != null && i.parentNode.nodeName.toLowerCase() == "body" ) i.parentNode.removeChild(i);
					};
					js.Browser.document.body.appendChild(i);
				}
			case TId:
				idCol = c;
			default:
			}
		names = [];
		for( index in 0...s.lines.length ) {
			var o = s.lines[index];
			var n = if( s.props.displayColumn != null ) Reflect.field(o, s.props.displayColumn) else null;
			if( (n == null || n == "") && idCol != null )
				n = Reflect.field(o, idCol.name);
			if( n == null || n == "" )
				n = "#" + index;
			names.push(n);
		}

		var state : LayerState = try haxe.Unserializer.run(js.Browser.getLocalStorage().getItem(level.sheetPath + ":" + name)) catch( e : Dynamic ) null;
		if( state != null ) {
			visible = state.visible;
			current = state.current;
		}
	}

	function set_visible(v) {
		visible = v;
		if( comp != null ) comp.toggleClass("hidden", !visible);
		saveState();
		return v;
	}

	function set_current(v) {
		current = v;
		saveState();
		return v;
	}

	function saveState() {
		var s : LayerState = {
			current : current,
			visible : visible,
		};
		js.Browser.getLocalStorage().setItem(level.sheetPath + ":" + name, haxe.Serializer.run(s));
	}

	public function getData() {
		var b = haxe.io.Bytes.alloc(level.width * level.height);
		var p = 0;
		for( y in 0...level.height )
			for( x in 0...level.width ) {
				b.set(p, data[p]);
				p++;
			}
		return haxe.crypto.Base64.encode(b);
	}


}

