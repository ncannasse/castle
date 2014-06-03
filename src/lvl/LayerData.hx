package lvl;
import cdb.Data;

typedef LayerState = {
	var current : Int;
	var visible : Bool;
	var lock : Bool;
	var cw : Int;
	var ch : Int;
}

enum LayerInnerData {
	Layer( a : Array<Int> );
	Objects( idCol : String, objs : Array<{ x : Float, y : Float, ?width : Float, ?height : Float }> );
	Tiles( t : { file : String, stride : Int, size : Int }, data : Array<Int> );
}


class LayerData {

	var level : Level;
	public var name : String;
	public var sheet : Sheet;
	public var names : Array<String>;
	public var colors : Array<Int>;
	public var images : Array<Image>;
	public var blanks : Array<Bool>;
	public var props : LayerProps;
	public var data : LayerInnerData;

	public var imagesStride : Int = 0;

	public var visible(default,set) : Bool = true;
	public var dirty : Bool;

	public var current(default, set) : Int = 0;
	public var currentWidth : Int = 1;
	public var currentHeight : Int = 1;
	public var comp : js.JQuery;

	public var baseSheet : Sheet;
	public var idToIndex : Map<String,Int>;
	public var indexToId : Array<String>;
	public var floatCoord : Bool;
	public var hasFloatCoord : Bool;
	public var hasSize : Bool;

	public var targetObj : { o : Dynamic, f : String };

	public function new(level, name, p, target) {
		this.level = level;
		this.name = name;
		props = p;
		blanks = [];
		targetObj = target;
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
		var first = @:privateAccess level.layers.length == 0;
		var erase = first ? "#ccc" : "rgba(0,0,0,0)";
		for( c in sheet.columns )
			switch( c.type ) {
			case TColor:
				colors = [for( o in sheet.lines ) { var c = Reflect.field(o, c.name); c == null ? 0 : c; } ];
			case TImage:
				if( images == null ) images = [];
				var size = level.tileSize;
				for( idx in 0...sheet.lines.length ) {
					var key = Reflect.field(sheet.lines[idx], c.name);
					var idat = level.model.getImageData(key);
					if( idat == null && images[idx] != null ) continue;
					if( idat == null ) {
						var i = new Image(size, size);
						i.text("#" + idx, 0, 12);
						images[idx] = i;
						continue;
					}
					level.wait();
					Image.load(idat, function(i) {
						i.resize(size, size);
						images[idx] = i;
						level.waitDone();
					});
				}
			case TTilePos:
				if( images == null ) images = [];

				var size = level.tileSize;

				for( idx in 0...sheet.lines.length ) {
					var data : cdb.Types.TilePos = Reflect.field(sheet.lines[idx], c.name);
					if( data == null && images[idx] != null ) continue;
					if( data == null ) {
						var i = new Image(size, size);
						i.text("#" + idx, 0, 12);
						images[idx] = i;
						continue;
					}
					level.wait();
					Image.load(level.model.getAbsPath(data.file), function(i) {
						var i2 = new Image(data.size, data.size);
						i2.fill(0xFFEEEEEE);
						i2.drawSub(i, data.x * data.size, data.y * data.size, data.size, data.size, 0, 0, data.size, data.size);
						i2.resize(size, size);
						images[idx] = i2;
						blanks[idx] = i2.isBlank();
						level.waitDone();
					});
					level.watch(data.file, function() { Image.clearCache(level.model.getAbsPath(data.file)); level.reload(); });
				}

			case TId:
				idCol = c;
			default:
			}
		names = [];
		imagesStride = Math.ceil(Math.sqrt(sheet.lines.length));
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
		loadState();
	}

	function loadState() {
		var state : LayerState = try haxe.Unserializer.run(js.Browser.getLocalStorage().getItem(level.sheetPath + ":" + name)) catch( e : Dynamic ) null;
		if( state != null ) {
			visible = state.visible;
			floatCoord = hasFloatCoord && !state.lock;
			if( state.current < (images != null ? images.length : names.length) ) {
				current = state.current;
				if( (current%imagesStride) + state.cw <= imagesStride && Std.int(current/imagesStride) + state.ch <= Math.ceil((images != null ? images.length : names.length) / imagesStride) ) {
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
			var i = new Image(16, 16);
			i.fill(0xFFFF00FF);
			images.push(i);
			return;
		}
		level.wait();
		Image.load(level.model.getAbsPath(file), function(i) {
			var w = Std.int(i.width / size);
			var h = Std.int(i.height / size);
			for( y in 0...h )
				for( x in 0...w ) {
					var i = i.sub(x * size, y * size, size, size);
					blanks[images.length] = i.isBlank();
					images.push(i);
				}

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
			imagesStride = d.stride = w;
			loadState();
			level.waitDone();
		});
		level.watch(file, function() Image.load(level.model.getAbsPath(file),function(_) level.reload(), function() {}, true));
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

	public function saveState() {
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
			var r = 0;
			for( y in 0...level.width )
				for( x in 0...level.height )
					b.writeUInt16(data[r++]);
			return t.file == null ? null : { file : t.file, size : t.size, stride : t.stride, data : haxe.crypto.Base64.encode(b.getBytes()) };
		}
	}


}

