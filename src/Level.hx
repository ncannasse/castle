import cdb.Data;
import js.JQuery.JQueryHelper.*;
import Main.K;

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
	public var tileSize : Int;

	var sheet : Sheet;
	var obj : Dynamic;
	var content : js.JQuery;
	var layers : Array<LayerData>;
	var images : Array<{ index : Int, data : js.html.CanvasElement }>;
	var props : LevelProps;

	var ctx : js.html.CanvasRenderingContext2D;
	var currentLayer : LayerData;
	var cursor : js.JQuery;
	var zoomView = 1.;
	var curPos : { x : Int, y : Int, xf : Float, yf : Float };
	var mouseDown : Bool;
	var needSave : Bool;

	public function new( model : Model, sheet : Sheet, index : Int ) {
		this.sheet = sheet;
		this.sheetPath = model.getPath(sheet);
		this.index = index;
		this.obj = sheet.lines[index];
		this.model = model;
		layers = [];
		images = [];
		props = sheet.props.levelProps;
		if( props.tileSize == null ) props.tileSize = 16;

		tileSize = props.tileSize;

		var lprops = new Map();
		if( props.layers == null ) props.layers = [];
		for( ld in props.layers )
			lprops.set(ld.l, ld);
		function getProps( name : String ) {
			var p = lprops.get(name);
			if( p == null ) {
				p = { l : name, p : { alpha : 1. } };
				props.layers.push(p);
			}
			lprops.remove(name);
			return p.p;
		}

		var title = "";
		for( c in sheet.columns ) {
			var val : Dynamic = Reflect.field(obj, c.name);
			switch( c.name ) {
			case "width": width = val;
			case "height": height = val;
			default:
			}
			switch( c.type ) {
			case TId:
				title = val;
			case TLayer(type):
				var l = new LayerData(this, c.name, getProps(c.name));
				l.loadSheetData(model.getSheet(type));
				l.setLayerData(val);
				layers.push(l);
			case TList:
				var sheet = model.getPseudoSheet(sheet, c);
				var floatCoord = false;
				if( (model.hasColumn(sheet, "x", [TInt]) && model.hasColumn(sheet, "y", [TInt])) || (floatCoord = true && model.hasColumn(sheet, "x", [TFloat]) && model.hasColumn(sheet, "y", [TFloat])) ) {
					var sid = null, idCol = null;
					for( cid in sheet.columns )
						switch( cid.type ) {
						case TRef(rid):
							sid = model.getSheet(rid);
							idCol = cid.name;
							break;
						default:
						}
					var l = new LayerData(this, c.name, getProps(c.name));
					l.hasFloatCoord = l.floatCoord = floatCoord;
					l.baseSheet = sheet;
					l.loadSheetData(sid);
					l.setObjectsData(idCol, val);
					l.hasSize = model.hasColumn(sheet, "width", [floatCoord?TFloat:TInt]) && model.hasColumn(sheet, "height", [floatCoord?TFloat:TInt]);
					layers.push(l);
				}
			case TFile:
				var index = layers.length;
				var path : String = model.getAbsPath(val);
				switch( path.split(".").pop().toLowerCase() ) {
				case "png", "jpeg", "jpg":
					var img = J("<img>");
					img[0].onload = function(_) {
						var c = js.Browser.document.createCanvasElement();
						c.width = img.width();
						c.height = img.height();
						var ctx = c.getContext2d();
						ctx.drawImage(cast img[0], 0, 0);
						img.remove();
						images.push( { index : index, data : c } );
						images.sort(function(i1, i2) return i1.index - i2.index);
						draw();
					};
					img.attr("src", path);
					img.appendTo("body");
				case "tmx":
					// TODO
				default:
				}
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

	function pick() {
		if( curPos == null ) return null;
		var i = layers.length - 1;
		while( i >= 0 ) {
			var l = layers[i--];
			if( !l.visible ) continue;
			switch( l.data ) {
			case Layer(data):
				var idx = curPos.x + curPos.y * width;
				var k = data[idx];
				if( k == 0 && i >= 0 ) continue;
				return { k : k, layer : l, index : idx };
			case Objects(idCol, objs):
				var x = curPos.xf;
				var y = curPos.yf;
				for( i in 0...objs.length ) {
					var o = objs[i];
					var w = l.hasSize ? o.width : 1;
					var h = l.hasSize ? o.height : 1;
					if( !(o.x >= x + 1 || o.y >= y + 1 || o.x + w < x || o.y + h < y) ) {
						if( l.idToIndex == null )
							return { k : 0, layer : l, index : i };
						var k = l.idToIndex.get(Reflect.field(o, idCol));
						if( k != null )
							return { k : k, layer : l, index : i };
					}
				}
			}
		}
		return null;
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
					setCursor(l);
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
				show : function(_) {
					setCursor(l);
				},
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
		canvas.attr("width", (width * tileSize) + "px");
		canvas.attr("height", (height * tileSize) + "px");
		var scroll = content.find(".scroll");
		var scont = content.find(".scrollContent");

		(untyped content.find("[name=color]")).spectrum({
			clickoutFiresChange : true,
			showButtons : false,
			change : function(c) {
				currentLayer.props.color = Std.parseInt("0x" + c.toHex());
				draw();
				save();
			},
		});

		var win = nodejs.webkit.Window.get();
		function onResize(_) {
			scroll.css("height", (win.height - 240) + "px");
		}
		win.on("resize", onResize);
		onResize(null);


		scroll.bind('mousewheel', function(e) {
			updateZoom(untyped e.originalEvent.wheelDelta > 0);
		});

		cursor = content.find("#cursor");
		cursor.hide();

		ctx = Std.instance(canvas[0],js.html.CanvasElement).getContext2d();

		var startPos : { x : Int, y : Int, xf : Float, yf : Float } = null;

		scont.mouseleave(function(_) {
			curPos = null;
			cursor.hide();
			J(".cursorPosition").text("");
		});
		scont.mousemove(function(e) {
			var off = canvas.parent().offset();
			var cxf = Std.int((e.pageX - off.left) / zoomView) / tileSize;
			var cyf = Std.int((e.pageY - off.top) / zoomView) / tileSize;
			var cx = Std.int(cxf);
			var cy = Std.int(cyf);
			if( cx < width && cy < height ) {
				cursor.show();
				var fc = currentLayer.floatCoord;
				var w = 1., h = 1.;
				var border = 0;
				var ccx = fc ? cxf : cx, ccy = fc ? cyf : cy;
				if( currentLayer.hasSize && mouseDown ) {
					var px = fc ? startPos.xf : startPos.x;
					var py = fc ? startPos.yf : startPos.y;
					var pw = (fc?cxf:cx) - px;
					var ph = (fc?cyf:cy) - py;
					if( pw < 0.5 ) pw = fc ? 0.5 : 1;
					if( ph < 0.5 ) ph = fc ? 0.5 : 1;
					ccx = px;
					ccy = py;
					w = pw;
					h = ph;
				}
				if( currentLayer.images == null )
					border = 1;
				cursor.css({
					marginLeft : Std.int(ccx * tileSize * zoomView - border) + "px",
					marginTop : Std.int(ccy * tileSize * zoomView - border) + "px",
					width : Std.int(w * tileSize * zoomView + border * 2) + "px",
					height : Std.int(h * tileSize * zoomView + border * 2) + "px"
				});
				curPos = { x : cx, y : cy, xf : cxf, yf : cyf };
				J(".cursorPosition").text(cx + "," + cy);
				if( mouseDown ) set(cx, cy);
			} else {
				cursor.hide();
				curPos = null;
				J(".cursorPosition").text("");
			}
		});
		function onMouseUp(_) {
			mouseDown = false;
			if( needSave ) save();
		}
		scroll.mousedown(function(e) {
			switch( e.which ) {
			case 1:
				mouseDown = true;
				if( curPos != null ) {
					set(curPos.x, curPos.y);
					startPos = Reflect.copy(curPos);
				}
			case 3:
				var p = pick();
				if( p != null ) {
					p.layer.current = p.k;
					setCursor(p.layer);
				}
			}
		});
		scroll.mouseleave(onMouseUp);
		scroll.mouseup(function(e) {
			onMouseUp(e);
			if( curPos == null ) {
				startPos = null;
				return;
			}
			switch( currentLayer.data ) {
			case Objects(idCol, objs):
				var fc = currentLayer.floatCoord;
				var px = fc ? curPos.xf : curPos.x;
				var py = fc ? curPos.yf : curPos.y;
				var w = 0., h = 0.;
				if( currentLayer.hasSize ) {
					if( startPos == null ) return;
					var sx = fc ? startPos.xf : startPos.x;
					var sy = fc ? startPos.yf : startPos.y;
					w = px - sx;
					h = py - sy;
					px = sx;
					py = sy;
					if( w < 0.5 ) w = fc ? 0.5 : 1;
					if( h < 0.5 ) h = fc ? 0.5 : 1;
				}
				for( i in 0...objs.length ) {
					var o = objs[i];
					if( o.x == px && o.y == py ) {
						editProps(currentLayer, i);
						return;
					}
				}
				var o : { x : Float, y : Float, ?width : Float, ?height : Float } = { x : px, y : py };
				objs.push(o);
				if( idCol != null )
					Reflect.setField(o, idCol, currentLayer.indexToId[currentLayer.current]);
				for( c in currentLayer.baseSheet.columns ) {
					if( c.opt || c.name == "x" || c.name == "y" || c.name == idCol ) continue;
					var v = model.getDefault(c);
					if( v != null ) Reflect.setField(o, c.name, v);
				}
				if( currentLayer.hasSize ) {
					o.width = w;
					o.height = h;
				}
				editProps(currentLayer, objs.length - 1);
				objs.sort(function(o1, o2) {
					var r = Reflect.compare(o1.y, o2.y);
					return if( r == 0 ) Reflect.compare(o1.x, o2.x) else r;
				});
				draw();
				save();
			default:
			}
			startPos = null;
		});
	}

	function editProps( l : LayerData, index : Int ) {
		var hasProp = false;
		var o = Reflect.field(obj, l.name)[index];
		var idCol = switch( l.data ) { case Objects(idCol, _): idCol; default: null; };
		for( c in l.baseSheet.columns )
			if( c.name != "x" && c.name != "y" && c.name != idCol )
				hasProp = true;
		if( !hasProp ) return;
		var popup = J("<div>").addClass("popup").prependTo(content.find(".scrollContent"));
		J(js.Browser.window).bind("mousedown", function(_) {
			popup.remove();
			draw();
			J(js.Browser.window).unbind("mousedown");
		});
		popup.mousedown(function(e) e.stopPropagation());
		popup.mouseup(function(e) e.stopPropagation());
		popup.click(function(e) e.stopPropagation());

		var table = J("<table>").appendTo(popup);
		var main = Std.instance(model, Main);
		for( c in l.baseSheet.columns ) {
			var tr = J("<tr>").appendTo(table);
			var th = J("<th>").text(c.name).appendTo(tr);
			var td = J("<td>").html(main.valueHtml(c, Reflect.field(o, c.name), l.baseSheet, o)).appendTo(tr);
			td.click(function(e) {
				var psheet : Sheet = {
					columns : l.baseSheet.columns, // SHARE
					props : l.baseSheet.props, // SHARE
					name : l.baseSheet.name, // same
					path : model.getPath(l.baseSheet) + ":" + index, // unique
					parent : { sheet : sheet, column : Lambda.indexOf(sheet.columns,Lambda.find(sheet.columns,function(c) return c.name == l.name)), line : index },
					lines : Reflect.field(obj, l.name), // ref
					separators : [], // none
				};
				main.editCell(c, td, psheet, index);
				e.preventDefault();
				e.stopPropagation();
			});
		}

		popup.css( { marginLeft : Std.int((o.x + 1) * tileSize * zoomView) + "px", marginTop : Std.int((o.y + 1) * tileSize * zoomView) + "px" } );
	}

	function updateZoom( ?f ) {
		if( f != null ) {
			J(".popup").remove();
			if( f ) zoomView *= 1.2 else zoomView /= 1.2;
		}
		savePrefs();
		content.find("canvas").css( { width : Std.int(width * tileSize * zoomView)+"px", height : Std.int(height * tileSize * zoomView)+"px" } );
		setCursor(currentLayer);
	}

	public function onKey( e : js.html.KeyboardEvent ) {
		if( e.ctrlKey || curPos == null ) return;
		switch( e.keyCode ) {
		case "P".code:
			var x = curPos.x;
			var y = curPos.y;
			switch( currentLayer.data ) {
			case Layer(data):
				if( data[x + y * width] == currentLayer.current ) return;
				function fillRec(x, y, k) {
					if( data[x + y * width] != k ) return;
					data[x + y * width] = currentLayer.current;
					currentLayer.dirty = true;
					if( x > 0 ) fillRec(x - 1, y, k);
					if( y > 0 ) fillRec(x, y - 1, k);
					if( x < width - 1 ) fillRec(x + 1, y, k);
					if( y < height - 1 ) fillRec(x, y + 1, k);
				}
				fillRec(x, y, data[x + y * width]);
				save();
				draw();
			default:
			}
		case K.NUMPAD_ADD:
			updateZoom(true);
		case K.NUMPAD_SUB:
			updateZoom(false);
		case K.DELETE:
			var p = pick();
			if( p == null ) return;
			switch( p.layer.data ) {
			case Layer(data):
				if( data[p.index] == 0 ) return;
				data[p.index] = 0;
				p.layer.dirty = true;
				save();
				draw();
			case Objects(_, objs):
				if( objs.remove(objs[p.index]) ) {
					save();
					draw();
				}
			}
		case "E".code:
			var p = pick();
			switch( p.layer.data ) {
			case Layer(_):
			case Objects(_,objs):
				J(".popup").remove();
				editProps(p.layer, p.index);
			}
		case K.ESC:
			J(".popup").remove();
			draw();
		default:
		}
	}

	function set( x, y ) {
		switch( currentLayer.data ) {
		case Layer(data):
			if( data[x + y * width] == currentLayer.current ) return;
			data[x + y * width] = currentLayer.current;
			currentLayer.dirty = true;
			save();
			draw();
		case Objects(_):
		}
	}

	function draw() {
		ctx.fillStyle = "black";
		ctx.globalAlpha = 1;
		ctx.fillRect(0, 0, width * tileSize, height * tileSize);
		var curImage = 0;
		for( index in 0...layers.length ) {
			while( curImage < images.length && images[curImage].index == index ) {
				ctx.globalAlpha = 1;
				ctx.drawImage(images[curImage].data, 0, 0);
				curImage++;
			}
			var l = layers[index];
			ctx.globalAlpha = l.props.alpha;
			if( !l.visible )
				continue;
			switch( l.data ) {
			case Layer(data):
				var first = index == 0;
				for( y in 0...height )
					for( x in 0...width ) {
						var k = data[x + y * width];
						if( k == 0 && !first ) continue;
						if( l.images != null ) {
							ctx.drawImage(l.images[k], x * tileSize, y * tileSize);
							continue;
						}
						ctx.fillStyle = toColor(l.colors[k]);
						ctx.fillRect(x * tileSize, y * tileSize, tileSize, tileSize);
					}
			case Objects(idCol, objs):
				if( idCol == null ) {
					ctx.fillStyle = toColor(l.props.color);
					for( o in objs ) {
						var w = l.hasSize ? o.width * tileSize : tileSize;
						var h = l.hasSize ? o.height * tileSize : tileSize;
						ctx.fillRect(o.x * tileSize, o.y * tileSize, w, h);
					}
				} else {
					for( o in objs ) {
						var id : String = Reflect.field(o, idCol);
						var k = l.idToIndex.get(id);
						if( k == null ) {
							ctx.fillStyle = "red";
							ctx.fillRect(o.x * tileSize, o.y * tileSize, tileSize, tileSize);
							ctx.fillStyle = "white";
							ctx.fillText( id == null || id == "" ? "???" : id, o.x * tileSize, (o.y + 0.5) * tileSize + 4);
							continue;
						}
						if( l.images != null ) {
							ctx.drawImage(l.images[k], o.x * tileSize, o.y * tileSize);
							continue;
						}
						ctx.fillStyle = toColor(l.colors[k]);
						var w = l.hasSize ? o.width * tileSize : tileSize;
						var h = l.hasSize ? o.height * tileSize : tileSize;
						ctx.fillRect(o.x * tileSize, o.y * tileSize, w, h);
					}
				}
			}
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

	@:keep function setLock(b:Bool) {
		currentLayer.floatCoord = currentLayer.hasFloatCoord && !b;
		currentLayer.saveState();
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

	@:keep function setTileSize( value : Int ) {
		this.props.tileSize = tileSize = value;
		for( l in layers ) {
			if( !l.hasFloatCoord ) continue;
			switch( l.data ) {
			case Objects(_, objs):
				for( o in objs ) {
					o.x = Std.int(o.x * tileSize) / tileSize;
					o.y = Std.int(o.y * tileSize) / tileSize;
					if( l.hasSize ) {
						o.width = Std.int(o.width * tileSize) / tileSize;
						o.height = Std.int(o.height * tileSize) / tileSize;
					}
				}
			default:
			}
		}
		var canvas = content.find("canvas");
		canvas.attr("width", (width * tileSize) + "px");
		canvas.attr("height", (height * tileSize) + "px");
		setCursor(currentLayer);
		draw();
		save();
	}

	@:keep function toggleOptions() {
		content.find(".submenu").toggle();
		content.find("[name=tileSize]").val("" + tileSize);
	}

	function setCursor( l : LayerData ) {
		content.find(".menu .item.selected").removeClass("selected");
		l.comp.addClass("selected");
		var old = currentLayer;
		currentLayer = l;
		if( old != l ) {
			savePrefs();
			J("[name=alpha]").val(Std.string(Std.int(l.props.alpha * 100)));
			J("[name=visible]").prop("checked", l.visible);
			J("[name=lock]").prop("checked", !l.floatCoord).closest(".item").css({ display : l.hasFloatCoord ? "" : "none" });
			(untyped J("[name=color]")).spectrum("set",toColor(l.props.color)).closest(".item").css({ display : l.idToIndex == null ? "" : "none" });
		}
		var size = Std.int(tileSize * zoomView);
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
	var lock : Bool;
}

enum LayerInnerData {
	Layer( a : Array<Int> );
	Objects( idCol : String, objs : Array<{ x : Float, y : Float, ?width : Float, ?height : Float }> );
}


class LayerData {

	var level : Level;
	public var name : String;
	public var sheet : Sheet;
	public var names : Array<String>;
	public var colors : Array<Int>;
	public var images : Array<js.html.ImageElement>;
	public var props : LayerProps;
	public var data : LayerInnerData;

	public var visible(default,set) : Bool = true;
	public var dirty : Bool;

	public var current(default,set) : Int = 0;
	public var comp : js.JQuery;

	public var baseSheet : Sheet;
	public var idToIndex : Map<String,Int>;
	public var indexToId : Array<String>;
	public var floatCoord : Bool;
	public var hasFloatCoord : Bool;
	public var hasSize : Bool;

	public function new(level, name, p) {
		this.level = level;
		this.name = name;
		props = p;
	}

	public function loadSheetData( sheet : Sheet ) {
		this.sheet = sheet;
		if( sheet == null ) {
			if( props.color == null ) props.color = 0xFF0000;
			colors = [props.color];
			names = [name];
			return;
		}
		var idCol = null;
		for( c in sheet.columns )
			switch( c.type ) {
			case TColor:
				colors = [for( o in sheet.lines ) { var c = Reflect.field(o, c.name); c == null ? 0 : c; } ];
			case TImage:
				images = [];
				var canvas = js.Browser.document.createCanvasElement();
				var size = level.tileSize;
				canvas.setAttribute("width", size+"px");
				canvas.setAttribute("height", size+"px");
				var ctx = canvas.getContext2d();

				for( idx in 0...sheet.lines.length ) {
					var key = Reflect.field(sheet.lines[idx], c.name);
					var idat = level.model.getImageData(key);
					var i = js.Browser.document.createImageElement();
					images[idx] = i;
					if( idat == null ) {
						ctx.fillStyle = "rgba(0,0,0,0)";
						ctx.fillRect(0, 0, size, size);
						ctx.fillStyle = "white";
						ctx.fillText("#" + idx, 0, 12);
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
		idToIndex = new Map();
		indexToId = [];
		for( index in 0...sheet.lines.length ) {
			var o = sheet.lines[index];
			var n = if( sheet.props.displayColumn != null ) Reflect.field(o, sheet.props.displayColumn) else null;
			if( (n == null || n == "") && idCol != null )
				n = Reflect.field(o, idCol.name);
			if( n == null || n == "" )
				n = "#" + index;
			if( idCol != null ) {
				var id = Reflect.field(o, idCol.name);
				if( id != null && id != "" ) idToIndex.set(id, index);
				indexToId[index] = id;
			}
			names.push(n);
		}

		var state : LayerState = try haxe.Unserializer.run(js.Browser.getLocalStorage().getItem(level.sheetPath + ":" + name)) catch( e : Dynamic ) null;
		if( state != null ) {
			visible = state.visible;
			floatCoord = hasFloatCoord && !state.lock;
			if( state.current < names.length ) current = state.current;
		}
	}

	public function setLayerData( val : String ) {
		if( val == null || val == "" )
			data = Layer([for( x in 0...level.width * level.height ) 0]);
		else {
			var a = haxe.crypto.Base64.decode(val);
			if( a.length != level.width * level.height ) throw "Invalid layer data";
			data = Layer([for( i in 0...level.width * level.height ) a.get(i)]);
		}
		if( sheet.lines.length > 256 ) throw "Too many lines";
	}

	public function setObjectsData( id, val ) {
		data = Objects(id, val);
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

	public function saveState() {
		var s : LayerState = {
			current : current,
			visible : visible,
			lock : hasFloatCoord && !floatCoord,
		};
		js.Browser.getLocalStorage().setItem(level.sheetPath + ":" + name, haxe.Serializer.run(s));
	}

	public function getData() : Dynamic {
		switch( data ) {
		case Layer(data):
			var b = haxe.io.Bytes.alloc(level.width * level.height);
			var p = 0;
			for( y in 0...level.height )
				for( x in 0...level.width ) {
					b.set(p, data[p]);
					p++;
				}
			return haxe.crypto.Base64.encode(b);
		case Objects(_, objs):
			return objs;
		}
	}


}

