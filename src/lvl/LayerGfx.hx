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

class LayerGfx {

	var level : Level;
	public var names : Array<String>;
	public var colors : Array<Int>;
	public var images : Array<Image>;
	public var blanks : Array<Bool>;
	public var stride : Int = 0;
	public var height : Int = 0;

	public var idToIndex : Map<String,Int>;
	public var indexToId : Array<String>;
	public var hasFloatCoord : Bool;
	public var hasSize : Bool;

	public function new(level:Level) {
		this.level = level;
	}

	public function fromSheet( sheet : Sheet, defColor ) {
		blanks = [];
		if( sheet == null ) {
			colors = [defColor];
			names = [""];
			return;
		}
		var idCol = null;
		var imageTags = [];
		for( c in sheet.columns )
			switch( c.type ) {
			case TColor:
				colors = [for( o in sheet.lines ) { var c = Reflect.field(o, c.name); c == null ? 0 : c; } ];
			case TImage:
				if( images == null ) images = [];
				var size = level.tileSize;
				for( idx in 0...sheet.lines.length ) {
					if( imageTags[idx] ) continue;
					var key = Reflect.field(sheet.lines[idx], c.name);
					var idat = level.model.getImageData(key);
					if( idat == null ) {
						var i = new Image(size, size);
						i.text("#" + idx, 0, 12);
						images[idx] = i;
						continue;
					}
					level.wait();
					imageTags[idx] = true;
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
					if( imageTags[idx] ) continue;
					var data : cdb.Types.TilePos = Reflect.field(sheet.lines[idx], c.name);
					if( data == null && images[idx] != null ) continue;
					if( data == null ) {
						var i = new Image(size, size);
						i.text("#" + idx, 0, 12);
						images[idx] = i;
						continue;
					}
					level.wait();
					imageTags[idx] = true;
					Image.load(level.model.getAbsPath(data.file), function(i) {
						var i2 = i.sub(data.x * data.size, data.y * data.size, data.size * (data.width == null ? 1 : data.width), data.size * (data.height == null ? 1 : data.height));
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
		stride = Math.ceil(Math.sqrt(sheet.lines.length));
		height = Math.ceil(sheet.lines.length / stride);
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
	}

}