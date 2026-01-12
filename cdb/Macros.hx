package cdb;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.Tools;
#end
using Lambda;

class Macros {
	public dynamic static function formatText(str:String, vars:Dynamic):String {
		for (f in Reflect.fields(vars))
			str = str.split("::" + f + "::").join("" + Reflect.field(vars, f));
		return str;
	}

	#if macro
	public static function getData(file:String):Data {
		var pos = Context.currentPos();
		var path = try Context.resolvePath(file) catch (e:Dynamic) null;
		if (path == null) {
			var r = Context.definedValue("resourcesPath");
			if (r != null) {
				r = r.split("\\").join("/");
				if (!StringTools.endsWith(r, "/"))
					r += "/";
				try
					path = Context.resolvePath(r + file)
				catch (e:Dynamic)
					null;
			}
		}
		if (path == null)
			try
				path = Context.resolvePath("res/" + file)
			catch (e:Dynamic)
				null;
		if (path == null)
			Context.error("File not found " + file, pos);
		return Parser.parse(sys.io.File.getContent(path), false);
	}

	public static function buildPoly(file:String, sheetName:String, moduleName:String = "Data") {
		var fields = Context.getBuildFields();
		var pos = Context.currentPos();

		inline function error(message:String) {
			Context.error(message, pos);
		}

		var db = new Database();
		db.loadData(getData(file));

		var sheet = db.getSheet(sheetName);
		if (sheet == null)
			error('"${sheetName}" not found');

		var sheetKind = Module.makeTypeName(sheetName) + "Kind";

		var idCol = sheet.columns.find(c -> c.type == TId);
		var polyCol = sheet.columns.find(c -> c.type == TPolymorph);
		if (idCol == null)
			error('Sheet needs a unique ID');
		if (polyCol == null)
			error('Sheet needs a polymorphic column');

		var polySheet = sheet.getSub(polyCol);
		var module = macro $i{moduleName};
		var polyColName = polyCol.name;

		var initExprs = new Array<Expr>();

		function fullType(tname:String) {
			return (moduleName + "." + Module.makeTypeName(tname)).toComplex();
		}

		function getData(id:String):Expr {
			return macro $module.$sheetName.get($module.$sheetKind.$id);
		}

		function getType(sheet:cdb.Sheet, col:cdb.Data.Column):Null<ComplexType> {
			return switch (col.type) {
				case TInt: macro :Int;
				case TFloat: macro :Float;
				case TBool: macro :Bool;
				case TString: macro :String;
				case TProperties | TPolymorph:
					var sub = sheet.getSub(col);
					fullType(sub.name);
				case TList:
					var sub = sheet.getSub(col);
					var scols = sub.columns;
					var et = scols.length == 1 ? getType(sub, scols[0]) : fullType(sub.name);
					macro :Array<$et>;
				default:
					error('Unsupported column type: ${col.type}');
					null;
			};
		}

		// Generates a value extraction expression, unwrapping single-column lists recursively
		// Returns null for types that use typed getters instead (TProperties, TPolymorph)
		function getValueExpr(sheet:cdb.Sheet, col:cdb.Data.Column, source:Expr):Null<Expr> {
			var colName = col.name;
			var accessed:Expr = macro ($source : Dynamic).$colName;
			return switch (col.type) {
				case TInt, TFloat, TBool:
					accessed;
				case TList:
					var sub = sheet.getSub(col);
					var scols = sub.columns;
					if (scols.length == 1) {
						var innerExpr = getValueExpr(sub, scols[0], macro l);
						if (innerExpr == null) accessed;
						else macro [for (l in ($accessed : Array<Dynamic>)) $innerExpr];
					} else {
						accessed;
					}
				default:
					null;
			};
		}

		var splitRegex = ~/::(.+?)::/g;
		function buildText(col:cdb.Data.Column, val:String, id:String):FieldType {
			if (!splitRegex.match(val)) {
				return FVar(macro :String, macro $v{val});
			}
			var args = new Array<haxe.macro.Expr.Field>();
			var map = new Map<String, Bool>();
			splitRegex.map(val, function(r) {
				var name = r.matched(1);
				if (!map.exists(name)) {
					map.set(name, true);
					args.push({
						name: name,
						kind: FVar(macro :Dynamic),
						pos: pos,
						meta: []
					});
				}
				return r.matched(0);
			});
			var textColName = col.name;
			return FFun({
				ret: macro :String,
				args: [{name: "vars", type: TAnonymous(args)}],
				params: [],
				expr: macro {
					var obj:Dynamic = ${getData(id)};
					var str = obj.$polyColName.$textColName;
					return cdb.Macros.formatText(str, vars);
				}
			});
		}

		function getVal(obj:Dynamic):{col:cdb.Data.Column, val:Dynamic} {
			for (col in polySheet.columns) {
				var v = Reflect.field(obj, col.name);
				if (v != null)
					return {col: col, val: v};
			}
			return null;
		}

		for (line in sheet.getLines()) {
			var id = Reflect.field(line, idCol.name);
			var pobj = Reflect.field(line, polyCol.name);
			if (id == null || id == "")
				continue;
			if (pobj == null)
				continue;

			var pval = getVal(pobj);
			if (pval == null)
				continue;

			var t = getType(polySheet, pval.col);
			if (t == null)
				continue;

			var pvar:FieldType = switch (pval.col.type) {
				case TString:
					buildText(pval.col, pval.val, id);
				case TProperties | TPolymorph:
					var colName = pval.col.name;
					fields.push({
						name: "get_" + id,
						pos: pos,
						access: [AStatic, APrivate],
						kind: FFun({
							args: [],
							ret: t,
							expr: macro {
								var obj:Dynamic = ${getData(id)};
								return obj.$polyColName.$colName;
							}
						})
					});
					FProp("get", "never", t);
				case TList | TInt | TFloat | TBool:
					initExprs.push(macro {
						var obj:Dynamic = ${getData(id)};
						$i{id} = ${getValueExpr(polySheet, pval.col, macro obj.$polyColName)};
					});
					var initVal = pval.col.type == TList ? macro null : macro $v{pval.val};
					FVar(t, initVal);
				default:
					error('Unsupported column type: ${pval.col.type}');
					null;
			};

			fields.push({
				name: id,
				pos: pos,
				access: [AStatic, APublic],
				kind: pvar
			});
		}

		fields.push({
			name: "reload",
			pos: pos,
			access: [AStatic, APublic],
			kind: FFun({
				args: [],
				ret: macro :Void,
				expr: macro {
					$b{initExprs}
				}
			})
		});

		return fields;
	}
	#end
}
