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

		var splitRegex = ~/::(.+?)::/g;
		function buildText(col:cdb.Data.Column, val:String, id:String):FieldType {
			if (!splitRegex.match(val))
				return FVar(macro :String, macro $v{val});
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

		for (line in sheet.getLines()) {
			var id = Reflect.field(line, idCol.name);
			var pobj = Reflect.field(line, polyCol.name);
			if (id == null || id == "")
				continue;
			if (pobj == null)
				continue;

			var col:cdb.Data.Column = null;
			var val:Dynamic = null;
			for (c in polySheet.columns) {
				var v = Reflect.field(pobj, c.name);
				if (v != null) {
					col = c;
					val = v;
					break;
				}
			}
			if (col == null)
				continue;

			var colName = col.name;

			function simpleType(t:cdb.Data.ColumnType):Null<ComplexType> {
				return switch (t) {
					case TInt: macro :Int;
					case TFloat: macro :Float;
					case TBool: macro :Bool;
					case TString: macro :String;
					default: null;
				};
			}

			var fieldId = id;
			var fieldKind:FieldType = switch (col.type) {
				case TInt | TFloat | TBool:
					initExprs.push(macro {
						var obj:Dynamic = ${getData(id)};
						$i{id} = obj.$polyColName.$colName;
					});
					FVar(simpleType(col.type), macro $v{val});
				case TString:
					buildText(col, val, id);
				case TProperties | TPolymorph:
					var t = fullType(polySheet.getSub(col).name);
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
				case TList:
					var sub = polySheet.getSub(col);
					if (sub.columns.length == 0) continue;
					if (sub.columns.length == 1) {
						// Single column list: unwrap to Array<ElementType>
						var scol = sub.columns[0];
						var scolName = scol.name;
						var et = simpleType(scol.type);
						if (et == null) et = fullType(sub.name);
						initExprs.push(macro {
							var obj:Dynamic = ${getData(id)};
							$i{id} = [for (l in (obj.$polyColName.$colName : Array<Dynamic>)) (l : Dynamic).$scolName];
						});
						FVar(macro :Array<$et>, macro null);
					//} //else if (scols[0].type == TId) {
						// TId list: generate anonymous type { rowId1: T, rowId2: T, ... }
						/*
						var idColName = scols[0].name;
						var valColName = scols.length == 2 ? scols[1].name : null;
						var rowType = valColName != null ? simpleType(scols[1].type) : null;
						if (rowType == null) rowType = fullType(sub.name);
						var anonFields = new Array<haxe.macro.Expr.Field>();
						var initFields = new Array<haxe.macro.Expr.ObjectField>();
						for (row in sub.getLines()) {
							var rowId:String = Reflect.field(row, idColName);
							if (rowId == null || rowId == "") continue;
							var valExpr = valColName != null ? macro item.$valColName : macro item;
							anonFields.push({ name: rowId, pos: pos, kind: FVar(rowType) });
							initFields.push({ field: rowId, expr: macro {
								var v:$rowType = null;
								for (item in (obj.$polyColName.$colName : Array<Dynamic>))
									if (item.$idColName == $v{rowId}) { v = $valExpr; break; }
								v;
							}});
						}
						initExprs.push(macro {
							var obj:Dynamic = ${getData(id)};
							$i{id} = ${ { expr: EObjectDecl(initFields), pos: pos } };
						});
						FVar(TAnonymous(anonFields), macro null);
						*/
						// null;
					} else {
						// Multi-column list without TId: Array<StructType>
						var et = fullType(sub.name);
						initExprs.push(macro {
							var obj:Dynamic = ${getData(id)};
							$i{id} = obj.$polyColName.$colName;
						});
						FVar(macro :Array<$et>, macro null);
					}
				default:
					error('Unsupported column type: ${col.type}');
					continue;
			};
			fields.push({
				name: id,
				pos: pos,
				access: [AStatic, APublic],
				kind: fieldKind
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
