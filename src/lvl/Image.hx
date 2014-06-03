package lvl;

class Image {
	public var width(default, null) : Int;
	public var height(default, null) : Int;
	var ctx : js.html.CanvasRenderingContext2D;
	var canvas : js.html.CanvasElement;
	// origin can be either the canvas element or the original IMG if not modified
	// this speed up things a lot since drawing canvas to canvas is very slow on Chrome
	var origin : Dynamic;
	var originX : Int = 0;
	var originY : Int = 0;

	public function new(w, h) {
		this.width = w;
		this.height = h;
		canvas = js.Browser.document.createCanvasElement();
		origin = canvas;
		canvas.width = w;
		canvas.height = h;
		ctx = canvas.getContext2d();
	}

	function getColor( color : Int ) {
		 return color >>> 24 == 0xFF ? "#" + StringTools.hex(color&0xFFFFFF, 6) : "rgba(" + ((color >> 16) & 0xFF) + "," + ((color >> 8) & 0xFF) + "," + (color & 0xFF) + "," + ((color >>> 24) / 255) + ")";
	}

	public function getCanvas() {
		return canvas;
	}

	public function clear() {
		ctx.clearRect(0, 0, width, height);
		invalidate();
	}

	function invalidate() {
		origin = canvas;
		originX = originY = 0;
	}

	public function fill( color : Int ) {
		ctx.fillStyle = getColor(color);
		ctx.fillRect(0, 0, width, height);
		invalidate();
	}

	public function fillRect( x : Int, y : Int, w : Int, h : Int, color : Int ) {
		ctx.fillStyle = getColor(color);
		ctx.fillRect(x, y, w, h);
		invalidate();
	}

	public function sub( x : Int, y : Int, w : Int, h : Int ) {
		var i = new Image(w, h);
		i.ctx.drawImage(origin, x, y, w, h, 0, 0, w, h);
		i.origin = origin;
		i.originX = originX + x;
		i.originY = originY + y;
		return i;
	}

	public function text( text : String, x : Int, y : Int, color : Int = 0xFFFFFFFF ) {
		ctx.fillStyle = getColor(color);
		ctx.fillText(text, x, y);
		invalidate();
	}

	public function draw( i : Image, x : Int, y : Int ) {
		ctx.drawImage(i.origin, i.originX, i.originY, i.width, i.height, x, y, i.width, i.height);
		invalidate();
	}

	public function drawSub( i : Image, srcX : Int, srcY : Int, srcW : Int, srcH : Int, x : Int, y : Int, dstW : Int = -1, dstH : Int = -1, smooth = false ) {
		if( dstW < 0 ) dstW = srcW;
		if( dstH < 0 ) dstH = srcH;
		ctx.imageSmoothingEnabled = smooth;
		ctx.drawImage(i.origin, srcX + i.originX, srcY + i.originY, srcW, srcH, x, y, dstW, dstH);
		invalidate();
	}

	public function copyFrom( i : Image, smooth = false ) {
		ctx.fillStyle = "rgba(0,0,0,0)";
		ctx.fillRect(0, 0, width, height);
		ctx.imageSmoothingEnabled = smooth;
		ctx.drawImage(i.origin, i.originX, i.originY, i.width, i.height, 0, 0, width, height);
		invalidate();
	}

	public function isBlank() {
		var i = ctx.getImageData(0, 0, width, height);
		for( k in 0...width * height * 4 )
			if( i.data[k] != 0 ) return false;
		return true;
	}

	public function setSize( width, height ) {
		if( width == this.width && height == this.height )
			return;
		canvas.width = width;
		canvas.height = height;
		canvas.setAttribute("width", width + "px");
		canvas.setAttribute("height", height + "px");
		ctx = canvas.getContext2d();
		this.width = width;
		this.height = height;
		invalidate();
	}

	public function resize( width : Int, height : Int, ?smooth : Bool ) {
		if( width == this.width && height == this.height )
			return;
		if( smooth == null )
			smooth = width < this.width || height < this.height;
		var c = js.Browser.document.createCanvasElement();
		c.width = width;
		c.height = height;
		var ctx2 = c.getContext2d();
		ctx2.imageSmoothingEnabled = smooth;
		ctx2.drawImage(canvas, 0, 0, this.width, this.height, 0, 0, width, height);
		ctx = ctx2;
		canvas = c;
		this.width = width;
		this.height = height;
		invalidate();
	}

	static var cache = new Map<String,js.html.ImageElement>();

	public static function clearCache( url : String ) {
		cache.remove(url);
	}

	public static function load( url : String, callb : Image -> Void, ?onError : Void -> Void, ?forceReload ) {
		var i = cache.get(url);
		if( i != null && !forceReload ) {
			var im = new Image(i.width, i.height);
			im.ctx.drawImage(i, 0, 0);
			im.origin = i;
			callb(im);
			return;
		}
		i = js.Browser.document.createImageElement();
		i.onload = function(_) {
			cache.set(url, i);
			var im = new Image(i.width, i.height);
			im.ctx.drawImage(i, 0, 0);
			im.origin = i;
			callb(im);
		};
		i.onerror = function(_) {
			if( onError != null ) {
				onError();
				return;
			}
			var i = new Image(16, 16);
			i.fill(0xFFFF00FF);
			callb(i);
		};
		i.src = url;
	}

	public static function fromCanvas( c : js.html.CanvasElement ) {
		var i = new Image(0, 0);
		i.width = c.width;
		i.height = c.height;
		i.canvas = i.origin = c;
		i.ctx = c.getContext2d();
		return i;
	}
}

