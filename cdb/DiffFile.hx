package cdb;

typedef SheetView = {
	var insert : Bool;
	var ?edit : Array<String>;
	var ?sub : haxe.DynamicAccess<SheetView>;
	var ?show : Array<String>;
	var ?forbid : Array<String>;
	var ?options : Dynamic;
}

typedef ConfigView = haxe.DynamicAccess<SheetView>;

private typedef DiffData = Any;

class DiffFile {

	var db1 : Database;
	var db2 : Database;

	public function new() {
	}

	public function apply( db : Database, diff : DiffData, view : ConfigView ) {
		db1 = db;
		for( s in db.sheets ) {
			var sview : SheetView = view == null ? { insert : true, edit : [for( c in s.columns ) c.name] } : Reflect.field(view, s.name);
			applySheet(s, s.lines, Reflect.field(diff,s.name), sview);
		}
	}

	function applySheet( s : Sheet, lines : Array<Dynamic>, diff : DiffData, view : SheetView ) {
		if( view == null || diff == null )
			return;
		var cid = null;
		for( c in s.columns )
			if( c.type == TId ) {
				cid = c;
				break;
			}
		if( cid != null ) {
			var oldById = new Map<String,Dynamic>();
			for( v in lines ) {
				var vid : String = Reflect.field(v,cid.name);
				if( vid != null )
					oldById.set(vid, v);
			}
			for( f in Reflect.fields(diff) ) {
				if( view.forbid != null && view.forbid.indexOf(f) >= 0 )
					continue;
				var obj : Dynamic = oldById.get(f);
				var d : Dynamic = Reflect.field(diff,f);
				if( obj == null ) {
					if( !view.insert ) continue;
					lines.push(d);
				} else {
					applyObject(s,obj,d,view);
				}
			}
		} else {
			for( f in Reflect.fields(diff) ) {
				var i = Std.parseInt(f);
				var obj : Dynamic = lines[i];
				var d : Dynamic = Reflect.field(diff,f);
				if( obj == null ) {
					if( !view.insert ) continue;
					lines[i] = d;
				} else {
					applyObject(s,obj,d,view);
				}
			}
		}
	}

	function applyObject( s : Sheet, obj : {}, diff : DiffData, view : SheetView ) {
		if( view == null )
			return;
		for( f in Reflect.fields(diff) ) {
			var c = null;
			for( col in s.columns )
				if( col.name == f ) {
					c = col;
					break;
				}
			if( c == null )
				continue;
			var d : Dynamic = Reflect.field(diff, f);
			var allow = view.edit != null && view.edit.indexOf(f) >= 0;
			switch( c.type ) {
			case TList, TProperties:
				var value : Dynamic = Reflect.field(obj,f);
				var sub = s.getSub(c);
				var view : SheetView = allow ? { insert : true, edit : [for( c in sub.columns ) c.name] } : Reflect.field(view.sub,c.name);
				if( value == null ) {
					if( allow ) Reflect.setField(obj, f, d);
					continue;
				}
				if( c.type == TProperties )
					applyObject(sub, value, d, view);
				else
					applySheet(sub, value, d, view);
			case TFlags(_):
				if( allow ) {
					var mask : Null<Int> = null;
					if( view.options != null )
						mask = Reflect.field(view.options, f);
					if( mask == null )
						Reflect.setField(obj, f, d);
					else {
						var prev : Null<Int> = Reflect.field(obj, f);
						if( prev == null ) prev = 0 else prev = prev & ~mask;
						if( d == null ) { if( prev != 0 ) d = prev; } else d = (d&mask) | prev;
						Reflect.setField(obj, f, d);
					}
				}
			default:
				if( allow ) Reflect.setField(obj, f, d);
			}
		}
	}

	public function make( origin : Database, db : Database ) : DiffData {
		var diff = new haxe.DynamicAccess();
		db1 = db;
		db2 = origin;
		for( s1 in db.sheets ) {

			if( s1.props.hide ) continue;

			var s2 = null;
			for( s in origin.sheets ) {
				if( s.name == s1.name ) {
					s2 = s;
					break;
				}
			}
			if( s2 == null ) throw "Missing sheet "+s1.name;

			var d = diffSheets(s1,s2,s1.lines,s2.lines);
			if( d != null )
				diff.set(s1.name, d);
		}
		return diff;
	}

	function diffSheets( s1 : Sheet, s2 : Sheet, lines1 : Array<Dynamic>, lines2 : Array<Dynamic> ) : DiffData {
		var diff = null;
		var cid = null;
		for( c in s1.columns )
			if( c.type == TId ) {
				cid = c;
				break;
			}
		if( cid != null ) {
			var oldById = new Map();
			for( vold in lines2 ) {
				var vid : String = Reflect.field(vold,cid.name);
				if( vid != null )
					oldById.set(vid, vold);
			}
			for( vnew in lines1 ) {
				var vid : String = Reflect.field(vnew,cid.name);
				if( vid == null ) throw "assert";
				var vold = oldById.get(vid);
				var d;
				if( vold != null ) {
					d = diffObject(s1,s2,vnew,vold);
					if( d == null ) continue;
				} else {
					d = copy(vnew);
				}
				if( diff == null ) diff = new haxe.DynamicAccess();
				diff.set(vid, d);
			}
			// TODO : handle reordering & separators (groups)
			return diff;
		} else {
			if( lines1.length != lines2.length )
				throw "TODO : lines length diff "+s1.name;
			for( i in 0...lines1.length ) {
				var obj1 : Dynamic = lines1[i];
				var obj2 : Dynamic = lines2[i];
				var d = diffObject(s1, s2, obj1, obj2);
				if( d != null ) {
					if( diff == null ) diff = new haxe.DynamicAccess();
					diff.set(""+i, d);
				}
			}
		}
		return diff;
	}

	function diffObject( s1 : Sheet, s2 : Sheet, obj1 : Dynamic, obj2 : Dynamic ) : DiffData {
		var diff = null;
		for( c1 in s1.columns ) {
			var vnew = Reflect.field(obj1,c1.name);
			var vold = Reflect.field(obj2,c1.name);
			if( vnew == vold ) continue;
			var d;
			switch( c1.type ) {
			case TList:
				if( vnew == null ) {
					d = null;
				} else if( vold == null ) {
					d = copy(vnew);
				} else {
					d = diffSheets(s1.getSub(c1),s2.getSub(c1), vnew, vold);
					if( d == null ) continue;
				}
			case TProperties:
				d = diffObject(s1.getSub(c1), s2.getSub(c1), vnew, vold);
				if( d == null ) continue;
			case TDynamic, TTilePos, TCustom(_), TTileLayer, TLayer(_):
				if( haxe.Json.stringify(vnew) == haxe.Json.stringify(vold) )
					continue;
				d = copy(vnew);
			default:
				d = vnew;
			}
			if( diff == null ) diff = new haxe.DynamicAccess();
			#if js
			if( d == js.Lib.undefined ) d = null;
			#end
			diff.set(c1.name, d);
		}
		return diff;
	}

	function copy<T>( obj : T ) : T {
		return haxe.Json.parse(haxe.Json.stringify(obj));
	}

}