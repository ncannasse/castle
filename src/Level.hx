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
	var tagMode : Null<String>;
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
	var paintMode : Bool = false;
	var randomMode : Bool = false;
	var tagMode : Null<String> = null;
	var spaceDown : Bool;

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
		props = obj.props;
		if( props == null ) {
			props = {
			};
			obj.props = props;
		}
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

	public function getTileProps(file,stride) {
		if( props.tileSets == null )
			props.tileSets = {};
		var p : TileProps = Reflect.field(props.tileSets,file);
		if( p == null ) {
			p = {
				stride : stride,
				sets : [],
				tags : [],
			};
			Reflect.setField(props.tileSets, file, p);
		} else {
			if( p.sets == null ) p.sets = [];
			if( p.tags == null ) p.tags = [];
			if( p.stride == null ) p.stride = stride else if( p.stride != stride ) {
				for( t in p.tags ) {
					var out = [];
					for( y in 0...Math.ceil(t.flags.length / p.stride) )
						for( x in 0...p.stride ) {
							if( t.flags[x + y * p.stride] )
								out[x + y * stride] = true;
						}
					t.flags = out;
				}
				p.stride = stride;
			}
		}
		return p;
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
			tagMode = state.tagMode;
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
			case TileInstances(_, insts):
				var objs = l.getTileObjects();
				for( idx in 0...insts.length ) {
					var i = insts[idx];
					var o = objs.get(i.o);
					if( curPos.xf >= i.x && curPos.yf >= i.y && curPos.xf < i.x + (o == null ? 1 : o.w) && curPos.yf < i.y + (o == null ? 1 : o.h) )
						return { k : i.o, layer : l, index : idx };
				}
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
			currentLayer = cast { name : name };
			savePrefs();
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
		var nshow = new MenuItem( { label : "Show Only" } );
		var nshowAll = new MenuItem( { label : "Show All" } );
		for( m in [nshow, nshowAll, nclear, ndel] )
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
			case TileInstances(_, insts):
				while( insts.length > 0 ) insts.pop();
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
		nshow.click = function() {
			for( l2 in layers )
				l2.visible = l == l2;
			draw();
		};
		nshowAll.click = function() {
			for( l2 in layers )
				l2.visible = true;
			draw();
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

		var mlayers = content.find(".layers");
		for( index in 0...layers.length ) {
			var l = layers[index];
			var td = J("<li class='item layer'>").appendTo(mlayers);
			l.comp = td;
			td.data("index", index);
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

		(untyped mlayers.sortable)( {
			vertical : false,
			onDrop : function(item, container, _super) {
				_super(item, container);
				var indexes = [];
				for( i in mlayers.find("li") )
					indexes.push(i.data("index"));
				layers = [for( i in 0...layers.length ) layers[indexes[i]]];
				for( i in 0...layers.length )
					layers[i].comp.data("index", i);

				// update layer list
				var groups = new Map();
				for( l in layers ) {
					if( l.listColumnn == null ) continue;
					var g = groups.get(l.listColumnn.name);
					if( g == null ) {
						g = [];
						groups.set(l.listColumnn.name, g);
					}
					g.push(l);
				}
				for( g in groups.keys() ) {
					var layers = groups.get(g);
					var objs = [for( l in layers ) l.targetObj.o];
					Reflect.setField(obj, g, objs);
				}
				save();
				draw();
			}
		});

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
				save();
				draw();
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
					switch( p.layer.data ) {
					case TileInstances(_, insts):
						var i = insts[p.index];
						var obj = p.layer.getTileObjects().get(i.o);
						if( obj != null ) {
							p.layer.currentWidth = obj.w;
							p.layer.currentHeight = obj.h;
							p.layer.saveState();
						}
					default:
					}
					setCursor(p.layer);
				}
			}
		});
		content.mouseup(function(e) {
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
				save();
				draw();
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
			J(js.Browser.window).unbind("mousedown");
			if( view != null ) draw();
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
		if( !l.visible ) return;
		switch( l.data ) {
		case Layer(data):
			var k = data[x + y * width];
			if( k == l.current || l.blanks[l.current] ) return;
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
			var k = data[x + y * width];
			if( k == l.current || l.blanks[l.current] ) return;
			var px = x, py = y, zero = [], todo = [x, y];
			while( todo.length > 0 ) {
				var y = todo.pop();
				var x = todo.pop();
				if( data[x + y * width] != k ) continue;
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
		if( e.ctrlKey || J(":focus").length > 0 || currentLayer == null ) return;

		J(".popup").remove();

		var l = currentLayer;
		switch( e.keyCode ) {
		case K.NUMPAD_ADD:
			updateZoom(true);
		case K.NUMPAD_SUB:
			updateZoom(false);
		case K.NUMPAD_DIV:
			zoomView = 1;
			updateZoom();
		case K.ESC:
			draw();
		case K.TAB:
			var i = (layers.indexOf(l) + (e.shiftKey ? layers.length-1 : 1) ) % layers.length;
			setCursor(layers[i]);
			e.preventDefault();
			e.stopPropagation();
		case K.SPACE:
			e.preventDefault();
			if( spaceDown ) return;
			spaceDown = true;
			var canvas = J(view.getCanvas());
			canvas.css( { cursor : "move" } );
			cursor.hide();
			var s = canvas.closest(".scroll");
			var curX = null, curY = null;
			canvas.on("mousemove", function(e) {
				var tx = e.pageX;
				var ty = e.pageY;
				if( curX == null ) {
					curX = tx;
					curY = ty;
				}
				var dx = tx - curX;
				var dy = ty - curY;
				s.scrollLeft(s.scrollLeft() - dx);
				s.scrollTop(s.scrollTop() - dy);
				curX += dx;
				curY += dy;
				mousePos.x = e.pageX;
				mousePos.y = e.pageY;
				e.stopPropagation();
			});
		case "O".code:
			if( palette != null ) paletteOption("mode", "object");
		case K.LEFT:
			e.preventDefault();
			if( l.current % l.imagesStride > 0 ) {
				l.current--;
				setCursor(l);
			}
		case K.RIGHT:
			e.preventDefault();
			if( l.current % l.imagesStride < l.imagesStride - 1 ) {
				l.current++;
				setCursor(l);
			}
		case K.DOWN:
			e.preventDefault();
			if( l.current + l.imagesStride < l.images.length ) {
				l.current += l.imagesStride;
				setCursor(l);
			}
		case K.UP:
			e.preventDefault();
			if( l.current >= l.imagesStride ) {
				l.current -= l.imagesStride;
				setCursor(l);
			}
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
			case TileInstances(_, insts):
				if( insts.remove(insts[p.index]) ) {
					p.layer.dirty = true;
					save();
					draw();
					return;
				}
			}
		case "E".code:
			var p = pick();
			switch( p.layer.data ) {
			case Layer(_), Tiles(_), TileInstances(_):
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
		case K.SPACE:
			spaceDown = false;
			var canvas = J(view.getCanvas());
			canvas.unbind("mousemove");
			canvas.css( { cursor : "" } );
			updateCursorPos();
		default:
		}
	}

	function set( x, y ) {
		if( paintMode ) {
			paint(x,y);
			return;
		}
		var l = currentLayer;
		if( !l.visible ) return;
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
		case TileInstances(_, insts):
			var objs = l.getTileObjects();
			var putObj = objs.get(l.current);
			var dx = putObj == null ? 0.5 : (putObj.w * 0.5);
			var dy = putObj == null ? 0.5 : putObj.h - 0.5;
			var x = l.floatCoord ? curPos.xf : curPos.x, y = l.floatCoord ? curPos.yf : curPos.y;
			for( i in insts ) {
				var o = objs.get(i.o);
				var ox = i.x + (o == null ? 0.5 : o.w * 0.5);
				var oy = i.y + (o == null ? 0.5 : o.h - 0.5);
				if( x + dx >= ox - 0.5 && y + dy >= oy - 0.5 && x + dx < ox + 0.5 && y + dy < oy + 0.5 ) {
					if( i.o == l.current && i.x == x && i.y == y ) return;
					insts.remove(i);
				}
			}
			if( putObj != null )
				insts.push( { x : x, y : y, o : l.current } );
			else
				for( dy in 0...l.currentHeight )
					for( dx in 0...l.currentWidth )
						insts.push( { x : x+dx, y : y+dy, o : l.current + dx + dy * l.imagesStride } );
			inline function getY(i) {
				var o = objs.get(i.o);
				return Std.int( (i.y + (o == null ? 1 : o.h)) * tileSize);
			}
			inline function getX(i) {
				var o = objs.get(i.o);
				return Std.int( (i.x + (o == null ? 0.5 : o.w * 0.5)) * tileSize );
			}
			insts.sort(function(i1, i2) { var dy = getY(i1) - getY(i2); return dy == 0 ? getX(i1) - getX(i2) : dy; });
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
				if( l.props.mode == Ground ) {
					var b = new cdb.TileBuilder(l.tileProps, l.imagesStride, l.images.length);
					var a = b.buildGrounds(data, width);
					var p = 0, max = a.length;
					while( p < max ) {
						var x = a[p++];
						var y = a[p++];
						var id = a[p++];
						view.draw(l.images[id], x * tileSize, y * tileSize);
					}
				}
			case TileInstances(_, insts):
				var objs = l.getTileObjects();
				for( i in insts ) {
					var x = Std.int(i.x * tileSize), y = Std.int(i.y * tileSize);
					var obj = objs.get(i.o);
					if( obj == null ) {
						view.draw(l.images[i.o], x, y);
						view.fillRect(x, y, tileSize, tileSize, 0x80FF0000);
					} else {
						for( dy in 0...obj.h )
							for( dx in 0...obj.w )
								view.draw(l.images[i.o + dx + dy * l.imagesStride], x + dx * tileSize, y + dy * tileSize);
					}
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
			curLayer : currentLayer == null ? null : currentLayer.name,
			scrollX : sc.scrollLeft(),
			scrollY : sc.scrollTop(),
			paintMode : paintMode,
			randomMode : randomMode,
			tagMode : tagMode,
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
				for( o in objs.copy() ) {
					o.x += dx;
					o.y += dy;
					if( o.x < 0 || o.y < 0 || o.x >= width || o.y >= height )
						objs.remove(o);
				}
			case TileInstances(_, insts):
				for( i in insts.copy() ) {
					i.x += dx;
					i.y += dy;
					if( i.x < 0 || i.y < 0 || i.x >= width || i.y >= height )
						insts.remove(i);
				}
			}
		}
		save();
		draw();
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
		save();
		draw();
	}

	@:keep function setLayerMode( mode : LayerMode ) {
		var l = currentLayer;
		if( l.tileProps == null ) {
			js.Lib.alert("Choose file first");
			return;
		}
		var old = l.props.mode;
		if( old == null ) old = Tiles;
		switch( [old, mode] ) {
		case [(Ground | Tiles), (Tiles | Ground)]:
			// nothing
		case [(Ground | Tiles), Objects]:
			switch( l.data ) {
			case Tiles(td, data):
				var oids = new Map();
				for( p in l.tileProps.sets )
					if( p.t == Object )
						oids.set(p.x + p.y * l.imagesStride, p);
				var objs = [];
				var p = -1;
				for( y in 0...height )
					for( x in 0...width ) {
						var d = data[++p] - 1;
						if( d < 0 ) continue;
						var o = oids.get(d);
						if( o != null ) {
							for( dy in 0...o.h ) {
								for( dx in 0...o.w ) {
									var tp = p + dx + dy * width;
									if( x + dx >= width || y + dy >= height ) continue;
									var id = d + dx + dy * l.imagesStride;
									if( data[tp] != id + 1 ) {
										if( data[tp] == 0 && l.blanks[id] ) continue;
										o = null;
										break;
									}
								}
								if( o == null ) break;
							}
						}
						if( o == null )
							objs.push({ x : x, y : y, b : y, id : d });
						else {
							for( dy in 0...o.h )
								for( dx in 0...o.w ) {
									if( x + dx >= width || y + dy >= height ) continue;
									data[p + dx + dy * width] = 0;
								}
							objs.push( { x : x, y : y, b : y + o.w - 1, id : d } );
						}
					}
				objs.sort(function(o1,o2) return o1.b - o2.b);
				l.data = TileInstances(td, [for( o in objs ) { x : o.x, y : o.y, o : o.id }]);
				l.dirty = true;
			default:
				throw "assert0";
			}
		case [Objects, (Ground | Tiles)]:
			switch( l.data ) {
			case TileInstances(td,insts):
				var objs = l.getTileObjects();
				var data = [for( i in 0...width * height ) 0];
				for( i in insts ) {
					var x = Std.int(i.x), y = Std.int(i.y);
					var obj = objs.get(i.o);
					if( obj == null ) {
						data[x + y * width] = i.o + 1;
					} else {
						for( dy in 0...obj.h )
							for( dx in 0...obj.w ) {
								var x = x + dx, y = y + dy;
								if( x < width && y < height )
									data[x + y * width] = i.o + dx + dy * l.imagesStride + 1;
							}
					}
				}
				l.data = Tiles(td, data);
				l.dirty = true;
			default:
				throw "assert1";
			}
		default:
			js.Lib.alert("Cannot convert from "+old+" to "+mode);
			return;
		}
		l.props.mode = mode;
		if( mode == Tiles ) Reflect.deleteField(currentLayer.props, "mode");
		save();
		reload();
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

	@:keep function paletteOption(name, ?val:String) {
		var l = currentLayer;
		if( val != null ) val = StringTools.trim(val);
		switch( name ) {
		case "random":
			randomMode = !randomMode;
			if( l.data.match(TileInstances(_)) ) randomMode = false;
			palette.find(".icon.random").toggleClass("active", randomMode);
			savePrefs();
			setCursor(l);
			return;
		case "paint":
			paintMode = !paintMode;
			if( l.data.match(TileInstances(_)) ) paintMode = false;
			savePrefs();
			palette.find(".icon.paint").toggleClass("active", paintMode);
			return;
		case "mode":
			var s = l.getTileProp();
			var m = TileMode.ofString(val);
			if( s == null ) {
				if( m == Tile ) return;
				s = { x : l.current % l.imagesStride, y : Std.int(l.current / l.imagesStride), w : l.currentWidth, h : l.currentHeight, t : m, opts : {} };
				l.tileProps.sets.push(s);
			} else if( m == Tile ) {
				l.tileProps.sets.remove(s);
			} else {
				if( s.t == m ) return;
				s.t = m;
				s.opts = { };
			}
			setCursor(l);
		case "name":
			var s = l.getTileProp();
			if( s != null )
				s.opts.name = val;
		case "priority":
			var s = l.getTileProp();
			if( s != null )
				s.opts.priority = Std.parseInt(val);
		case "border_in":
			var s = l.getTileProp();
			if( s != null ) {
				if( val == "null" )
					Reflect.deleteField(s.opts,"borderIn");
				else
					s.opts.borderIn = val;
			}
		case "border_out":
			var s = l.getTileProp();
			if( s != null ) {
				if( val == "null" )
					Reflect.deleteField(s.opts,"borderOut");
				else
					s.opts.borderOut = val;
			}
		case "border_mode":
			var s = l.getTileProp();
			if( s != null ) {
				if( val == "null" )
					Reflect.deleteField(s.opts,"borderMode");
				else
					s.opts.borderMode = val;
			}
		case "tag":
			tagMode = (tagMode == null ? (l.tileProps.tags.length == 0 ? "" : l.tileProps.tags[0].name) : null);
			palette.find(".icon.tag").toggleClass("active", tagMode != null);
			savePrefs();
			setCursor(l);
		case "addTag":
			if( val == "" ) return;
			for( t in l.tileProps.tags )
				if( t.name == val )
					return;
			l.tileProps.tags.push( { name : val, flags : [] } );
			tagMode = val;
			savePrefs();
			setCursor(l);
		case "delTag":
			for( t in l.tileProps.tags )
				if( t.name == tagMode ) {
					l.tileProps.tags.remove(t);
					var t = l.tileProps.tags[0];
					tagMode = t == null ? "" : t.name;
					savePrefs();
				}
			setCursor(l);
		case "selectTag":
			tagMode = val;
			savePrefs();
			setCursor(l);
		}
		save();
		draw();
	}

	function setCursor( l : LayerData ) {

		if( l == null ) {
			cursor.hide();
			return;
		}

		content.find(".menu .item.selected").removeClass("selected");
		l.comp.addClass("selected");
		var old = currentLayer;
		currentLayer = l;
		if( old != l ) {
			savePrefs();
			content.find("[name=alpha]").val(Std.string(Std.int(l.props.alpha * 100)));
			content.find("[name=visible]").prop("checked", l.visible);
			content.find("[name=lock]").prop("checked", !l.floatCoord).closest(".item").css( { display : l.hasFloatCoord ? "" : "none" } );
			content.find("[name=mode]").val(""+(l.props.mode != null ? l.props.mode : LayerMode.Tiles));
			(untyped content.find("[name=color]")).spectrum("set", toColor(l.props.color)).closest(".item").css( { display : l.idToIndex == null && !l.data.match(Tiles(_) | TileInstances(_)) ? "" : "none" } );
			switch( l.data ) {
			case Tiles(t,_), TileInstances(t,_):
				content.find("[name=size]").val("" + t.size).closest(".item").show();
				content.find("[name=file]").closest(".item").show();
			default:
				content.find("[name=size]").closest(".item").hide();
				content.find("[name=file]").closest(".item").hide();
			}

			if( l.data.match(TileInstances(_)) ) {
				randomMode = false;
				paintMode = false;
				savePrefs();
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
				palette.find(".icon.paint").toggleClass("active", paintMode);
				palette.find(".icon.tag").toggleClass("active", tagMode != null);

				var start = { x : l.current % l.imagesStride, y : Std.int(l.current / l.imagesStride), down : false };
				jsel.mousedown(function(e) {
					var o = jsel.offset();
					var x = Std.int((e.pageX - o.left) / (tileSize + 1));
					var y = Std.int((e.pageY - o.top) / (tileSize + 1));

					if( tagMode != null ) {
						var t = Lambda.find(l.tileProps.tags, function(t) return t.name == tagMode);
						if( t != null ) {
							t.flags[x + y * l.imagesStride] = !t.flags[x + y * l.imagesStride];
							setCursor(l);
							save();
						}
						return;
					}

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
						if( l.tileProps != null )
							for( p in l.tileProps.sets )
								if( x >= p.x && y >= p.y && x < p.x + p.w && y < p.y + p.h && p.t == Object ) {
									l.current = p.x + p.y * l.imagesStride;
									l.currentWidth = p.w;
									l.currentHeight = p.h;
									l.saveState();
									setCursor(l);
									return;
								}
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
			case TileInstances(_, insts):
				var objs = l.getTileObjects();
				for( i in insts ) {
					var t = objs.get(i.o);
					if( t == null ) {
						used[i.o] = true;
						continue;
					}
					for( dy in 0...t.h )
						for( dx in 0...t.w )
							used[i.o + dx + dy * l.imagesStride] = true;
				}
			}

			if( tagMode == null ) {
				for( i in 0...l.images.length ) {
					if( used[i] ) continue;
					paletteSelect.fillRect( (i % l.imagesStride) * (tileSize + 1), Std.int(i / l.imagesStride) * (tileSize + 1), tileSize, tileSize, 0x80000000);
				}
				paletteSelect.fillRect( (l.current % l.imagesStride) * (tileSize + 1), Std.int(l.current / l.imagesStride) * (tileSize + 1), (tileSize + 1) * l.currentWidth - 1, (tileSize + 1) * l.currentHeight - 1, 0x805BA1FB);
			}

			var m = palette.find(".mode");
			var t = palette.find(".tagMode").hide();
			if( l.tileProps == null ) {
				m.hide();
			} else if( tagMode != null ) {
				t.find("[name=tags]").html([for( t in l.tileProps.tags ) '<option value="${t.name}">${t.name}</option>'].join("")).val(tagMode);
				m.hide();
				t.show();

				var t = Lambda.find(l.tileProps.tags, function(t) return t.name == tagMode);
				if( t != null ) {
					for( y in 0...height )
						for( x in 0...width )
							if( t.flags[x + y * l.imagesStride] )
								paletteSelect.fillRect(x * (tileSize+1), y * (tileSize+1), tileSize + 1, tileSize + 1, 0x80FB5BA1);
				}

			} else {

				var grounds = [];

				for( s in l.tileProps.sets ) {
					var color = switch( s.t ) {
					case Tile: 0;
					case Ground:
						if( s.opts.name != null && s.opts.name != "" ) {
							grounds.remove(s.opts.name);
							grounds.push(s.opts.name);
						}
						0x00FF00;
					case Border: 0x00FFFF;
					case Object: 0xFF0000;
					}
					color |= 0xFF000000;
					var px = s.x * (tileSize + 1);
					var py = s.y * (tileSize + 1);
					var w = s.w * (tileSize + 1) - 1;
					var h = s.h * (tileSize + 1) - 1;
					paletteSelect.fillRect(px, py, w, 1, color);
					paletteSelect.fillRect(px, py + h - 1, w, 1, color);
					paletteSelect.fillRect(px, py, 1, h, color);
					paletteSelect.fillRect(px + w - 1, py, 1, h, color);
				}

				var tobj = l.getTileProp();
				if( tobj == null )
					tobj = { x : 0, y : 0, w : 0, h : 0, t : Tile, opts : { } };

				var tkind = tobj.t.toString();
				m.find("[name=mode]").val(tkind);
				m.attr("class", "").addClass("mode").addClass("m_" + tkind);
				switch( tobj.t ) {
				case Tile:
				case Ground:
					m.find("[name=name]").val(tobj.opts.name == null ? "" : tobj.opts.name);
					m.find("[name=priority]").val("" + (tobj.opts.priority == null ? 0 : tobj.opts.priority));
				case Object:
				case Border:
					var opts = [for( g in grounds ) '<option value="$g">$g</option>'].join("");
					m.find("[name=border_in]").html("<option value='null'>upper</option><option value='lower'>lower</option>" + opts).val(Std.string(tobj.opts.borderIn));
					m.find("[name=border_out]").html("<option value='null'>lower</option><option value='upper'>upper</option>" + opts).val(Std.string(tobj.opts.borderOut));
					m.find("[name=border_mode]").val(Std.string(tobj.opts.borderMode));
				}
				m.show();
			}
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
