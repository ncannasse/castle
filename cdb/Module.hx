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
package cdb;
import haxe.macro.Context;
using haxe.macro.Tools;

class Module {

	#if macro
	static function makeFakeEnum( tname : String, curMod, pos, values : Array<String> ) : haxe.macro.Expr.TypeDefinition {
		var fields : Array<haxe.macro.Expr.Field> = [for( i in 0...values.length ) { name : values[i], pos : pos, kind : FVar(null, macro $v { i } ) } ];
		var tint = macro : Int;
		fields.push( {
			name : "COUNT",
			pos : pos,
			kind : FVar(null, macro $v { values.length } ),
			access : [APublic, AStatic, AInline],
		});
		fields.push( {
			name : "NAMES",
			pos : pos,
			kind : FVar(null, macro $v { values } ),
			access : [APublic, AStatic],
		});
		fields.push( {
			name : "ofInt",
			pos : pos,
			kind : FFun({
				args : [ { name : "v", type : tint } ],
				ret : tname.toComplex(),
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
		return {
			pos : pos,
			name : tname,
			pack : curMod,
			kind : TDAbstract(tint),
			meta : [{ name : ":enum", pos : pos },{ name : ":fakeEnum", pos : pos }],
			fields : fields,
		};
	}
	#end

	static function getSheetLines( sheets : Array<Data.SheetData>, s : Data.SheetData ) {
		if( !s.props.hide )
			return s.lines;
		var name = s.name.split("@");
		var col = name.pop();
		var parent = name.join("@");
		var psheet = null;
		for( sp in sheets )
			if( sp.name == parent ) {
				psheet = sp;
				break;
			}
		if( psheet == null )
			return s.lines;
		var out = [];
		for( o in getSheetLines(sheets,psheet) ) {
			var objs : Array<Dynamic> = Reflect.field(o, col);
			if( objs != null )
				for( o in objs )
					out.push(o);
		}
		return out;
	}

	public static function build( file : String, ?typeName : String ) {
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
		if( typeName != null ) modName = typeName;

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
				case TInt, TColor: macro : Int;
				case TFloat: macro : Float;
				case TBool: macro : Bool;
				case TString, TFile: macro : String;
				case TList:
					var t = makeTypeName(s.name + "@" + c.name).toComplex();
					macro : cdb.Types.ArrayRead<$t>;
				case TRef(t): makeTypeName(t).toComplex();
				case TImage: macro : String;
				case TId:
					tkind.toComplex();
				case TEnum(values):
					var t = makeTypeName(s.name + "@" + c.name);
					types.push(makeFakeEnum(t,curMod,pos,values));
					t.toComplex();
				case TCustom(name):
					name.toComplex();
				case TFlags(values):
					var t = makeTypeName(s.name + "@" + c.name);
					types.push(makeFakeEnum(t, curMod, pos, values));
					var t = t.toComplex();
					macro : cdb.Types.Flags<$t>;
				case TLayer(t):
					var t = makeTypeName(t).toComplex();
					macro : cdb.Types.Layer<$t>;
				case TTilePos:
					macro : cdb.Types.TilePos;
				case TTileLayer:
					macro : cdb.Types.TileLayer;
				case TDynamic:
					var t = tname.toComplex();
					s.props.level != null && c.name == "props" ? macro : cdb.Types.LevelPropsAccess<$t> : macro : Dynamic;
				case TProperties:
					makeTypeName(s.name + "@" + c.name).toComplex();
				}

				var rt = switch( c.type ) {
				case TInt, TEnum(_), TFlags(_), TColor: macro : Int;
				case TFloat: macro : Float;
				case TBool: macro : Bool;
				case TString, TRef(_), TImage, TId, TFile: macro : String;
				case TCustom(_): macro : Array<Dynamic>;
				case TList:
					var t = (makeTypeName(s.name+"@"+c.name) + "Def").toComplex();
					macro : Array<$t>;
				case TLayer(_): macro : String;
				case TTilePos: macro : { file : String, size : Int, x : Int, y : Int, ?width : Int, ?height : Int };
				case TTileLayer: macro : { file : String, stride : Int, size : Int, data : String };
				case TDynamic: macro : Dynamic;
				case TProperties:
					(makeTypeName(s.name+"@" + c.name) + "Def").toComplex();
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
				case TInt, TFloat, TString, TBool, TImage, TColor, TFile, TTilePos, TDynamic:
					var cname = c.name;
					fields.push({
						name : "get_"+c.name,
						pos : pos,
						kind : FFun({
							ret : t,
							args : [],
							expr : macro return this.$cname,
						}),
						access : [AInline, APrivate],
					});
				case TId:
					hasId = true;

					var cname = c.name;
					for( obj in getSheetLines(data.sheets,s) ) {
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
							args : [],
							expr : macro return cast this.$cname,
						}),
						access : [AInline, APrivate],
					});
				case TList, TEnum(_), TFlags(_), TLayer(_), TTileLayer, TProperties:
					// cast
					var cname = c.name;
					fields.push({
						name : "get_"+c.name,
						pos : pos,
						kind : FFun({
							ret : t,
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
							args : [],
							expr : c.opt ? macro return this.$cname == null ? null : $i{name + "Builder"}.build(this.$cname) : macro return $i{name + "Builder"}.build(this.$cname),
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
					kind : FFun( { ret : tint, args : [], expr : macro return this.index } ),
					access : [AInline, APrivate],
				});
			}

			var gtitles = s.props.separatorTitles;
			if( s.props.hasGroup && gtitles != null ) {
				var tint = macro : Int;
				realFields.push( { name : "group", pos : pos, kind : FVar(tint) } );
				var tgroup = makeTypeName(s.name + "@group");
				var groups = [for( t in gtitles ) if( t != null ) makeTypeName(t)];
				if( s.separators[0] != 0 || gtitles[0] == null )
					groups.unshift("None");
				types.push(makeFakeEnum(tgroup, curMod, pos, groups));
				var tgroup = tgroup.toComplex();
				fields.push( { name : "group", pos : pos, kind : FProp("get", "never", tgroup), access : [APublic] } );
				fields.push({
					name : "get_group",
					pos : pos,
					kind : FFun( { ret : tgroup, args : [], expr : macro return cast this.group } ),
					access : [AInline, APrivate],
				});
			}

			var def = tname + "Def";
			types.push({
				pos : pos,
				name : def,
				pack : curMod,
				kind : TDStructure,
				fields : realFields,
			});


			if( hasId ) {
				ids.push( {
					name : "toString",
					pos : pos,
					kind : FFun( { ret : macro:String, args : [], expr : macro return this } ),
					access : [AInline, APublic],
				});
				types.push({
					pos : pos,
					name : tkind,
					pack : curMod,
					meta : [{ name : ":enum", pos : pos },{ name : ":fakeEnum", pos : pos }],
					kind : TDAbstract(macro : String),
					fields : ids,
				});
			} else {
				var fields = [for( c in fields ) { name:c.name, k:c.kind } ];
				fields.sort(function(a, b) return Reflect.compare(a.name, b.name));
				var sign = Context.signature(fields);
				var prevName = typesCache.get(sign);
				if( prevName == null )
					typesCache.set(sign, tname);
				else {
					types.push({
						pos : pos,
						name : tname,
						pack : curMod,
						kind : TDAlias(prevName.toComplex()),
						fields : [],
					});
					continue;
				}
			}


			types.push({
				pos : pos,
				name : tname,
				pack : curMod,
				kind : TDAbstract(def.toComplex()),
				fields : fields,
			});
		}
		for( t in data.customTypes ) {
			types.push( {
				pos : pos,
				name : t.name,
				pack : curMod,
				kind : TDEnum,
				fields : [for( c in t.cases )
				{
					name : c.name,
					pos : pos,
					kind : if( c.args.length == 0 ) FVar(null) else FFun({
						ret : null,
						expr : null,
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
			// build enum values
			var cases = new Array<haxe.macro.Expr.Case>();
			for( i in 0...t.cases.length ) {
				var c = t.cases[i];
				var eargs = [];
				for( ai in 0...c.args.length ) {
					var a = c.args[ai];
					var econv = switch( a.type ) {
					case TId, TString, TBool, TInt, TFloat, TImage, TEnum(_), TFlags(_), TColor, TFile, TTileLayer, TDynamic:
						macro v[$v { ai + 1 } ];
					case TCustom(id):
						if( a.opt )
							macro { var tmp = v[$v{ai+1}]; tmp == null ? null : $i{id+"Builder"}.build(tmp); }
						else
							macro $i{id+"Builder"}.build(v[$v{ai+1}]);
					case TRef(s):
						var fname = fieldName(s);
						macro $i{modName}.$fname.resolve(v[$v{ai+1}]);
					case TList, TLayer(_), TTilePos, TProperties:
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
				kind : TDClass(),
				fields : [
					{
						name : "build",
						pos : pos,
						access : [APublic, AStatic],
						kind : FFun( {
							ret : t.name.toComplex(),
							expr : macro return $expr,
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
			var fname = fieldName(s.name);
			if( Lambda.exists(s.columns, function(c) return c.type == TId) ) {
				var kind = (tname + "Kind").toComplex();
				fields.push({
					name : fname,
					pos : pos,
					access : [APublic, AStatic],
					kind : FVar(macro : cdb.Types.IndexId<$t,$kind>),
				});
				assigns.push(macro $i { fname } = new cdb.Types.IndexId(root, $v { s.name } ));
			} else {
				fields.push({
					name : fname,
					pos : pos,
					access : [APublic, AStatic],
					kind : FVar(macro : cdb.Types.Index<$t>),
				});
				assigns.push(macro $i { fname } = new cdb.Types.Index(root, $v { s.name } ));
			}
		}
		types.push({
			pos : pos,
			name : modName,
			pack : curMod,
			kind : TDClass(),
			fields : (macro class {
				private static var root : cdb.Data;
				public static function applyLang( xml : String, ?onMissing : String -> Void ) {
					var c = new cdb.Lang(root);
					if( onMissing != null ) c.onMissing = onMissing;
					return c.apply(xml);
				}
				public static function load( content : String ) {
					root = cdb.Parser.parse(content);
					{$a{assigns}};
				}
			}).fields.concat(fields),
		});
		var mpath = Context.getLocalModule();
		Context.defineModule(mpath, types);
		Context.registerModuleDependency(mpath, path);
		#if (haxe_ver >= 3.2)
		return macro : Void;
		#else
		return Context.getType("Void");
		#end
		#end
	}

}