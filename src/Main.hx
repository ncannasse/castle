import js.JQuery.JQueryHelper.*;

typedef Prefs = {
	windowPos : { x : Int, y : Int, w : Int, h : Int, max : Bool },
	curFile : String,
	curSheet : Int,
}

class Main {

	var window : nw.Window;
	var prefs : Prefs;
	var data : Data;
	var sheet : Data.Sheet;
	var smap : Map<String, { s : Data.Sheet, ids : Map < String, String >, all : Array<{ id : String, disp : String }> } >;
	
	static var r_id = ~/^[A-Za-z_][A-Za-z_0-9]*$/;
	
	function new() {
		window = nw.Window.get();
		
		prefs = {
			windowPos : { x : 50, y : 50, w : 800, h : 600, max : false },
			curFile : null,
			curSheet : 0,
		};
		try {
			prefs = haxe.Unserializer.run(js.Browser.getLocalStorage().getItem("prefs"));
		} catch( e : Dynamic ) {
		}

		initMenu();
		window.window.addEventListener("keydown", onKey);

		load(true);
	}
	
	function getDefault( c : Data.Column ) : Dynamic {
		if( c.opt )
			return null;
		return switch( c.type ) {
		case TInt, TFloat, TEnum(_): 0;
		case TString, TId, TRef(_): "";
		case TBool: false;
		}
	}
	
	function onKey( e : js.html.KeyboardEvent ) {
		// F1
		if( e.keyCode == 112 && sheet != null )
			newLine();
	}
	
	function changed( c : Data.Column ) {
		save();
		if( c.type == TId ) {
			makeSheet(sheet);
			refresh();
		}
	}
	
	function load(noError=false) {
		try {
			var sdata : Data.SavedData = haxe.Json.parse(sys.io.File.getContent(prefs.curFile));
			data = {
				sheets : [],
			};
			for( s in sdata.sheets ) {
				data.sheets.push({
					name : s.name,
					props : s.props,
					columns : haxe.Unserializer.run(s.schema),
					lines : sdata.lines.shift(),
				});
			}
		} catch( e : Dynamic ) {
			if( noError ) {
				prefs.curFile = null;
				prefs.curSheet = 0;
				data = {
					sheets : [],
				};
			}
		}
		makeSheets();
		initContent();
	}
	
	function save() {
		if( prefs.curFile == null )
			return;
		var data : Data.SavedData = {
			sheets : [],
			lines : [],
		};
		for( s in this.data.sheets ) {
			data.sheets.push({
				name : s.name,
				props : s.props,
				schema : haxe.Serializer.run(s.columns),
			});
			data.lines.push(s.lines);
		}
		sys.io.File.saveContent(prefs.curFile, untyped haxe.Json.stringify(data,null,"\t"));
	}
	
	function makeSheets() {
		smap = new Map();
		for( s in data.sheets )
			makeSheet(s);
	}
	
	function error( msg ) {
		js.Lib.alert(msg);
	}
	
	function makeSheet( s : Data.Sheet ) {
		var sdat = {
			s : s,
			ids : new Map(),
			all : [],
		};
		var cid = null;
		for( c in s.columns )
			if( c.type == TId ) {
				for( l in s.lines ) {
					var v = Reflect.field(l, c.name);
					if( v != null && v != "" ) {
						var disp = v;
						if( s.props.displayColumn != null ) {
							disp = Reflect.field(c.name, s.props.displayColumn);
							if( disp == null || disp == "" ) disp = "#"+v;
						}
						sdat.ids.set(v, disp);
						sdat.all.push( { id : v, disp:disp } );
					}
				}
				break;
			}
		this.smap.set(s.name, sdat);
	}
	
	function valueHtml( c : Data.Column, v : Dynamic ) : String {
		if( v == null ) {
			if( c.opt )
				return "&nbsp;";
			return '<span class="error">#NULL</span>';
		}
		return switch( c.type ) {
		case TInt, TFloat:
			v + "";
		case TId:
			v == "" ? '<span class="error">#MISSING</span>' : v;
		case TString:
			v == "" ? "&nbsp;" : StringTools.htmlEscape(v);
		case TRef(sname):
			if( v == "" )
				'<span class="error">#MISSING</span>';
			else {
				var s = smap.get(sname);
				var disp = s.ids.get(v);
				disp == null ? '<span class="error">#REF($v)</span>' : StringTools.htmlEscape(disp);
			}
		case TBool:
			v?"Y":"N";
		case TEnum(values):
			values[v];
		}
	}
	
	function refresh() {
		var s = sheet;
		var content = J("#content");
		if( s.columns.length == 0 ) {
			content.html("<a href='javascript:_.newColumn()'>Add a column</a>");
			return;
		}
		content.html("");
			
		var lines = [for( l in s.lines ) J("<tr>")];
		var cols = J("<tr>").addClass("head");
		var types = [for( t in Type.getEnumConstructs(Data.ColumnType) ) t.substr(1).toLowerCase()];
		for( c in s.columns ) {
			var col = J("<td>");
			col.html(c.name);
			col.css("width", c.size == null ? Std.int(100 / s.columns.length) + "%" : c.size + "%");
			col.dblclick(function(_) newColumn(c));
			cols.append(col);
			var ctype = "t_" + types[Type.enumIndex(c.type)];
			var ids = new Map<String,Int>();
			for( index in 0...s.lines.length ) {
				var obj = s.lines[index];
				var val : Dynamic = Reflect.field(obj,c.name);
				var v = J("<td>").addClass(ctype);
				v.appendTo(lines[index]);
				var html = valueHtml(c, val);
				if( c.type == TId && val != null && val != "" ) {
					if( ids.get(val) == null )
						ids.set(val, index);
					else
						html = '<span class="error">#DUP($val)</span>';
				}
				v.html(html);
				v.click(function() {
					if( v.hasClass("edit") ) return;
					function editDone() {
						v.html(html);
						v.removeClass("edit");
						v.removeClass("edit");
					}
					switch( c.type ) {
					case TInt, TFloat, TString, TId:
						v.html("");
						var i = J("<input>");
						v.addClass("edit");
						i.appendTo(v);
						if( val != null ) i.val(""+val);
						i.keydown(function(e:js.JQuery.JqEvent) {
							switch( e.keyCode ) {
							case 27:
								editDone();
							case 13:
								i.blur();
							case 46: // delete
								var val2 = getDefault(c);
								if( val2 != val ) {
									val = val2;
									if( val == null )
										Reflect.deleteField(obj, c.name);
									else
										Reflect.setField(obj, c.name, val);
								}
								html = valueHtml(c, val);
								changed(c);
								editDone();
							}
						});
						i.blur(function(_) {
							var nv = i.val();
							if( nv == "" && c.opt ) {
								if( val != null ) {
									val = html = null;
									Reflect.deleteField(obj, c.name);
									changed(c);
								}
							} else {
								var val2 : Dynamic = switch( c.type ) {
								case TInt:
									Std.parseInt(nv);
								case TFloat:
									var f = Std.parseFloat(nv);
									if( Math.isNaN(f) ) null else f;
								case TId:
									r_id.match(nv) ? nv : null;
								default:
									nv;
								}
								if( val2 != val && val2 != null ) {
									val = val2;
									html = valueHtml(c, val);
									Reflect.setField(obj, c.name, val);
									changed(c);
								}
							}
							editDone();
						});
						i.focus();
					case TEnum(values):
						v.html("");
						var s = J("<select>");
						v.addClass("edit");
						for( i in 0...values.length )
							J("<option>").attr("value", "" + i).attr(val == i ? "selected" : "_sel", "selected").text(values[i]).appendTo(s);
						if( c.opt )
							J("<option>").attr("value","-1").text("--- None ---").prependTo(s);
						v.append(s);
						s.change(function(_) {
							val = Std.parseInt(s.val());
							if( val < 0 )
								Reflect.deleteField(obj, c.name);
							else
								Reflect.setField(obj, c.name, val);
							html = valueHtml(c, val);
							changed(c);
							editDone();
						});
						s.blur(function(_) {
							editDone();
						});
						s.focus();
						var event : Dynamic = cast js.Browser.document.createEvent('MouseEvents');
						event.initMouseEvent('mousedown', true, true, js.Browser.window);
						s[0].dispatchEvent(event);
					case TRef(sname):
						var sdat = smap.get(sname);
						if( sdat == null ) return;

						v.html("");
						var s = J("<select>");
						v.addClass("edit");
						for( l in sdat.all )
							J("<option>").attr("value", "" + l.id).attr(val == l.id ? "selected" : "_sel", "selected").text(l.disp).appendTo(s);
						if( c.opt )
							J("<option>").attr("value", "").text("--- None ---").prependTo(s);
						v.append(s);
						s.change(function(_) {
							val = s.val();
							if( val == "" ) {
								val = null;
								Reflect.deleteField(obj, c.name);
							} else
								Reflect.setField(obj, c.name, val);
							html = valueHtml(c, val);
							changed(c);
							editDone();
						});
						s.blur(function(_) {
							editDone();
						});
						s.focus();
						var event : Dynamic = cast js.Browser.document.createEvent('MouseEvents');
						event.initMouseEvent('mousedown', true, true, js.Browser.window);
						s[0].dispatchEvent(event);
					case TBool:
						val = !val;
						Reflect.setField(obj, c.name, val);
						v.html(valueHtml(c, val));
						changed(c);
					}
				});
			}
		}
		content.html("");
		content.append(cols);
		for( l in lines )
			content.append(l);
	}
	
	function selectSheet( s : Data.Sheet ) {
		sheet = s;
		prefs.curSheet = Lambda.indexOf(data.sheets, s);
		J("#sheets li").removeClass("active").filter("#sheet_" + prefs.curSheet).addClass("active");
		refresh();
	}
	
	function newSheet() {
		J("#newsheet").show();
	}
	
	function newColumn( ?ref : Data.Column ) {
		var form = J("#newcol");
		
		var sheets = J("[name=sheet]");
		sheets.html("");
		for( i in 0...data.sheets.length )
			J("<option>").attr("value", "" + i).text(data.sheets[i].name).appendTo(sheets);
			
		if( ref != null ) {
			form.find("[name=name]").val(ref.name);
			form.find("[name=type]").val(ref.type.getName().substr(1).toLowerCase()).change();
			form.find("[name=opt]").attr("checked", cast ref.opt);
			form.find("[name=ref]").val(ref.name);
			form.find("input.create").val("Modify");
			switch( ref.type ) {
			case TEnum(values):
				form.find("[name=values]").val(values.join(","));
			case TRef(sname):
				form.find("[name=sheet]").val(sname);
			default:
			}
		} else {
			form.find("input").val("");
		}
		
		J("#newcol").show();
	}
	
	function newLine() {
		var o = {
		};
		for( c in sheet.columns ) {
			var d = getDefault(c);
			if( d != null )
				Reflect.setField(o, c.name, d);
		}
		sheet.lines.push(o);
		refresh();
	}
		
	function createSheet( name : String ) {
		name = StringTools.trim(name);
		if( name == "" )
			return;
		J("#newsheet").hide();
		var s = {
			name : name,
			columns : [],
			lines : [],
			props : {
				displayColumn : null,
			},
		};
		prefs.curSheet = data.sheets.length - 1;
		data.sheets.push(s);
		makeSheets();
		initContent();
		save();
	}
	
	function createColumn() {
		
		var v : Dynamic<String> = { };
		var cols = J("#col_form input, #col_form select").not("[type=submit]");
		for( i in cols )
			Reflect.setField(v, i.attr("name"), i.attr("type") == "checkbox" ? (i.is(":checked")?"on":null) : i.val());

		var refColumn = null;
		if( v.ref != "" ) {
			for( c in sheet.columns )
				if( c.name == v.ref )
					refColumn = c;
		}
	
		var t : Data.ColumnType = switch( v.type ) {
		case "id":
			if( refColumn == null )
				for( c in sheet.columns )
					if( c.type == TId ) {
						error("Only one ID allowed");
						return;
					}
			TId;
		case "int": TInt;
		case "float": TFloat;
		case "string": TString;
		case "bool": TBool;
		case "enum":
			var vals = StringTools.trim(v.values).split(",");
			if( vals.length == 0 ) {
				error("Missing value list");
				return;
			}
			TEnum([for( f in vals ) StringTools.trim(f)]);
		case "ref":
			var s = data.sheets[Std.parseInt(v.sheet)];
			if( s == null ) {
				error("Sheet not found");
				return;
			}
			TRef(s.name);
		default:
			return;
		}
		var c : Data.Column = {
			type : t,
			opt : v.opt == "on",
			name : v.name,
			size : null,
		};
		
		if( refColumn != null ) {
			// modify
			
			var old = refColumn;
			if( old.name != c.name ) {
				for( o in sheet.lines ) {
					var v = Reflect.field(o, old.name);
					Reflect.deleteField(o, old.name);
					if( v != null )
						Reflect.setField(o, c.name, v);
				}
				old.name = c.name;
			}
			
			if( !old.type.equals(c.type) ) {
				var conv : Dynamic -> Dynamic = null;
				switch( [old.type, c.type] ) {
				case [TInt, TFloat]:
					// nothing
				case [TId | TRef(_), TString]:
					// nothing
				case [TString, (TId | TRef(_))]:
					// nothing
				case [TBool, (TInt | TFloat)]:
					conv = function(b) return b ? 1 : 0;
				case [TString, TInt]:
					conv = Std.parseInt;
				case [TString, TFloat]:
					conv = Std.parseFloat;
				case [TString, TBool]:
					conv = function(s) return s != "";
				case [TString, TEnum(values)]:
					var map = new Map();
					for( i in 0...values.length )
						map.set(values[i].toLowerCase(), i);
					conv = function(s:String) return map.get(s.toLowerCase());
				case [TFloat, TInt]:
					conv = Std.int;
				case [(TInt | TFloat | TBool), TString]:
					conv = Std.string;
				case [(TFloat|TInt), TBool]:
					conv = function(v:Float) return v != 0;
				case [TEnum(values1), TEnum(values2)]:
					var map = [];
					for( v in values1 ) {
						var pos = Lambda.indexOf(values2, v);
						if( pos < 0 ) map.push(null) else map.push(pos);
					}
					conv = function(i) return map[i];
				case [TInt, TEnum(values)]:
					conv = function(i) return if( i < 0 || i >= values.length ) null else i;
				case [TEnum(values), TInt]:
					// nothing
				default:
					error("Cannot convert " + old.type.getName().substr(1) + " to " + c.type.getName().substr(1));
					return;
				}
				if( conv != null )
					for( o in sheet.lines ) {
						var v = Reflect.field(o, c.name);
						if( v != null ) {
							v = conv(v);
							if( v != null ) Reflect.setField(o, c.name, v) else Reflect.deleteField(o, c.name);
						}
					}
				old.type = c.type;
			}
			
			if( old.opt != c.opt ) {
				if( old.opt ) {
					for( o in sheet.lines ) {
						var v = Reflect.field(o, c.name);
						if( v == null ) {
							v = getDefault(c);
							if( v != null ) Reflect.setField(o, c.name, v);
						}
					}
				} else {
					switch( old.type ) {
					case TEnum(_):
						// first choice should not be removed
					default:
						var def = getDefault(old);
						for( o in sheet.lines ) {
							var v = Reflect.field(o, c.name);
							if( v == def )
								Reflect.deleteField(o, c.name);
						}
					}
				}
				old.opt = c.opt;
			}
			makeSheet(sheet);
				
		} else {
			// create
			for( c2 in sheet.columns )
				if( c2.name == c.name ) {
					error("Column already exists");
					return;
				}
			sheet.columns.push(c);
			for( i in sheet.lines ) {
				var def = getDefault(c);
				if( def != null ) Reflect.setField(i, c.name, def);
			}
		}
		
		J("#newcol").hide();
		for( c in cols )
			c.val("");
		refresh();
		save();
	}
	
	function initContent() {
		var sheets = J("ul#sheets");
		sheets.children().remove();
		for( i in 0...data.sheets.length ) {
			var s = data.sheets[i];
			J("<li>").text(s.name).attr("id", "sheet_" + i).appendTo(sheets).click(selectSheet.bind(s));
		}
		if( data.sheets.length == 0 ) {
			J("#content").html("<a href='javascript:_.newSheet()'>Create a sheet</a>");
			return;
		}
		var s = data.sheets[prefs.curSheet];
		if( s == null ) s = data.sheets[0];
		selectSheet(s);
	}

	function initMenu() {
		var menu = nw.Menu.createWindowMenu();
		var mfile = new nw.MenuItem({ label : "File" });
		var mnew = new nw.MenuItem( { label : "New" } );
		var mopen = new nw.MenuItem( { label : "Open..." } );
		var msave = new nw.MenuItem( { label : "Save As..." } );
		var mfiles = new nw.Menu();
		var mdebug = new nw.MenuItem( { label : "Dev" } );
		mnew.click = function() {
			data = {
				sheets : [],
			};
			prefs.curFile = null;
			initContent();
		};
		mdebug.click = function() window.showDevTools();
		mopen.click = function() {
			var i = J("<input>").attr("type", "file").css("display","none").change(function(e) {
				var j = JTHIS;
				prefs.curFile = j.val();
				load();
				j.remove();
			});
			i.appendTo(J("body"));
			i.click();
		};
		msave.click = function() {
			var i = J("<input>").attr("type", "file").attr("nwsaveas","new.cas").css("display","none").change(function(e) {
				var j = JTHIS;
				prefs.curFile = j.val();
				save();
				j.remove();
			});
			i.appendTo(J("body"));
			i.click();
		};
		mfiles.append(mnew);
		mfiles.append(mopen);
		mfiles.append(msave);
		mfile.submenu = mfiles;
		menu.append(mfile);
		menu.append(mdebug);
		window.menu = menu;
		window.moveTo(prefs.windowPos.x, prefs.windowPos.y);
		window.resizeTo(prefs.windowPos.w, prefs.windowPos.h);
		window.show();
		if( prefs.windowPos.max ) window.maximize();
		window.on('close', function() {
			if( !prefs.windowPos.max )
				prefs.windowPos = {
					x : window.x,
					y : window.y,
					w : window.width,
					h : window.height,
					max : false,
				};
			savePrefs();
			window.close(true);
		});
		window.on('maximize', function() {
			prefs.windowPos.max = true;
		});
		window.on('unmaximize', function() {
			prefs.windowPos.max = false;
		});
	}
	
	function savePrefs() {
		js.Browser.getLocalStorage().setItem("prefs", haxe.Serializer.run(prefs));
	}
	
	static function main() {
		var m = new Main();
		Reflect.setField(js.Browser.window, "_", m);
	}

}
