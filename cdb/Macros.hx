package cdb;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.Tools;
using Lambda;

typedef FieldBuild = {
	var type:ComplexType;
	@:optional var init:Null<Expr>;
}

typedef BuildArgs = {
	/** CDB module name */
	@:optional var moduleName:String;

	/** Whether to group consts by separator names */
	@:optional var groupIds:Bool;

	/** Whether to wrap load expressions in try/catch */
	@:optional var safeLoad:Bool;
}
#end

class Macros {
	public dynamic static function formatText(str:String, vars:Dynamic):String {
		for (f in Reflect.fields(vars))
			str = str.split("::" + f + "::").join("" + Reflect.field(vars, f));
		return str;
	}

	#if macro
	public static function buildConsts(file:String, path:String, args:BuildArgs = null) {
		var moduleName = args?.moduleName ?? "Data";
		var groupIds = args?.groupIds ?? false;
		var safeLoad = args?.safeLoad ?? false;

		var fields = Context.getBuildFields();
		var pos = Context.currentPos();

		inline function error(msg:String)
			Context.error(msg, pos);

		var data = Module.getData(file);
		var db = new Database();
		db.loadData(data);

		var mpath = Context.getLocalModule();
		Context.registerModuleDependency(mpath, Module.getDataPath(file));

		var parts = path.split("@");
		if (parts.length < 2)
			error('Path must contain at least Sheet@Column, got: "${path}"');

		var sheetName = parts[0];
		var colPath = parts.slice(1);

		var rootSheet = db.getSheet(sheetName);
		if (rootSheet == null)
			error('Sheet "${sheetName}" not found');

		var sheetKind = Module.makeTypeName(sheetName) + "Kind";
		var idCol = rootSheet.columns.find(c -> c.type == TId);
		if (idCol == null)
			error('Sheet "${sheetName}" needs a unique ID');

		var colSheetName = parts.slice(0, -1).join("@");
		var colSheet = db.getSheet(colSheetName);
		if (colSheet == null)
			error('Column sheet "${colSheetName}" not found');

		var colName = colPath[colPath.length - 1];
		var buildCol = colSheet.columns.find(c -> c.name == colName);
		if (buildCol == null)
			error('Column "${colName}" not found in sheet "${colSheetName}"');

		function getObj(line:Dynamic):Dynamic {
			var obj = line;
			for (fieldName in colPath) {
				obj = Reflect.field(obj, fieldName);
				if (obj == null)
					return null;
			}
			return obj;
		}

		var module = macro $i{moduleName};

		var refTables = new Map<String, Bool>();

		var fullTypes = new Map<String, ComplexType>();
		function fullType(tname:String) {
			if(fullTypes.exists(tname))
				return fullTypes.get(tname);
			var type = (moduleName + "." + Module.makeTypeName(tname)).toComplex();
			fullTypes.set(tname, type);
			return type;
		}

		function extractTextArgs(val:String):Null<Array<haxe.macro.Expr.Field>> {
			var splitRegex = ~/::(.+?)::/g;
			if (!splitRegex.match(val))
				return null;
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

		var simpleTypes = new Map<cdb.Data.ColumnType, ComplexType>();
		function simpleType(t:cdb.Data.ColumnType):Null<ComplexType> {
			if(simpleTypes.exists(t))
				return simpleTypes.get(t);
			var type = switch (t) {
				case TInt | TColor: macro :Int;
				case TFloat: macro :Float;
				case TBool: macro :Bool;
				case TString: macro :String;
				case TCurve: macro :cdb.Types.Curve;
				case TGradient: macro :cdb.Types.Gradient;
				case TImage: macro :String;
				case TFile: macro :String;
				case TTilePos: macro :cdb.Types.TilePos;
				case TTileLayer: macro :cdb.Types.TileLayer;
				case TDynamic: macro :Dynamic;
				default: null;
			};
			simpleTypes.set(t, type);
			return type;
		}

		function getPolyVal(polySub:Sheet, colVal:Dynamic):{col:cdb.Data.Column, val:Dynamic} {
			for (pc in polySub.columns) {
				var pv = Reflect.field(colVal, pc.name);
				if (pv != null)
					return {col: pc, val: pv};
			}
			return null;
		}

		function buildField(col:cdb.Data.Column, colVal:Dynamic, sheet:Sheet, prefix:String):FieldBuild {
			if (colVal == null)
				return null;
			switch (col.type) {
				case TInt | TColor | TFloat | TBool:
					return {
						type: simpleType(col.type),
						init: macro $v{colVal}
					};
				case TCurve | TGradient | TImage | TFile | TTilePos | TTileLayer | TDynamic:
					return { type: simpleType(col.type) };
				case TString:
					var textArgs = extractTextArgs(colVal);
					if (textArgs == null)
						return { type: macro :String };
					return { type: TFunction([TAnonymous(textArgs)], macro :String) };
				case TRef(refTable):
					refTables.set(refTable, true);
					return { type: fullType(refTable) };
				case TProperties:
					return { type: fullType(sheet.getSub(col).name) };
				case TPolymorph:
					var polySub = sheet.getSub(col);
					var pval = getPolyVal(polySub, colVal);
					if (pval == null)
						return null;
					return buildField(pval.col, pval.val, polySub, prefix);
				case TList:
					var sub = sheet.getSub(col);
					var subCols = sub.columns.filter(c -> c.kind != Hidden);
					if (subCols.length == 0)
						error('Empty sub-list');

					var idCol = subCols.find(c -> c.type == TId);
					if (subCols.length == 2 && idCol != null) {
						subCols.remove(idCol);
						var valCol = subCols[0];

						var val:Array<Dynamic> = colVal;
						var fields:Array<haxe.macro.Expr.Field> = [];
						var valueType:ComplexType = null;
						var iterator = true;

						for (row in val) {
							var sid:String = Reflect.field(row, idCol.name);
							if (sid == null || sid == "")
								continue;
							var itemVal = Reflect.field(row, valCol.name);
							var result = buildField(valCol, itemVal, sub, prefix + "_" + sid);
							if (result == null)
								return continue;
							fields.push({
								name: sid,
								pos: pos,
								kind: FVar(result.type),
								access: [AFinal]
							});
							if(iterator) {
								if (valueType == null)
									valueType = result.type;
								// comparison relies on memoized types in fullType and simpleType
								else if(!Type.enumEq(valueType, result.type))
									iterator = false;
							}
						}

						if (iterator && valueType != null) {
							var iterElemType:ComplexType = TAnonymous([
								{name: idCol.name, pos: pos, kind: FVar(macro :String)},
								{name: valCol.name, pos: pos, kind: FVar(valueType)}
							]);
							fields.push({
								name: "iterator",
								pos: pos,
								kind: FFun({args: [], ret: macro :Iterator<$iterElemType>, expr: null}),
								meta: [{name: ":noCompletion", pos: pos}]
							});
						}

						return { type: TAnonymous(fields) };
					} else if (subCols.length == 1) {
						var vcol = subCols[0];
						var vname = vcol.name;
						var valueType : ComplexType = null;

						if (vcol.type == TPolymorph) {
							// Special case, list of polymorphs of identical type
							var polyCol : String = null;
							var polySub = sub.getSub(vcol);

							for (row in (colVal : Array<Dynamic>)) {
								var cv = Reflect.field(row, vname);
								if (cv == null) continue;
								var pval = getPolyVal(polySub, cv);
								if (pval == null) continue;

								var result = buildField(pval.col, pval.val, polySub, prefix);
								if (result == null) {
									valueType = null;
									break;
								}
								if (valueType == null) {
									valueType = result.type;
									polyCol = pval.col.name;
								}
								// comparison relies on memoized types in fullType and simpleType
								else if (!Type.enumEq(valueType, result.type)) {
									valueType = null;
									break;
								}
								else if (polyCol != pval.col.name) {
									valueType = null;
									break;
								}
							}
						}

						if(valueType == null)
							valueType = simpleType(vcol.type) ?? fullType(sub.name);

						return { type: macro :cdb.Types.ArrayRead<$valueType> };
					} else {
						var et = fullType(sub.name);
						return { type: macro :cdb.Types.ArrayRead<$et> };
					}
				default:
					error('Unsupported column type ${col.type}');
					return null;
			}
		};

		if (groupIds) {
			// Group fields by separators
			var separators = rootSheet.separators;
			if (separators == null || separators.length == 0)
				error('Sheet needs separators for groupIds feature');
			if (separators[0].index == null)
				error("groupIds need exported groups");

			var i = 0;
			for (sepi in 0...separators.length) {
				var sep = separators[sepi];
				var nextSep = (sepi < separators.length - 1) ? separators[sepi + 1] : null;

				var groupFields = [];
				var initExprs = [];

				while (i < rootSheet.lines.length) {
					var line = rootSheet.lines[i];
					if (nextSep != null && nextSep.index == i)
						break;
					i++;

					var id = Reflect.field(line, idCol.name);
					var pobj = getObj(line);

					if (id == null || id == "" || pobj == null)
						continue;

					var result = buildField(buildCol, pobj, colSheet, id);
					if (result == null)
						continue;

					initExprs.push({field: id, expr: result.init ?? macro cast null});

					groupFields.push({
						name: id,
						pos: pos,
						kind: FVar(result.type),
						access: [AFinal]
					});
				}

				fields.push({
					name: sep.title,
					pos: pos,
					access: [AStatic, APublic],
					kind: FVar(TAnonymous(groupFields), {
						expr: EObjectDecl(initExprs), pos: pos
					})
				});
			}
		} else {
			// Flat fields
			for (line in rootSheet.getLines()) {
				var id = Reflect.field(line, idCol.name);
				var pobj = getObj(line);
				if (id == null || id == "" || pobj == null)
					continue;

				var result = buildField(buildCol, pobj, colSheet, id);
				if (result == null)
					continue;

				fields.push({
					name: id,
					pos: pos,
					access: [AStatic, APublic],
					kind: FVar(result.type, result.init)
				});
			}
		}

		// resolver for TRef consts: table name -> Data.<sheet>.resolve(id)
		var refCases = [for (t in refTables.keys()) {
			var fname = Module.fieldName(t);
			({ values: [macro $v{t}], expr: macro $module.$fname.resolve(id, true) } : Case);
		}];
		var resolveRef = macro function(table:String, id:String):Dynamic
			return ${{ expr: ESwitch(macro table, refCases, macro null), pos: pos }};

		var colPathElems = [for (p in colPath) macro $v{p}];
		var colPathExpr = macro $a{colPathElems};
		var cls = Context.getLocalClass().get();
		var clsExpr = macro $p{cls.pack.concat([cls.name])};

		fields.push({
			name: "reload",
			pos: pos,
			access: [AStatic, APublic],
			kind: FFun({args: [], ret: macro :Void, expr: macro {
				var loader = new cdb.ConstLoader(@:privateAccess $module.root, $resolveRef, $v{safeLoad});
				loader.reloadConsts($clsExpr, $v{sheetName}, $colPathExpr, $v{groupIds});
			}})
		});

		return fields;
	}
	#end
}
