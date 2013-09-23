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
	var smap : Map<String, { s : Data.Sheet, ids : Map < String, String > } >;
	
	static var r_id = ~/^[A-Za-z_][A-Za-z_0-9]*$/;
	
	function new() {
		window = nw.Window.get();
		
		window.window.onerror = function(msg:String) {
			if( msg.indexOf("removeClass") > 0 )
				return false;
			window.show();
			window.showDevTools();
			return false;
		};
		
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
		case TStruct(_): { };
		case TList(_): [];
		case TBool: false;
		}
	}
	
	function onKey( e : js.html.KeyboardEvent ) {
		// F1
		if( e.keyCode == 112 && sheet != null )
			newLine();
	}
	
	function changed() {
		save();
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
		for( s in data.sheets ) {
			var sdat = {
				s : s,
				ids : new Map(),
			}
			smap.set(s.name, sdat);
		}
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
		case TStruct(_):
			"...";
		case TRef(sname):
			var s = smap.get(sname);
			var disp = s.ids.get(v);
			disp == null ? '<span class="error">#REF($v)</span>' : StringTools.htmlEscape(disp);
		case TBool:
			v?"Y":"N";
		case TList(t):
			var a : Array<Dynamic> = v;
			var out = [];
			var ct = { name : "", id : "", type : t, opt : false, size : null };
			for( v in a )
				out.push(valueHtml(ct, v));
			Std.string(out);
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
								changed();
								editDone();
							}
						});
						i.blur(function(_) {
							var nv = i.val();
							if( nv == "" && c.opt ) {
								if( val != null ) {
									val = html = null;
									Reflect.deleteField(obj, c.name);
									changed();
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
									if( c.type == TId && val != null && ids.get(val) == index ) ids.remove(val);
									val = val2;
									html = valueHtml(c, val);
									if( c.type == TId ) {
										if( ids.get(val) == null )
											ids.set(val, index);
										else
											html = '<span class="error">#DUP($val)</span>';
									}
									Reflect.setField(obj, c.name, val);
									changed();
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
							J("<option>").attr("value", "" + i).attr(val == i ? "selected" : "_sel","selected").text(values[i]).appendTo(s);
						v.append(s);
						s.change(function(_) {
							val = Std.parseInt(s.val());
							if( val < 0 )
								Reflect.deleteField(obj, c.name);
							else
								Reflect.setField(obj, c.name, val);
							html = valueHtml(c, val);
							changed();
							editDone();
						});
						s.blur(function(_) {
							editDone();
						});
						s.focus();
						var event : Dynamic = cast js.Browser.document.createEvent('MouseEvents');
						event.initMouseEvent('mousedown', true, true, js.Browser.window);
						s[0].dispatchEvent(event);
					case TRef(_):
					case TStruct(_):
					case TList(_):
					case TBool:
						val = !val;
						Reflect.setField(obj, c.name, val);
						v.html(valueHtml(c, val));
						changed();
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
	
	function newColumn() {
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
		var t : Data.ColumnType = switch( v.type ) {
		case "id":
			v.opt = "";
			v.list = "";
			TId;
		case "int": TInt;
		case "float": TFloat;
		case "string": TString;
		case "bool": TBool;
		case "enum":
			var vals = StringTools.trim(v.values).split(",");
			if( vals.length == 0 ) return;
			TEnum([for( f in vals ) StringTools.trim(f)]);
		case "ref":
			return;
		default:
			return;
		}
		if( v.list == "on" )
			t = TList(t);
		var c : Data.Column = {
			type : t,
			opt : v.opt == "on",
			id : v.name,
			name : v.name,
			size : null,
		};
		
		for( c2 in sheet.columns )
			if( c2.name == c.name )
				return;
		
		var isList = false, isStruct = null;
		var def : Dynamic = switch( t ) {
		case TId, TString: "";
		case TRef(sheet):
			var found = null;
			for( s in data.sheets )
				if( s.name == sheet && s.lines.length > 0 )
					found = Reflect.field(s.lines[0], s.columns[0].name);
			found;
		case TInt, TFloat, TEnum(_): 0;
		case TBool: false;
		case TList(_): isList = !c.opt; [];
		case TStruct(_): isStruct = !c.opt; {};
		};
		if( c.opt ) def = null;
		sheet.columns.push(c);
		if( def != null )
			for( i in sheet.lines ) {
				var def : Dynamic = def;
				if( isList ) def = [] else if( isStruct ) def = { };
				Reflect.setField(i, c.name, def);
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
