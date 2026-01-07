package cdb;
import haxe.macro.Context;
using haxe.macro.Tools;
#if macro
import haxe.macro.Expr;
#end
using Lambda;

class Macros {

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

        var db = new Database();
        db.loadData(getData(file));

        var sheet = db.getSheet(sheetName);
        if(sheet == null)
            Context.error("Sheet '" + sheetName + "' not found", pos);

        var idCol = sheet.columns.find(c -> c.type == TId);
        if(idCol == null)
            Context.error("Sheet '" + sheet.name + "' must have a unique ID", pos);
        var polyCol = sheet.columns.find(c -> c.type == TPolymorph);
        if(polyCol == null)
            Context.error("Sheet '" + sheet.name + "' must have a polymorphic column", pos);

        var polySheet = sheet.getSub(polyCol);
        if(polySheet == null)
            Context.error("Polymorph sub-sheet not found for column '" + polyCol.name + "'", pos);

        var splitRegex = ~/::(.+?)::/g;
        function textField(val: String) {
            if (!splitRegex.match(val)) {
                return FVar(macro: String, macro $v{val});
            }
            // Parse parameters for strong typing
            var fields = new Array<haxe.macro.Expr.Field>();
            var map = new Map<String, Bool>();
            splitRegex.map(val, function(r) {
                var name = r.matched(1);
                if (!map.exists(name)) {
                    map.set(name, true);
                    fields.push({
                        name: name,
                        kind: FVar(macro: Dynamic),
                        pos: pos,
                        meta: []
                    });
                }
                return r.matched(0);
            });
            var funcType = TFunction([TAnonymous(fields)], macro: String);

            // Use FProp for strong typing like DynamicText does
            return FProp("default", "never", funcType);
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
                case TString: textField(pval.val);
                case TBool: FVar(macro: Bool, macro $v{pval.val});
                case TProperties:
                    var psheet = polySheet.getSub(pval.col);
                    if(psheet == null) null;
                    else {
                        // full path like Data.Sheet_col_prop
                        var fullPath = moduleName + "." + Module.fieldName(psheet.name);
                        var typeName = moduleName + "." + Module.makeTypeName(psheet.name);
                        FVar(typeName.toComplex(), null);
                    }
                    
                default: null;
                // case TList:
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
}