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

typedef Prefs = {
	windowPos : { x : Int, y : Int, w : Int, h : Int, max : Bool },
	curFile : String,
	curSheet : Int,
	recent : Array<String>,
}

typedef HistoryElement = { d : String, o : String };

class Model {

	public var base : cdb.Database;
	var prefs : Prefs;
	var imageBank : Dynamic<String>;
	var openedList : Map<String,Bool>;
	var existsCache : Map<String,{ t : Float, r : Bool }>;

	var curSavedData : HistoryElement;
	var history : Array<HistoryElement>;
	var redo : Array<HistoryElement>;

	function new() {
		openedList = new Map();
		prefs = {
			windowPos : { x : 50, y : 50, w : 800, h : 600, max : false },
			curFile : null,
			curSheet : 0,
			recent : [],
		};
		existsCache = new Map();
		loadPrefs();
	}

	function quickExists(path) {
		var c = existsCache.get(path);
		if( c == null ) {
			c = { t : -1e9, r : false };
			existsCache.set(path, c);
		}
		var t = haxe.Timer.stamp();
		if( c.t < t - 10 ) { // cache result for 10s
			c.r = sys.FileSystem.exists(path);
			c.t = t;
		}
		return c.r;
	}

	public function getImageData( key : String ) : String {
		return Reflect.field(imageBank, key);
	}

	public function getAbsPath( file : String ) {
		return file.charAt(0) == "/" || file.charAt(1) == ":" ? file : new haxe.io.Path(prefs.curFile).dir.split("\\").join("/") + "/" + file;
	}

	public inline function getSheet( name : String ) {
		return base.getSheet(name);
	}

	public function save( history = true ) {
		var sdata = quickSave();
		if( history && (curSavedData == null || sdata.d != curSavedData.d || sdata.o != curSavedData.o) ) {
			this.history.push(curSavedData);
			this.redo = [];
			if( this.history.length > 100 || sdata.d.length * (this.history.length + this.redo.length) * 2 > 300<<20 ) this.history.shift();
			curSavedData = sdata;
		}
		if( prefs.curFile == null )
			return;
		var tmp = Sys.getEnv("TMP");
		if( tmp == null ) tmp = Sys.getEnv("TMPDIR");
		var tmpFile = tmp+"/"+prefs.curFile.split("\\").join("/").split("/").pop()+".lock";
		try sys.io.File.saveContent(tmpFile,"LOCKED by CDB") catch( e : Dynamic ) {};
		try {
			sys.io.File.saveContent(prefs.curFile, sdata.d);
		} catch( e : Dynamic ) {
			// retry once after EBUSY
			haxe.Timer.delay(function() {
				sys.io.File.saveContent(prefs.curFile, sdata.d);
			},500);
		}
		try sys.FileSystem.deleteFile(tmpFile) catch( e : Dynamic ) {};
	}

	function saveImages() {
		if( prefs.curFile == null )
			return;
		var img = prefs.curFile.split(".");
		img.pop();
		var path = img.join(".") + ".img";
		if( imageBank == null )
			sys.FileSystem.deleteFile(path);
		else
			sys.io.File.saveContent(path, untyped haxe.Json.stringify(imageBank, null, "\t"));
	}

	function quickSave() : HistoryElement {
		return {
			d : base.save(),
			o : haxe.Serializer.run(openedList),
		};
	}

	function quickLoad(sdata:HistoryElement) {
		base.load(sdata.d);
		openedList = haxe.Unserializer.run(sdata.o);
	}

	public function compressionEnabled() {
		return base.compress;
	}

	function error( msg ) {
		js.Browser.alert(msg);
	}

	function load(noError = false) {
		history = [];
		redo = [];
		base = new cdb.Database();
		try {
			base.load(sys.io.File.getContent(prefs.curFile));
			if( prefs.curSheet > base.sheets.length )
				prefs.curSheet = 0;
			else while( base.sheets[prefs.curSheet].props.hide )
				prefs.curSheet--;
		} catch( e : Dynamic ) {
			if( !noError ) error(Std.string(e));
			prefs.curFile = null;
			prefs.curSheet = 0;
			base = new cdb.Database();
		}
		try {
			var img = prefs.curFile.split(".");
			img.pop();
			imageBank = haxe.Json.parse(sys.io.File.getContent(img.join(".") + ".img"));
		} catch( e : Dynamic ) {
			imageBank = null;
		}
		curSavedData = quickSave();
	}

	function cleanImages() {
		if( imageBank == null )
			return;
		var used = new Map();
		for( s in base.sheets )
			for( c in s.columns ) {
				switch( c.type ) {
				case TImage:
					for( obj in s.getLines() ) {
						var v = Reflect.field(obj, c.name);
						if( v != null ) used.set(v, true);
					}
				default:
				}
			}
		for( f in Reflect.fields(imageBank) )
			if( !used.get(f) )
				Reflect.deleteField(imageBank, f);
	}

	function loadPrefs() {
		try {
			prefs = haxe.Unserializer.run(js.Browser.getLocalStorage().getItem("prefs"));
			if( prefs.recent == null ) prefs.recent = [];
		} catch( e : Dynamic ) {
		}
	}

	function savePrefs() {
		js.Browser.getLocalStorage().setItem("prefs", haxe.Serializer.run(prefs));
	}

}