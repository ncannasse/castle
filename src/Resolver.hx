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
class Resolver {


	var hasError = false;

	function new() {
	}

	public function check( file : String ) {
		var minRev = 0, maxRev = 0;
		var basePath = file.split("\\").join("/").split("/").pop();
		for( f in sys.FileSystem.readDirectory(file.substr(0, -basePath.length)) ) {
			if( StringTools.startsWith(f, basePath + ".r") ) {
				var rev = Std.parseInt(f.substr(basePath.length + 2));
				if( minRev == 0 || minRev > rev ) minRev = rev;
				if( maxRev == 0 || maxRev < rev ) maxRev = rev;
			}
		}
		inline function parse(file) {
			return haxe.Json.parse(sys.io.File.getContent(file));
		}
		var merged = sys.io.File.getContent(file).split("<<<<<<< .mine");

		// no conflict : it was already resolved by hand, but not marked as resolved
		if( merged.length == 1 )
			return true;

		var endConflict = ~/>>>>>>> \.r[0-9]+[\r\n]+/;
		for( i in 1...merged.length ) {
			endConflict.match(merged[i]);
			merged[i] = endConflict.matchedLeft().split("=======").shift() + endConflict.matchedRight();
		}
		var mine = haxe.Json.parse(merged.join(""));
		var origin = parse(file+".r" + minRev);
		var other = parse(file+".r" + maxRev);
		hasError = false;
		try {
			resolveRec(mine, origin, other, []);
		} catch( e : String ) {
			error(e);
			hasError = true;
		}
		if( hasError )
			return false;

		// resolve successful, let's overwrite
		// create a backup (just in case)
		try {
			sys.io.File.saveContent(Sys.getEnv("TEMP") + "/" + basePath + ".merged" + minRev + "_" + maxRev, sys.io.File.getContent(file));
		} catch( e : Dynamic ) {
		}
		sys.io.File.saveContent(file, haxe.Json.stringify(other, null, "\t"));
		sys.FileSystem.deleteFile(file+".mine");
		sys.FileSystem.deleteFile(file+".r"+minRev);
		sys.FileSystem.deleteFile(file+".r"+maxRev);
		return true;
	}

	function resolveError( message : String, path : Array<String> ) {
		error(message+"\n  in\n" + path.join("."));
		hasError = true;
	}

	function resolveRec( mine : Dynamic, origin : Dynamic, other : Dynamic, path : Array<String> ) {
		if( mine == origin || mine == other )
			return other;
		if( other == origin )
			return mine;
		if( Std.is(mine, Array) ) {
			var target = other;
			if( origin == null ) {
				origin = []; // was inserted by mine
				if( target == null ) target = other = []; // create in other as well
			} else if( target == null )
				target = []; // let's check for conflict if we have changed origin, don't copy to other
			else if( other.length != mine.length )
				resolveError("Array resize conflict",path);
			for( i in 0...mine.length ) {
				var mv = mine[i];
				var name = Reflect.field(mv, "id");
				if( name == null ) name = Reflect.field(mv, "name");
				path.push(Std.is(name,String) ? name+"#"+i : "[" + i + "]");
				target[i] = resolveRec(mv, origin[i], target[i], path);
				path.pop();
			}
		} else if( Reflect.isObject(mine) && !Std.is(mine, String) ) {
			var target = other;
			if( origin == null ) {
				origin = { };
				if( other == null ) target = other = { };
			} else if( target == null )
				target = { };
			for( f in Reflect.fields(target) )
				if( !Reflect.hasField(mine, f) )
					Reflect.setField(mine, f, null);
			for( f in Reflect.fields(mine) ) {
				path.push(f);
				Reflect.setField(target, f, resolveRec(Reflect.field(mine, f), Reflect.field(origin, f), Reflect.field(target, f), path));
				path.pop();
			}
		} else {
			if( Std.is(mine, String) && Std.is(other, String) ) {
				try {
					var dorigin = cdb.Lz4Reader.decodeString(origin);
					var dmine = cdb.Lz4Reader.decodeString(mine);
					var dother = cdb.Lz4Reader.decodeString(other);
					if( dorigin.length != dmine.length || dorigin.length != dother.length ) throw "resized";
					for( i in 0...dorigin.length ) {
						var mine = dmine.get(i);
						var origin = dorigin.get(i);
						var other = dother.get(i);
						if( mine == origin || mine == other ) continue;
						if( other == origin )
							dother.set(i, mine);
						else
							throw "conflict";
					}
					// merged
					return cdb.Lz4Reader.encodeBytes(dother, other.substr(0, 5) == "BCJNG");
				} catch( e : Dynamic ) {
					// manual merging fallback
				}
			}
			function display(v:Dynamic) {
				var str = Std.string(v);
				if( str.length > 50 ) str = str.substr(0, 50) + "...";
				return str;
			}
			var r = js.Browser.window.confirm('A conflict has been found in ${path.join(".")}\nOrigin = ${display(origin)}    Mine = ${display(mine)}    Other = ${display(other)}\nDo you want to keep your changes (OK) or discard them (CANCEL) ?\n\n');
			if( !js.Browser.window.confirm('Are you sure ?') )
				throw "Resolve aborted";
			if( r ) other = mine;
		}
		return other;
	}

	function error( msg ) {
		js.Browser.alert(msg);
	}

	public static function resolveConflict(file) {
		return new Resolver().check(file);
	}

}