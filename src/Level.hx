import cdb.Data;
import js.JQuery.JQueryHelper.*;
import Main.K;
import lvl.LayerData;

import nodejs.webkit.Menu;
import nodejs.webkit.MenuItem;
import nodejs.webkit.MenuItemType;

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
	public var sheet : Sheet;

	var obj : Dynamic;
	var content : js.JQuery;
	var layers : Array<LayerData>;
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

	var view : lvl.Image3D;

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
	}

	public function getName() {
		var name = "#"+index;
		for( c in sheet.columns ) {
			var v : Dynamic = Reflect.field(obj, c.name);
			switch( c.type ) {
			case TString if( c.name == sheet.props.displayColumn && v != null && v != "" ):
				return v;
			case TId:
				name = v;
			default:
			}
		}
		return name;
	}

	public function init() {
		layers = [];
		watchList = [];
		watchTimer = new haxe.Timer(50);
		watchTimer.run = checkWatch;
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
						l.listColumnn = c;
						layers.push(l);
					}
					newLayer = c;
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
		if( content != null ) content.html("");
		if( view != null ) {
			view.dispose();
			var ca = view.getCanvas();
			ca.parentNode.removeChild(ca);
			view = null;
		}
		watchTimer.stop();
		watchTimer = null;
	}

	public function isDisposed() {
		return watchTimer == null;
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
		if( isDisposed() ) return;

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

	@:keep function action(name) {
		switch( name ) {
		case "close":
			cast(model, Main).closeLevel(this);
		case 'options':
			var opt = content.find(".submenu.options");
			var hide = opt.is(":visible");
			content.find(".submenu").hide();
			if( hide )
				content.find(".submenu.layer").show();
			else {
				opt.show();
				content.find("[name=tileSize]").val("" + tileSize);
			}
		case 'layer':
			if( newLayer == null ) return;
			var opt = content.find(".submenu.newlayer");
			var hide = opt.is(":visible");
			content.find(".submenu").hide();
			if( hide )
				content.find(".submenu.layer").show();
			else {
				opt.show();
				content.find("[name=newName]").val("");
			}
		case 'file':
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
	}

	@:keep function addNewLayer( name ) {
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

	function popupLayer( l : LayerData, mouseX : Int, mouseY : Int ) {
		setCursor(l);

		var n = new Menu();
		var nclear = new MenuItem( { label : "Clear" } );
		var ndel = new MenuItem( { label : "Delete" } );
		for( m in [nclear, ndel] )
			n.append(m);
		nclear.click = function() {
			switch( l.data ) {
			case Tiles(_, data):
				for( i in 0...data.length )
					data[i] = 0;
			case Objects(_, objs):
				while( objs.length > 0 ) objs.pop();
			case Layer(data):
				for( i in 0...data.length )
					data[i] = 0;
			}
			l.dirty = true;
			save();
			draw();
		};
		ndel.enabled = l.listColumnn != null;
		ndel.click = function() {
			var layers : Array<Dynamic> = Reflect.field(obj, l.listColumnn.name);
			layers.remove(l.targetObj.o);
			save();
			reload();
		};
		n.popup(mouseX, mouseY);
	}


	public function onResize() {
		var win = nodejs.webkit.Window.get();
		content.find(".scroll").css("height", (win.height - 240) + "px");
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
			td.mousedown(function(e) {
				switch( e.which ) {
				case 1:
					setCursor(l);
				case 3:
					popupLayer(l, e.pageX, e.pageY);
					e.preventDefault();
				}
			});
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



		var scroll = content.find(".scroll");
		var scont = content.find(".scrollContent");

		view = lvl.Image3D.getInstance();
		var ca = view.getCanvas();
		ca.className = "display";
		scont.append(ca);

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

		onResize();

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
					setCursor(currentLayer);
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
		if( currentLayer == null ) return;
		var off = J(view.getCanvas()).parent().offset();
		var cxf = Std.int((mousePos.x - off.left) / zoomView) / tileSize;
		var cyf = Std.int((mousePos.y - off.top) / zoomView) / tileSize;
		var cx = Std.int(cxf);
		var cy = Std.int(cyf);
		if( cx < width && cy < height ) {
			cursor.show();
			var fc = currentLayer.floatCoord;
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
				cursorImage.setSize( Std.int(pw * tileSize * zoomView), Std.int(ph * tileSize * zoomView) );
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
		view.setSize(Std.int(width * tileSize * zoomView), Std.int(height * tileSize * zoomView));
		view.zoom = zoomView;
		draw();
		updateCursorPos();
		setCursor(currentLayer);
	}

	function paint(x, y) {
		var l = currentLayer;
		switch( l.data ) {
		case Layer(data):
			if( data[x + y * width] == l.current || l.blanks[l.current] ) return;
			var k = data[x + y * width];
			var todo = [x, y];
			while( todo.length > 0 ) {
				var y = todo.pop();
				var x = todo.pop();
				if( data[x + y * width] != k ) continue;
				data[x + y * width] = l.current;
				l.dirty = true;
				if( x > 0 ) {
					todo.push(x - 1);
					todo.push(y);
				}
				if( y > 0 ) {
					todo.push(x);
					todo.push(y - 1);
				}
				if( x < width - 1 ) {
					todo.push(x + 1);
					todo.push(y);
				}
				if( y < height - 1 ) {
					todo.push(x);
					todo.push(y + 1);
				}
			}
			save();
			draw();
		case Tiles(_, data):
			if( data[x + y * width] != 0 ) return;
			var px = x, py = y, zero = [], todo = [x, y];
			while( todo.length > 0 ) {
				var y = todo.pop();
				var x = todo.pop();
				if( data[x + y * width] != 0 ) continue;
				var dx = (x - px) % l.currentWidth; if( dx < 0 ) dx += l.currentWidth;
				var dy = (y - py) % l.currentHeight; if( dy < 0 ) dy += l.currentHeight;
				var t = l.current + (randomMode ? Std.random(l.currentWidth) + Std.random(l.currentHeight) * l.imagesStride : dx + dy * l.imagesStride);
				if( l.blanks[t] )
					zero.push(x + y * width);
				data[x + y * width] = t + 1;
				l.dirty = true;
				if( x > 0 ) {
					todo.push(x - 1);
					todo.push(y);
				}
				if( y > 0 ) {
					todo.push(x);
					todo.push(y - 1);
				}
				if( x < width - 1 ) {
					todo.push(x + 1);
					todo.push(y);
				}
				if( y < height - 1 ) {
					todo.push(x);
					todo.push(y + 1);
				}
			}
			for( z in zero )
				data[z] = 0;
			save();
			draw();
		default:
		}
	}

	public function onKey( e : js.html.KeyboardEvent ) {
		if( e.ctrlKey && e.keyCode == K.F4 )
			action("close");
		if( e.ctrlKey ) return;


		switch( e.keyCode ) {
		case K.NUMPAD_ADD:
			updateZoom(true);
		case K.NUMPAD_SUB:
			updateZoom(false);
		case K.NUMPAD_DIV:
			zoomView = 1;
			updateZoom();
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

		if( curPos == null ) return;

		switch( e.keyCode ) {
		case "P".code:
			paint(curPos.x, curPos.y);
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
		view.fill(0xFFE0E0E0);
		for( index in 0...layers.length ) {
			var l = layers[index];
			view.alpha = l.props.alpha;
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
							view.draw(l.images[k], x * tileSize, y * tileSize);
							continue;
						}
						view.fillRect(x * tileSize, y * tileSize, tileSize, tileSize, l.colors[k] | 0xFF000000);
					}
			case Tiles(t, data):
				for( y in 0...height )
					for( x in 0...width ) {
						var k = data[x + y * width] - 1;
						if( k < 0 ) continue;
						view.draw(l.images[k], x * tileSize, y * tileSize);
					}
			case Objects(idCol, objs):
				if( idCol == null ) {
					var col = l.props.color | 0xFF000000;
					for( o in objs ) {
						var w = l.hasSize ? o.width * tileSize : tileSize;
						var h = l.hasSize ? o.height * tileSize : tileSize;
						view.fillRect(Std.int(o.x * tileSize), Std.int(o.y * tileSize), Std.int(w), Std.int(h), col);
					}
				} else {
					for( o in objs ) {
						var id : String = Reflect.field(o, idCol);
						var k = l.idToIndex.get(id);
						if( k == null ) {
							var w = l.hasSize ? o.width * tileSize : tileSize;
							var h = l.hasSize ? o.height * tileSize : tileSize;
							view.fillRect(Std.int(o.x * tileSize), Std.int(o.y * tileSize), Std.int(w), Std.int(h), 0xFFFF00FF);
							continue;
						}
						if( l.images != null ) {
							view.draw(l.images[k], Std.int(o.x * tileSize), Std.int(o.y * tileSize));
							continue;
						}
						var w = l.hasSize ? o.width * tileSize : tileSize;
						var h = l.hasSize ? o.height * tileSize : tileSize;
						view.fillRect(Std.int(o.x * tileSize), Std.int(o.y * tileSize), Std.int(w), Std.int(h), l.colors[k] | 0xFF000000);
					}
				}
			}
		}
		view.flush();
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

	@:keep function scroll( dx : Int, dy : Int ) {
		for( l in layers ) {
			l.dirty = true;
			switch( l.data ) {
			case Tiles(_, data), Layer(data):
				var ndata = [];
				for( y in 0...height )
					for( x in 0...width ) {
						var tx = x - dx;
						var ty = y - dy;
						var k;
						if( tx < 0 || ty < 0 || tx >= width || ty >= height )
							k = 0;
						else
							k = data[tx + ty * width];
						ndata.push(k);
					}
				for( i in 0...width * height )
					data[i] = ndata[i];
			case Objects(_, objs):
				for( o in objs ) {
					o.x += dx;
					o.y += dy;
				}
			}
		}
		draw();
		save();
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
			var used = [];
			switch( l.data ) {
			case Tiles(_, data):
				for( k in data ) {
					if( k == 0 ) continue;
					used[k - 1] = true;
				}
			case Layer(data):
				for( k in data )
					used[k] = true;
			case Objects(id, objs):
				for( o in objs ) {
					var id = l.idToIndex.get(Reflect.field(o, id));
					if( id != null ) used[id] = true;
				}
			}
			for( i in 0...l.images.length ) {
				if( used[i] ) continue;
				paletteSelect.fillRect( (i % l.imagesStride) * (tileSize + 1), Std.int(i / l.imagesStride) * (tileSize + 1), tileSize, tileSize, 0x80000000);
			}
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
