import cdb.Data;
import js.JQuery.JQueryHelper.*;
import Main.K;
import lvl.LayerData;

typedef LevelState = {
	var curLayer : String;
	var zoomView : Float;
	var scrollX : Int;
	var scrollY : Int;
	var paintMode : Bool;
	var randomMode : Bool;
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
	var backgroundImages : Array<{ index : Int, data : lvl.Image }>;
	var props : LevelProps;

	var currentLayer : LayerData;
	var cursor : js.JQuery;
	var cursorImage : lvl.Image;
	var zoomView = 1.;
	var curPos : { x : Int, y : Int, xf : Float, yf : Float };
	var mouseDown : Bool;
	var delDown : Bool;
	var needSave : Bool;
	var waitCount : Int;

	var ctx : js.html.CanvasRenderingContext2D;
	var displayCanvas : js.html.CanvasRenderingContext2D;

	var mousePos = { x : 0, y : 0 };
	var startPos : { x : Int, y : Int, xf : Float, yf : Float } = null;
	var newLayer : Column;

	var palette : js.JQuery;
	var paletteSelect : lvl.Image;
	var paintMode : Bool;
	var randomMode : Bool;

	var watchList : Array<{ path : String, time : Float, callb : Void -> Void }>;
	var watchTimer : haxe.Timer;

	public function new( model : Model, sheet : Sheet, index : Int ) {
		this.sheet = sheet;
		this.sheetPath = model.getPath(sheet);
		this.index = index;
		this.obj = sheet.lines[index];
		this.model = model;
		layers = [];
		watchList = [];
		watchTimer = new haxe.Timer(50);
		watchTimer.run = checkWatch;
		backgroundImages = [];
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

		waitCount = 1;

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
				var l = new LayerData(this, c.name, getProps(c.name), { o : obj, f : c.name });
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
					var l = new LayerData(this, c.name, getProps(c.name), { o : obj, f : c.name });
					l.hasFloatCoord = l.floatCoord = floatCoord;
					l.baseSheet = sheet;
					l.loadSheetData(sid);
					l.setObjectsData(idCol, val);
					l.hasSize = model.hasColumn(sheet, "width", [floatCoord?TFloat:TInt]) && model.hasColumn(sheet, "height", [floatCoord?TFloat:TInt]);
					layers.push(l);
				} else if( model.hasColumn(sheet, "name", [TString]) && model.hasColumn(sheet, "data", [TTileLayer]) ) {
					var val : Array<{ name : String, data : Dynamic }> = val;
					for( lobj in val ) {
						if( lobj.name == null ) continue;
						var l = new LayerData(this, lobj.name, getProps(lobj.name), { o : lobj, f : "data" });
						l.setTilesData(lobj.data);
						layers.push(l);
					}
					newLayer = c;
				}
			case TFile:
				if( val == null || c.name.toLowerCase().indexOf("layer") < 0 ) continue;
				var index = layers.length;
				var path : String = model.getAbsPath(val);
				switch( path.split(".").pop().toLowerCase() ) {
				case "png", "jpeg", "jpg":
					wait();
					lvl.Image.load(path, function(i) {
						backgroundImages.push( { index : index, data : i } );
						backgroundImages.sort(function(i1, i2) return i1.index - i2.index);
						waitDone();
					});
				case "tmx":
					// TODO
				default:
				}
			case TTileLayer:
				var l = new LayerData(this, c.name, getProps(c.name), { o : obj, f : c.name });
				l.setTilesData(val);
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

		waitDone();
	}

	var reloading = false;
	public function reload() {
		if( !reloading ) {
			reloading = true;
			model.initContent();
		}
	}

	public function dispose() {
		watchTimer.stop();
	}

	public function watch( path : String, callb : Void -> Void ) {
		path = model.getAbsPath(path);
		watchList.push( { path : path, time : getFileTime(path), callb : callb } );
	}

	function checkWatch() {
		for( w in watchList ) {
			var f = getFileTime(w.path);
			if( f != w.time && f != 0. ) {
				w.time = f;
				w.callb();
			}
		}
	}

	function getFileTime(path) {
		return try sys.FileSystem.stat(path).mtime.getTime()*1. catch( e : Dynamic ) 0.;
	}

	public function wait() {
		waitCount++;
	}

	public function waitDone() {

		if( --waitCount != 0 ) return;

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
			paintMode = state.paintMode;
			randomMode = state.randomMode;
		}

		setCursor(layer);
		updateZoom();

		if( state != null ) {
			var sc = content.find(".scroll");
			sc.scrollLeft(state.scrollX);
			sc.scrollTop(state.scrollY);
		}
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
			case Tiles(_,data):
				var idx = curPos.x + curPos.y * width;
				var k = data[idx] - 1;
				if( k < 0 ) continue;
				return { k : k, layer : l, index : idx };
			}
		}
		return null;
	}

	@:keep function addNewLayer( ?name ) {
		if( newLayer == null ) return;
		if( name == null ) {
			var opt = content.find(".submenu.newlayer");
			var hide = opt.is(":visible");
			content.find(".submenu").hide();
			if( hide )
				content.find(".submenu.layer").show();
			else {
				opt.show();
				content.find("[name=newName]").val("");
			}
			return;
		}
		switch( newLayer.type ) {
		case TList:
			var s = model.getPseudoSheet(sheet, newLayer);
			var o = { name : null, data : null };
			for( c in s.columns ) {
				var v = model.getDefault(c);
				if( v != null ) Reflect.setField(o, c.name, v);
			}
			var a : Array<{ name : String, data : cdb.Types.TileLayer }> = Reflect.field(obj, newLayer.name);
			o.name = name;
			a.push(o);
			var n = a.length - 2;
			while( n >= 0 ) {
				var o2 = a[n--];
				if( o2.data != null ) {
					var a = cdb.Types.TileLayerData.encode([for( k in 0...width * height ) 0]);
					o.data = cast { file : o2.data.file, size : o2.data.size, stride : o2.data.stride, data : a };
					break;
				}
			}
			save();
			reload();
		default:
		}
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
				if( l.images.length > 0 ) isel.append(J(l.images[l.current].getCanvas()));
				isel.click(function(e) {
					setCursor(l);
					var list = J("<div class='imglist'>");
					for( i in 0...l.images.length )
						list.append(J("<img>").attr("src", l.images[i].getCanvas().toDataURL()).click(function(_) {
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

		content.find('[name=newlayer]').css({ display : newLayer != null ? 'block' : 'none' });


		displayCanvas = cast(content.find("canvas.display")[0], js.html.CanvasElement).getContext2d();

		var canvas = js.Browser.document.createCanvasElement();
		displayCanvas.canvas.width = canvas.width = width * tileSize;
		displayCanvas.canvas.height = canvas.height = height * tileSize;
		ctx = canvas.getContext2d();

		var scroll = content.find(".scroll");
		var scont = content.find(".scrollContent");

		scroll.scroll(function(_) {
			savePrefs();
		});

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
			//updateZoom(untyped e.originalEvent.wheelDelta > 0);
		});

		cursor = content.find("#cursor");
		cursorImage = new lvl.Image(0, 0);
		cursor[0].appendChild(cursorImage.getCanvas());
		cursor.hide();


		scont.mouseleave(function(_) {
			curPos = null;
			cursor.hide();
			J(".cursorPosition").text("");
		});
		scont.mousemove(function(e) {
			mousePos.x = e.pageX;
			mousePos.y = e.pageY;
			updateCursorPos();
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

	function updateCursorPos() {
		var off = J(displayCanvas.canvas).parent().offset();
		var cxf = Std.int((mousePos.x - off.left) / zoomView) / tileSize;
		var cyf = Std.int((mousePos.y - off.top) / zoomView) / tileSize;
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
			});
			curPos = { x : cx, y : cy, xf : cxf, yf : cyf };
			J(".cursorPosition").text(cx + "," + cy);
			if( mouseDown ) set(cx, cy);
		} else {
			cursor.hide();
			curPos = null;
			J(".cursorPosition").text("");
		}

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
		displayCanvas.canvas.width = Std.int(width * tileSize * zoomView);
		displayCanvas.canvas.height = Std.int(height * tileSize * zoomView);
		copy();
		updateCursorPos();
		setCursor(currentLayer);
	}

	function paint(x, y) {
		var l = currentLayer;
		switch( l.data ) {
		case Layer(data):
			if( data[x + y * width] == l.current || l.blanks[l.current] ) return;
			function fillRec(x, y, k) {
				if( data[x + y * width] != k ) return;
				data[x + y * width] = l.current;
				l.dirty = true;
				if( x > 0 ) fillRec(x - 1, y, k);
				if( y > 0 ) fillRec(x, y - 1, k);
				if( x < width - 1 ) fillRec(x + 1, y, k);
				if( y < height - 1 ) fillRec(x, y + 1, k);
			}
			fillRec(x, y, data[x + y * width]);
			save();
			draw();
		case Tiles(_, data):
			if( data[x + y * width] != 0 ) return;
			var px = x, py = y, zero = [];
			function fillRec(x, y, k) {
				if( data[x + y * width] != 0 ) return;
				var dx = (x - px) % l.currentWidth; if( dx < 0 ) dx += l.currentWidth;
				var dy = (y - py) % l.currentHeight; if( dy < 0 ) dy += l.currentHeight;
				var t = l.current + (randomMode ? Std.random(l.currentWidth) + Std.random(l.currentHeight) * l.imagesStride : dx + dy * l.imagesStride);
				if( l.blanks[t] )
					zero.push(x + y * width);
				data[x + y * width] = t + 1;
				l.dirty = true;
				if( x > 0 ) fillRec(x - 1, y, k);
				if( y > 0 ) fillRec(x, y - 1, k);
				if( x < width - 1 ) fillRec(x + 1, y, k);
				if( y < height - 1 ) fillRec(x, y + 1, k);
			}
			fillRec(x, y, data[x + y * width]);
			for( z in zero )
				data[z] = 0;
			save();
			draw();
		default:
		}
	}

	public function onKey( e : js.html.KeyboardEvent ) {
		if( e.ctrlKey || curPos == null ) return;
		switch( e.keyCode ) {
		case "P".code:
			paint(curPos.x, curPos.y);
		case K.NUMPAD_ADD:
			updateZoom(true);
		case K.NUMPAD_SUB:
			updateZoom(false);
		case K.DELETE:
			delDown = true;
			var p = pick();
			if( p == null ) return;
			switch( p.layer.data ) {
			case Layer(data):
				if( data[p.index] == 0 ) return;
				data[p.index] = 0;
				p.layer.dirty = true;
				cursor.css({ opacity : 0 }).fadeTo(100,1);
				save();
				draw();
			case Objects(_, objs):
				if( objs.remove(objs[p.index]) ) {
					save();
					draw();
				}
			case Tiles(_, data):
				var changed = false;
				var l = currentLayer;
				for( dy in 0...l.currentHeight )
					for( dx in 0...l.currentWidth ) {
						var i = p.index + dx + dy * width;
						if( data[i] == 0 ) continue;
						data[i] = 0;
						changed = true;
					}
				if( changed ) {
					p.layer.dirty = true;
					cursor.css({ opacity : 0 }).fadeTo(100,1);
					save();
					draw();
				}
			}
		case "E".code:
			var p = pick();
			switch( p.layer.data ) {
			case Layer(_), Tiles(_):
			case Objects(_,objs):
				J(".popup").remove();
				editProps(p.layer, p.index);
			}
		case K.ESC:
			J(".popup").remove();
			draw();
		case K.TAB:
			var i = (layers.indexOf(currentLayer) + (e.shiftKey ? layers.length-1 : 1) ) % layers.length;
			setCursor(layers[i]);
			e.preventDefault();
			e.stopPropagation();
		default:
		}
	}

	public function onKeyUp( e : js.html.KeyboardEvent ) {
		switch( e.keyCode ) {
		case K.DELETE:
			delDown = false;
			if( needSave ) save();
		default:
		}
	}

	function set( x, y ) {
		if( paintMode ) {
			paint(x,y);
			return;
		}
		var l = currentLayer;
		switch( l.data ) {
		case Layer(data):
			if( data[x + y * width] == l.current || l.blanks[l.current] ) return;
			data[x + y * width] = l.current;
			l.dirty = true;
			save();
			draw();
		case Tiles(_, data):
			var changed = false;
			if( randomMode ) {
				var p = x + y * width;
				var id = l.current + Std.random(l.currentWidth) + Std.random(l.currentHeight) * l.imagesStride + 1;
				if( data[p] == id || l.blanks[id - 1] ) return;
				data[p] = id;
				changed = true;
			} else {
				for( dy in 0...l.currentHeight )
					for( dx in 0...l.currentWidth ) {
						var p = x + dx + (y + dy) * width;
						var id = l.current + dx + dy * l.imagesStride + 1;
						if( data[p] == id || l.blanks[id - 1] ) continue;
						data[p] = id;
						changed = true;
					}
			}
			if( !changed ) return;
			l.dirty = true;
			save();
			draw();
		case Objects(_):
		}
	}

	public function draw() {
		ctx.fillStyle = "black";
		ctx.globalAlpha = 1;
		ctx.fillRect(0, 0, width * tileSize, height * tileSize);
		var curImage = 0;
		for( index in 0...layers.length ) {
			while( curImage < backgroundImages.length && backgroundImages[curImage].index == index ) {
				ctx.globalAlpha = 1;
				ctx.drawImage(backgroundImages[curImage].data.getCanvas(), 0, 0);
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
							ctx.drawImage(l.images[k].getCanvas(), x * tileSize, y * tileSize);
							continue;
						}
						ctx.fillStyle = toColor(l.colors[k]);
						ctx.fillRect(x * tileSize, y * tileSize, tileSize, tileSize);
					}
			case Tiles(t, data):
				for( y in 0...height )
					for( x in 0...width ) {
						var k = data[x + y * width] - 1;
						if( k < 0 ) continue;
						ctx.drawImage(l.images[k].getCanvas(), x * tileSize, y * tileSize, tileSize, tileSize);
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
							ctx.drawImage(l.images[k].getCanvas(), o.x * tileSize, o.y * tileSize);
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
		copy();
	}

	function copy() {
		var canvas = ctx.canvas;
		displayCanvas.imageSmoothingEnabled = zoomView < 1;
		displayCanvas.drawImage(canvas, 0, 0, canvas.width, canvas.height, 0, 0, displayCanvas.canvas.width, displayCanvas.canvas.height);
	}

	function save() {
		if( mouseDown || delDown ) {
			needSave = true;
			return;
		}
		needSave = false;
		for( l in layers )
			l.save();
		model.save();
	}

	function savePrefs() {
		var sc = content.find(".scroll");
		var state : LevelState = {
			zoomView : zoomView,
			curLayer : currentLayer.name,
			scrollX : sc.scrollLeft(),
			scrollY : sc.scrollTop(),
			paintMode : paintMode,
			randomMode : randomMode,
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
		var opt = content.find(".submenu.options");
		var hide = opt.is(":visible");
		content.find(".submenu").hide();
		if( hide )
			content.find(".submenu.layer").show();
		else {
			opt.show();
			content.find("[name=tileSize]").val("" + tileSize);
		}
	}

	@:keep function setSize(size) {
		switch( currentLayer.data ) {
		case Tiles(t, _):
			t.stride = Std.int(t.size * t.stride / size);
			t.size = size;
			currentLayer.dirty = true;
			save();
			reload();
		default:
		}
	}

	@:keep function selectFile() {
		var m = cast(model, Main);
		m.chooseFile(function(path) {
			switch( currentLayer.data ) {
			case Tiles(t, data):
				t.file = path;
				currentLayer.dirty = true;
				save();
				reload();
			default:
			}
		});
	}

	@:keep function paletteOption(name) {
		var l = currentLayer;
		switch( name ) {
		case "random":
			randomMode = !randomMode;
			palette.find(".icon.random").toggleClass("active", randomMode);
			savePrefs();
			setCursor(l);
		case "paint":
			paintMode = !paintMode;
			savePrefs();
			palette.find(".icon.paint").toggleClass("active",paintMode);
		}
	}

	function setCursor( l : LayerData ) {
		content.find(".menu .item.selected").removeClass("selected");
		l.comp.addClass("selected");
		var old = currentLayer;
		currentLayer = l;
		if( old != l ) {
			savePrefs();
			content.find("[name=alpha]").val(Std.string(Std.int(l.props.alpha * 100)));
			content.find("[name=visible]").prop("checked", l.visible);
			content.find("[name=lock]").prop("checked", !l.floatCoord).closest(".item").css({ display : l.hasFloatCoord ? "" : "none" });
			(untyped content.find("[name=color]")).spectrum("set", toColor(l.props.color)).closest(".item").css( { display : l.idToIndex == null && !l.data.match(Tiles(_)) ? "" : "none" } );
			switch( l.data ) {
			case Tiles(t,_):
				content.find("[name=size]").val("" + t.size).closest(".item").show();
				content.find("[name=file]").closest(".item").show();
			default:
				content.find("[name=size]").closest(".item").hide();
				content.find("[name=file]").closest(".item").hide();
			}

			if( palette != null ) {
				palette.remove();
				paletteSelect = null;
			}
			if( l.images != null ) {
				palette = J(J("#paletteContent").html()).appendTo(content);
				var i = lvl.Image.fromCanvas(cast palette.find("canvas.view")[0]);
				i.setSize(l.imagesStride * (tileSize + 1), Math.ceil(l.images.length / l.imagesStride) * (tileSize + 1));
				for( n in 0...l.images.length ) {
					var x = (n % l.imagesStride) * (tileSize + 1);
					var y = Std.int(n / l.imagesStride) * (tileSize + 1);
					i.draw(l.images[n], x, y);
				}
				var jsel = palette.find("canvas.select");
				var select = lvl.Image.fromCanvas(cast jsel[0]);
				select.setSize(i.width, i.height);

				palette.find(".icon.random").toggleClass("active",randomMode);
				palette.find(".icon.paint").toggleClass("active",paintMode);

				var start = { x : l.current % l.imagesStride, y : Std.int(l.current / l.imagesStride), down : false };
				jsel.mousedown(function(e) {
					var o = jsel.offset();
					var x = Std.int((e.pageX - o.left) / (tileSize + 1));
					var y = Std.int((e.pageY - o.top) / (tileSize + 1));
					if( e.shiftKey ) {
						var x0 = x < start.x ? x : start.x;
						var y0 = y < start.y ? y : start.y;
						var x1 = x < start.x ? start.x : x;
						var y1 = y < start.y ? start.y : y;
						l.current = x0 + y0 * l.imagesStride;
						l.currentWidth = x1 - x0 + 1;
						l.currentHeight = y1 - y0 + 1;
						l.saveState();
						setCursor(l);
					} else {
						start.x = x;
						start.y = y;
						start.down = true;
						l.current = x + y * l.imagesStride;
						setCursor(l);
					}
				});
				jsel.mousemove(function(e) {
					if( !start.down ) return;
					var o = jsel.offset();
					var x = Std.int((e.pageX - o.left) / (tileSize + 1));
					var y = Std.int((e.pageY - o.top) / (tileSize + 1));
					var x0 = x < start.x ? x : start.x;
					var y0 = y < start.y ? y : start.y;
					var x1 = x < start.x ? start.x : x;
					var y1 = y < start.y ? start.y : y;
					l.current = x0 + y0 * l.imagesStride;
					l.currentWidth = x1 - x0 + 1;
					l.currentHeight = y1 - y0 + 1;
					l.saveState();
					setCursor(l);
				});
				jsel.mouseup(function(e) {
					start.down = false;
				});
				paletteSelect = select;
			}
		}

		if( paletteSelect != null ) {
			paletteSelect.clear();
			paletteSelect.fillRect( (l.current % l.imagesStride) * (tileSize + 1), Std.int(l.current / l.imagesStride) * (tileSize + 1), (tileSize + 1) * l.currentWidth - 1, (tileSize + 1) * l.currentHeight - 1, 0x805BA1FB);
		}

		var size = zoomView < 1 ? Std.int(tileSize * zoomView) : Math.ceil(tileSize * zoomView);
		var w = randomMode ? 1 : l.currentWidth;
		var h = randomMode ? 1 : l.currentHeight;
		cursorImage.setSize(size * w,size * h);
		if( l.images != null ) {
			cursorImage.clear();
			for( y in 0...h )
				for( x in 0...w ) {
					var i = l.images[l.current + x + y * l.imagesStride];
					cursorImage.drawSub(i, 0, 0, i.width, i.height, x * size, y * size, size, size);
				}
			cursorImage.fill(0x605BA1FB);
			cursor.css( { border : "none" } );
		} else {
			var c = l.colors[l.current];
			var lum = ((c & 0xFF) + ((c >> 8) & 0xFF) + ((c >> 16) & 0xFF)) / (255 * 3);
			cursorImage.fill(c | 0xFF000000);
			cursor.css( { border : "1px solid " + (lum < 0.25 ? "white":"black") } );
		}
	}

}
