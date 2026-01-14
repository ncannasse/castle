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

		var module = macro $i{moduleName};

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

		function buildField (col:cdb.Data.Column, colVal:Dynamic, sheet:Sheet, rowExpr:Expr, prefix:String) : { fieldType:ComplexType, varDecls:Array<Expr>, initExpr:Expr } {
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
				case TProperties:
					var subType = fullType(sheet.getSub(col).name);
					{ fieldType: subType, varDecls: [], initExpr: macro $rowExpr.$colName };
				case TPolymorph:
					// Find the active variant and recurse into it
					var polySub = sheet.getSub(col);
					var variantCol:cdb.Data.Column = null;
					var variantVal:Dynamic = null;
					for (pc in polySub.columns) {
						var pv = Reflect.field(colVal, pc.name);
						if (pv != null) {
							variantCol = pc;
							variantVal = pv;
							break;
						}
					}
					if (variantCol == null) {
						// No variant set, return the raw polymorph type
						var subType = fullType(polySub.name);
						{ fieldType: subType, varDecls: [], initExpr: macro $rowExpr.$colName };
					} else {
						// Recurse on the specific variant
						var polyExpr = macro $rowExpr.$colName;
						buildField(variantCol, variantVal, polySub, polyExpr, prefix);
					}
				case TList:
					var sub = sheet.getSub(col);
					if (sub.columns.length == 0) {
						error('Empty sub-list');
						null;
					} else {
						var firstCol = sub.columns[0];
						var firstColName = firstCol.name;
						if (firstCol.type == TId && sub.columns.length == 2) {
							// Sub-ID list: (id, value) where value can be any type (including recursive TList)
							var val:Array<Dynamic> = colVal;
							var idcolName = firstCol.name;
							var arrayExpr = macro $rowExpr.$colName;
							var anonFields = new Array<haxe.macro.Expr.Field>();
							var initFields = new Array<haxe.macro.Expr.ObjectField>();
							var allVarDecls = new Array<Expr>();

							var vcol = sub.columns[1];
							var vcolName = vcol.name;
							for (i => row in val) {
								var sid:String = Reflect.field(row, idcolName);
								if (sid == null || sid == "") continue;
								var itemExpr = macro $arrayExpr[$v{i}];
								var entryVar = prefix + "_" + sid;
								var vcolVal = Reflect.field(row, vcolName);
								var result = buildField(vcol, vcolVal, sub, itemExpr, entryVar);
								for (d in result.varDecls) allVarDecls.push(d);
								allVarDecls.push(makeVar(entryVar, result.initExpr));
								anonFields.push({ name: sid, pos: pos, kind: FVar(result.fieldType) });
								initFields.push({ field: sid, expr: macro $i{entryVar} });
							}
							{ fieldType: TAnonymous(anonFields), varDecls: allVarDecls, initExpr: { expr: EObjectDecl(initFields), pos: pos } };
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

		for (line in sheet.getLines()) {
			var id = Reflect.field(line, idCol.name);
			var pobj = Reflect.field(line, polyCol.name);
			if (id == null || id == "")
				continue;
			if (pobj == null)
				continue;

			// Let buildField handle polymorph variant detection
			var result = buildField(polyCol, pobj, sheet, macro obj, id);

			// Build init block
			var initBlock = new Array<Expr>();
			initBlock.push(macro var obj:Dynamic = ${getData(id)});
			for (d in result.varDecls) initBlock.push(d);
			initBlock.push(macro $i{id} = ${result.initExpr});
			initExprs.push(macro $b{initBlock});

			// Create top-level field
			fields.push({
				name: id,
				pos: pos,
				access: [AStatic, APublic],
				kind: FVar(result.fieldType, macro cast null)
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
