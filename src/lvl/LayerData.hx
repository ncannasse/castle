package lvl;
import cdb.Data;

typedef LayerState = {
	var current : Int;
	var visible : Bool;
	var lock : Bool;
	var cw : Int;
	var ch : Int;
}

typedef TileInfos = { file : String, stride : Int, size : Int };

enum LayerInnerData {
	Layer( a : Array<Int> );
	Objects( idCol : String, objs : Array<{ x : Float, y : Float, ?width : Float, ?height : Float }> );
	Tiles( t : TileInfos, data : Array<Int> );
	TileInstances( t : TileInfos, insts : Array<{ x : Float, y : Float, o : Int }> );
}

class LayerData extends LayerGfx {

	public var sheet : Sheet;
	public var name : String;
	public var props : LayerProps;
	public var data : LayerInnerData;

	public var visible(default,set) : Bool = true;
	public var dirty : Bool;

	public var current(default, set) : Int = 0;
	public var currentWidth : Int = 1;
	public var currentHeight : Int = 1;
	public var comp : js.JQuery;

	public var baseSheet : Sheet;
	public var floatCoord : Bool;

	public var targetObj : { o : Dynamic, f : String };
	public var listColumnn : Column;
	public var tileProps : TilesetProps;

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

	function loadState() {
		var state : LayerState = try haxe.Unserializer.run(js.Browser.getLocalStorage().getItem(level.sheetPath + ":" + name)) catch( e : Dynamic ) null;
		if( state != null ) {
			visible = state.visible;
			floatCoord = hasFloatCoord && !state.lock;
			if( state.current < (images != null ? images.length : names.length) ) {
				current = state.current;
				if( (current%stride) + state.cw <= stride && Std.int(current/stride) + state.ch <= height ) {
					currentWidth = state.cw;
					currentHeight = state.ch;
					saveState();
				}
			}
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

	public function getTileProp() {
		if( tileProps == null ) return null;
		for( s in tileProps.sets )
			if( s.x + s.y * stride == current )
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
					v = vx + vy * w;
					if( vx >= w || vy >= h || blanks[v] )
						data[i] = 0;
					else
						data[i] = v + 1;
				}
			case Objects:
				var insts = [];
				var p = 1;
				if( data[0] != 0xFFFF ) throw "assert";
				while( p < data.length ) {
					var x = data[p++]/level.tileSize;
					var y = data[p++]/level.tileSize;
					var v = data[p++];
					var vx = v % stride;
					var vy = Std.int(v / stride);
					v = vx + vy * w;
					if( vx >= w || vy >= h || x >= level.width || y >= level.height )
						continue;
					insts.push({ x : x, y : y, o : v });
				}
				this.data = TileInstances(d, insts);
				hasFloatCoord = floatCoord = true;
			}
			this.stride = d.stride = w;
			height = h;
			tileProps = level.getTileProps(file, w);
			loadState();
			level.waitDone();
		});
	}

	function set_visible(v) {
		visible = v;
		if( comp != null ) comp.toggleClass("hidden", !visible);
		saveState();
		return v;
	}

	function set_current(v) {
		current = v;
		currentWidth = 1;
		currentHeight = 1;

		if( images != null && comp != null )
			comp.find("div.img").html("").append(new js.JQuery(images[current].getCanvas()));

		saveState();
		return v;
	}

	function setCurrent(id, w, h) {
		if( current == id && currentWidth == w && currentHeight == h )
			return;
		Reflect.setField(this, "current", id);
		currentWidth = w;
		currentHeight = h;
		if( images != null && comp != null )
			comp.find("div.img").html("").append(new js.JQuery(images[current].getCanvas()));
		saveState(false);
	}

	public function saveState( sync = true ) {
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
			lock : hasFloatCoord && !floatCoord,
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
			return haxe.crypto.Base64.encode(b);
		case Objects(_, objs):
			return objs;
		case Tiles(t, data):
			var b = new haxe.io.BytesOutput();
			for( r in 0...data.length )
				b.writeUInt16(data[r]);
			return t.file == null ? null : { file : t.file, size : t.size, stride : t.stride, data : haxe.crypto.Base64.encode(b.getBytes()) };
		case TileInstances(t, insts):
			var b = new haxe.io.BytesOutput();
			b.writeUInt16(0xFFFF);
			for( i in insts ) {
				b.writeUInt16(Std.int(i.x * level.tileSize));
				b.writeUInt16(Std.int(i.y * level.tileSize));
				b.writeUInt16(i.o);
			}
			return t.file == null ? null : { file : t.file, size : t.size, stride : t.stride, data : haxe.crypto.Base64.encode(b.getBytes()) };
		}
	}


}

