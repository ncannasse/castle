package cdb;
import haxe.macro.Context;
using haxe.macro.Tools;

private class ArrayIterator<T> {
	var a : Array<T>;
	var pos : Int;
	public inline function new(a) {
		this.a = a;
		this.pos = 0;
	}
	public inline function hasNext() {
		return pos < a.length;
	}
	public inline function next() {
		return a[pos++];
	}
}

abstract ArrayRead<T>(Array<T>) {
	
	public var length(get, never) : Int;
	
	inline function get_length() {
		return this.length;
	}
	
	public inline function iterator() : ArrayIterator<T> {
		return new ArrayIterator(toArray());
	}
	
	function toArray() : Array<T> {
		return this;
	}
	
	@:arrayAccess inline function getIndex( v : Int ) {
		return this[v];
	}
	
}

class Index<T,Kind> {
	
	public var all : ArrayRead<T>;
	var byIndex : Array<T>;
	var byId : Map<String,T>;
	var name : String;
	
	public function new( data : Data, sheet : String ) {
		this.name = sheet;
		for( s in data.sheets )
			if( s.name == sheet ) {
				all = cast s.lines;
				byId = new Map();
				byIndex = [];
				for( c in s.columns )
					switch( c.type ) {
					case TId:
						var cname = c.name;
						for( a in s.lines ) {
							var id = Reflect.field(a, cname);
							if( id != null && id != "" ) {
								byId.set(id, a);
								byIndex.push(a);
							}
						}
						break;
					default:
					}
				return;
			}
		throw "'" + sheet + "' not found in CDB data";
	}
	
	public inline function get( k : Kind ) {
		return byId.get(cast k);
	}
	
	public function resolve( id : String, ?opt : Bool ) : T {
		if( id == null ) return null;
		var v = byId.get(id);
		return v == null && !opt ? throw "Missing " + name + "." + id : v;
	}
	
}

class Module {
	
	public static function build( file : String ) {
		#if !macro
		throw "This can only be called in a macro";
		#else
		var pos = Context.currentPos();
		var path = try Context.resolvePath(file) catch( e : Dynamic ) null;
		if( path == null ) {
			var r = Context.definedValue("resourcesPath");
			if( r != null ) {
				r = r.split("\\").join("/");
				if( !StringTools.endsWith(r, "/") ) r += "/";
				try path = Context.resolvePath(r + file) catch( e : Dynamic ) null;
			}
		}
		if( path == null )
			try path = Context.resolvePath("res/" + file) catch( e : Dynamic ) null;
		if( path == null )
			Context.error("File not found " + file, pos);
		var data = Parser.parse(sys.io.File.getContent(path));
		var r_chars = ~/[^A-Za-z0-9_]/g;
		function makeTypeName( name : String ) {
			var t = r_chars.replace(name, "_");
			t = t.substr(0, 1).toUpperCase() + t.substr(1);
			return t;
		}
		function fieldName( name : String ) {
			return r_chars.replace(name, "_");
		}
		var types = new Array<haxe.macro.Expr.TypeDefinition>();
		var curMod = Context.getLocalModule().split(".");
		var modName = curMod.pop();
		
		var typesCache = new Map<String,String>();
		
		for( s in data.sheets ) {
			var tname = makeTypeName(s.name);
			var tkind = tname + "Kind";
			var hasId = false;
			var fields : Array<haxe.macro.Expr.Field> = [];
			var realFields : Array<haxe.macro.Expr.Field> = [];
			var ids : Array<haxe.macro.Expr.Field> = [];
			for( c in s.columns ) {
				var t = switch( c.type ) {
				case TInt: macro : Int;
				case TFloat: macro : Float;
				case TBool: macro : Bool;
				case TString: macro : String;
				case TList:
					var t = makeTypeName(s.name + "@" + c.name).toComplex();
					macro : cdb.Module.ArrayRead<$t>;
				case TRef(t): makeTypeName(t).toComplex();
				case TImage: macro : String;
				case TId:
					tkind.toComplex();
				case TEnum(values):
					var t = makeTypeName(s.name + "@" + c.name);
					var fields : Array<haxe.macro.Expr.Field> = [for( i in 0...values.length ) { name : values[i], pos : pos, kind : FVar(null, macro $v { i } ) } ];
					var tint = macro : Int;
					fields.push( {
						name : "COUNT",
						pos : pos,
						kind : FVar(null, macro $v { values.length } ),
						access : [APublic, AStatic, AInline],
					});
					fields.push( {
						name : "ofInt",
						pos : pos,
						kind : FFun({
							args : [ { name : "v", type : tint } ],
							ret : t.toComplex(),
							expr : macro return cast v,
						}),
						access : [APublic, AStatic, AInline],
					});
					fields.push( {
						name : "toInt",
						pos : pos,
						kind : FFun( {
							args : [],
							ret : tint,
							expr : macro return this,
						}),
						access : [APublic, AInline],
					});
					types.push({
						pos : pos,
						name : t,
						params : [],
						pack : curMod,
						kind : TDAbstract(tint),
						meta : [{ name : ":fakeEnum", pos : pos }],
						isExtern : false,
						fields : fields,
					});
					t.toComplex();
				case TCustom(name):
					name.toComplex();
				}
				
				var rt = switch( c.type ) {
				case TInt, TEnum(_): macro : Int;
				case TFloat: macro : Float;
				case TBool: macro : Bool;
				case TString, TRef(_), TImage, TId: macro : String;
				case TCustom(_): macro : Array<Dynamic>;
				case TList:
					var t = (makeTypeName(s.name+"@"+c.name) + "Def").toComplex();
					macro : Array<$t>;
				};

				if( c.opt ) {
					t = macro : Null<$t>;
					rt = macro : Null<$rt>;
				}
				
				fields.push({
					name : c.name,
					pos : pos,
					kind : FProp("get", "never", t),
					access : [APublic],
				});
				
				switch( c.type ) {
				case TInt, TFloat, TString, TBool, TImage:
					var cname = c.name;
					fields.push({
						name : "get_"+c.name,
						pos : pos,
						kind : FFun({
							ret : t,
							params : [],
							args : [],
							expr : macro return this.$cname,
						}),
						access : [AInline, APrivate],
					});
				case TId:
					hasId = true;
					
					var cname = c.name;
					for( obj in s.lines ) {
						var id = Reflect.field(obj, cname);
						if( id != null && id != "" )
							ids.push({
								name : id,
								pos : pos,
								kind : FVar(null,macro $v{id}),
							});
					}
					
					fields.push({
						name : "get_"+c.name,
						pos : pos,
						kind : FFun({
							ret : t,
							params : [],
							args : [],
							expr : macro return cast this.$cname,
						}),
						access : [AInline, APrivate],
					});
				case TList, TEnum(_):
					// cast to convert Array<Def> to ArrayRead<T>
					var cname = c.name;
					fields.push({
						name : "get_"+c.name,
						pos : pos,
						kind : FFun({
							ret : t,
							params : [],
							args : [],
							expr : macro return cast this.$cname,
						}),
						access : [AInline,APrivate],
					});
				case TRef(s):
					var cname = c.name;
					var fname = fieldName(s);
					fields.push({
						name : "get_"+c.name,
						pos : pos,
						kind : FFun({
							ret : t,
							params : [],
							args : [],
							expr : c.opt ? macro return $i{modName}.$fname.resolve(this.$cname) : macro return this.$cname == null ? null : $i{modName}.$fname.resolve(this.$cname),
						}),
						access : [APrivate],
					});
					// allow direct id access (no fetch)
					var tid = (makeTypeName(s) + "Kind").toComplex();
					if( c.opt ) tid = macro : Null<$tid>;
					fields.push( {
						name : c.name + "Id",
						pos : pos,
						kind : FProp("get", "never", tid),
						access : [APublic],
					});
					fields.push( {
						name : "get_" + c.name + "Id",
						pos : pos,
						kind : FFun( {
							args : [],
							ret : tid,
							params : [],
							expr : macro return cast this.$cname,
						}),
						access : [APrivate, AInline],
					});
				case TCustom(name):
					var cname = c.name;
					fields.push({
						name : "get_"+c.name,
						pos : pos,
						kind : FFun({
							ret : t,
							params : [],
							args : [],
							expr : macro return $i{name + "Builder"}.build(this.$cname),
						}),
						access : [AInline,APrivate],
					});
				}
				
				realFields.push({
					name : c.name,
					pos : pos,
					kind : FVar(rt),
				});
			}
			
			if( s.props.hasIndex ) {
				var tint = macro : Int;
				realFields.push( { name : "index", pos : pos, kind : FVar(tint) } );
				fields.push( { name : "index", pos : pos, kind : FProp("get", "never", tint), access : [APublic] } );
				fields.push({
					name : "get_index",
					pos : pos,
					kind : FFun( { ret : tint, args : [], params : [], expr : macro return this.index } ),
					access : [AInline, APrivate],
				});
			}
			
			var def = tname + "Def";
			types.push({
				pos : pos,
				name : def,
				params : [],
				pack : curMod,
				meta : [],
				kind : TDStructure,
				isExtern : false,
				fields : realFields,
			});
			

			if( hasId ) {
				ids.push( {
					name : "toString",
					pos : pos,
					kind : FFun( { ret : macro:String, args : [], params : [], expr : macro return this } ),
					access : [AInline, APublic],
				});
				types.push({
					pos : pos,
					name : tkind,
					params : [],
					pack : curMod,
					meta : [{ name : ":fakeEnum", pos : pos, params : [] }],
					kind : TDAbstract(macro : String),
					isExtern : false,
					fields : ids,
				});
			} else {
				var fields = [for( c in realFields ) { name:c.name, k:c.kind } ];
				fields.sort(function(a, b) return Reflect.compare(a.name, b.name));
				var sign = Context.signature(fields);
				var prevName = typesCache.get(sign);
				if( prevName == null )
					typesCache.set(sign, tname);
				else {
					types.push({
						pos : pos,
						name : tname,
						params : [],
						pack : curMod,
						meta : [],
						kind : TDAlias(prevName.toComplex()),
						isExtern : false,
						fields : [],
					});
					continue;
				}
			}
						
			
			types.push({
				pos : pos,
				name : tname,
				params : [],
				pack : curMod,
				meta : [],
				kind : TDAbstract(def.toComplex()),
				isExtern : false,
				fields : fields,
			});
		}
		for( t in data.customTypes ) {
			types.push( {
				pos : pos,
				name : t.name,
				pack : curMod,
				meta : [],
				params : [],
				kind : TDEnum,
				isExtern : false,
				fields : [for( c in t.cases )
				{
					name : c.name,
					pos : pos,
					kind : if( c.args.length == 0 ) FVar(null) else FFun({
						ret : null,
						expr : null,
						params : [],
						args : [
							for( a in c.args ) {
								var t = switch( a.type ) {
								case TInt: macro : Int;
								case TFloat: macro : Float;
								case TString: macro : String;
								case TBool: macro : Bool;
								case TCustom(name): name.toComplex();
								case TRef(name): makeTypeName(name).toComplex();
								default: throw "TODO " + a.type;
								}
								{
									name : a.name,
									type : t,
									opt : a.opt == true,
								}
							}
						],
					}),
				}
				],
			});
			var cases = new Array<haxe.macro.Expr.Case>();
			for( i in 0...t.cases.length ) {
				var c = t.cases[i];
				var eargs = [];
				for( ai in 0...c.args.length ) {
					var a = c.args[ai];
					var econv = switch( a.type ) {
					case TId, TString, TBool, TInt, TFloat, TImage, TEnum(_):
						macro v[$v { ai + 1 } ];
					case TCustom(id):
						macro $i{id+"Builder"}.build(v[$v{ai+1}]);
					case TRef(s):
						var fname = fieldName(s);
						macro $i{modName}.$fname.resolve(v[$v{ai+1}]);
					case TList:
						throw "assert";
					}
					eargs.push(econv);
				}
				cases.push({
					values : [macro $v{ i }],
					expr : if( c.args.length == 0 ) macro $i{c.name} else macro $i{c.name}($a{eargs}),
				});
			}
			var expr : haxe.macro.Expr = {
				expr : ESwitch(macro v[0], cases, macro throw "Invalid value " + v),
				pos : pos,
			};
			types.push({
				pos : pos,
				name : t.name + "Builder",
				pack : curMod,
				meta : [],
				params : [],
				kind : TDClass(),
				isExtern : false,
				fields : [
					{
						name : "build",
						pos : pos,
						access : [APublic, AStatic],
						kind : FFun( {
							ret : t.name.toComplex(),
							expr : macro return $expr,
							params : [],
							args : [{ name : "v",type: macro:Array<Dynamic>, opt:false}],
						}),
					}
				]
			});
		}
		
		var assigns = [], fields = new Array<haxe.macro.Expr.Field>();
		for( s in data.sheets ) {
			if( s.props.hide ) continue;
			var tname = makeTypeName(s.name);
			var t = tname.toComplex();
			var kind = (tname + "Kind").toComplex();
			var fname = fieldName(s.name);
			fields.push({
				name : fname,
				pos : pos,
				access : [APublic, AStatic],
				kind : FVar(macro : cdb.Module.Index<$t,$kind>),
			});
			assigns.push(macro $i { fname } = new cdb.Module.Index(root, $v{ s.name } ));
		}
		types.push({
			pos : pos,
			name : modName,
			params : [],
			pack : curMod,
			meta : [],
			kind : TDClass(),
			isExtern : false,
			fields : (macro class {
				public static function load( content : String ) {
					var root = cdb.Parser.parse(content);
					{$a{assigns}};
				}
			}).fields.concat(fields),
		});
		var mpath = Context.getLocalModule();
		Context.defineModule(mpath, types);
		Context.registerModuleDependency(mpath, path);
		return Context.getType("Void");
		#end
	}
	
}