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

		// Extract text interpolation args, returns null if no interpolation needed
		function extractTextArgs(val:String):Null<Array<haxe.macro.Expr.Field>> {
			if (!splitRegex.match(val)) return null;
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
			return args;
		}

		function simpleType(t:cdb.Data.ColumnType):Null<ComplexType> {
			return switch (t) {
				case TInt: macro :Int;
				case TFloat: macro :Float;
				case TBool: macro :Bool;
				case TString: macro :String;
				default: null;
			};
		}

		// Helper to create a var declaration expression
		function makeVar(name:String, initExpr:Expr):Expr {
			return { expr: EVars([{ name: name, type: null, expr: initExpr, isFinal: false }]), pos: pos };
		}

		// Forward declarations for mutual recursion
		var buildNestedField:(col:cdb.Data.Column, colVal:Dynamic, sheet:Sheet, rowExpr:Expr, prefix:String) -> { fieldType:ComplexType, varDecls:Array<Expr>, initExpr:Expr } = null;
		var buildSubIdType:(sub:Sheet, val:Array<Dynamic>, arrayExpr:Expr, prefix:String) -> { anonFields:Array<haxe.macro.Expr.Field>, varDecls:Array<Expr>, initExpr:Expr } = null;

		// Builds field type and init expression for a column in nested context
		buildNestedField = function(col:cdb.Data.Column, colVal:Dynamic, sheet:Sheet, rowExpr:Expr, prefix:String) {
			var colName = col.name;
			return switch (col.type) {
				case TInt | TFloat | TBool:
					{ fieldType: simpleType(col.type), varDecls: [], initExpr: macro $rowExpr.$colName };
				case TString:
					var textArgs = extractTextArgs(colVal);
					if (textArgs == null) {
						{ fieldType: macro :String, varDecls: [], initExpr: macro $rowExpr.$colName };
					} else {
						{
							fieldType: TFunction([TAnonymous(textArgs)], macro :String),
							varDecls: [],
							initExpr: macro function(vars) { return cdb.Macros.formatText($rowExpr.$colName, vars); }
						};
					}
				case TProperties | TPolymorph:
					var subType = fullType(sheet.getSub(col).name);
					{ fieldType: subType, varDecls: [], initExpr: macro $rowExpr.$colName };
				case TList:
					var sub = sheet.getSub(col);
					if (sub.columns.length == 0) {
						error('Empty sub-list');
						null;
					} else {
						var firstCol = sub.columns[0];
						var firstColName = firstCol.name;
						if (firstCol.type == TId && sub.columns.length >= 2) {
							// Recursive sub-ID access
							var result = buildSubIdType(sub, colVal, macro $rowExpr.$colName, prefix);
							{ fieldType: TAnonymous(result.anonFields), varDecls: result.varDecls, initExpr: result.initExpr };
						} else if (sub.columns.length == 1) {
							// Single column list
							var et = simpleType(firstCol.type);
							if (et == null) et = fullType(sub.name);
							{
								fieldType: macro :Array<$et>,
								varDecls: [],
								initExpr: macro [for (l in ($rowExpr.$colName : Array<Dynamic>)) (l : Dynamic).$firstColName]
							};
						} else {
							// Multi-column list without TId
							var et = fullType(sub.name);
							{ fieldType: macro :Array<$et>, varDecls: [], initExpr: macro $rowExpr.$colName };
						}
					}
				default:
					error('Unsupported column type ${col.type}');
					null;
			};
		};

		// Builds anonymous type and init expression for a sub-ID list (recursive)
		// Generates intermediate variables: prefix_SubID = { ... }
		buildSubIdType = function(sub:Sheet, val:Array<Dynamic>, arrayExpr:Expr, prefix:String) {
			var idcol = sub.columns[0];
			var idcolName = idcol.name;
			var anonFields = new Array<haxe.macro.Expr.Field>();
			var initFields = new Array<haxe.macro.Expr.ObjectField>();
			var allVarDecls = new Array<Expr>();

			for (i => row in val) {
				var sid:String = Reflect.field(row, idcolName);
				if (sid == null || sid == "") continue;
				var rowExpr = macro $arrayExpr[$v{i}];
				var entryVar = prefix + "_" + sid;

				if (sub.columns.length == 2) {
					// Single value column - field name is just the ID
					var vcol = sub.columns[1];
					var colVal = Reflect.field(row, vcol.name);
					var result = buildNestedField(vcol, colVal, sub, rowExpr, entryVar);
					// Collect child var decls
					for (d in result.varDecls) allVarDecls.push(d);
					// Create var for this entry
					allVarDecls.push(makeVar(entryVar, result.initExpr));
					anonFields.push({ name: sid, pos: pos, kind: FVar(result.fieldType) });
					initFields.push({ field: sid, expr: macro $i{entryVar} });
				} else {
					// Multiple value columns - nested anonymous type per ID
					var nestedAnonFields = new Array<haxe.macro.Expr.Field>();
					var nestedInitFields = new Array<haxe.macro.Expr.ObjectField>();
					for (j in 1...sub.columns.length) {
						var vcol = sub.columns[j];
						var colVal = Reflect.field(row, vcol.name);
						var result = buildNestedField(vcol, colVal, sub, rowExpr, entryVar + "_" + vcol.name);
						// Collect child var decls
						for (d in result.varDecls) allVarDecls.push(d);
						nestedAnonFields.push({ name: vcol.name, pos: pos, kind: FVar(result.fieldType) });
						nestedInitFields.push({ field: vcol.name, expr: result.initExpr });
					}
					// Create var for this entry (the nested object)
					var nestedObj:Expr = { expr: EObjectDecl(nestedInitFields), pos: pos };
					allVarDecls.push(makeVar(entryVar, nestedObj));
					anonFields.push({ name: sid, pos: pos, kind: FVar(TAnonymous(nestedAnonFields)) });
					initFields.push({ field: sid, expr: macro $i{entryVar} });
				}
			}

			return { anonFields: anonFields, varDecls: allVarDecls, initExpr: { expr: EObjectDecl(initFields), pos: pos } };
		};

		function buildText(col:cdb.Data.Column, val:String, id:String):FieldType {
			var args = extractTextArgs(val);
			if (args == null)
				return FVar(macro :String, macro $v{val});
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
					var firstCol = sub.columns[0];
					var firstColName = firstCol.name;
					if (sub.columns.length == 1) {
						// Single column list: unwrap to Array<ElementType>
						var et = simpleType(firstCol.type);
						if (et == null) et = fullType(sub.name);
						initExprs.push(macro {
							var obj:Dynamic = ${getData(id)};
							$i{id} = [for (l in (obj.$polyColName.$colName : Array<Dynamic>)) (l : Dynamic).$firstColName];
						});
						FVar(macro :Array<$et>, macro null);
					} else if (firstCol.type == TId) {
						// Sub-ID access - use recursive helper
						var result = buildSubIdType(sub, val, macro vals, id);
						// Build init block: var declarations then assignment
						var initBlock = new Array<Expr>();
						initBlock.push(macro var obj:Dynamic = ${getData(id)});
						initBlock.push(macro var vals:Array<Dynamic> = obj.$polyColName.$colName);
						for (d in result.varDecls) initBlock.push(d);
						initBlock.push(macro $i{id} = ${result.initExpr});
						initExprs.push(macro $b{initBlock});
						FVar(TAnonymous(result.anonFields), macro null);
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
