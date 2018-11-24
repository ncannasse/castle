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
package lvl;
import cdb.Data;
import cdb.Sheet;

typedef LayerState = {
	var current : Int;
	var visible : Bool;
	var lockGrid : Bool;
	var lock : Bool;
	var cw : Int;
	var ch : Int;
}

typedef TileInfos = { file : String, stride : Int, size : Int };

typedef Instance = { x : Float, y : Float, o : Int, rot : Int, flip : Bool };

enum LayerInnerData {
	Layer( a : Array<Int> );
	Objects( idCol : String, objs : Array<{ x : Float, y : Float, ?width : Float, ?height : Float }> );
	Tiles( t : TileInfos, data : Array<Int> );
	TileInstances( t : TileInfos, insts : Array<Instance> );
}

class LayerData extends LayerGfx {

	public var sheet : Sheet;
	public var name : String;
	public var props : LayerProps;
	public var data : LayerInnerData;

	public var visible(default,set) : Bool = true;
	public var lock : Bool = false;
	public var dirty : Bool;

	public var current(default, set) : Int = 0;
	public var currentWidth : Int = 1;
	public var currentHeight : Int = 1;
	public var comp : js.jquery.JQuery;

	public var baseSheet : Sheet;
	public var floatCoord : Bool;
	public var hasRotFlip : Bool;

	public var targetObj : { o : Dynamic, f : String };
	public var listColumnn : Column;
	public var tileProps : TilesetProps;

	var stateLoaded : Bool;

	public function new(level, name, p, target) {
		super(level);
		this.name = name;
		props = p;
		targetObj = target;
	}

	public function loadSheetData( sheet : Sheet ) {
		// look for default color
		if( sheet == null && props.color == null ) {
			props.color = 0xFF0000;
			for( o in level.sheet.lines ) {
				var props : cdb.Data.LevelProps = o.props;
				if( props == null ) continue;
				for( l in props.layers )
					if( l.l == this.name && l.p.color != null ) {
						this.props.color = l.p.color;
						props = null;
						break;
					}
				if( props == null ) break;
			}
		}
		this.sheet = sheet;
		fromSheet(sheet, props.color);
		loadState();
	}

	public function enabled() {
		return visible && !lock;
	}

	function loadState() {
		var state : LayerState = try haxe.Unserializer.run(js.Browser.getLocalStorage().getItem(level.sheetPath + ":" + name)) catch( e : Dynamic ) null;
		if( state != null ) {
			visible = state.visible;
			lock = !!state.lock;
			floatCoord = hasFloatCoord && !state.lockGrid;
			if( state.current < (images != null ? images.length : names.length) ) {
				current = state.current;
				if( (current%stride) + state.cw <= stride && Std.int(current/stride) + state.ch <= height ) {
					currentWidth = state.cw;
					currentHeight = state.ch;
				}
			}
		}
		stateLoaded = true;
	}

	public function setLayerData( val : String ) {
		if( val == null || val == "" )
			data = Layer([for( x in 0...level.width * level.height ) 0]);
		else {
			var a = cdb.Lz4Reader.decodeString(val);
			if( a.length != level.width * level.height ) throw "Invalid layer data";
			data = Layer([for( i in 0...level.width * level.height ) a.get(i)]);
		}
		if( sheet.lines.length > 256 ) throw "Too many lines";
	}

	public function getTileProp( mode ) {
		if( tileProps == null ) return null;
		for( s in tileProps.sets )
			if( s.x + s.y * stride == current && s.t == mode )
				return s;
		return null;
	}

	public function getTileObjects() {
		var objs = new Map();
		if( tileProps == null ) return objs;
		for( o in tileProps.sets )
			if( o.t == Object )
				objs.set(o.x + o.y * stride, o);
		return objs;
	}

	public function getSelObjects() {
		if( tileProps == null ) return [];
		var x = current % stride;
		var y = Std.int(current / stride);
		var out = [];
		for( o in tileProps.sets )
			if( o.t == Object && !(o.x >= x + currentWidth || o.y >= y + currentHeight || o.x + o.w <= x || o.y + o.h <= y) )
				out.push(o);
		return out;
	}

	public function setObjectsData( id, val ) {
		data = Objects(id, val);
	}

	public function setTilesData( val : cdb.Types.TileLayer ) {
		var file = val == null ? null : val.file;
		var size = val == null ? 16 : val.size;
		var data = val == null ? [for( i in 0...level.width*level.height ) 0] : val.data.decode();
		var stride = val == null ? 0 : val.stride;
		var d = { file : file, size : size, stride : stride };
		images = [];
		this.data = Tiles(d, data);
		if( file == null ) {
			if( props.mode != Tiles && props.mode != null ) Reflect.deleteField(props, "mode");
			var i = new Image(16, 16);
			i.fill(0xFFFF00FF);
			images.push(i);
			loadState();
			return;
		}
		level.wait();
		level.loadAndSplit(file, size, function(w, h, images, blanks) {

			this.images = images;
			this.blanks = blanks;

			if( data[0] == 0xFFFF )
				props.mode = Objects;

			switch( props.mode ) {
			case null, Tiles, Ground:
				var max = w * h;
				for( i in 0...data.length ) {
					var v = data[i] - 1;
					if( v < 0 ) continue;
					var vx = v % stride;
					var vy = Std.int(v / stride);
					var v2 = vx + vy * w;
					if( vx >= w || vy >= h || blanks[v2] )
						v2 = -1;
					if( v != v2 ) {
						data[i] = v2 + 1;
						dirty = true;
					}
				}
			case Objects:
				var insts = [];
				var p = 1;
				if( data[0] != 0xFFFF ) throw "assert";
				while( p < data.length ) {
					var x = data[p++];
					var y = data[p++];
					var v = data[p++];
					var flip = v & 0x8000 != 0;
					var rot = (x >> 15) | ((y >> 15) << 1);
					v &= 0x7FFF;
					var x = (x&0x7FFF)/level.tileSize;
					var y = (y&0x7FFF)/level.tileSize;
					var vx = v % stride;
					var vy = Std.int(v / stride);
					var v2 = vx + vy * w;
					if( vx >= w || vy >= h || x >= level.width || y >= level.height ) {
						dirty = true;
						continue;
					}
					if( v != v2 ) dirty = true;
					insts.push({ x : x, y : y, o : v2, flip : flip, rot : rot });
				}
				this.data = TileInstances(d, insts);
				hasRotFlip = true;
				hasFloatCoord = floatCoord = true;
			}
			this.stride = d.stride = w;
			height = h;
			tileProps = level.palette.getTileProps(file, w, w*h);
			loadState();
			level.waitDone();
		});
	}

	function set_visible(v) {
		visible = v;
		if( comp != null ) comp.toggleClass("hidden", !visible);
		return v;
	}

	function set_current(v) {
		current = v;
		currentWidth = 1;
		currentHeight = 1;
		saveState();
		return v;
	}

	function setCurrent(id, w, h) {
		if( current == id && currentWidth == w && currentHeight == h )
			return;
		Reflect.setField(this, "current", id);
		currentWidth = w;
		currentHeight = h;
		saveState(false);
	}

	public function saveState( sync = true ) {
		if( !stateLoaded )
			return;
		if( sync && data != null ) {
			switch( data ) {
			case Tiles(t, _), TileInstances(t, _):
				for( l in level.layers )
					if( l != this ) {
						switch( l.data ) {
						case Tiles(t2, _), TileInstances(t2, _) if( t2.file == t.file ):
							l.setCurrent(current, currentWidth, currentHeight);
						default:
						}
					}
			default:
			}
		}
		var s : LayerState = {
			current : current,
			visible : visible,
			lock : lock,
			lockGrid : hasFloatCoord && !floatCoord,
			cw : currentWidth,
			ch : currentHeight,
		};
		js.Browser.getLocalStorage().setItem(level.sheetPath + ":" + name, haxe.Serializer.run(s));
	}

	public function save() {
		if( !dirty ) return;
		dirty = false;
		Reflect.setField(targetObj.o, targetObj.f, getData());
	}

	function getData() : Dynamic {
		switch( data ) {
		case Layer(data):
			var b = haxe.io.Bytes.alloc(level.width * level.height);
			var p = 0;
			for( y in 0...level.height )
				for( x in 0...level.width ) {
					b.set(p, data[p]);
					p++;
				}
			return cdb.Lz4Reader.encodeBytes(b, level.model.compressionEnabled());
		case Objects(_, objs):
			return objs;
		case Tiles(t, data):
			var b = new haxe.io.BytesOutput();
			for( r in 0...data.length )
				b.writeUInt16(data[r]);
			return t.file == null ? null : { file : t.file, size : t.size, stride : t.stride, data : cdb.Lz4Reader.encodeBytes(b.getBytes(),level.model.compressionEnabled()) };
		case TileInstances(t, insts):
			var b = new haxe.io.BytesOutput();
			b.writeUInt16(0xFFFF);
			for( i in insts ) {
				b.writeUInt16(Std.int(i.x * level.tileSize) | ((i.rot&1) << 15));
				b.writeUInt16(Std.int(i.y * level.tileSize) | ((i.rot>>1) << 15));
				b.writeUInt16(i.o | ((i.flip?1:0)<<15));
			}
			return t.file == null ? null : { file : t.file, size : t.size, stride : t.stride, data : cdb.Lz4Reader.encodeBytes(b.getBytes(),level.model.compressionEnabled()) };
		}
	}

	public function scale( s : Float ) {
		var width = level.width;
		var height = level.height;
		switch( data ) {
		case Tiles(_, data), Layer(data):
			var ndata = [];
			for( y in 0...height )
				for( x in 0...width ) {
					var tx = Std.int(x / s);
					var ty = Std.int(y / s);
					var k = if( tx >= width || ty >= height ) 0 else data[tx + ty * width];
					ndata.push(k);
				}
			for( i in 0...width * height )
				data[i] = ndata[i];
		case Objects(_, objs):
			var m = floatCoord ? level.tileSize : 1;
			for( o in objs.copy() ) {
				o.x = Std.int(o.x * s * m) / m;
				o.y = Std.int(o.y * s * m) / m;
				if( o.x < 0 || o.y < 0 || o.x >= width || o.y >= height )
					objs.remove(o);
			}
		case TileInstances(_, insts):
			var m = floatCoord ? level.tileSize : 1;
			for( i in insts.copy() ) {
				i.x = Std.int(i.x * s * m) / m;
				i.y = Std.int(i.y * s * m) / m;
				if( i.x < 0 || i.y < 0 || i.x >= width || i.y >= height )
					insts.remove(i);
			}
		}
	}

	public function scroll( dx : Int, dy : Int ) {
		var width = level.width;
		var height = level.height;
		switch( data ) {
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

	public function setMode( mode : LayerMode ) {
		var old = props.mode;
		if( old == null ) old = Tiles;
		var width = level.width;
		var height = level.height;
		switch( [old, mode] ) {
		case [(Ground | Tiles), (Tiles | Ground)], [Objects, Objects]:
			// nothing
		case [(Ground | Tiles), Objects]:
			switch( data ) {
			case Tiles(td, data):
				var oids = new Map();
				for( p in tileProps.sets )
					if( p.t == Object )
						oids.set(p.x + p.y * stride, p);
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
									var id = d + dx + dy * stride;
									if( data[tp] != id + 1 ) {
										if( data[tp] == 0 && blanks[id] ) continue;
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
				this.data = TileInstances(td, [for( o in objs ) { x : o.x, y : o.y, o : o.id, flip : false, rot : 0 }]);
				dirty = true;
			default:
				throw "assert0";
			}
		case [Objects, (Ground | Tiles)]:
			switch( data ) {
			case TileInstances(td,insts):
				var objs = getTileObjects();
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
									data[x + y * width] = i.o + dx + dy * stride + 1;
							}
					}
				}
				this.data = Tiles(td, data);
				dirty = true;
			default:
				throw "assert1";
			}
		}
		props.mode = mode;
		if( mode == Tiles ) Reflect.deleteField(props, "mode");
	}


	public inline function initMatrix( m : { a : Float, b : Float, c : Float, d : Float, x : Float, y : Float }, w : Int, h : Int, rot : Int, flip : Bool ) {
		m.a = 1;
		m.b = 0;
		m.c = 0;
		m.d = 1;
		m.x = -w * 0.5;
		m.y = -h * 0.5;
		if( rot != 0 ) {
			var a = Math.PI * rot / 2;
			var c = Math.cos(a);
			var s = Math.sin(a);
			var x = m.x, y = m.y;
			m.a = c;
			m.b = s;
			m.c = -s;
			m.d = c;
			m.x = x * c - y * s;
			m.y = x * s + y * c;
		}
		if( flip ) {
			m.a = -m.a;
			m.c = -m.c;
			m.x = -m.x;
		}
		m.x += Math.abs(m.a * w * 0.5 + m.c * h * 0.5);
		m.y += Math.abs(m.b * w * 0.5 + m.d * h * 0.5);
	}

	public function draw( view : lvl.Image3D ) {
		view.alpha = props.alpha;
		var width = level.width;
		var height = level.height;
		var size = level.tileSize;
		switch( data ) {
		case Layer(data):
			var first = @:privateAccess level.layers[0] == this; // firstLayer : no transparency
			for( y in 0...height )
				for( x in 0...width ) {
					var k = data[x + y * width];
					if( k == 0 && !first ) continue;
					if( images != null ) {
						var i = images[k];
						view.draw(i, x * size - ((i.width - size) >> 1), y * size - (i.height - size));
						continue;
					}
					view.fillRect(x * size, y * size, size, size, colors[k] | 0xFF000000);
				}
		case Tiles(t, data):
			for( y in 0...height )
				for( x in 0...width ) {
					var k = data[x + y * width] - 1;
					if( k < 0 ) continue;
					view.draw(images[k], x * size, y * size);
				}
			if( props.mode == Ground ) {
				var b = new cdb.TileBuilder(tileProps, stride, images.length);
				var a = b.buildGrounds(data, width);
				var p = 0, max = a.length;
				while( p < max ) {
					var x = a[p++];
					var y = a[p++];
					var id = a[p++];
					view.draw(images[id], x * size, y * size);
				}
			}
		case TileInstances(_, insts):
			var objs = getTileObjects();
			var mat = { a : 1., b : 0., c : 0., d : 1., x : 0., y : 0. };
			for( i in insts ) {
				var x = Std.int(i.x * size), y = Std.int(i.y * size);
				var obj = objs.get(i.o);
				var w = obj == null ? 1 : obj.w;
				var h = obj == null ? 1 : obj.h;
				initMatrix(mat, w * size, h * size, i.rot, i.flip);
				mat.x += x;
				mat.y += y;
				if( obj == null ) {
					view.drawMat(images[i.o], mat);
					view.fillRect(x, y, size, size, 0x80FF0000);
				} else {
					var px = mat.x;
					var py = mat.y;
					for( dy in 0...obj.h )
						for( dx in 0...obj.w ) {
							mat.x = px + dx * size * mat.a + dy * size * mat.c;
							mat.y = py + dx * size * mat.b + dy * size * mat.d;
							view.drawMat(images[i.o + dx + dy * stride], mat);
						}
				}
			}
		case Objects(idCol, objs):
			if( idCol == null ) {
				var col = props.color | 0xA0000000;
				for( o in objs ) {
					var w = hasSize ? o.width * size : size;
					var h = hasSize ? o.height * size : size;
					view.fillRect(Std.int(o.x * size), Std.int(o.y * size), Std.int(w), Std.int(h), col);
				}
				var col = props.color | 0xFF000000;
				for( o in objs ) {
					var w = hasSize ? Std.int(o.width * size) : size;
					var h = hasSize ? Std.int(o.height * size) : size;
					var px = Std.int(o.x * size);
					var py = Std.int(o.y * size);
					view.fillRect(px, py, w, 1, col);
					view.fillRect(px, py + h - 1, w, 1, col);
					view.fillRect(px, py + 1, 1, h - 2, col);
					view.fillRect(px + w - 1, py + 1, 1, h - 2, col);
				}
			} else {
				for( o in objs ) {
					var w   = Std.int(hasSize ? o.width  * size : size);
					var h   = Std.int(hasSize ? o.height * size : size);
					var px  = Std.int(o.x * size);
					var py  = Std.int(o.y * size);

					var col = props.color;
					var id : String = Reflect.field(o, idCol);
					var k = idToIndex.get(id);
					if ( k != null && colors != null ) col = colors[k];

					if( hasSize || images == null || k == null ) {
						view.fillRect(px, py, w, h, col | 0xA0000000);
						var col = col | 0xFF000000;
						view.fillRect(px, py, w, 1, col);
						view.fillRect(px, py + h - 1, w, 1, col);
						view.fillRect(px, py + 1, 1, h - 2, col);
						view.fillRect(px + w - 1, py + 1, 1, h - 2, col);
					}

					if( images != null && k != null ) {
						var i = images[k];
						view.draw(i, px, py);
					}
				}
			}
		}
	}

}

