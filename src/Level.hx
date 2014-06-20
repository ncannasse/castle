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
	var paletteMode : Null<String>;
	var paletteModeCursor : Int;
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
	public var layers : Array<LayerData>;

	var obj : Dynamic;
	var content : js.JQuery;
	var props : LevelProps;

	var currentLayer : LayerData;
	var cursor : js.JQuery;
	var cursorImage : lvl.Image;
	var zoomView = 1.;
	var curPos : { x : Int, y : Int, xf : Float, yf : Float };
	var mouseDown : Bool;
	var deleteMode : { l : LayerData };
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
	var paletteMode : Null<String> = null;
	var paletteModeCursor : Int = 0;
	var spaceDown : Bool;

	var perTileProps : Array<Column>;
	var perTileGfx : Map<String, lvl.LayerGfx>;

	var watchList : Array<{ path : String, time : Float, callb : Void -> Void }>;
	var watchTimer : haxe.Timer;
	var references : Array<{ ref : Dynamic -> Void }>;

	var selection : { sx : Float, sy : Float, x : Float, y : Float, w : Float, h : Float, down : Bool };

	static var loadedTilesCache = new Map< String, { pending : Array < Int->Int->Array<lvl.Image>->Array<Bool>->Void >, data : { w : Int, h : Int, img : Array<lvl.Image>, blanks : Array<Bool> }} >();

	public function new( model : Model, sheet : Sheet, index : Int ) {
		this.sheet = sheet;
		this.sheetPath = model.getPath(sheet);
		this.index = index;
		this.obj = sheet.lines[index];
		this.model = model;
		perTileProps = [];
		for( c in sheet.columns )
			if( c.name == "tileProps" && c.type == TList )
				perTileProps = model.getPseudoSheet(sheet, c).columns;
		references = [];
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
		
		// load tile props gfxs
		perTileGfx = new Map();
		for( c in perTileProps )
			switch( c.type ) {
			case TRef(s):
				var g = new lvl.LayerGfx(this);
				g.fromSheet(model.getSheet(s), 0xFF0000);
				perTileGfx.set(c.name, g);
			default:
			}

		waitDone();
	}

	public function loadAndSplit(file, size:Int, callb) {
		var key = file + "@" + size;
		var a = loadedTilesCache.get(key);
		if( a == null ) {
			a = { pending : [], data : null };
			loadedTilesCache.set(key, a);
			lvl.Image.load(model.getAbsPath(file), function(i) {
				var images = [], blanks = [];
				var w = Std.int(i.width / size);
				var h = Std.int(i.height / size);
				for( y in 0...h )
					for( x in 0...w ) {
						var i = i.sub(x * size, y * size, size, size);
						blanks[images.length] = i.isBlank();
						images.push(i);
					}
				a.data = { w : w, h : h, img : images, blanks : blanks };
				for( p in a.pending )
					p(w, h, images, blanks);
				a.pending = [];
			},function() {
				throw "Could not load " + file;
			});
			watch(file, function() lvl.Image.load(model.getAbsPath(file), function(_) { loadedTilesCache.remove(key); reload(); } , function() { }, true));
		}
		if( a.data != null )
			callb(a.data.w, a.data.h, a.data.img, a.data.blanks);
		else
			a.pending.push(callb);
	}

	public function getTileProps(file,stride) {
		var p : TilesetProps = Reflect.field(sheet.props.level.tileSets,file);
		if( p == null ) {
			p = {
				stride : stride,
				sets : [],
				props : [],
			};
			Reflect.setField(sheet.props.level.tileSets, file, p);
		} else {
			if( p.sets == null ) p.sets = [];
			if( p.props == null ) p.props = [];
			Reflect.deleteField(p, "tags");
			if( p.stride == null ) p.stride = stride else if( p.stride != stride ) {
				var out = [];
				for( y in 0...Math.ceil(p.props.length / p.stride) )
					for( x in 0...p.stride )
						out[x + y * stride] = p.props[x + y * p.stride];
				while( out.length > 0 && out[out.length - 1] == null )
					out.pop();
				p.props = out;
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

	function allocRef(f) {
		var r = { ref : f };
		references.push(r);
		return r;
	}

	public function dispose() {
		if( content != null ) content.html("");
		if( view != null ) {
			view.dispose();
			var ca = view.getCanvas();
			ca.parentNode.removeChild(ca);
			view = null;
			for( r in references )
				r.ref = null;
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
			paletteMode = state.paletteMode;
			paletteModeCursor = state.paletteModeCursor;
		}

		setLayer(layer);
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

	function pick( ?filter ) {
		if( curPos == null ) return null;
		var i = layers.length - 1;
		while( i >= 0 ) {
			var l = layers[i--];
			if( !l.visible || (filter != null && !filter(l)) ) continue;
			var x = currentLayer.floatCoord ? curPos.xf : curPos.x;
			var y = currentLayer.floatCoord ? curPos.yf : curPos.y;
			switch( l.data ) {
			case Layer(data):
				var idx = curPos.x + curPos.y * width;
				var k = data[idx];
				if( k == 0 && i >= 0 ) continue;
				return { k : k, layer : l, index : idx };
			case Objects(idCol, objs):
				for( i in 0...objs.length ) {
					var o = objs[i];
					var w = l.hasSize ? o.width : 1;
					var h = l.hasSize ? o.height : 1;
					if( x >= o.x && y >= o.y && x < o.x + w && y < o.y + h ) {
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
					if( x >= i.x && y >= i.y && x < i.x + (o == null ? 1 : o.w) && y < i.y + (o == null ? 1 : o.h) )
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
		setLayer(l);

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

	function setSort( j : js.JQuery, callb : { ref : Dynamic -> Void } ) {
		(untyped j.sortable)( {
			vertical : false,
			onDrop : function(item, container, _super) {
				_super(item, container);
				callb.ref(null);
			}
		});
	}

	function spectrum( j : js.JQuery, options : { }, change : { ref : Dynamic -> Void }, ?show : { ref : Dynamic -> Void } ) {
		untyped options.change = function(c) {
			change.ref(Std.parseInt("0x" + c.toHex()));
		};
		if( show != null )
			untyped options.show = function() {
				show.ref(null);
			};
		(untyped j).spectrum(options);
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
					paletteMode = null;
					setLayer(l);
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
					setLayer(l);
					var list = J("<div class='imglist'>");
					for( i in 0...l.images.length )
						list.append(J("<img>").attr("src", l.images[i].getCanvas().toDataURL()).click(function(_) {
							l.current = i;
							setLayer(l);
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
			spectrum(t,{
				color : toColor(l.colors[l.current]),
				clickoutFiresChange : true,
				showButtons : false,
				showPaletteOnly : true,
				showPalette : true,
				palette : [for( c in l.colors ) toColor(c)],
			},allocRef(function(color:Int) {
				for( i in 0...l.colors.length )
					if( l.colors[i] == color ) {
						l.current = i;
						setLayer(l);
						return;
					}
				setLayer(l);
			}),allocRef(function(_) {
				setLayer(l);
			}));
		}

		var callb = allocRef(function(_) {
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
		});
		setSort(mlayers, callb);

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

		scroll[0].onmousewheel = function(e) {
			if( e.shiftKey )
				updateZoom(e.wheelDelta > 0);
		};

		spectrum(content.find("[name=color]"), { clickoutFiresChange : true, showButtons : false }, allocRef(function(c) {
			currentLayer.props.color = c;
			save();
			draw();
		}));

		onResize();

		cursor = content.find("#cursor");
		cursorImage = new lvl.Image(0, 0);
		cursor[0].appendChild(cursorImage.getCanvas());
		cursor.hide();


		scont.mouseleave(function(_) {
			curPos = null;
			if( selection == null ) cursor.hide();
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
			if( paletteMode != null ) {
				paletteMode = null;
				setCursor();
				return;
			}
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
					setLayer(p.layer);
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
				var l = currentLayer;
				var fc = l.floatCoord;
				var px = fc ? curPos.xf : curPos.x;
				var py = fc ? curPos.yf : curPos.y;
				var w = 0., h = 0.;
				if( l.hasSize ) {
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
					if( o.x == px && o.y == py && w <= 1 && h <= 1 ) {
						editProps(l, i);
						setCursor();
						return;
					}
				}
				var o : { x : Float, y : Float, ?width : Float, ?height : Float } = { x : px, y : py };
				objs.push(o);
				if( idCol != null )
					Reflect.setField(o, idCol, l.indexToId[currentLayer.current]);
				for( c in l.baseSheet.columns ) {
					if( c.opt || c.name == "x" || c.name == "y" || c.name == idCol ) continue;
					var v = model.getDefault(c);
					if( v != null ) Reflect.setField(o, c.name, v);
				}
				if( l.hasSize ) {
					o.width = w;
					o.height = h;
					setCursor();
				}
				objs.sort(function(o1, o2) {
					var r = Reflect.compare(o1.y, o2.y);
					return if( r == 0 ) Reflect.compare(o1.x, o2.x) else r;
				});
				if( hasProps(l, true) )
					editProps(l, Lambda.indexOf(objs, o));
				save();
				draw();
			default:
			}
			startPos = null;
			if( selection != null ) {
				moveSelection();
				save();
				draw();
			}
		});
	}

	function deleteSelection() {
		for( l in layers ) {
			if( !l.visible ) continue;
			l.dirty = true;
			var sx = selection.x;
			var sy = selection.y;
			var sw = selection.w;
			var sh = selection.h;
			switch( l.data ) {
			case Layer(data), Tiles(_, data):
				var sx = Std.int(selection.x);
				var sy = Std.int(selection.y);
				var sw = Math.ceil(selection.x + selection.w) - sx;
				var sh = Math.ceil(selection.y + selection.h) - sy;
				for( dx in 0...sw )
					for( dy in 0...sh )
						data[sx + dx + (sy + dy) * width] = 0;
			case TileInstances(_, insts):
				var objs = l.getTileObjects();
				for( i in insts.copy() ) {
					var o = objs.get(i.o);
					var ow = o == null ? 1 : o.w;
					var oh = o == null ? 1 : o.h;
					if( sx + sw <= i.x || sy + sh <= i.y || sx >= i.x + ow || sy >= i.y + oh ) continue;
					insts.remove(i);
				}
			case Objects(_, objs):
				for( o in objs.copy() ) {
					var ow = l.hasSize ? o.width : 1;
					var oh = l.hasSize ? o.height : 1;
					if( sx + sw <= o.x || sy + sh <= o.y || sx >= o.x + ow || sy >= o.y + oh ) continue;
					objs.remove(o);
				}
			}
		}
	}

	function moveSelection() {
		var dx = selection.x - selection.sx;
		var dy = selection.y - selection.sy;
		if( dx == 0 && dy == 0 )
			return;

		var ix = Std.int(dx);
		var iy = Std.int(dy);

		for( l in layers ) {
			if( !l.visible ) continue;
			var sx = selection.x;
			var sy = selection.y;
			var sw = selection.w;
			var sh = selection.h;

			l.dirty = true;
			switch( l.data ) {
			case Tiles(_, data), Layer(data):
				var sx = Std.int(selection.x);
				var sy = Std.int(selection.y);
				var sw = Math.ceil(selection.x + selection.w) - sx;
				var sh = Math.ceil(selection.y + selection.h) - sy;

				var ndata = [];
				for( y in 0...height )
					for( x in 0...width ) {
						var k;
						if( x >= sx && x < sx + sw && y >= sy && y < sy + sh ) {
							var tx = x - ix;
							var ty = y - iy;
							if( tx >= 0 && tx < width && ty >= 0 && ty < height )
								k = data[tx + ty * width];
							else
								k = 0;
						} else if( x >= sx - ix && x < sx + sw - ix && y >= sy - iy && y < sy + sh - iy )
							k = 0;
						else
							k = data[x + y * width];
						ndata.push(k);
					}
				for( i in 0...data.length )
					data[i] = ndata[i];
			case TileInstances(_, insts):

				sx -= dx;
				sy -= dy;

				var objs = l.getTileObjects();
				for( i in insts.copy() ) {
					var o = objs.get(i.o);
					var ow = o == null ? 1 : o.w;
					var oh = o == null ? 1 : o.h;
					if( sx + sw <= i.x || sy + sh <= i.y || sx >= i.x + ow || sy >= i.y + oh ) continue;
					i.x += l.hasFloatCoord ? dx : ix;
					i.y += l.hasFloatCoord ? dy : iy;
					if( i.x < 0 || i.y < 0 || i.x >= width || i.y >= height )
						insts.remove(i);
				}
			case Objects(_, objs):

				sx -= dx;
				sy -= dy;

				for( o in objs.copy() ) {
					var ow = l.hasSize ? o.width : 1;
					var oh = l.hasSize ? o.height : 1;
					if( sx + sw <= o.x || sy + sh <= o.y || sx >= o.x + ow || sy >= o.y + oh ) continue;
					o.x += l.hasFloatCoord ? dx : ix;
					o.y += l.hasFloatCoord ? dy : iy;
					if( o.x < 0 || o.y < 0 || o.x >= width || o.y >= height )
						objs.remove(o);
				}
			}
		}
		save();
		draw();
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
			content.find(".cursorPosition").text(cx + "," + cy);
			if( mouseDown ) set(cx, cy);
			if( deleteMode != null ) doDelete();
		} else {
			cursor.hide();
			curPos = null;
			content.find(".cursorPosition").text("");
		}

		if( selection != null ) {
			var fc = currentLayer.floatCoord;
			var ccx = fc ? cxf : cx, ccy = fc ? cyf : cy;
			if( ccx < 0 ) ccx = 0;
			if( ccy < 0 ) ccy = 0;
			if( ccx > width ) ccx = width;
			if( ccy > height ) ccy = height;
			if( !selection.down ) {
				if( startPos != null ) {
					selection.x = selection.sx + (ccx - startPos.x);
					selection.y = selection.sy + (ccy - startPos.y);
				} else {
					selection.sx = selection.x;
					selection.sy = selection.y;
				}
				setCursor();
				return;
			}
			var x0 = ccx < selection.sx ? ccx : selection.sx;
			var y0 = ccy < selection.sy ? ccy : selection.sy;
			var x1 = ccx < selection.sx ? selection.sx : ccx;
			var y1 = ccy < selection.sy ? selection.sy : ccy;
			selection.x = x0;
			selection.y = y0;
			selection.w = x1 - x0;
			selection.h = y1 - y0;
			setCursor();
		}
	}

	function hasProps( l : LayerData, required = false ) {
		var idCol = switch( l.data ) { case Objects(idCol, _): idCol; default: null; };
		for( c in l.baseSheet.columns )
			if( c.name != "x" && c.name != "y" && c.name != idCol && (!required || (!c.opt && model.getDefault(c) == null)) )
				return true;
		return false;
	}

	function editProps( l : LayerData, index : Int ) {
		if( !hasProps(l) ) return;
		var o = Reflect.field(obj, l.name)[index];
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
		setCursor();
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
			if( k == l.current + 1 || l.blanks[l.current] ) return;
			var px = x, py = y, zero = [], todo = [x, y];
			while( todo.length > 0 ) {
				var y = todo.pop();
				var x = todo.pop();
				if( data[x + y * width] != k ) continue;
				var dx = (x - px) % l.currentWidth; if( dx < 0 ) dx += l.currentWidth;
				var dy = (y - py) % l.currentHeight; if( dy < 0 ) dy += l.currentHeight;
				var t = l.current + (randomMode ? Std.random(l.currentWidth) + Std.random(l.currentHeight) * l.stride : dx + dy * l.stride);
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
		if( e.ctrlKey || J("input[type=text]:focus").length > 0 || currentLayer == null ) return;

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
			clearSelection();
			draw();
		case K.TAB:
			var i = (layers.indexOf(l) + (e.shiftKey ? layers.length-1 : 1) ) % layers.length;
			setLayer(layers[i]);
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
			if( palette != null && l.tileProps != null ) {
				var mode = Object;
				for( t in l.tileProps.sets )
					if( t.x + t.y * l.stride == l.current && t.t == mode ) {
						l.tileProps.sets.remove(t);
						setCursor();
						return;
					}
				l.tileProps.sets.push( { x : l.current % l.stride, y : Std.int(l.current / l.stride), w : l.currentWidth, h : l.currentHeight, t : mode, opts : {} } );
				setCursor();
			}
		case "R".code:
			paletteOption("random");
		case K.LEFT:
			e.preventDefault();
			if( l.current % l.stride > 0 ) {
				l.current--;
				setCursor();
			}
		case K.RIGHT:
			e.preventDefault();
			if( l.current % l.stride < l.stride - 1 ) {
				l.current++;
				setCursor();
			}
		case K.DOWN:
			e.preventDefault();
			if( l.current + l.stride < l.images.length ) {
				l.current += l.stride;
				setCursor();
			}
		case K.UP:
			e.preventDefault();
			if( l.current >= l.stride ) {
				l.current -= l.stride;
				setCursor();
			}
		case K.DELETE if( selection != null ):
			deleteSelection();
			clearSelection();
			save();
			draw();
			return;
		default:
		}

		if( curPos == null ) return;

		switch( e.keyCode ) {
		case "P".code:
			paint(curPos.x, curPos.y);
		case K.DELETE:
			if( deleteMode != null ) return;
			deleteMode = { l : null };
			doDelete();
		case "E".code:
			var p = pick(function(l) return l.data.match(Objects(_)) && hasProps(l));
			if( p == null ) return;
			switch( p.layer.data ) {
			case Objects(_, objs):
				J(".popup").remove();
				editProps(p.layer, p.index);
			default:
			}
		case "S".code:
			if( selection != null ) {
				if( selection.down ) return;
				clearSelection();
			}
			var x = l.floatCoord ? curPos.xf : curPos.x, y = l.floatCoord ? curPos.yf : curPos.y;
			selection = { sx : x, sy : y, x : x, y : y, w : 1, h : 1, down : true };
			cursor.addClass("select");
			setCursor();
		default:
		}
	}

	function clearSelection() {
		selection = null;
		cursor.removeClass("select");
		cursor.css( { width : "auto", height : "auto" } );
		setCursor();
	}

	function doDelete() {
		var p = pick(deleteMode.l == null ? null : function(l2) return l2 == deleteMode.l);
		if( p == null ) return;
		deleteMode.l = p.layer;
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
			var w = currentLayer.currentWidth, h = currentLayer.currentHeight;
			if( randomMode ) w = h = 1;
			for( dy in 0...h )
				for( dx in 0...w ) {
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
	}

	public function onKeyUp( e : js.html.KeyboardEvent ) {
		switch( e.keyCode ) {
		case K.DELETE:
			deleteMode = null;
			if( needSave ) save();
		case K.SPACE:
			spaceDown = false;
			var canvas = J(view.getCanvas());
			canvas.unbind("mousemove");
			canvas.css( { cursor : "" } );
			updateCursorPos();
		case "S".code:
			if( selection != null ) {
				selection.down = false;
				selection.sx = selection.x;
				selection.sy = selection.y;
				setCursor();
			}
		default:
		}
	}

	function set( x, y ) {
		if( selection != null )
			return;
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
				var id = l.current + Std.random(l.currentWidth) + Std.random(l.currentHeight) * l.stride + 1;
				if( data[p] == id || l.blanks[id - 1] ) return;
				data[p] = id;
				changed = true;
			} else {
				for( dy in 0...l.currentHeight )
					for( dx in 0...l.currentWidth ) {
						var p = x + dx + (y + dy) * width;
						var id = l.current + dx + dy * l.stride + 1;
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
			var putObjs = l.getSelObjects();
			var putObj = putObjs[Std.random(putObjs.length)];
			var dx = putObj == null ? 0.5 : (putObj.w * 0.5);
			var dy = putObj == null ? 0.5 : putObj.h - 0.5;
			var x = l.floatCoord ? curPos.xf : curPos.x, y = l.floatCoord ? curPos.yf : curPos.y;

			if( putObj != null ) {
				x += (putObjs[0].w - putObj.w) * 0.5;
				y += putObjs[0].h - putObj.h;
			}

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
				insts.push( { x : x, y : y, o : putObj.x + putObj.y * l.stride } );
			else
				for( dy in 0...l.currentHeight )
					for( dx in 0...l.currentWidth )
						insts.push( { x : x+dx, y : y+dy, o : l.current + dx + dy * l.stride } );
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

	function drawTiles( l : LayerData, data : Array<Int> ) {
		for( y in 0...height )
			for( x in 0...width ) {
				var k = data[x + y * width] - 1;
				if( k < 0 ) continue;
				view.draw(l.images[k], x * tileSize, y * tileSize);
			}
		if( l.props.mode == Ground ) {
			var b = new cdb.TileBuilder(l.tileProps, l.stride, l.images.length);
			var a = b.buildGrounds(data, width);
			var p = 0, max = a.length;
			while( p < max ) {
				var x = a[p++];
				var y = a[p++];
				var id = a[p++];
				view.draw(l.images[id], x * tileSize, y * tileSize);
			}
		}
	}

	public function draw() {
		view.fill(0xFF909090);
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
				drawTiles(l, data);
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
								view.draw(l.images[i.o + dx + dy * l.stride], x + dx * tileSize, y + dy * tileSize);
					}
				}
			case Objects(idCol, objs):
				if( idCol == null ) {
					var col = l.props.color | 0xA0000000;
					for( o in objs ) {
						var w = l.hasSize ? o.width * tileSize : tileSize;
						var h = l.hasSize ? o.height * tileSize : tileSize;
						view.fillRect(Std.int(o.x * tileSize), Std.int(o.y * tileSize), Std.int(w), Std.int(h), col);
					}
					var col = l.props.color | 0xFF000000;
					for( o in objs ) {
						var w = l.hasSize ? Std.int(o.width * tileSize) : tileSize;
						var h = l.hasSize ? Std.int(o.height * tileSize) : tileSize;
						var px = Std.int(o.x * tileSize);
						var py = Std.int(o.y * tileSize);
						view.fillRect(px, py, w, 1, col);
						view.fillRect(px, py + h - 1, w, 1, col);
						view.fillRect(px, py + 1, 1, h - 2, col);
						view.fillRect(px + w - 1, py + 1, 1, h - 2, col);
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
		if( mouseDown || deleteMode != null ) {
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
			paletteMode : paletteMode,
			paletteModeCursor : paletteModeCursor,
		};
		js.Browser.getLocalStorage().setItem(sheetPath, haxe.Serializer.run(state));
	}

	@:keep function scroll( dx : Int, dy : Int ) {
		if( dx == null || Math.isNaN(dx) ) dx = 0;
		if( dy == null || Math.isNaN(dy) ) dy = 0;
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
		J(":focus").blur();
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
		setCursor();
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
						oids.set(p.x + p.y * l.stride, p);
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
									var id = d + dx + dy * l.stride;
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
									data[x + y * width] = i.o + dx + dy * l.stride + 1;
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
			setCursor();
			return;
		case "paint":
			paintMode = !paintMode;
			if( l.data.match(TileInstances(_)) ) paintMode = false;
			savePrefs();
			palette.find(".icon.paint").toggleClass("active", paintMode);
			return;
		case "mode":
			paletteMode = val == "t_tile" ? null : val;
			paletteModeCursor = 0;
			setCursor();
		case "toggleMode":
			var m = TileMode.ofString(paletteMode.substr(2));
			var s = l.getTileProp();
			if( s == null ) {
				s = { x : l.current % l.stride, y : Std.int(l.current / l.stride), w : l.currentWidth, h : l.currentHeight, t : m, opts : {} };
				l.tileProps.sets.push(s);
			} else
				l.tileProps.sets.remove(s);
			setCursor();
		case "name":
			var s = l.getTileProp();
			if( s != null )
				s.opts.name = val;
		case "value":
			var s = l.getTileProp();
			if( s != null ) {
				var v = try haxe.Json.parse(val) catch( e : Dynamic ) null;
				if( v == null )
					Reflect.deleteField(s.opts, "value");
				else
					s.opts.value = v;
				palette.find("[name=value]").val(v == null ? "" : haxe.Json.stringify(v));
			}
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
		}
		save();
		draw();
	}

	function getPaletteProp() {
		if( paletteMode == null || paletteMode.substr(0, 2) == "t_" )
			return null;
		for( c in perTileProps )
			if( c.name == paletteMode )
				return c;
		return null;
	}


	function getTileProp(x, y) {
		var l = currentLayer;
		var a = x + y * l.stride;
		var p = currentLayer.tileProps.props[a];
		if( p == null ) {
			p = { };
			for( c in perTileProps ) {
				var v = model.getDefault(c);
				if( v != null ) Reflect.setField(p, c.name, v);
			}
			currentLayer.tileProps.props[a] = p;
		}
		return p;
	}
	
	function saveTileProps() {
		var pr = currentLayer.tileProps.props;
		for( i in 0...pr.length ) {
			var p = pr[i];
			if( p == null ) continue;
			var def = true;
			for( c in perTileProps ) {
				var v = model.getDefault(c);
				if( Reflect.field(p, c.name) != v ) {
					def = false;
					break;
				}
			}
			if( def )
				pr[i] = null;
		}
		while( pr.length > 0 && pr[pr.length - 1] == null )
			pr.pop();
		save();
		setCursor();
	}
	
	function setLayer( l : LayerData ) {
		var old = currentLayer;
		if( l == old ) {
			setCursor();
			return;
		}
		currentLayer = l;
		
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
		
		if( l.images == null ) {
			setCursor();
			return;
		}
		
		palette = J(J("#paletteContent").html()).appendTo(content);
		var i = lvl.Image.fromCanvas(cast palette.find("canvas.view")[0]);
		i.setSize(l.stride * (tileSize + 1), l.height * (tileSize + 1));
		for( n in 0...l.images.length ) {
			var x = (n % l.stride) * (tileSize + 1);
			var y = Std.int(n / l.stride) * (tileSize + 1);
			i.draw(l.images[n], x, y);
		}
		var jsel = palette.find("canvas.select");
		var select = lvl.Image.fromCanvas(cast jsel[0]);
		select.setSize(i.width, i.height);

		palette.find(".icon.random").toggleClass("active",randomMode);
		palette.find(".icon.paint").toggleClass("active", paintMode);

		var start = { x : l.current % l.stride, y : Std.int(l.current / l.stride), down : false };
		jsel.mousedown(function(e) {
			var o = jsel.offset();
			var x = Std.int((e.pageX - o.left) / (tileSize + 1));
			var y = Std.int((e.pageY - o.top) / (tileSize + 1));

			if( e.shiftKey ) {
				var x0 = x < start.x ? x : start.x;
				var y0 = y < start.y ? y : start.y;
				var x1 = x < start.x ? start.x : x;
				var y1 = y < start.y ? start.y : y;
				l.current = x0 + y0 * l.stride;
				l.currentWidth = x1 - x0 + 1;
				l.currentHeight = y1 - y0 + 1;
				l.saveState();
				setCursor();
			} else {
				start.x = x;
				start.y = y;
				if( l.tileProps != null && (paletteMode == null || paletteMode == "t_objects") )
					for( p in l.tileProps.sets )
						if( x >= p.x && y >= p.y && x < p.x + p.w && y < p.y + p.h && p.t == Object ) {
							l.current = p.x + p.y * l.stride;
							l.currentWidth = p.w;
							l.currentHeight = p.h;
							l.saveState();
							setCursor();
							return;
						}
				start.down = true;
				l.current = x + y * l.stride;
				setCursor();
			}

			var prop = getPaletteProp();
			if( prop != null ) {
				switch( prop.type ) {
				case TBool:
					var v = getTileProp(x, y);
					Reflect.setField(v, prop.name, !Reflect.field(v, prop.name));
					saveTileProps();
				case TRef(_):
					var c = perTileGfx.get(prop.name);
					if( paletteModeCursor < 0 )
						Reflect.deleteField(getTileProp(x, y), prop.name);
					else
						Reflect.setField(getTileProp(x, y), prop.name, c.indexToId[paletteModeCursor]);
					saveTileProps();
				default:
				}
			}
		});
		
		jsel.mousemove(function(e) {
			mousePos.x = e.pageX;
			mousePos.y = e.pageY;
			updateCursorPos();
			if( selection == null ) cursor.hide();

			var o = jsel.offset();
			var x = Std.int((e.pageX - o.left) / (tileSize + 1));
			var y = Std.int((e.pageY - o.top) / (tileSize + 1));
			content.find(".cursorPosition").text(x+","+y);
			if( !start.down ) return;
			var x0 = x < start.x ? x : start.x;
			var y0 = y < start.y ? y : start.y;
			var x1 = x < start.x ? start.x : x;
			var y1 = y < start.y ? start.y : y;
			l.current = x0 + y0 * l.stride;
			l.currentWidth = x1 - x0 + 1;
			l.currentHeight = y1 - y0 + 1;
			l.saveState();
			setCursor();
		});
		
		jsel.mouseleave(function(e) {
			content.find(".cursorPosition").text("");
		});
		
		jsel.mouseup(function(e) {
			start.down = false;
		});
		paletteSelect = select;
		setCursor();
	}

	function setCursor() {
		var l = currentLayer;
		if( l == null ) {
			cursor.hide();
			return;
		}

		content.find(".menu .item.selected").removeClass("selected");
		l.comp.addClass("selected");

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
							used[i.o + dx + dy * l.stride] = true;
				}
			}

			for( i in 0...l.images.length ) {
				if( used[i] ) continue;
				paletteSelect.fillRect( (i % l.stride) * (tileSize + 1), Std.int(i / l.stride) * (tileSize + 1), tileSize, tileSize, 0x80000000);
			}

			var prop = getPaletteProp();
			if( prop == null || !prop.type.match(TBool | TRef(_)) ) {
				var objs = paletteMode == null ? l.getSelObjects() : [];
				if( objs.length > 1 )
					for( o in objs )
						paletteSelect.fillRect( o.x * (tileSize + 1), o.y * (tileSize + 1), (tileSize + 1) * o.w - 1, (tileSize + 1) * o.h - 1, 0x805BA1FB);
				else
					paletteSelect.fillRect( (l.current % l.stride) * (tileSize + 1), Std.int(l.current / l.stride) * (tileSize + 1), (tileSize + 1) * l.currentWidth - 1, (tileSize + 1) * l.currentHeight - 1, 0x805BA1FB);
			}
			if( prop != null ) {
				switch( prop.type ) {
				case TBool:
					var k = 0;
					for( y in 0...l.height )
						for( x in 0...l.stride ) {
							var p = l.tileProps.props[k++];
							if( p == null || Reflect.field(p, prop.name) != true ) continue;
							paletteSelect.fillRect( x * (tileSize + 1), y * (tileSize + 1), tileSize, tileSize, 0x80FB5BA1);
						}
				case TRef(_):
					var gfx = perTileGfx.get(prop.name);
					var k = 0;
					paletteSelect.alpha = 0.5;
					for( y in 0...l.height )
						for( x in 0...l.stride ) {
							var p = l.tileProps.props[k++];
							if( p == null ) continue;
							var v = gfx.idToIndex.get(Reflect.field(p, prop.name));
							if( v == null ) continue;
							paletteSelect.draw(gfx.images[v], x * (tileSize + 1), y * (tileSize + 1));
						}
					paletteSelect.alpha = 1;
				default:
					// no per-tile display
				}
			}

			var m = palette.find(".mode");
			if( l.tileProps == null ) {
				m.hide();
			} else {

				var grounds = [];

				for( s in l.tileProps.sets ) {
					var color;
					switch( s.t ) {
					case Tile:
						continue;
					case Ground:
						if( s.opts.name != null && s.opts.name != "" ) {
							grounds.remove(s.opts.name);
							grounds.push(s.opts.name);
						}
						if( paletteMode != null && paletteMode != "t_ground" ) continue;
						color = 0x00FF00;
					case Border:
						if( paletteMode != "t_border" ) continue;
						color = 0x00FFFF;
					case Object:
						if( paletteMode != null && paletteMode != "t_object" ) continue;
						color = 0xFF0000;
					case Group:
						if( paletteMode != "t_group" ) continue;
						color = 0xFFFFFF;
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

				var baseModes = [for( m in ["tile", "object", "ground", "border", "group"] ) '<option value="t_$m">${m.substr(0,1).toUpperCase()+m.substr(1)}</option>'].join("\n");
				var props = [for( t in perTileProps ) '<option value="${t.name}">${t.name}</option>'].join("\n");
				m.find("[name=mode]").html(baseModes + props).val(paletteMode == null ? "t_tile" : paletteMode);
				m.attr("class", "").addClass("mode");
				if( prop != null ) {
					switch( prop.type ) {
					case TRef(_):
						var gfx = perTileGfx.get(prop.name);
						m.addClass("m_ref");
						var refList = m.find(".opt.refList");
						refList.html("");
						J("<div>").addClass("icon").addClass("delete").appendTo(refList).toggleClass("active", paletteModeCursor < 0).click(function() {
							paletteModeCursor = -1;
							setCursor();
						});
						for( i in 0...gfx.images.length ) {
							var d = J("<div>").addClass("icon").css( { background : "url('" + gfx.images[i].getCanvas().toDataURL() + "')" } );
							d.appendTo(refList);
							d.toggleClass("active", paletteModeCursor == i);
							d.click(function() {
								paletteModeCursor = i;
								setCursor();
							});
						}
					default:
					}
				} else if( "t_" + tobj.t != paletteMode ) {
					if( paletteMode != null ) m.addClass("m_create");
				} else {
					m.addClass("m_"+paletteMode.substr(2)).addClass("m_exists");
					switch( tobj.t ) {
					case Tile, Object:
					case Ground:
						m.find("[name=name]").val(tobj.opts.name == null ? "" : tobj.opts.name);
						m.find("[name=priority]").val("" + (tobj.opts.priority == null ? 0 : tobj.opts.priority));
					case Group:
						m.find("[name=name]").val(tobj.opts.name == null ? "" : tobj.opts.name);
						m.find("[name=value]").val(tobj.opts.value == null ? "" : haxe.Json.stringify(tobj.opts.value));
					case Border:
						var opts = [for( g in grounds ) '<option value="$g">$g</option>'].join("");
						m.find("[name=border_in]").html("<option value='null'>upper</option><option value='lower'>lower</option>" + opts).val(Std.string(tobj.opts.borderIn));
						m.find("[name=border_out]").html("<option value='null'>lower</option><option value='upper'>upper</option>" + opts).val(Std.string(tobj.opts.borderOut));
						m.find("[name=border_mode]").val(Std.string(tobj.opts.borderMode));
					}
				}
				m.show();
			}
		}

		var size = zoomView < 1 ? Std.int(tileSize * zoomView) : Math.ceil(tileSize * zoomView);

		if( selection != null ) {
			cursorImage.setSize(0,0);
			cursor.show();
			cursor.css( {
				border : "",
				marginLeft : Std.int(selection.x * tileSize * zoomView - 1) + "px",
				marginTop : Std.int(selection.y * tileSize * zoomView) + "px",
				width : Std.int(selection.w * tileSize * zoomView) + "px",
				height : Std.int(selection.h * size) + "px"
			});
			return;
		}

		var cur = l.current;
		var w = randomMode ? 1 : l.currentWidth;
		var h = randomMode ? 1 : l.currentHeight;
		if( l.data.match(TileInstances(_)) ) {
			var o = l.getSelObjects();
			if( o.length > 0 ) {
				cur = o[0].x + o[0].y * l.stride;
				w = o[0].w;
				h = o[0].h;
			}
		}
		cursorImage.setSize(size * w,size * h);
		if( l.images != null ) {
			cursorImage.clear();
			for( y in 0...h )
				for( x in 0...w ) {
					var i = l.images[cur + x + y * l.stride];
					cursorImage.drawSub(i, 0, 0, i.width, i.height, x * size, y * size, size, size);
				}
			cursorImage.fill(0x605BA1FB);
			cursor.css( { border : "none" } );
		} else {
			var c = l.colors[cur];
			var lum = ((c & 0xFF) + ((c >> 8) & 0xFF) + ((c >> 16) & 0xFF)) / (255 * 3);
			cursorImage.fill(c | 0xFF000000);
			cursor.css( { border : "1px solid " + (lum < 0.25 ? "white":"black") } );
		}
	}

}
