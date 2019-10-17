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
import cdb.Data;
import cdb.Sheet;
import js.jquery.Helper.*;
import js.jquery.JQuery;
import Main.K;
import lvl.LayerData;

import js.node.webkit.Menu;
import js.node.webkit.MenuItem;
import js.node.webkit.MenuItemType;

typedef LevelState = {
	var curLayer : String;
	var zoomView : Float;
	var scrollX : Int;
	var scrollY : Int;
	var smallPalette : Bool;
	var paintMode : Bool;
	var randomMode : Bool;
	var paletteMode : Null<String>;
	var paletteModeCursor : Int;
	var flipMode : Bool;
	var rotation : Int;
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
	public var palette : lvl.Palette;

	var obj : Dynamic;
	var content : JQuery;
	var props : LevelProps;

	var currentLayer : LayerData;
	var cursor : JQuery;
	var cursorImage : lvl.Image;
	var tmpImage : lvl.Image;
	var zoomView = 1.;
	var curPos : { x : Int, y : Int, xf : Float, yf : Float };
	var mouseDown : { rx : Int, ry : Int, w : Int, h : Int };
	var deleteMode : { l : LayerData };
	var needSave : Bool;
	var waitCount : Int;
	var mouseCapture(default,set) : JQuery;

	var view : lvl.Image3D;

	var mousePos = { x : 0, y : 0 };
	var startPos : { x : Int, y : Int, xf : Float, yf : Float } = null;
	var newLayer : Column;
	var spaceDown : Bool;
	var flipMode : Bool = false;
	var rotation = 0;

	var watchList : Array<{ path : String, time : Float, callb : Array<Void -> Void> }>;
	var watchTimer : haxe.Timer;
	var references : Array<{ ref : Dynamic -> Void }>;

	var selection : { sx : Float, sy : Float, x : Float, y : Float, w : Float, h : Float, down : Bool };

	static var loadedTilesCache = new Map< String, { pending : Array < Int->Int->Array<lvl.Image>->Array<Bool>->Void >, data : { w : Int, h : Int, img : Array<lvl.Image>, blanks : Array<Bool> }} >();

	public function new( model : Model, sheet : Sheet, index : Int ) {
		this.sheet = sheet;
		this.sheetPath = sheet.getPath();
		this.index = index;
		this.obj = sheet.lines[index];
		this.model = model;
		references = [];
		palette = new lvl.Palette(this);
	}

	public function getName() {
		var name = "#"+index;
		for( c in sheet.columns ) {
			var v : Dynamic = Reflect.field(obj, c.name);
			switch( c.type ) {
			case TString | TRef(_) if( c.name == sheet.props.displayColumn && v != null && v != "" ):
				return v+"#"+index;
			case TId:
				name = v;
			default:
			}
		}
		return name;
	}

	function set_mouseCapture(e) {
		mouseCapture = e;
		if( e != null ) {
			function onUp(_) {
				js.Browser.document.removeEventListener("mouseup", onUp);
				if( mouseCapture != null ) {
					mouseCapture.mouseup();
					mouseCapture = null;
				}
			}
			js.Browser.document.addEventListener("mouseup", onUp);
		}
		return e;
	}

	public function init() {
		layers = [];
		watchList = [];
		watchTimer = new haxe.Timer(50);
		watchTimer.run = checkWatch;

		for( key in loadedTilesCache.keys() )
			watchSplit(key);

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
		for( ld in props.layers ) {
			var prev = lprops.get(ld.l);
			if( prev != null ) props.layers.remove(prev);
			lprops.set(ld.l, ld);
		}
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
				var sheet = sheet.getSub(c);
				var floatCoord = false;
				if( (sheet.hasColumn("x", [TInt]) && sheet.hasColumn("y", [TInt])) || (floatCoord = true && sheet.hasColumn("x", [TFloat]) && sheet.hasColumn("y", [TFloat])) ) {
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
					l.hasSize = sheet.hasColumn("width", [floatCoord?TFloat:TInt]) && sheet.hasColumn("height", [floatCoord?TFloat:TInt]);
					layers.push(l);
				} else if( sheet.hasColumn("name", [TString]) && sheet.hasColumn("data", [TTileLayer]) ) {
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

		palette.init();
		waitDone();
	}

	function watchSplit(key:String) {
		var file = key.split("@").shift();
		var abs = model.getAbsPath(file);
		watch(file, function() lvl.Image.load(abs, function(_) { loadedTilesCache.remove(key); reload(); } , function() {
			for( w in watchList )
				if( w.path == abs )
					w.time = 0;
		}, true));
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
			watchSplit(key);
		}
		if( a.data != null )
			callb(a.data.w, a.data.h, a.data.img, a.data.blanks);
		else
			a.pending.push(callb);
	}

	var reloading = false;
	public function reload() {
		if( !reloading ) {
			reloading = true;
			#if (haxe_ver < 4)
			Std.instance(model,Main).initContent();
			#else
			Std.downcast(model,Main).initContent();
			#end
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
			view.viewport.parentNode.removeChild(view.viewport);
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
		for( w in watchList )
			if( w.path == path ) {
				w.callb.push(callb);
				return;
			}
		watchList.push( { path : path, time : getFileTime(path), callb : [callb] } );
	}

	function checkWatch() {
		for( w in watchList ) {
			var f = getFileTime(w.path);
			if( f != w.time && f != 0. ) {
				w.time = f;
				js.node.webkit.App.clearCache();
				for( c in w.callb )
					c();
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
		var state : LevelState = try haxe.Unserializer.run(js.Browser.getLocalStorage().getItem(sheetPath+"#"+index)) catch( e : Dynamic ) null;
		if( state != null ) {
			for( l in layers )
				if( l.name == state.curLayer ) {
					layer = l;
					break;
				}
			zoomView = state.zoomView;
			palette.paintMode = state.paintMode;
			palette.randomMode = state.randomMode;
			palette.mode = state.paletteMode;
			palette.modeCursor = state.paletteModeCursor;
			palette.small = state.smallPalette;
			flipMode = state.flipMode;
			rotation = state.rotation;
			if( rotation == null ) rotation = 0;
			if( palette.small == null ) palette.small = false;
		}

		setLayer(layer);
		updateZoom();

		var sc = content.find(".scroll");
		if( state != null ) {
			sc.scrollLeft(state.scrollX);
			sc.scrollTop(state.scrollY);
		}
		sc.scroll();
	}

	public function toColor( v : Int ) {
		return "#" + StringTools.hex(v, 6);
	}

	function hasHole( i : lvl.Image, x : Int, y : Int ) {
		for( dx in -1...2 )
			for( dy in -1...2 ) {
				var x = x + dx, y = y + dy;
				if( x >= 0 && y >= 0 && x < i.width && y < i.height && i.getPixel(x, y) >>> 24 != 0 )
					return false;
			}
		return true;
	}

	function pick( ?filter ) {
		if( curPos == null ) return null;
		var i = layers.length - 1;
		while( i >= 0 ) {
			var l = layers[i--];
			if( !l.enabled() || (filter != null && !filter(l)) ) continue;
			var x = curPos.xf;
			var y = curPos.yf;
			var ix = Std.int((x - curPos.x) * tileSize);
			var iy = Std.int((y - curPos.y) * tileSize);
			switch( l.data ) {
			case Layer(data):
				var idx = curPos.x + curPos.y * width;
				var k = data[idx];
				if( k == 0 && i >= 0 ) continue;
				if( l.images != null ) {
					var i = l.images[k];
					if( hasHole(i, ix + ((i.width - tileSize)>>1), iy + (i.height - tileSize)) ) continue;
				}
				return { k : k, layer : l, index : idx };
			case Objects(idCol, objs):
				if( l.images == null ) {
					var found = [];
					for( i in 0...objs.length ) {
						var o = objs[i];
						var w = l.hasSize ? o.width : 1;
						var h = l.hasSize ? o.height : 1;
						if( x >= o.x && y >= o.y && x < o.x + w && y < o.y + h ) {
							if( l.idToIndex == null )
								found.push( { k : 0, layer : l, index : i } );
							else
								found.push({ k : l.idToIndex.get(Reflect.field(o, idCol)), layer : l, index : i });
						}
					}
					// pick small first in case of overlap
					if( l.hasSize )
						found.sort(function(f1, f2) {
							var o1 = objs[f1.index];
							var o2 = objs[f2.index];
							return Reflect.compare(o2.width * o2.height,o1.width * o1.height);
						});
					if( found.length > 0 )
						return found.pop();
				} else {
					var max = objs.length - 1;
					for( i in 0...objs.length ) {
						var i = max - i;
						var o = objs[i];
						var k = l.idToIndex.get(Reflect.field(o, idCol));
						if( k == null ) continue;
						var img = l.images[k];
						var w = img.width / tileSize, h = img.height / tileSize;
						var ox = o.x;
						var oy = o.y;
						if( x >= ox && y >= oy && x < ox + w && y < oy + h && !hasHole(img, Std.int((x - ox) * tileSize), Std.int((y - oy) * tileSize)) )
							return { k : k, layer : l, index : i };
					}
				}
			case Tiles(_,data):
				var idx = curPos.x + curPos.y * width;
				var k = data[idx] - 1;
				if( k < 0 ) continue;
				var i = l.images[k];
				if( i.getPixel(ix, iy) >>> 24 == 0 ) continue;
				return { k : k, layer : l, index : idx };
			case TileInstances(_, insts):
				var objs = l.getTileObjects();
				var idx = insts.length;
				while( idx > 0 ) {
					var i = insts[--idx];
					var o = objs.get(i.o);
					if( x >= i.x && y >= i.y && x < i.x + (o == null ? 1 : o.w) && y < i.y + (o == null ? 1 : o.h) ) {
						var im = l.images[i.o + Std.int(x-i.x) + Std.int(y - i.y) * l.stride];
						if( hasHole(im, ix, iy) ) continue;
						return { k : i.o, layer : l, index : idx };
					}
				}
			}
		}
		return null;
	}

	@:keep function action(name, ?val:Dynamic) {
		var l = currentLayer;
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
				case Tiles(t, _), TileInstances(t, _):
					if( t.file == null ) {
						var size = this.props.tileSize;
						t.stride = Std.int(t.size * t.stride / size);
						t.size = size;
					}
					t.file = path;
					currentLayer.dirty = true;
					save();
					reload();
				default:
				}
			});
		case 'lock':
			l.lock = val;
			l.comp.toggleClass("locked", l.lock);
			l.saveState();
		case 'lockGrid':
			l.floatCoord = l.hasFloatCoord && !val;
			l.saveState();
		case 'visible':
			l.visible = val;
			l.saveState();
			draw();
		case 'alpha':
			l.props.alpha = val / 100;
			model.save(false);
			draw();
		case 'size':
			switch( l.data ) {
			case Tiles(t, _), TileInstances(t,_):
				var size : Int = val;
				t.stride = Std.int(t.size * t.stride / size);
				t.size = size;
				l.dirty = true;
				save();
				reload();
			default:
			}
		case 'mode':
			setLayerMode(val);
		}
		J(":focus").blur();
	}


	@:keep function addNewLayer( name ) {
		switch( newLayer.type ) {
		case TList:
			var s = sheet.getSub(newLayer);
			var o = { name : null, data : null };
			for( c in s.columns ) {
				var v = model.base.getDefault(c);
				if( v != null ) Reflect.setField(o, c.name, v);
			}
			var a : Array<{ name : String, data : cdb.Types.TileLayer }> = Reflect.field(obj, newLayer.name);
			o.name = name;
			a.push(o);
			var n = a.length - 2;
			while( n >= 0 ) {
				var o2 = a[n--];
				if( o2.data != null ) {
					var a = cdb.Types.TileLayerData.encode([for( k in 0...width * height ) 0], model.compressionEnabled());
					o.data = cast { file : o2.data.file, size : o2.data.size, stride : o2.data.stride, data : a };
					break;
				}
			}
			props.layers.push({ l : name, p : { alpha : 1. } });
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
		var nrename = new MenuItem( { label : "Rename" } );
		for( m in [nshow, nshowAll, nrename, nclear, ndel] )
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
			for( l2 in layers ) {
				l2.visible = l == l2;
				l2.saveState();
			}
			draw();
		};
		nshowAll.click = function() {
			for( l2 in layers ) {
				l2.visible = true;
				l2.saveState();
			}
			draw();
		};
		nrename.click = function() {
			l.comp.find("span").remove();
			l.comp.prepend(J("<input type='text'>").val(l.name).focus().blur(function(_) {
				var n = StringTools.trim(JTHIS.val());
				for( p in props.layers )
					if( p.l == n ) {
						reload();
						return;
					}
				for( p in props.layers )
					if( p.l == l.name )
						p.l = n;
				var layers : Array<{ name : String, data : Dynamic }> = Reflect.field(obj, newLayer.name);
				for( l2 in layers )
					if( l2.name == l.name )
						l2.name = n;
				l.name = n;
				currentLayer = null;
				setLayer(l);
				save();
				reload();
			}).keypress(function(e) if( e.keyCode == 13 ) JTHIS.blur()));
		};
		nrename.enabled = ndel.enabled;
		n.popup(mouseX, mouseY);
	}


	public function onResize() {
		var win = js.node.webkit.Window.get();
		content.find(".scroll").css("height", (win.height - 240) + "px");
	}

	function setSort( j : JQuery, callb : { ref : Dynamic -> Void } ) {
		(untyped j.sortable)( {
			vertical : false,
			onDrop : function(item, container, _super) {
				_super(item, container);
				callb.ref(null);
			}
		});
	}

	function spectrum( j : JQuery, options : { }, change : { ref : Dynamic -> Void }, ?show : { ref : Dynamic -> Void } ) {
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
			if( l.lock ) td.addClass("locked");
			td.mousedown(function(e) {
				switch( e.which ) {
				case 1:
					palette.mode = null;
					setLayer(l);
				case 3:
					popupLayer(l, Std.int(e.pageX), Std.int(e.pageY));
					e.preventDefault();
				}
			});
			J("<span>").text(l.name).appendTo(td);

			if( l.images != null || l.colors == null ) {
				td.find("span").css("margin-top", "10px");
				/*var isel = J("<div class='img'>").appendTo(td);
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
				});*/
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
			for( i in mlayers.find("li").elements() )
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
		scont.append(view.viewport);

		scroll.scroll(function(_) {
			savePrefs();
			view.setScrollPos(Std.int(scroll.scrollLeft()) - 20, Std.int(scroll.scrollTop()) - 20);
		});

		untyped scroll[0].onmousewheel = function(e) {
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
		cursorImage.smooth = false;
		tmpImage = new lvl.Image(0, 0);
		cursor[0].appendChild(cursorImage.getCanvas());
		cursor.hide();


		scont.mouseleave(function(_) {
			curPos = null;
			if( selection == null ) cursor.hide();
			J(".cursorPosition").text("");
		});
		scont.mousemove(function(e) {
			mousePos.x = Std.int(e.pageX);
			mousePos.y = Std.int(e.pageY);
			updateCursorPos();
		});
		function onMouseUp(_) {
			mouseDown = null;
			if( currentLayer != null && currentLayer.hasSize ) setCursor();
			if( needSave ) save();
		}
		scroll.mousedown(function(e) {
			if( palette.mode != null ) {
				palette.mode = null;
				setCursor();
				return;
			}
			switch( e.which ) {
			case 1:
				var l = currentLayer;
				if( l == null )
					return;
				var o = l.getSelObjects()[0];
				var w = o == null ? currentLayer.currentWidth : o.w;
				var h = o == null ? currentLayer.currentHeight : o.h;
				if( o == null && palette.randomMode )
					w = h = 1;
				mouseDown = { rx : curPos == null ? 0 : (curPos.x % w), ry : curPos == null ? 0 : (curPos.y % h), w : w, h : h };
				mouseCapture = scroll;
				if( curPos != null ) {
					set(curPos.x, curPos.y, e.ctrlKey);
					startPos = Reflect.copy(curPos);
				}
			case 3:

				if( selection != null ) {
					clearSelection();
					draw();
					return;
				}

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
						flipMode = i.flip;
						rotation = i.rot;
					default:
					}
					setLayer(p.layer);
				}
			}
		});
		content.mouseup(function(e) {
			mouseCapture = null;
			onMouseUp(e);
			if( curPos == null ) {
				startPos = null;
				return;
			}
			if( e.which == 1 && selection == null && currentLayer.enabled() && curPos.x >= 0 && curPos.y >= 0 )
				setObject();
			startPos = null;
			if( selection != null ) {
				moveSelection();
				save();
				draw();
			}
		});
	}

	function setObject() {
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
				if( w < 0 ) {
					px += w;
					w = -w;
				}
				if( h < 0 ) {
					py += h;
					h = -h;
				}
				if( !fc ) {
					w += 1;
					h += 1;
				}
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
				var v = model.base.getDefault(c);
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
	}

	function deleteSelection() {
		for( l in layers ) {
			if( !l.enabled() ) continue;
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
			if( !l.enabled() ) continue;
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
							if( k == 0 && !(x >= sx - ix && x < sx + sw - ix && y >= sy - iy && y < sy + sh - iy) )
								k = data[x + y * width];
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
			if( ccx < 0 ) ccx = 0;
			if( ccy < 0 ) ccy = 0;
			if( fc ) {
				if( ccx > width ) ccx = width;
				if( ccy > height ) ccy = height;
			} else {
				if( ccx >= width ) ccx = width - 1;
				if( ccy >= height ) ccy = height - 1;
			}
			if( currentLayer.hasSize && mouseDown != null ) {
				var px = fc ? startPos.xf : startPos.x;
				var py = fc ? startPos.yf : startPos.y;
				var pw = (fc?cxf:cx) - px;
				var ph = (fc?cyf:cy) - py;
				if( pw < 0 ) {
					px += pw;
					pw = -pw;
				}
				if( ph < 0 ) {
					py += ph;
					ph = -ph;
				}
				if( !fc ) {
					pw += 1;
					ph += 1;
				}
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
			if( mouseDown != null )
				set(Std.int(cx/mouseDown.w)*mouseDown.w + mouseDown.rx, Std.int(cy/mouseDown.h)*mouseDown.h + mouseDown.ry, false);
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
			if( fc ) {
				if( ccx > width ) ccx = width;
				if( ccy > height ) ccy = height;
			} else {
				if( ccx >= width ) ccx = width - 1;
				if( ccy >= height ) ccy = height - 1;
			}
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
			if( !fc ) {
				selection.w += 1;
				selection.h += 1;
			}
			setCursor();
		}
	}

	function hasProps( l : LayerData, required = false ) {
		var idCol = switch( l.data ) { case Objects(idCol, _): idCol; default: null; };
		for( c in l.baseSheet.columns )
			if( c.name != "x" && c.name != "y" && c.name != idCol && (!required || (!c.opt && model.base.getDefault(c) == null)) )
				return true;
		return false;
	}

	function editProps( l : LayerData, index : Int ) {
		if( !hasProps(l) ) return;
		var o = Reflect.field(obj, l.name)[index];
		var scroll = content.find(".scrollContent");
		var popup = J("<div>").addClass("popup").prependTo(scroll);
		J(js.Browser.window).on("mousedown", function(_) {
			popup.remove();
			J(js.Browser.window).off("mousedown");
			if( view != null ) draw();
		});
		popup.mousedown(function(e) e.stopPropagation());
		popup.mouseup(function(e) e.stopPropagation());
		popup.click(function(e) e.stopPropagation());

		var table = J("<table>").appendTo(popup);
		var main = #if (haxe_ver < 4) Std.instance(model, Main) #else Std.downcast(model, Main) #end;
		for( c in l.baseSheet.columns ) {
			var tr = J("<tr>").appendTo(table);
			var th = J("<th>").text(c.name).appendTo(tr);
			var td = J("<td>").html(main.valueHtml(c, Reflect.field(o, c.name), l.baseSheet, o)).appendTo(tr);
			td.click(function(e) {
				var psheet = new Sheet(null,{
					columns : l.baseSheet.columns, // SHARE
					props : l.baseSheet.props, // SHARE
					name : l.baseSheet.name, // same
					lines : Reflect.field(obj, l.name), // ref
					separators : [], // none
				},l.baseSheet.getPath() + ":" + index, { sheet : sheet, column : Lambda.indexOf(sheet.columns,Lambda.find(sheet.columns,function(c) return c.name == l.name)), line : index });
				main.editCell(c, td, psheet, index);
				e.preventDefault();
				e.stopPropagation();
			});
		}

		var x = (o.x + 1) * tileSize * zoomView;
		var y = (o.y + 1) * tileSize * zoomView;
		var cw = width * tileSize * zoomView;
		var ch = height * tileSize * zoomView;

		if( x > cw - popup.width() - 30 ) x = cw - popup.width() - 30;
		if( y > ch - popup.height() - 30 ) y = ch - popup.height() - 30;

		var scroll = content.find(".scroll");
		if( x < scroll.scrollLeft() + 20 ) x = scroll.scrollLeft() + 20;
		if( y < scroll.scrollTop() + 20 ) y = scroll.scrollTop() + 20;
		if( x + popup.width() > scroll.scrollLeft() + scroll.width() - 20 ) x = scroll.scrollLeft() + scroll.width() - 20 - popup.width();
		if( y + popup.height() > scroll.scrollTop() + scroll.height() - 20) y = scroll.scrollTop() + scroll.height() - 20 - popup.height();

		popup.css( { marginLeft : Std.int(x) + "px", marginTop : Std.int(y) + "px" } );
	}

	function updateZoom( ?f ) {
		var tx = 0, ty = 0;
		var sc = content.find(".scroll");
		if( f != null ) {
			J(".popup").remove();
			var width = sc.width(), height = sc.height();
			var cx = (sc.scrollLeft() + width*0.5) / zoomView;
			var cy = (sc.scrollTop() + height * 0.5) / zoomView;
			if( f ) zoomView *= 1.2 else zoomView /= 1.2;
			tx = Math.round(cx * zoomView - width * 0.5);
			ty = Math.round(cy * zoomView - height * 0.5);
		}
		savePrefs();
		view.setSize(Std.int(width * tileSize * zoomView), Std.int(height * tileSize * zoomView));
		view.zoom = zoomView;
		draw();
		updateCursorPos();
		setCursor();
		if( f != null ) {
			sc.scrollLeft(tx);
			sc.scrollTop(ty);
		}
	}

	function paint(x, y) {
		var l = currentLayer;
		if( !l.enabled() ) return;
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
				var t = l.current + (palette.randomMode ? Std.random(l.currentWidth) + Std.random(l.currentHeight) * l.stride : dx + dy * l.stride);
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
		var l = currentLayer;

		if( e.ctrlKey ) {
			switch( e.keyCode ) {
			case K.F4:
				action("close");
			case K.DELETE:
				var p = pick();
				if( p != null )
					deleteAll(p.layer, p.k, p.index);
			}
			return;
		}
		if( J("input[type=text]:focus").length > 0 || currentLayer == null ) return;

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
		case "V".code:
			action("visible", !l.visible);
			content.find("[name=visible]").prop("checked", l.visible);
		case "L".code:
			action("lock", !l.lock);
			content.find("[name=lock]").prop("checked", l.lock);
		case "G".code:
			if( l.hasFloatCoord ) {
				action("lockGrid", l.floatCoord);
				content.find("[name=lockGrid]").prop("checked", !l.floatCoord);
			}
		case "F".code:
			if( currentLayer.hasRotFlip ) {
				flipMode = !flipMode;
				savePrefs();
			}
			setCursor();
		case "I".code:
			paletteOption("small");
		case "D".code:
			if( currentLayer.hasRotFlip ) {
				rotation++;
				rotation %= 4;
				savePrefs();
			}
			setCursor();
		case "O".code:
			if( palette != null && l.tileProps != null ) {
				var mode = Object;
				var found = false;

				for( t in l.tileProps.sets )
					if( t.x + t.y * l.stride == l.current && t.t == mode ) {
						found = true;
						l.tileProps.sets.remove(t);
						break;
					}
				if( !found ) {
					l.tileProps.sets.push( { x : l.current % l.stride, y : Std.int(l.current / l.stride), w : l.currentWidth, h : l.currentHeight, t : mode, opts : { } } );

					// look for existing objects and group them
					for( l2 in layers )
						if( l2.tileProps == l.tileProps ) {
							switch( l2.data ) {
							case TileInstances(_, insts):
								var found = [];
								for( i in insts )
									if( i.o == l.current )
										found.push({ x : i.x, y : i.y, i : [] });
									else {
										var d = i.o - l.current;
										var dx = d % l.stride;
										var dy = Std.int(d / l.stride);
										for( f in found )
											if( f.x == i.x - dx && f.y == i.y - dy )
												f.i.push(i);
									}
								var count = l.currentWidth * l.currentHeight - 1;
								for( f in found )
									if( f.i.length == count )
										for( i in f.i ) {
											l2.dirty = true;
											insts.remove(i);
										}
							default:
							}
						}
				}

				setCursor();
				save();
				draw();
			}
		case "R".code:
			paletteOption("random");
		case K.LEFT:
			e.preventDefault();
			var w = l.currentWidth, h = l.currentHeight;
			if( l.current % l.stride > w-1 ) {
				l.current -= w;
				if( w != 1 || h != 1 ) {
					l.currentWidth = w;
					l.currentHeight = h;
					l.saveState();
				}
				setCursor();
			}
		case K.RIGHT:
			e.preventDefault();
			var w = l.currentWidth, h = l.currentHeight;
			if( l.current % l.stride < l.stride - w && l.images != null && l.current + w < l.images.length ) {
				l.current += w;
				if( w != 1 || h != 1 ) {
					l.currentWidth = w;
					l.currentHeight = h;
					l.saveState();
				}
				setCursor();
			}
		case K.DOWN:
			e.preventDefault();
			var w = l.currentWidth, h = l.currentHeight;
			if( l.images != null && l.current + l.stride * h < l.images.length ) {
				l.current += l.stride * h;
				if( w != 1 || h != 1 ) {
					l.currentWidth = w;
					l.currentHeight = h;
					l.saveState();
				}
				setCursor();
			}
		case K.UP:
			e.preventDefault();
			var w = l.currentWidth, h = l.currentHeight;
			if( l.current >= l.stride * h ) {
				l.current -= l.stride * h;
				if( w != 1 || h != 1 ) {
					l.currentWidth = w;
					l.currentHeight = h;
					l.saveState();
				}
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

	function deleteAll( l : LayerData, k : Int, index : Int ) {
		switch( l.data ) {
		case Layer(data), Tiles(_, data):
			for( i in 0...width * height )
				if( data[i] == k + 1 )
					data[i] = 0;
		case Objects(_, objs):
			return;
		case TileInstances(_, insts):
			for( i in insts.copy() )
				if( i.o == k )
					insts.remove(i);
		}
		l.dirty = true;
		save();
		draw();
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
			if( palette.randomMode ) w = h = 1;
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
			canvas.off("mousemove");
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

	function set( x, y, replace ) {
		if( selection != null )
			return;
		if( palette.paintMode ) {
			paint(x,y);
			return;
		}
		var l = currentLayer;
		if( !l.enabled() ) return;
		switch( l.data ) {
		case Layer(data):
			if( data[x + y * width] == l.current || l.blanks[l.current] ) return;
			data[x + y * width] = l.current;
			l.dirty = true;
			save();
			draw();
		case Tiles(_, data):
			var changed = false;
			if( palette.randomMode ) {
				var putObjs = l.getSelObjects();
				var putObj = putObjs[Std.random(putObjs.length)];
				if( putObj != null ) {
					var id = putObj.x + putObj.y * l.stride + 1;
					for( dx in 0...putObj.w )
						for( dy in 0...putObj.h ) {
							var k = id + dx + dy * l.stride;
							var p = (x + dx) + (y + dy) * width;
							var old = data[p];
							if( old == k || l.blanks[k - 1] ) continue;
							if( replace && old > 0 ) {
								for( i in 0...width*height )
									if( data[i] == old )
										data[i] = k;
							} else
								data[p] = k;
							changed = true;
						}
					changed = true;
				} else {
					var p = x + y * width;
					var old = data[p];
					if( replace && old > 0 ) {
						for( i in 0...width*height )
							if( data[i] == old ) {
								var id = l.current + Std.random(l.currentWidth) + Std.random(l.currentHeight) * l.stride + 1;
								if( old == id || l.blanks[id - 1] ) continue;
								data[i] = id;
							}
					} else {
						var id = l.current + Std.random(l.currentWidth) + Std.random(l.currentHeight) * l.stride + 1;
						if( old == id || l.blanks[id - 1] ) return;
						data[p] = id;
					}
					changed = true;
				}
			} else {
				for( dy in 0...l.currentHeight )
					for( dx in 0...l.currentWidth ) {
						var p = x + dx + (y + dy) * width;
						var id = l.current + dx + dy * l.stride + 1;
						var old = data[p];
						if( old == id || l.blanks[id - 1] ) continue;
						if( replace && old > 0 ) {
							for( i in 0...width*height )
								if( data[i] == old )
									data[i] = id;
						} else
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
					if( i.o == l.current && i.x == x && i.y == y && i.flip == flipMode && i.rot == rotation ) return;
					insts.remove(i);
				}
			}
			if( putObj != null )
				insts.push( { x : x, y : y, o : putObj.x + putObj.y * l.stride, rot : rotation, flip : flipMode } );
			else
				for( dy in 0...l.currentHeight )
					for( dx in 0...l.currentWidth )
						insts.push( { x : x+dx, y : y+dy, o : l.current + dx + dy * l.stride, rot : rotation, flip : flipMode } );
			inline function getY(i:Instance) {
				var o = objs.get(i.o);
				return Std.int( (i.y + (o == null ? 1 : o.h)) * tileSize);
			}
			inline function getX(i:Instance) {
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
		view.fill(0xFF909090);
		for( index in 0...layers.length ) {
			var l = layers[index];
			if( !l.visible )
				continue;
			l.draw(view);
		}
		view.flush();
	}

	public function save() {
		if( mouseDown != null || deleteMode != null ) {
			needSave = true;
			return;
		}
		needSave = false;
		for( l in layers )
			l.save();
		model.save();
	}

	public function savePrefs() {
		var sc = content.find(".scroll");
		var state : LevelState = {
			zoomView : zoomView,
			curLayer : currentLayer == null ? null : currentLayer.name,
			scrollX : Std.int(sc.scrollLeft()),
			scrollY : Std.int(sc.scrollTop()),
			paintMode : palette.paintMode,
			randomMode : palette.randomMode,
			paletteMode : palette.mode,
			paletteModeCursor : palette.modeCursor,
			smallPalette : palette.small,
			rotation : rotation,
			flipMode : flipMode,
		};
		js.Browser.getLocalStorage().setItem(sheetPath+"#"+index, haxe.Serializer.run(state));
	}

	@:keep function scale( s : Float ) {
		if( s == null || Math.isNaN(s) )
			return;
		for( l in layers ) {
			if( !l.visible ) continue;
			l.dirty = true;
			l.scale(s);
		}
		save();
		draw();
	}

	@:keep function scroll( dx : Int, dy : Int ) {
		if( dx == null || Math.isNaN(dx) ) dx = 0;
		if( dy == null || Math.isNaN(dy) ) dy = 0;
		for( l in layers ) {
			if( !l.visible ) continue;
			l.dirty = true;
			l.scroll(dx, dy);
		}
		save();
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
		setCursor();
		save();
		draw();
	}

	function setLayerMode( mode : LayerMode ) {
		if( currentLayer.tileProps == null ) {
			js.Browser.alert("Choose file first");
			return;
		}
		currentLayer.setMode(mode);
		save();
		reload();
	}

	@:keep function paletteOption(name, ?val:String) {
		if( palette.option(name, val) ) {
			save();
			draw();
		}
	}

	function setLayer( l : LayerData ) {
		var old = currentLayer;
		if( l == old ) {
			setCursor();
			return;
		}
		currentLayer = l;
		if( !l.hasRotFlip ) {
			flipMode = false;
			rotation = 0;
		}

		savePrefs();
		content.find("[name=alpha]").val(Std.string(Std.int(l.props.alpha * 100)));
		content.find("[name=visible]").prop("checked", l.visible);
		content.find("[name=lock]").prop("checked", l.lock);
		content.find("[name=lockGrid]").prop("checked", !l.floatCoord).closest(".item").css( { display : l.hasFloatCoord ? "" : "none" } );
		content.find("[name=mode]").val("" + (l.props.mode != null ? l.props.mode : LayerMode.Tiles));
		var tmp : Dynamic = content.find("[name=color]");
		var css = { display : (l.idToIndex == null || ((l.images == null || l.hasSize) && l.colors == null)) && !l.data.match(Tiles(_) | TileInstances(_)) ? "" : "none" };
		tmp.spectrum("set", toColor(l.props.color)).closest(".item").css(css);
		switch( l.data ) {
		case Tiles(t,_), TileInstances(t,_):
			content.find("[name=size]").val("" + t.size).closest(".item").show();
			content.find("[name=file]").closest(".item").show();
		default:
			content.find("[name=size]").closest(".item").hide();
			content.find("[name=file]").closest(".item").hide();
		}

		if( l.data.match(TileInstances(_)) ) {
			palette.randomMode = false;
			palette.paintMode = false;
			savePrefs();
		}

		palette.reset();

		if( l.images == null ) {
			setCursor();
			return;
		}

		palette.layerChanged(l);
		setCursor();
	}

	public function setCursor() {
		var l = currentLayer;
		if( l == null ) {
			cursor.hide();
			return;
		}

		content.find(".menu .item.selected").removeClass("selected");
		l.comp.addClass("selected");
		palette.updateSelect();

		var size = zoomView < 1 ? Std.int(tileSize * zoomView) : Math.ceil(tileSize * zoomView);

		if( selection != null ) {
			cursorImage.setSize(0,0);
			cursor.show();
			cursor.css( {
				border : "",
				marginLeft : Std.int(selection.x * tileSize * zoomView - 1) + "px",
				marginTop : Std.int(selection.y * tileSize * zoomView) + "px",
				width : Std.int(selection.w * tileSize * zoomView) + "px",
				height : Std.int(selection.h * tileSize * zoomView) + "px"
			});
			return;
		}

		var cur = l.current;
		var w = palette.randomMode ? 1 : l.currentWidth;
		var h = palette.randomMode ? 1 : l.currentHeight;
		if( l.data.match(TileInstances(_)) ) {
			var o = l.getSelObjects();
			if( o.length > 0 ) {
				cur = o[0].x + o[0].y * l.stride;
				w = o[0].w;
				h = o[0].h;
			}
		}
		cursorImage.setSize(size * w, size * h);
		var px = 0, py = 0;
		if( l.images != null ) {
			switch( l.data ) {
			case Objects(_):
				var i = l.images[cur];
				var w = Math.ceil(i.width * zoomView);
				var h = Math.ceil(i.height * zoomView);
				cursorImage.setSize(w, h);
				cursorImage.clear();
				cursorImage.drawScaled(i, 0, 0, w, h);
			default:
				cursorImage.clear();
				for( y in 0...h )
					for( x in 0...w ) {
						var i = l.images[cur + x + y * l.stride];
						cursorImage.drawSub(i, 0, 0, i.width, i.height, x * size, y * size, size, size);
					}
				cursor.css( { border : "none" } );
				if( flipMode || rotation != 0 ) {
					var tw = size * w, th = size * h;
					tmpImage.setSize(tw, th);
					var m = { a : 0., b : 0., c : 0., d : 0., x : 0., y : 0. };
					l.initMatrix(m, tw, th, rotation, flipMode);
					tmpImage.clear();
					tmpImage.draw(cursorImage, 0, 0);
					var cw = Std.int(tw * m.a + th * m.c);
					var ch = Std.int(tw * m.b + th * m.d);
					cursorImage.setSize(cw < 0 ? -cw : cw, ch < 0 ? -ch : ch);
					cursorImage.clear();
					cursorImage.drawMat(tmpImage, m);
				}
			}
			cursorImage.fill(0x605BA1FB);
			if (l.hasSize) cursor.css( { border : "1px solid black" } );
		} else {
			var c = l.colors == null ? l.props.color : l.colors[cur];
			var lum = ((c & 0xFF) + ((c >> 8) & 0xFF) + ((c >> 16) & 0xFF)) / (255 * 3);
			cursorImage.fill(c | 0xFF000000);
			cursor.css( { border : "1px solid " + (lum < 0.25 ? "white":"black") } );
		}
		var canvas = cursorImage.getCanvas();
		canvas.style.marginLeft = -px + "px";
		canvas.style.marginTop = -py + "px";
	}

}
