package lvl;
import js.html.webgl.GL;
import js.html.webgl.Texture;

class Image3D extends Image {

	var gl : js.html.webgl.RenderingContext;
	var curTexture : Texture;
	var curDraw : js.html.Float32Array;
	var curIndex : js.html.Uint16Array;
	var drawPos : Int;
	var indexPos : Int;

	var attribPos : Int;
	var attribUV : Int;
	var uniTex : js.html.webgl.UniformLocation;
	var uniAlpha : js.html.webgl.UniformLocation;

	public var alpha(default, set) : Float = 1;
	public var zoom(default, set) : Float = 1;

	var scaleX : Float;
	var scaleY : Float;

	var colorCache : Map<Int,Image>;
	var texturesObjects : Array<Dynamic>;

	public function new(w, h) {
		super(w, h);
		colorCache = new Map();
		curDraw = new js.html.Float32Array(4 * 4 * Math.ceil(65536 / 6));
		curIndex = new js.html.Uint16Array(65536);
	}

	override function init() {
		dispose();

		gl = untyped canvas.gl;
		if( gl != null ) {
			setViewport();
			return;
		}
		gl = canvas.getContextWebGL( { alpha : false, antialias : false } );
		untyped canvas.gl = gl;
		gl.disable(GL.CULL_FACE);
		gl.disable(GL.DEPTH_TEST);

		var vertex = gl.createShader(GL.VERTEX_SHADER);
		gl.shaderSource(vertex, "
			varying vec2 tuv;
			attribute vec2 pos;
			attribute vec2 uv;
			void main() {
				tuv = uv;
				gl_Position = vec4(pos + vec2(-1.,1.), 0, 1);
			}
		");
		gl.compileShader(vertex);
		if( gl.getShaderParameter(vertex, GL.COMPILE_STATUS) != cast 1 )
			throw gl.getShaderInfoLog(vertex);
		var frag = gl.createShader(GL.FRAGMENT_SHADER);
		gl.shaderSource(frag, "
			varying mediump vec2 tuv;
			uniform sampler2D texture;
			uniform lowp float alpha;
			void main() {
				lowp vec4 color = texture2D(texture, tuv);
				color.a *= alpha;
				gl_FragColor = color;
			}
		");
		gl.compileShader(frag);
		if( gl.getShaderParameter(frag, GL.COMPILE_STATUS) != cast 1 )
			throw gl.getShaderInfoLog(frag);

		var p = gl.createProgram();
		gl.attachShader(p, vertex);
		gl.attachShader(p, frag);
		gl.linkProgram(p);
		if( gl.getProgramParameter(p, GL.LINK_STATUS) != cast 1 )
			throw gl.getProgramInfoLog(p);

		gl.useProgram(p);
		gl.enableVertexAttribArray(0);
		gl.enableVertexAttribArray(1);

		gl.enable(GL.BLEND);
		gl.blendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
		uniTex = gl.getUniformLocation(p, "texture");
		uniAlpha = gl.getUniformLocation(p, "alpha");
		attribPos = gl.getAttribLocation(p, "pos");
		attribUV = gl.getAttribLocation(p, "uv");

		setViewport();
	}

	public function dispose() {
		if( texturesObjects != null )
			for( o in texturesObjects ) {
				gl.deleteTexture(o.texture);
				o.texture = null;
			}
		texturesObjects = [];
	}

	function set_alpha(v) {
		endDraw();
		return alpha = v;
	}

	function beginDraw( t : Texture ) {
		if( t != curTexture ) {
			endDraw();
			curTexture = t;
			drawPos = 0;
			indexPos = 0;
		}
	}

	function getColorImage( color : Int ) : Image {
		var i = colorCache.get(color);
		if( i != null ) return i;
		i = new Image(1, 1);
		i.fill(color);
		colorCache.set(color, i);
		return i;
	}

	function getTexture( i : Image ) : Texture {
		var t = i.origin.texture;
		if( t != null ) return t;
		t = gl.createTexture();
		i.origin.texture = t;
		untyped t.origin = i.origin;
		gl.bindTexture(GL.TEXTURE_2D, t);
		gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
		gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
		gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
		gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
		gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, i.origin);
		gl.bindTexture(GL.TEXTURE_2D, null);
		texturesObjects.push(i.origin);
		untyped {
			t.width = i.origin.width;
			t.height = i.origin.height;
		}
		return t;
	}

	override function draw( i : Image, x : Int, y : Int ) {

		beginDraw(getTexture(i));

		var x = x;
		var y = y;
		var w = i.width;
		var h = i.height;

		inline function px(x:Int, h) {
			var t = x * scaleX;
			var rt = Std.int(t * width) / width;
			return rt;
		}

		inline function py(y:Int, h) {
			var t = y * scaleY;
			var rt = Std.int(t * height) / height;
			return rt;
		}

		inline function tu(v:Int,h) {
			return (v + (h ? 0 : 0.001)) / untyped curTexture.width;
		}
		inline function tv(v:Int,h) {
			return (v + (h ? -0.01 : 0)) / untyped curTexture.height;
		}

		var pos = drawPos >> 2;
		curDraw[drawPos++] = px(x,false);
		curDraw[drawPos++] = py(y,false);
		curDraw[drawPos++] = tu(i.originX,false);
		curDraw[drawPos++] = tv(i.originY,false);

		curDraw[drawPos++] = px(x + w, true);
		curDraw[drawPos++] = py(y,false);
		curDraw[drawPos++] = tu(i.originX + i.width,true);
		curDraw[drawPos++] = tv(i.originY,false);

		curDraw[drawPos++] = px(x, false);
		curDraw[drawPos++] = py(y + h, true);
		curDraw[drawPos++] = tu(i.originX,false);
		curDraw[drawPos++] = tv(i.originY + i.height,true);

		curDraw[drawPos++] = px(x + w, true);
		curDraw[drawPos++] = py(y + h, true);
		curDraw[drawPos++] = tu(i.originX + i.width,true);
		curDraw[drawPos++] = tv(i.originY + i.height, true);

		curIndex[indexPos++] = pos;
		curIndex[indexPos++] = pos + 1;
		curIndex[indexPos++] = pos + 2;
		curIndex[indexPos++] = pos + 1;
		curIndex[indexPos++] = pos + 3;
		curIndex[indexPos++] = pos + 2;

		if( indexPos > 65500 ) endDraw();
	}

	function endDraw() {
		if( curTexture == null || indexPos == 0 ) return;

		var index = gl.createBuffer();
		var vertex = gl.createBuffer();

		gl.bindBuffer(GL.ARRAY_BUFFER, vertex);
		gl.bufferData(GL.ARRAY_BUFFER, curDraw.subarray(0, drawPos), GL.STATIC_DRAW);

		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, index);
		gl.bufferData(GL.ELEMENT_ARRAY_BUFFER, curIndex.subarray(0, indexPos), GL.STATIC_DRAW);

		gl.vertexAttribPointer(attribPos, 2, GL.FLOAT, false, 4 * 4, 0);
		gl.vertexAttribPointer(attribUV, 2, GL.FLOAT, false, 4 * 4, 2 * 4);

		gl.activeTexture(GL.TEXTURE0);
		gl.uniform1i(uniTex, 0);
		gl.uniform1f(uniAlpha, alpha);
		gl.bindTexture(GL.TEXTURE_2D, curTexture);

		gl.drawElements(GL.TRIANGLES, indexPos, GL.UNSIGNED_SHORT, 0);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);
		gl.bindBuffer(GL.ARRAY_BUFFER, null);

		gl.deleteBuffer(index);
		gl.deleteBuffer(vertex);

		indexPos = 0;
		drawPos = 0;
	}


	override function setSize(w, h) {
		super.setSize(w, h);
		setViewport();
	}

	function setViewport() {
		gl.viewport(0, 0, width > 4096 ? 4096 : width, height > 4096 ? 4096 : height);
		scaleX = (zoom / width) * 2;
		scaleY = (zoom / height) * -2;
	}

	override function fill(color) {
		gl.clearColor(((color >> 16) & 0xFF) / 255, ((color >> 8) & 0xFF) / 255, (color & 0xFF) / 255, (color >>> 24) / 255);
		gl.clear(GL.COLOR_BUFFER_BIT);
	}

	override function fillRect( x : Int, y : Int, w : Int, h : Int, color : Int ) {
		var i = getColorImage(color);
		i.width = w;
		i.height = h;
		draw(i, x, y);
	}

	public function flush() {
		endDraw();
		gl.finish();
	}

	function set_zoom(z) {
		zoom = z;
		setViewport();
		return z;
	}

	static var inst;
	public static function getInstance() {
		if( inst == null )
			inst = new Image3D(0, 0);
		return inst;
	}

	public static function fromCanvas( c : js.html.CanvasElement ) {
		var i = new Image3D(0, 0);
		i.width = c.width;
		i.height = c.height;
		i.canvas = i.origin = c;
		i.init();
		return i;
	}

}