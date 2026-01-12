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

		var reloadExprs = new Array<Expr>();

		function fullType(tname:String) {
			return (moduleName + "." + Module.makeTypeName(tname)).toComplex();
		}

		function getType(sheet:cdb.Sheet, col:cdb.Data.Column):Null<ComplexType> {
			return switch (col.type) {
				case TInt: macro :Int;
				case TFloat: macro :Float;
				case TBool: macro :Bool;
				case TString: macro :String;
				case TProperties | TPolymorph:
					var subSheet = sheet.getSub(col);
					if (subSheet == null) null; else fullType(subSheet.name);
				case TList:
					var subSheet = sheet.getSub(col);
					if (subSheet == null) null; else if (subSheet.columns.length == 1) {
						var t = getType(subSheet, subSheet.columns[0]);
						if (t == null)
							t = macro :Dynamic;
						macro :Array<$t>;
					} else {
						var typeName = fullType(subSheet.name);
						macro :Array<$typeName>;
					}
				default: null;
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
					var obj:Dynamic = $module.$sheetName.get($module.$sheetKind.$id);
					var str = obj.$polyColName.$textColName;
					return cdb.Macros.formatText(str, vars);
				}
			});
		}

		function buildProps(col:cdb.Data.Column, val:Dynamic, id:String):FieldType {
			var propType = getType(polySheet, col);
			if (propType == null)
				return null;
			var colName = col.name;

			fields.push({
				name: "get_" + id,
				pos: pos,
				access: [AStatic, APrivate],
				kind: FFun({
					args: [],
					ret: propType,
					expr: macro {
						var obj:Dynamic = $module.$sheetName.get($module.$sheetKind.$id);
						return obj.$polyColName.$colName;
					}
				})
			});

			return FProp("get", "never", propType);
		}

		function buildList(col:cdb.Data.Column, val:Dynamic, id:String):FieldType {
			var arrayType = getType(polySheet, col);
			if (arrayType == null)
				return null;
			return FVar(arrayType, macro null);
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

		var pvar:FieldType = switch (pval.col.type) {
			case TString: buildText(pval.col, pval.val, id);
			case TProperties | TPolymorph: buildProps(pval.col, pval.val, id);
			case TList: buildList(pval.col, pval.val, id);
			default:
				var colType = getType(polySheet, pval.col);
				colType != null ? FVar(colType, macro $v{pval.val}) : null;
		};

			if (pvar != null) {
				fields.push({
					name: id,
					pos: pos,
					access: [AStatic, APublic],
					kind: pvar
				});
			}
		}

		fields.push({
			name: "reload",
			pos: pos,
			access: [AStatic, APublic],
			kind: FFun({
				args: [],
				ret: macro :Void,
				expr: macro {
					$b{reloadExprs}
				}
			})
		});

		return fields;
	}
	#end
}
