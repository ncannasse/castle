package cdb;
#if macro
import haxe.macro.Context;
using haxe.macro.Tools;
import haxe.macro.Expr;
#end
using Lambda;

class Macros {

    public static function interpolateText(str: String, vars: Dynamic): String {
        for (f in Reflect.fields(vars))
            str = str.split("::" + f + "::").join("" + Reflect.field(vars, f));
        return str;
    }

#if macro
    public static function getData(file:String) : Data {
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
        return Parser.parse(sys.io.File.getContent(path), false);
    }

    public static function buildPoly(file: String, sheetName: String, moduleName: String="Data") {
        var fields = Context.getBuildFields();
        var pos = Context.currentPos();

        inline function error(message: String) {
            Context.error(message, pos);
        }

        var db = new Database();
        db.loadData(getData(file));

        var sheet = db.getSheet(sheetName);
        if(sheet == null) error('"${sheetName}" not found');

        var sheetKind = Module.makeTypeName(sheetName) + "Kind";

        var idCol = sheet.columns.find(c -> c.type == TId);
        var polyCol = sheet.columns.find(c -> c.type == TPolymorph);
        if(idCol == null) error('Sheet needs a unique ID');
        if(polyCol == null) error('Sheet needs a polymorphic column');

        var polySheet = sheet.getSub(polyCol);
        var module = macro $i{moduleName};
        var polyColName = polyCol.name;


        var splitRegex = ~/::(.+?)::/g;
        function buildText(col: cdb.Data.Column, val: String, id: String): FieldType {
            if (!splitRegex.match(val)) {
                return FVar(macro: String, macro $v{val});
            }
            var args = new Array<haxe.macro.Expr.Field>();
            var map = new Map<String, Bool>();
            splitRegex.map(val, function(r) {
                var name = r.matched(1);
                if (!map.exists(name)) {
                    map.set(name, true);
                    args.push({
                        name: name,
                        kind: FVar(macro: Dynamic),
                        pos: pos,
                        meta: []
                    });
                }
                return r.matched(0);
            });
            var textColName = col.name;
            return FFun({
                ret: macro: String,
                args: [{name: "vars", type: TAnonymous(args)}],
                params: [],
                expr: macro {
                    var obj : Dynamic = $module.$sheetName.get($module.$sheetKind.$id);
                    var str = obj.$polyColName.$textColName;
                    return cdb.Macros.interpolateText(str, vars);
                }
            });
        }

        function buildProps(col: cdb.Data.Column, val: Dynamic, id: String): FieldType {
            var psheet = polySheet.getSub(col);
            if(psheet == null) 
                return null;
            var typeName = moduleName + "." + Module.makeTypeName(psheet.name);
            var colName = col.name;

            fields.push({
                name: "get_" + id,
                pos: pos,
                access: [AStatic, APrivate],
                kind: FFun({
                    args: [],
                    ret: typeName.toComplex(),
                    expr: macro {
                        var obj : Dynamic = $module.$sheetName.get($module.$sheetKind.$id);
                        return obj.$polyColName.$colName;
                    }
                })
            });

            return FProp("get", "never", typeName.toComplex());
        }

        for(line in sheet.getLines()) {
            var id = Reflect.field(line, idCol.name);
            var pobj = Reflect.field(line, polyCol.name);
            if(id == null || id == "")
                continue;
            if(pobj == null)
                continue;

            var pval = polySheet.getPolyVal(pobj);
            if(pval == null)
                continue;

            var pvar : FieldType = switch(pval.col.type) {
                case TFloat: FVar(macro: Float, macro $v{pval.val});
                case TInt: FVar(macro: Int, macro $v{pval.val});
                case TBool: FVar(macro: Bool, macro $v{pval.val});
                case TString: buildText(pval.col, pval.val, id);
                case TProperties: buildProps(pval.col, pval.val, id);
                default: null;
            };

            if(pvar != null) {
                fields.push({
                    name : id,
                    pos : pos,
                    access: [AStatic, APublic],
                    kind : pvar
                });
            }
        }

        return fields;
    }
#end
}