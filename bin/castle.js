(function () { "use strict";
var $hxClasses = {},$estr = function() { return js.Boot.__string_rec(this,''); };
var ColumnType = $hxClasses["ColumnType"] = { __ename__ : ["ColumnType"], __constructs__ : ["TId","TString","TBool","TInt","TFloat","TEnum","TRef","TList","TStruct"] }
ColumnType.TId = ["TId",0];
ColumnType.TId.toString = $estr;
ColumnType.TId.__enum__ = ColumnType;
ColumnType.TString = ["TString",1];
ColumnType.TString.toString = $estr;
ColumnType.TString.__enum__ = ColumnType;
ColumnType.TBool = ["TBool",2];
ColumnType.TBool.toString = $estr;
ColumnType.TBool.__enum__ = ColumnType;
ColumnType.TInt = ["TInt",3];
ColumnType.TInt.toString = $estr;
ColumnType.TInt.__enum__ = ColumnType;
ColumnType.TFloat = ["TFloat",4];
ColumnType.TFloat.toString = $estr;
ColumnType.TFloat.__enum__ = ColumnType;
ColumnType.TEnum = function(values) { var $x = ["TEnum",5,values]; $x.__enum__ = ColumnType; $x.toString = $estr; return $x; }
ColumnType.TRef = function(sheet) { var $x = ["TRef",6,sheet]; $x.__enum__ = ColumnType; $x.toString = $estr; return $x; }
ColumnType.TList = function(t) { var $x = ["TList",7,t]; $x.__enum__ = ColumnType; $x.toString = $estr; return $x; }
ColumnType.TStruct = function(a) { var $x = ["TStruct",8,a]; $x.__enum__ = ColumnType; $x.toString = $estr; return $x; }
var EReg = function(r,opt) {
	opt = opt.split("u").join("");
	this.r = new RegExp(r,opt);
};
$hxClasses["EReg"] = EReg;
EReg.__name__ = ["EReg"];
EReg.prototype = {
	match: function(s) {
		if(this.r.global) this.r.lastIndex = 0;
		this.r.m = this.r.exec(s);
		this.r.s = s;
		return this.r.m != null;
	}
	,__class__: EReg
}
var HxOverrides = function() { }
$hxClasses["HxOverrides"] = HxOverrides;
HxOverrides.__name__ = ["HxOverrides"];
HxOverrides.dateStr = function(date) {
	var m = date.getMonth() + 1;
	var d = date.getDate();
	var h = date.getHours();
	var mi = date.getMinutes();
	var s = date.getSeconds();
	return date.getFullYear() + "-" + (m < 10?"0" + m:"" + m) + "-" + (d < 10?"0" + d:"" + d) + " " + (h < 10?"0" + h:"" + h) + ":" + (mi < 10?"0" + mi:"" + mi) + ":" + (s < 10?"0" + s:"" + s);
}
HxOverrides.strDate = function(s) {
	var _g = s.length;
	switch(_g) {
	case 8:
		var k = s.split(":");
		var d = new Date();
		d.setTime(0);
		d.setUTCHours(k[0]);
		d.setUTCMinutes(k[1]);
		d.setUTCSeconds(k[2]);
		return d;
	case 10:
		var k = s.split("-");
		return new Date(k[0],k[1] - 1,k[2],0,0,0);
	case 19:
		var k = s.split(" ");
		var y = k[0].split("-");
		var t = k[1].split(":");
		return new Date(y[0],y[1] - 1,y[2],t[0],t[1],t[2]);
	default:
		throw "Invalid date format : " + s;
	}
}
HxOverrides.cca = function(s,index) {
	var x = s.charCodeAt(index);
	if(x != x) return undefined;
	return x;
}
HxOverrides.substr = function(s,pos,len) {
	if(pos != null && pos != 0 && len != null && len < 0) return "";
	if(len == null) len = s.length;
	if(pos < 0) {
		pos = s.length + pos;
		if(pos < 0) pos = 0;
	} else if(len < 0) len = s.length + len - pos;
	return s.substr(pos,len);
}
HxOverrides.iter = function(a) {
	return { cur : 0, arr : a, hasNext : function() {
		return this.cur < this.arr.length;
	}, next : function() {
		return this.arr[this.cur++];
	}};
}
var Lambda = function() { }
$hxClasses["Lambda"] = Lambda;
Lambda.__name__ = ["Lambda"];
Lambda.indexOf = function(it,v) {
	var i = 0;
	var $it0 = $iterator(it)();
	while( $it0.hasNext() ) {
		var v2 = $it0.next();
		if(v == v2) return i;
		i++;
	}
	return -1;
}
var List = function() {
	this.length = 0;
};
$hxClasses["List"] = List;
List.__name__ = ["List"];
List.prototype = {
	iterator: function() {
		return { h : this.h, hasNext : function() {
			return this.h != null;
		}, next : function() {
			if(this.h == null) return null;
			var x = this.h[0];
			this.h = this.h[1];
			return x;
		}};
	}
	,add: function(item) {
		var x = [item];
		if(this.h == null) this.h = x; else this.q[1] = x;
		this.q = x;
		this.length++;
	}
	,__class__: List
}
var Main = function() {
	var _g = this;
	this["window"] = nw.Window.get();
	this["window"]["window"].onerror = function(msg) {
		if(msg.indexOf("removeClass") > 0) return false;
		_g["window"].show();
		_g["window"].showDevTools();
		return false;
	};
	this.prefs = { windowPos : { x : 50, y : 50, w : 800, h : 600, max : false}, curFile : null, curSheet : 0};
	try {
		this.prefs = haxe.Unserializer.run(js.Browser.getLocalStorage().getItem("prefs"));
	} catch( e ) {
	}
	this.initMenu();
	this["window"]["window"].addEventListener("keydown",$bind(this,this.onKey));
	this.load(true);
};
$hxClasses["Main"] = Main;
Main.__name__ = ["Main"];
Main.main = function() {
	var m = new Main();
	var o = window;
	o._ = m;
}
Main.prototype = {
	savePrefs: function() {
		js.Browser.getLocalStorage().setItem("prefs",haxe.Serializer.run(this.prefs));
	}
	,initMenu: function() {
		var _g = this;
		var menu = new nw.Menu({ type : "menubar"});
		var mfile = new nw.MenuItem({ label : "File"});
		var mnew = new nw.MenuItem({ label : "New"});
		var mopen = new nw.MenuItem({ label : "Open..."});
		var msave = new nw.MenuItem({ label : "Save As..."});
		var mfiles = new nw.Menu();
		var mdebug = new nw.MenuItem({ label : "Dev"});
		mnew.click = function() {
			_g.data = { sheets : []};
			_g.prefs.curFile = null;
			_g.initContent();
		};
		mdebug.click = function() {
			_g["window"].showDevTools();
		};
		mopen.click = function() {
			var i = new js.JQuery("<input>").attr("type","file").css("display","none").change(function(e) {
				var j = $(this);
				_g.prefs.curFile = j.val();
				_g.load();
				j.remove();
			});
			i.appendTo(new js.JQuery("body"));
			i.click();
		};
		msave.click = function() {
			var i = new js.JQuery("<input>").attr("type","file").attr("nwsaveas","new.cas").css("display","none").change(function(e) {
				var j = $(this);
				_g.prefs.curFile = j.val();
				_g.save();
				j.remove();
			});
			i.appendTo(new js.JQuery("body"));
			i.click();
		};
		mfiles.append(mnew);
		mfiles.append(mopen);
		mfiles.append(msave);
		mfile.submenu = mfiles;
		menu.append(mfile);
		menu.append(mdebug);
		this["window"].menu = menu;
		this["window"].moveTo(this.prefs.windowPos.x,this.prefs.windowPos.y);
		this["window"].resizeTo(this.prefs.windowPos.w,this.prefs.windowPos.h);
		this["window"].show();
		if(this.prefs.windowPos.max) this["window"].maximize();
		this["window"].on("close",function() {
			if(!_g.prefs.windowPos.max) _g.prefs.windowPos = { x : _g["window"].x, y : _g["window"].y, w : _g["window"].width, h : _g["window"].height, max : false};
			_g.savePrefs();
			_g["window"].close(true);
		});
		this["window"].on("maximize",function() {
			_g.prefs.windowPos.max = true;
		});
		this["window"].on("unmaximize",function() {
			_g.prefs.windowPos.max = false;
		});
	}
	,initContent: function() {
		var sheets = new js.JQuery("ul#sheets");
		sheets.children().remove();
		var _g1 = 0;
		var _g = this.data.sheets.length;
		while(_g1 < _g) {
			var i = _g1++;
			var s = this.data.sheets[i];
			new js.JQuery("<li>").text(s.name).attr("id","sheet_" + i).appendTo(sheets).click((function($this) {
				var $r;
				var f = [$bind($this,$this.selectSheet)], s1 = [s];
				$r = (function(s1,f) {
					return function() {
						return f[0](s1[0]);
					};
				})(s1,f);
				return $r;
			}(this)));
		}
		if(this.data.sheets.length == 0) {
			new js.JQuery("#content").html("<a href='javascript:_.newSheet()'>Create a sheet</a>");
			return;
		}
		var s = this.data.sheets[this.prefs.curSheet];
		if(s == null) s = this.data.sheets[0];
		this.selectSheet(s);
	}
	,createColumn: function() {
		var v = { };
		var cols = new js.JQuery("#col_form input, #col_form select").not("[type=submit]");
		var $it0 = (cols.iterator)();
		while( $it0.hasNext() ) {
			var i = $it0.next();
			var field = i.attr("name");
			var value;
			if(i.attr("type") == "checkbox") {
				if(i["is"](":checked")) value = "on"; else value = null;
			} else value = i.val();
			v[field] = value;
		}
		var t;
		var _g = v.type;
		switch(_g) {
		case "id":
			v.opt = "";
			v.list = "";
			t = ColumnType.TId;
			break;
		case "int":
			t = ColumnType.TInt;
			break;
		case "float":
			t = ColumnType.TFloat;
			break;
		case "string":
			t = ColumnType.TString;
			break;
		case "bool":
			t = ColumnType.TBool;
			break;
		case "enum":
			var vals = StringTools.trim(v.values).split(",");
			if(vals.length == 0) return;
			t = ColumnType.TEnum((function($this) {
				var $r;
				var _g1 = [];
				{
					var _g2 = 0;
					while(_g2 < vals.length) {
						var f = vals[_g2];
						++_g2;
						_g1.push(StringTools.trim(f));
					}
				}
				$r = _g1;
				return $r;
			}(this)));
			break;
		case "ref":
			return;
		default:
			return;
		}
		if(v.list == "on") t = ColumnType.TList(t);
		var c = { type : t, opt : v.opt == "on", id : v.name, name : v.name, size : null};
		var _g1 = 0;
		var _g2 = this.sheet.columns;
		while(_g1 < _g2.length) {
			var c2 = _g2[_g1];
			++_g1;
			if(c2.name == c.name) return;
		}
		var isList = false;
		var isStruct = null;
		var def;
		switch(t[1]) {
		case 0:case 1:
			def = "";
			break;
		case 6:
			var sheet = t[2];
			var found = null;
			var _g1 = 0;
			var _g2 = this.data.sheets;
			while(_g1 < _g2.length) {
				var s = _g2[_g1];
				++_g1;
				if(s.name == sheet && s.lines.length > 0) {
					var v1 = null;
					try {
						v1 = s.lines[0][s.columns[0].name];
					} catch( e ) {
					}
					found = v1;
				}
			}
			def = found;
			break;
		case 3:case 4:case 5:
			def = 0;
			break;
		case 2:
			def = false;
			break;
		case 7:
			isList = !c.opt;
			def = [];
			break;
		case 8:
			isStruct = !c.opt;
			def = { };
			break;
		}
		if(c.opt) def = null;
		this.sheet.columns.push(c);
		if(def != null) {
			var _g1 = 0;
			var _g2 = this.sheet.lines;
			while(_g1 < _g2.length) {
				var i = _g2[_g1];
				++_g1;
				var def1 = def;
				if(isList) def1 = []; else if(isStruct) def1 = { };
				i[c.name] = def1;
			}
		}
		new js.JQuery("#newcol").hide();
		var $it1 = (cols.iterator)();
		while( $it1.hasNext() ) {
			var c1 = $it1.next();
			c1.val("");
		}
		this.refresh();
		this.save();
	}
	,createSheet: function(name) {
		name = StringTools.trim(name);
		if(name == "") return;
		new js.JQuery("#newsheet").hide();
		var s = { name : name, columns : [], lines : [], props : { displayColumn : null}};
		this.prefs.curSheet = this.data.sheets.length - 1;
		this.data.sheets.push(s);
		this.makeSheets();
		this.initContent();
		this.save();
	}
	,newLine: function() {
		var o = { };
		var _g = 0;
		var _g1 = this.sheet.columns;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			var d = this.getDefault(c);
			if(d != null) o[c.name] = d;
		}
		this.sheet.lines.push(o);
		this.refresh();
	}
	,newColumn: function() {
		new js.JQuery("#newcol").show();
	}
	,newSheet: function() {
		new js.JQuery("#newsheet").show();
	}
	,selectSheet: function(s) {
		this.sheet = s;
		this.prefs.curSheet = Lambda.indexOf(this.data.sheets,s);
		new js.JQuery("#sheets li").removeClass("active").filter("#sheet_" + this.prefs.curSheet).addClass("active");
		this.refresh();
	}
	,refresh: function() {
		var _g8 = this;
		var s = this.sheet;
		var content = new js.JQuery("#content");
		if(s.columns.length == 0) {
			content.html("<a href='javascript:_.newColumn()'>Add a column</a>");
			return;
		}
		content.html("");
		var lines;
		var _g = [];
		var _g1 = 0;
		var _g2 = s.lines;
		while(_g1 < _g2.length) {
			var l = _g2[_g1];
			++_g1;
			_g.push(new js.JQuery("<tr>"));
		}
		lines = _g;
		var cols = new js.JQuery("<tr>").addClass("head");
		var types;
		var _g1 = [];
		var _g2 = 0;
		var _g3 = Type.getEnumConstructs(ColumnType);
		while(_g2 < _g3.length) {
			var t = _g3[_g2];
			++_g2;
			_g1.push(HxOverrides.substr(t,1,null).toLowerCase());
		}
		types = _g1;
		var _g2 = 0;
		var _g3 = s.columns;
		while(_g2 < _g3.length) {
			var c = [_g3[_g2]];
			++_g2;
			var col = new js.JQuery("<td>");
			col.html(c[0].name);
			col.css("width",c[0].size == null?(100 / s.columns.length | 0) + "%":c[0].size + "%");
			cols.append(col);
			var ctype = "t_" + types[c[0].type[1]];
			var ids = [new haxe.ds.StringMap()];
			var _g5 = 0;
			var _g4 = s.lines.length;
			while(_g5 < _g4) {
				var index = [_g5++];
				var obj = [s.lines[index[0]]];
				var val = [(function($this) {
					var $r;
					var v = null;
					try {
						v = obj[0][c[0].name];
					} catch( e ) {
					}
					$r = v;
					return $r;
				}(this))];
				var v1 = [new js.JQuery("<td>").addClass(ctype)];
				v1[0].appendTo(lines[index[0]]);
				var html = [this.valueHtml(c[0],val[0])];
				if(c[0].type == ColumnType.TId && val[0] != null && val[0] != "") {
					if((function($this) {
						var $r;
						var key = val[0];
						$r = ids[0].get(key);
						return $r;
					}(this)) == null) {
						var key = val[0];
						ids[0].set(key,index[0]);
					} else html[0] = "<span class=\"error\">#DUP(" + Std.string(val[0]) + ")</span>";
				}
				v1[0].html(html[0]);
				v1[0].click((function(html,v1,val,obj,index,ids,c) {
					return function() {
						if(v1[0].hasClass("edit")) return;
						var editDone = (function(html,v1) {
							return function() {
								v1[0].html(html[0]);
								v1[0].removeClass("edit");
								v1[0].removeClass("edit");
							};
						})(html,v1);
						{
							var _g6 = c[0].type;
							switch(_g6[1]) {
							case 3:case 4:case 1:case 0:
								v1[0].html("");
								var i = new js.JQuery("<input>");
								v1[0].addClass("edit");
								i.appendTo(v1[0]);
								if(val[0] != null) i.val("" + Std.string(val[0]));
								i.keydown((function(html,val,obj,c) {
									return function(e) {
										var _g7 = e.keyCode;
										switch(_g7) {
										case 27:
											editDone();
											break;
										case 13:
											i.blur();
											break;
										case 46:
											var val2 = _g8.getDefault(c[0]);
											if(val2 != val[0]) {
												val[0] = val2;
												if(val[0] == null) Reflect.deleteField(obj[0],c[0].name); else obj[0][c[0].name] = val[0];
											}
											html[0] = _g8.valueHtml(c[0],val[0]);
											_g8.changed();
											editDone();
											break;
										}
									};
								})(html,val,obj,c));
								i.blur((function(html,val,obj,index,ids,c) {
									return function(_) {
										var nv = i.val();
										if(nv == "" && c[0].opt) {
											if(val[0] != null) {
												val[0] = html[0] = null;
												Reflect.deleteField(obj[0],c[0].name);
												_g8.changed();
											}
										} else {
											var val2;
											var _g7 = c[0].type;
											switch(_g7[1]) {
											case 3:
												val2 = Std.parseInt(nv);
												break;
											case 4:
												var f = Std.parseFloat(nv);
												if(Math.isNaN(f)) val2 = null; else val2 = f;
												break;
											case 0:
												if(Main.r_id.match(nv)) val2 = nv; else val2 = null;
												break;
											default:
												val2 = nv;
											}
											if(val2 != val[0] && val2 != null) {
												if(c[0].type == ColumnType.TId && val[0] != null && (function($this) {
													var $r;
													var key = val[0];
													$r = ids[0].get(key);
													return $r;
												}(this)) == index[0]) {
													var key = val[0];
													ids[0].remove(key);
												}
												val[0] = val2;
												html[0] = _g8.valueHtml(c[0],val[0]);
												if(c[0].type == ColumnType.TId) {
													if((function($this) {
														var $r;
														var key = val[0];
														$r = ids[0].get(key);
														return $r;
													}(this)) == null) {
														var key = val[0];
														ids[0].set(key,index[0]);
													} else html[0] = "<span class=\"error\">#DUP(" + Std.string(val[0]) + ")</span>";
												}
												obj[0][c[0].name] = val[0];
												_g8.changed();
											}
										}
										editDone();
									};
								})(html,val,obj,index,ids,c));
								i.focus();
								break;
							case 5:
								var values = _g6[2];
								v1[0].html("");
								var s1 = new js.JQuery("<select>");
								v1[0].addClass("edit");
								var _g81 = 0;
								var _g7 = values.length;
								while(_g81 < _g7) {
									var i = _g81++;
									new js.JQuery("<option>").attr("value","" + i).attr(val[0] == i?"selected":"_sel","selected").text(values[i]).appendTo(s1);
								}
								v1[0].append(s1);
								s1.change((function(html,val,obj,c) {
									return function(_) {
										val[0] = Std.parseInt(s1.val());
										if(val[0] < 0) Reflect.deleteField(obj[0],c[0].name); else obj[0][c[0].name] = val[0];
										html[0] = _g8.valueHtml(c[0],val[0]);
										_g8.changed();
										editDone();
									};
								})(html,val,obj,c));
								s1.blur((function() {
									return function(_) {
										editDone();
									};
								})());
								s1.focus();
								var event = window.document.createEvent("MouseEvents");
								event.initMouseEvent("mousedown",true,true,window);
								s1[0].dispatchEvent(event);
								break;
							case 6:
								break;
							case 8:
								break;
							case 7:
								break;
							case 2:
								val[0] = !val[0];
								obj[0][c[0].name] = val[0];
								v1[0].html(_g8.valueHtml(c[0],val[0]));
								_g8.changed();
								break;
							}
						}
					};
				})(html,v1,val,obj,index,ids,c));
			}
		}
		content.html("");
		content.append(cols);
		var _g2 = 0;
		while(_g2 < lines.length) {
			var l = lines[_g2];
			++_g2;
			content.append(l);
		}
	}
	,valueHtml: function(c,v) {
		if(v == null) {
			if(c.opt) return "&nbsp;";
			return "<span class=\"error\">#NULL</span>";
		}
		{
			var _g = c.type;
			switch(_g[1]) {
			case 3:case 4:
				return Std.string(v) + "";
			case 0:
				if(v == "") return "<span class=\"error\">#MISSING</span>"; else return v;
				break;
			case 1:
				if(v == "") return "&nbsp;"; else return StringTools.htmlEscape(v);
				break;
			case 8:
				return "...";
			case 6:
				var sname = _g[2];
				var s = this.smap.get(sname);
				var disp;
				var key = v;
				disp = s.ids.get(key);
				if(disp == null) return "<span class=\"error\">#REF(" + Std.string(v) + ")</span>"; else return StringTools.htmlEscape(disp);
				break;
			case 2:
				if(v) return "Y"; else return "N";
				break;
			case 7:
				var t = _g[2];
				var a = v;
				var out = [];
				var ct = { name : "", id : "", type : t, opt : false, size : null};
				var _g1 = 0;
				while(_g1 < a.length) {
					var v1 = a[_g1];
					++_g1;
					out.push(this.valueHtml(ct,v1));
				}
				return Std.string(out);
			case 5:
				var values = _g[2];
				return values[v];
			}
		}
	}
	,makeSheets: function() {
		this.smap = new haxe.ds.StringMap();
		var _g = 0;
		var _g1 = this.data.sheets;
		while(_g < _g1.length) {
			var s = _g1[_g];
			++_g;
			var sdat = { s : s, ids : new haxe.ds.StringMap()};
			this.smap.set(s.name,sdat);
		}
	}
	,save: function() {
		if(this.prefs.curFile == null) return;
		var data = { sheets : [], lines : []};
		var _g = 0;
		var _g1 = this.data.sheets;
		while(_g < _g1.length) {
			var s = _g1[_g];
			++_g;
			data.sheets.push({ name : s.name, props : s.props, schema : haxe.Serializer.run(s.columns)});
			data.lines.push(s.lines);
		}
		sys.io.File.saveContent(this.prefs.curFile,js.Node.stringify(data,null,"\t"));
	}
	,load: function(noError) {
		if(noError == null) noError = false;
		try {
			var sdata;
			var jsonString = sys.io.File.getContent(this.prefs.curFile);
			sdata = js.Node.parse(jsonString);
			this.data = { sheets : []};
			var _g = 0;
			var _g1 = sdata.sheets;
			while(_g < _g1.length) {
				var s = _g1[_g];
				++_g;
				this.data.sheets.push({ name : s.name, props : s.props, columns : haxe.Unserializer.run(s.schema), lines : sdata.lines.shift()});
			}
		} catch( e ) {
			if(noError) {
				this.prefs.curFile = null;
				this.prefs.curSheet = 0;
				this.data = { sheets : []};
			}
		}
		this.makeSheets();
		this.initContent();
	}
	,changed: function() {
		this.save();
	}
	,onKey: function(e) {
		if(e.keyCode == 112 && this.sheet != null) this.newLine();
	}
	,getDefault: function(c) {
		if(c.opt) return null;
		{
			var _g = c.type;
			switch(_g[1]) {
			case 3:case 4:case 5:
				return 0;
			case 1:case 0:case 6:
				return "";
			case 8:
				return { };
			case 7:
				return [];
			case 2:
				return false;
			}
		}
	}
	,__class__: Main
}
var IMap = function() { }
$hxClasses["IMap"] = IMap;
IMap.__name__ = ["IMap"];
var Reflect = function() { }
$hxClasses["Reflect"] = Reflect;
Reflect.__name__ = ["Reflect"];
Reflect.hasField = function(o,field) {
	return Object.prototype.hasOwnProperty.call(o,field);
}
Reflect.fields = function(o) {
	var a = [];
	if(o != null) {
		var hasOwnProperty = Object.prototype.hasOwnProperty;
		for( var f in o ) {
		if(f != "__id__" && f != "hx__closures__" && hasOwnProperty.call(o,f)) a.push(f);
		}
	}
	return a;
}
Reflect.isFunction = function(f) {
	return typeof(f) == "function" && !(f.__name__ || f.__ename__);
}
Reflect.deleteField = function(o,field) {
	if(!Reflect.hasField(o,field)) return false;
	delete(o[field]);
	return true;
}
var Std = function() { }
$hxClasses["Std"] = Std;
Std.__name__ = ["Std"];
Std.string = function(s) {
	return js.Boot.__string_rec(s,"");
}
Std.parseInt = function(x) {
	var v = parseInt(x,10);
	if(v == 0 && (HxOverrides.cca(x,1) == 120 || HxOverrides.cca(x,1) == 88)) v = parseInt(x);
	if(isNaN(v)) return null;
	return v;
}
Std.parseFloat = function(x) {
	return parseFloat(x);
}
var StringBuf = function() {
	this.b = "";
};
$hxClasses["StringBuf"] = StringBuf;
StringBuf.__name__ = ["StringBuf"];
StringBuf.prototype = {
	__class__: StringBuf
}
var StringTools = function() { }
$hxClasses["StringTools"] = StringTools;
StringTools.__name__ = ["StringTools"];
StringTools.urlEncode = function(s) {
	return encodeURIComponent(s);
}
StringTools.urlDecode = function(s) {
	return decodeURIComponent(s.split("+").join(" "));
}
StringTools.htmlEscape = function(s,quotes) {
	s = s.split("&").join("&amp;").split("<").join("&lt;").split(">").join("&gt;");
	if(quotes) return s.split("\"").join("&quot;").split("'").join("&#039;"); else return s;
}
StringTools.isSpace = function(s,pos) {
	var c = HxOverrides.cca(s,pos);
	return c > 8 && c < 14 || c == 32;
}
StringTools.ltrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,r)) r++;
	if(r > 0) return HxOverrides.substr(s,r,l - r); else return s;
}
StringTools.rtrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,l - r - 1)) r++;
	if(r > 0) return HxOverrides.substr(s,0,l - r); else return s;
}
StringTools.trim = function(s) {
	return StringTools.ltrim(StringTools.rtrim(s));
}
var ValueType = $hxClasses["ValueType"] = { __ename__ : ["ValueType"], __constructs__ : ["TNull","TInt","TFloat","TBool","TObject","TFunction","TClass","TEnum","TUnknown"] }
ValueType.TNull = ["TNull",0];
ValueType.TNull.toString = $estr;
ValueType.TNull.__enum__ = ValueType;
ValueType.TInt = ["TInt",1];
ValueType.TInt.toString = $estr;
ValueType.TInt.__enum__ = ValueType;
ValueType.TFloat = ["TFloat",2];
ValueType.TFloat.toString = $estr;
ValueType.TFloat.__enum__ = ValueType;
ValueType.TBool = ["TBool",3];
ValueType.TBool.toString = $estr;
ValueType.TBool.__enum__ = ValueType;
ValueType.TObject = ["TObject",4];
ValueType.TObject.toString = $estr;
ValueType.TObject.__enum__ = ValueType;
ValueType.TFunction = ["TFunction",5];
ValueType.TFunction.toString = $estr;
ValueType.TFunction.__enum__ = ValueType;
ValueType.TClass = function(c) { var $x = ["TClass",6,c]; $x.__enum__ = ValueType; $x.toString = $estr; return $x; }
ValueType.TEnum = function(e) { var $x = ["TEnum",7,e]; $x.__enum__ = ValueType; $x.toString = $estr; return $x; }
ValueType.TUnknown = ["TUnknown",8];
ValueType.TUnknown.toString = $estr;
ValueType.TUnknown.__enum__ = ValueType;
var Type = function() { }
$hxClasses["Type"] = Type;
Type.__name__ = ["Type"];
Type.getClassName = function(c) {
	var a = c.__name__;
	return a.join(".");
}
Type.getEnumName = function(e) {
	var a = e.__ename__;
	return a.join(".");
}
Type.resolveClass = function(name) {
	var cl = $hxClasses[name];
	if(cl == null || !cl.__name__) return null;
	return cl;
}
Type.resolveEnum = function(name) {
	var e = $hxClasses[name];
	if(e == null || !e.__ename__) return null;
	return e;
}
Type.createEmptyInstance = function(cl) {
	function empty() {}; empty.prototype = cl.prototype;
	return new empty();
}
Type.createEnum = function(e,constr,params) {
	var f = (function($this) {
		var $r;
		var v = null;
		try {
			v = e[constr];
		} catch( e1 ) {
		}
		$r = v;
		return $r;
	}(this));
	if(f == null) throw "No such constructor " + constr;
	if(Reflect.isFunction(f)) {
		if(params == null) throw "Constructor " + constr + " need parameters";
		return f.apply(e,params);
	}
	if(params != null && params.length != 0) throw "Constructor " + constr + " does not need parameters";
	return f;
}
Type.getEnumConstructs = function(e) {
	var a = e.__constructs__;
	return a.slice();
}
Type["typeof"] = function(v) {
	var _g = typeof(v);
	switch(_g) {
	case "boolean":
		return ValueType.TBool;
	case "string":
		return ValueType.TClass(String);
	case "number":
		if(Math.ceil(v) == v % 2147483648.0) return ValueType.TInt;
		return ValueType.TFloat;
	case "object":
		if(v == null) return ValueType.TNull;
		var e = v.__enum__;
		if(e != null) return ValueType.TEnum(e);
		var c = v.__class__;
		if(c != null) return ValueType.TClass(c);
		return ValueType.TObject;
	case "function":
		if(v.__name__ || v.__ename__) return ValueType.TObject;
		return ValueType.TFunction;
	case "undefined":
		return ValueType.TNull;
	default:
		return ValueType.TUnknown;
	}
}
var haxe = {}
haxe.Json = function() { }
$hxClasses["haxe.Json"] = haxe.Json;
haxe.Json.__name__ = ["haxe","Json"];
haxe.Json.stringify = function(obj,replacer,insertion) {
	return js.Node.stringify(obj,replacer,insertion);
}
haxe.Json.parse = function(jsonString) {
	return js.Node.parse(jsonString);
}
haxe.Serializer = function() {
	this.buf = new StringBuf();
	this.cache = new Array();
	this.useCache = haxe.Serializer.USE_CACHE;
	this.useEnumIndex = haxe.Serializer.USE_ENUM_INDEX;
	this.shash = new haxe.ds.StringMap();
	this.scount = 0;
};
$hxClasses["haxe.Serializer"] = haxe.Serializer;
haxe.Serializer.__name__ = ["haxe","Serializer"];
haxe.Serializer.run = function(v) {
	var s = new haxe.Serializer();
	s.serialize(v);
	return s.toString();
}
haxe.Serializer.prototype = {
	serialize: function(v) {
		{
			var _g = Type["typeof"](v);
			switch(_g[1]) {
			case 0:
				this.buf.b += "n";
				break;
			case 1:
				if(v == 0) {
					this.buf.b += "z";
					return;
				}
				this.buf.b += "i";
				this.buf.b += Std.string(v);
				break;
			case 2:
				if(Math.isNaN(v)) this.buf.b += "k"; else if(!Math.isFinite(v)) this.buf.b += Std.string(v < 0?"m":"p"); else {
					this.buf.b += "d";
					this.buf.b += Std.string(v);
				}
				break;
			case 3:
				this.buf.b += Std.string(v?"t":"f");
				break;
			case 6:
				var c = _g[2];
				if(c == String) {
					this.serializeString(v);
					return;
				}
				if(this.useCache && this.serializeRef(v)) return;
				switch(c) {
				case Array:
					var ucount = 0;
					this.buf.b += "a";
					var l = v.length;
					var _g1 = 0;
					while(_g1 < l) {
						var i = _g1++;
						if(v[i] == null) ucount++; else {
							if(ucount > 0) {
								if(ucount == 1) this.buf.b += "n"; else {
									this.buf.b += "u";
									this.buf.b += Std.string(ucount);
								}
								ucount = 0;
							}
							this.serialize(v[i]);
						}
					}
					if(ucount > 0) {
						if(ucount == 1) this.buf.b += "n"; else {
							this.buf.b += "u";
							this.buf.b += Std.string(ucount);
						}
					}
					this.buf.b += "h";
					break;
				case List:
					this.buf.b += "l";
					var v1 = v;
					var $it0 = v1.iterator();
					while( $it0.hasNext() ) {
						var i = $it0.next();
						this.serialize(i);
					}
					this.buf.b += "h";
					break;
				case Date:
					var d = v;
					this.buf.b += "v";
					var x = HxOverrides.dateStr(d);
					this.buf.b += Std.string(x);
					break;
				case haxe.ds.StringMap:
					this.buf.b += "b";
					var v1 = v;
					var $it1 = v1.keys();
					while( $it1.hasNext() ) {
						var k = $it1.next();
						this.serializeString(k);
						this.serialize(v1.get(k));
					}
					this.buf.b += "h";
					break;
				case haxe.ds.IntMap:
					this.buf.b += "q";
					var v1 = v;
					var $it2 = v1.keys();
					while( $it2.hasNext() ) {
						var k = $it2.next();
						this.buf.b += ":";
						this.buf.b += Std.string(k);
						this.serialize(v1.get(k));
					}
					this.buf.b += "h";
					break;
				case haxe.ds.ObjectMap:
					this.buf.b += "M";
					var v1 = v;
					var $it3 = v1.keys();
					while( $it3.hasNext() ) {
						var k = $it3.next();
						var id = (function($this) {
							var $r;
							var v2 = null;
							try {
								v2 = k.__id__;
							} catch( e ) {
							}
							$r = v2;
							return $r;
						}(this));
						Reflect.deleteField(k,"__id__");
						this.serialize(k);
						k.__id__ = id;
						this.serialize(v1.h[k.__id__]);
					}
					this.buf.b += "h";
					break;
				case haxe.io.Bytes:
					var v1 = v;
					var i = 0;
					var max = v1.length - 2;
					var charsBuf = new StringBuf();
					var b64 = haxe.Serializer.BASE64;
					while(i < max) {
						var b1;
						var pos = i++;
						b1 = v1.b[pos];
						var b2;
						var pos = i++;
						b2 = v1.b[pos];
						var b3;
						var pos = i++;
						b3 = v1.b[pos];
						var x = b64.charAt(b1 >> 2);
						charsBuf.b += Std.string(x);
						var x = b64.charAt((b1 << 4 | b2 >> 4) & 63);
						charsBuf.b += Std.string(x);
						var x = b64.charAt((b2 << 2 | b3 >> 6) & 63);
						charsBuf.b += Std.string(x);
						var x = b64.charAt(b3 & 63);
						charsBuf.b += Std.string(x);
					}
					if(i == max) {
						var b1;
						var pos = i++;
						b1 = v1.b[pos];
						var b2;
						var pos = i++;
						b2 = v1.b[pos];
						var x = b64.charAt(b1 >> 2);
						charsBuf.b += Std.string(x);
						var x = b64.charAt((b1 << 4 | b2 >> 4) & 63);
						charsBuf.b += Std.string(x);
						var x = b64.charAt(b2 << 2 & 63);
						charsBuf.b += Std.string(x);
					} else if(i == max + 1) {
						var b1;
						var pos = i++;
						b1 = v1.b[pos];
						var x = b64.charAt(b1 >> 2);
						charsBuf.b += Std.string(x);
						var x = b64.charAt(b1 << 4 & 63);
						charsBuf.b += Std.string(x);
					}
					var chars = charsBuf.b;
					this.buf.b += "s";
					this.buf.b += Std.string(chars.length);
					this.buf.b += ":";
					this.buf.b += Std.string(chars);
					break;
				default:
					this.cache.pop();
					if(v.hxSerialize != null) {
						this.buf.b += "C";
						this.serializeString(Type.getClassName(c));
						this.cache.push(v);
						v.hxSerialize(this);
						this.buf.b += "g";
					} else {
						this.buf.b += "c";
						this.serializeString(Type.getClassName(c));
						this.cache.push(v);
						this.serializeFields(v);
					}
				}
				break;
			case 4:
				if(this.useCache && this.serializeRef(v)) return;
				this.buf.b += "o";
				this.serializeFields(v);
				break;
			case 7:
				var e = _g[2];
				if(this.useCache && this.serializeRef(v)) return;
				this.cache.pop();
				this.buf.b += Std.string(this.useEnumIndex?"j":"w");
				this.serializeString(Type.getEnumName(e));
				if(this.useEnumIndex) {
					this.buf.b += ":";
					this.buf.b += Std.string(v[1]);
				} else this.serializeString(v[0]);
				this.buf.b += ":";
				var l = v.length;
				this.buf.b += Std.string(l - 2);
				var _g1 = 2;
				while(_g1 < l) {
					var i = _g1++;
					this.serialize(v[i]);
				}
				this.cache.push(v);
				break;
			case 5:
				throw "Cannot serialize function";
				break;
			default:
				throw "Cannot serialize " + Std.string(v);
			}
		}
	}
	,serializeFields: function(v) {
		var _g = 0;
		var _g1 = Reflect.fields(v);
		while(_g < _g1.length) {
			var f = _g1[_g];
			++_g;
			this.serializeString(f);
			this.serialize((function($this) {
				var $r;
				var v1 = null;
				try {
					v1 = v[f];
				} catch( e ) {
				}
				$r = v1;
				return $r;
			}(this)));
		}
		this.buf.b += "g";
	}
	,serializeRef: function(v) {
		var vt = typeof(v);
		var _g1 = 0;
		var _g = this.cache.length;
		while(_g1 < _g) {
			var i = _g1++;
			var ci = this.cache[i];
			if(typeof(ci) == vt && ci == v) {
				this.buf.b += "r";
				this.buf.b += Std.string(i);
				return true;
			}
		}
		this.cache.push(v);
		return false;
	}
	,serializeString: function(s) {
		var x = this.shash.get(s);
		if(x != null) {
			this.buf.b += "R";
			this.buf.b += Std.string(x);
			return;
		}
		this.shash.set(s,this.scount++);
		this.buf.b += "y";
		s = StringTools.urlEncode(s);
		this.buf.b += Std.string(s.length);
		this.buf.b += ":";
		this.buf.b += Std.string(s);
	}
	,toString: function() {
		return this.buf.b;
	}
	,__class__: haxe.Serializer
}
haxe.Unserializer = function(buf) {
	this.buf = buf;
	this.length = buf.length;
	this.pos = 0;
	this.scache = new Array();
	this.cache = new Array();
	var r = haxe.Unserializer.DEFAULT_RESOLVER;
	if(r == null) {
		r = Type;
		haxe.Unserializer.DEFAULT_RESOLVER = r;
	}
	this.setResolver(r);
};
$hxClasses["haxe.Unserializer"] = haxe.Unserializer;
haxe.Unserializer.__name__ = ["haxe","Unserializer"];
haxe.Unserializer.initCodes = function() {
	var codes = new Array();
	var _g1 = 0;
	var _g = haxe.Unserializer.BASE64.length;
	while(_g1 < _g) {
		var i = _g1++;
		codes[haxe.Unserializer.BASE64.charCodeAt(i)] = i;
	}
	return codes;
}
haxe.Unserializer.run = function(v) {
	return new haxe.Unserializer(v).unserialize();
}
haxe.Unserializer.prototype = {
	unserialize: function() {
		var _g;
		var p = this.pos++;
		_g = this.buf.charCodeAt(p);
		switch(_g) {
		case 110:
			return null;
		case 116:
			return true;
		case 102:
			return false;
		case 122:
			return 0;
		case 105:
			return this.readDigits();
		case 100:
			var p1 = this.pos;
			while(true) {
				var c = this.buf.charCodeAt(this.pos);
				if(c >= 43 && c < 58 || c == 101 || c == 69) this.pos++; else break;
			}
			return Std.parseFloat(HxOverrides.substr(this.buf,p1,this.pos - p1));
		case 121:
			var len = this.readDigits();
			if((function($this) {
				var $r;
				var p = $this.pos++;
				$r = $this.buf.charCodeAt(p);
				return $r;
			}(this)) != 58 || this.length - this.pos < len) throw "Invalid string length";
			var s = HxOverrides.substr(this.buf,this.pos,len);
			this.pos += len;
			s = StringTools.urlDecode(s);
			this.scache.push(s);
			return s;
		case 107:
			return Math.NaN;
		case 109:
			return Math.NEGATIVE_INFINITY;
		case 112:
			return Math.POSITIVE_INFINITY;
		case 97:
			var buf = this.buf;
			var a = new Array();
			this.cache.push(a);
			while(true) {
				var c = this.buf.charCodeAt(this.pos);
				if(c == 104) {
					this.pos++;
					break;
				}
				if(c == 117) {
					this.pos++;
					var n = this.readDigits();
					a[a.length + n - 1] = null;
				} else a.push(this.unserialize());
			}
			return a;
		case 111:
			var o = { };
			this.cache.push(o);
			this.unserializeObject(o);
			return o;
		case 114:
			var n = this.readDigits();
			if(n < 0 || n >= this.cache.length) throw "Invalid reference";
			return this.cache[n];
		case 82:
			var n = this.readDigits();
			if(n < 0 || n >= this.scache.length) throw "Invalid string reference";
			return this.scache[n];
		case 120:
			throw this.unserialize();
			break;
		case 99:
			var name = this.unserialize();
			var cl = this.resolver.resolveClass(name);
			if(cl == null) throw "Class not found " + name;
			var o = Type.createEmptyInstance(cl);
			this.cache.push(o);
			this.unserializeObject(o);
			return o;
		case 119:
			var name = this.unserialize();
			var edecl = this.resolver.resolveEnum(name);
			if(edecl == null) throw "Enum not found " + name;
			var e = this.unserializeEnum(edecl,this.unserialize());
			this.cache.push(e);
			return e;
		case 106:
			var name = this.unserialize();
			var edecl = this.resolver.resolveEnum(name);
			if(edecl == null) throw "Enum not found " + name;
			this.pos++;
			var index = this.readDigits();
			var tag = Type.getEnumConstructs(edecl)[index];
			if(tag == null) throw "Unknown enum index " + name + "@" + index;
			var e = this.unserializeEnum(edecl,tag);
			this.cache.push(e);
			return e;
		case 108:
			var l = new List();
			this.cache.push(l);
			var buf = this.buf;
			while(this.buf.charCodeAt(this.pos) != 104) l.add(this.unserialize());
			this.pos++;
			return l;
		case 98:
			var h = new haxe.ds.StringMap();
			this.cache.push(h);
			var buf = this.buf;
			while(this.buf.charCodeAt(this.pos) != 104) {
				var s = this.unserialize();
				h.set(s,this.unserialize());
			}
			this.pos++;
			return h;
		case 113:
			var h = new haxe.ds.IntMap();
			this.cache.push(h);
			var buf = this.buf;
			var c;
			var p = this.pos++;
			c = this.buf.charCodeAt(p);
			while(c == 58) {
				var i = this.readDigits();
				h.set(i,this.unserialize());
				var p = this.pos++;
				c = this.buf.charCodeAt(p);
			}
			if(c != 104) throw "Invalid IntMap format";
			return h;
		case 77:
			var h = new haxe.ds.ObjectMap();
			this.cache.push(h);
			var buf = this.buf;
			while(this.buf.charCodeAt(this.pos) != 104) {
				var s = this.unserialize();
				h.set(s,this.unserialize());
			}
			this.pos++;
			return h;
		case 118:
			var d;
			var s = HxOverrides.substr(this.buf,this.pos,19);
			d = HxOverrides.strDate(s);
			this.cache.push(d);
			this.pos += 19;
			return d;
		case 115:
			var len = this.readDigits();
			var buf = this.buf;
			if((function($this) {
				var $r;
				var p = $this.pos++;
				$r = $this.buf.charCodeAt(p);
				return $r;
			}(this)) != 58 || this.length - this.pos < len) throw "Invalid bytes length";
			var codes = haxe.Unserializer.CODES;
			if(codes == null) {
				codes = haxe.Unserializer.initCodes();
				haxe.Unserializer.CODES = codes;
			}
			var i = this.pos;
			var rest = len & 3;
			var size;
			size = (len >> 2) * 3 + (rest >= 2?rest - 1:0);
			var max = i + (len - rest);
			var bytes = haxe.io.Bytes.alloc(size);
			var bpos = 0;
			while(i < max) {
				var c1 = codes[(function($this) {
					var $r;
					var index = i++;
					$r = buf.charCodeAt(index);
					return $r;
				}(this))];
				var c2 = codes[(function($this) {
					var $r;
					var index = i++;
					$r = buf.charCodeAt(index);
					return $r;
				}(this))];
				var pos = bpos++;
				bytes.b[pos] = c1 << 2 | c2 >> 4;
				var c3 = codes[(function($this) {
					var $r;
					var index = i++;
					$r = buf.charCodeAt(index);
					return $r;
				}(this))];
				var pos = bpos++;
				bytes.b[pos] = c2 << 4 | c3 >> 2;
				var c4 = codes[(function($this) {
					var $r;
					var index = i++;
					$r = buf.charCodeAt(index);
					return $r;
				}(this))];
				var pos = bpos++;
				bytes.b[pos] = c3 << 6 | c4;
			}
			if(rest >= 2) {
				var c1 = codes[(function($this) {
					var $r;
					var index = i++;
					$r = buf.charCodeAt(index);
					return $r;
				}(this))];
				var c2 = codes[(function($this) {
					var $r;
					var index = i++;
					$r = buf.charCodeAt(index);
					return $r;
				}(this))];
				var pos = bpos++;
				bytes.b[pos] = c1 << 2 | c2 >> 4;
				if(rest == 3) {
					var c3 = codes[(function($this) {
						var $r;
						var index = i++;
						$r = buf.charCodeAt(index);
						return $r;
					}(this))];
					var pos = bpos++;
					bytes.b[pos] = c2 << 4 | c3 >> 2;
				}
			}
			this.pos += len;
			this.cache.push(bytes);
			return bytes;
		case 67:
			var name = this.unserialize();
			var cl = this.resolver.resolveClass(name);
			if(cl == null) throw "Class not found " + name;
			var o = Type.createEmptyInstance(cl);
			this.cache.push(o);
			o.hxUnserialize(this);
			if((function($this) {
				var $r;
				var p = $this.pos++;
				$r = $this.buf.charCodeAt(p);
				return $r;
			}(this)) != 103) throw "Invalid custom data";
			return o;
		default:
		}
		this.pos--;
		throw "Invalid char " + this.buf.charAt(this.pos) + " at position " + this.pos;
	}
	,unserializeEnum: function(edecl,tag) {
		if((function($this) {
			var $r;
			var p = $this.pos++;
			$r = $this.buf.charCodeAt(p);
			return $r;
		}(this)) != 58) throw "Invalid enum format";
		var nargs = this.readDigits();
		if(nargs == 0) return Type.createEnum(edecl,tag);
		var args = new Array();
		while(nargs-- > 0) args.push(this.unserialize());
		return Type.createEnum(edecl,tag,args);
	}
	,unserializeObject: function(o) {
		while(true) {
			if(this.pos >= this.length) throw "Invalid object";
			if(this.buf.charCodeAt(this.pos) == 103) break;
			var k = this.unserialize();
			if(!js.Boot.__instanceof(k,String)) throw "Invalid object key";
			var v = this.unserialize();
			o[k] = v;
		}
		this.pos++;
	}
	,readDigits: function() {
		var k = 0;
		var s = false;
		var fpos = this.pos;
		while(true) {
			var c = this.buf.charCodeAt(this.pos);
			if(c != c) break;
			if(c == 45) {
				if(this.pos != fpos) break;
				s = true;
				this.pos++;
				continue;
			}
			if(c < 48 || c > 57) break;
			k = k * 10 + (c - 48);
			this.pos++;
		}
		if(s) k *= -1;
		return k;
	}
	,setResolver: function(r) {
		if(r == null) this.resolver = { resolveClass : function(_) {
			return null;
		}, resolveEnum : function(_) {
			return null;
		}}; else this.resolver = r;
	}
	,__class__: haxe.Unserializer
}
haxe.ds = {}
haxe.ds.IntMap = function() {
	this.h = { };
};
$hxClasses["haxe.ds.IntMap"] = haxe.ds.IntMap;
haxe.ds.IntMap.__name__ = ["haxe","ds","IntMap"];
haxe.ds.IntMap.__interfaces__ = [IMap];
haxe.ds.IntMap.prototype = {
	keys: function() {
		var a = [];
		for( var key in this.h ) {
		if(this.h.hasOwnProperty(key)) a.push(key | 0);
		}
		return HxOverrides.iter(a);
	}
	,get: function(key) {
		return this.h[key];
	}
	,set: function(key,value) {
		this.h[key] = value;
	}
	,__class__: haxe.ds.IntMap
}
haxe.ds.ObjectMap = function() {
	this.h = { };
	this.h.__keys__ = { };
};
$hxClasses["haxe.ds.ObjectMap"] = haxe.ds.ObjectMap;
haxe.ds.ObjectMap.__name__ = ["haxe","ds","ObjectMap"];
haxe.ds.ObjectMap.__interfaces__ = [IMap];
haxe.ds.ObjectMap.prototype = {
	keys: function() {
		var a = [];
		for( var key in this.h.__keys__ ) {
		if(this.h.hasOwnProperty(key)) a.push(this.h.__keys__[key]);
		}
		return HxOverrides.iter(a);
	}
	,set: function(key,value) {
		var id;
		if(key.__id__ != null) id = key.__id__; else id = key.__id__ = ++haxe.ds.ObjectMap.count;
		this.h[id] = value;
		this.h.__keys__[id] = key;
	}
	,__class__: haxe.ds.ObjectMap
}
haxe.ds.StringMap = function() {
	this.h = { };
};
$hxClasses["haxe.ds.StringMap"] = haxe.ds.StringMap;
haxe.ds.StringMap.__name__ = ["haxe","ds","StringMap"];
haxe.ds.StringMap.__interfaces__ = [IMap];
haxe.ds.StringMap.prototype = {
	keys: function() {
		var a = [];
		for( var key in this.h ) {
		if(this.h.hasOwnProperty(key)) a.push(key.substr(1));
		}
		return HxOverrides.iter(a);
	}
	,remove: function(key) {
		key = "$" + key;
		if(!this.h.hasOwnProperty(key)) return false;
		delete(this.h[key]);
		return true;
	}
	,get: function(key) {
		return this.h["$" + key];
	}
	,set: function(key,value) {
		this.h["$" + key] = value;
	}
	,__class__: haxe.ds.StringMap
}
haxe.io = {}
haxe.io.Bytes = function(length,b) {
	this.length = length;
	this.b = b;
};
$hxClasses["haxe.io.Bytes"] = haxe.io.Bytes;
haxe.io.Bytes.__name__ = ["haxe","io","Bytes"];
haxe.io.Bytes.alloc = function(length) {
	return new haxe.io.Bytes(length,new Buffer(length));
}
haxe.io.Bytes.ofString = function(s) {
	var nb = new Buffer(s,"utf8");
	return new haxe.io.Bytes(nb.length,nb);
}
haxe.io.Bytes.ofData = function(b) {
	return new haxe.io.Bytes(b.length,b);
}
haxe.io.Bytes.prototype = {
	getData: function() {
		return this.b;
	}
	,toString: function() {
		return this.readString(0,this.length);
	}
	,readString: function(pos,len) {
		if(pos < 0 || len < 0 || pos + len > this.length) throw haxe.io.Error.OutsideBounds;
		var s = "";
		var b = this.b;
		var fcc = String.fromCharCode;
		var i = pos;
		var max = pos + len;
		while(i < max) {
			var c = b[i++];
			if(c < 128) {
				if(c == 0) break;
				s += fcc(c);
			} else if(c < 224) s += fcc((c & 63) << 6 | b[i++] & 127); else if(c < 240) {
				var c2 = b[i++];
				s += fcc((c & 31) << 12 | (c2 & 127) << 6 | b[i++] & 127);
			} else {
				var c2 = b[i++];
				var c3 = b[i++];
				s += fcc((c & 15) << 18 | (c2 & 127) << 12 | c3 << 6 & 127 | b[i++] & 127);
			}
		}
		return s;
	}
	,compare: function(other) {
		var b1 = this.b;
		var b2 = other.b;
		var len;
		if(this.length < other.length) len = this.length; else len = other.length;
		var _g = 0;
		while(_g < len) {
			var i = _g++;
			if(b1[i] != b2[i]) return b1[i] - b2[i];
		}
		return this.length - other.length;
	}
	,sub: function(pos,len) {
		if(pos < 0 || len < 0 || pos + len > this.length) throw haxe.io.Error.OutsideBounds;
		var nb = new Buffer(len);
		var slice = this.b.slice(pos,pos + len);
		slice.copy(nb,0,0,len);
		return new haxe.io.Bytes(len,nb);
	}
	,blit: function(pos,src,srcpos,len) {
		if(pos < 0 || srcpos < 0 || len < 0 || pos + len > this.length || srcpos + len > src.length) throw haxe.io.Error.OutsideBounds;
		src.b.copy(this.b,pos,srcpos,srcpos + len);
	}
	,set: function(pos,v) {
		this.b[pos] = v;
	}
	,get: function(pos) {
		return this.b[pos];
	}
	,__class__: haxe.io.Bytes
}
haxe.io.BytesBuffer = function() {
	this.b = new Array();
};
$hxClasses["haxe.io.BytesBuffer"] = haxe.io.BytesBuffer;
haxe.io.BytesBuffer.__name__ = ["haxe","io","BytesBuffer"];
haxe.io.BytesBuffer.prototype = {
	getBytes: function() {
		var nb = new Buffer(this.b);
		var bytes = new haxe.io.Bytes(nb.length,nb);
		this.b = null;
		return bytes;
	}
	,addBytes: function(src,pos,len) {
		if(pos < 0 || len < 0 || pos + len > src.length) throw haxe.io.Error.OutsideBounds;
		var b1 = this.b;
		var b2 = src.b;
		var _g1 = pos;
		var _g = pos + len;
		while(_g1 < _g) {
			var i = _g1++;
			this.b.push(b2[i]);
		}
	}
	,add: function(src) {
		var b1 = this.b;
		var b2 = src.b;
		var _g1 = 0;
		var _g = src.length;
		while(_g1 < _g) {
			var i = _g1++;
			this.b.push(b2[i]);
		}
	}
	,addByte: function($byte) {
		this.b.push($byte);
	}
	,__class__: haxe.io.BytesBuffer
}
haxe.io.Eof = function() { }
$hxClasses["haxe.io.Eof"] = haxe.io.Eof;
haxe.io.Eof.__name__ = ["haxe","io","Eof"];
haxe.io.Eof.prototype = {
	toString: function() {
		return "Eof";
	}
	,__class__: haxe.io.Eof
}
haxe.io.Error = $hxClasses["haxe.io.Error"] = { __ename__ : ["haxe","io","Error"], __constructs__ : ["Blocked","Overflow","OutsideBounds","Custom"] }
haxe.io.Error.Blocked = ["Blocked",0];
haxe.io.Error.Blocked.toString = $estr;
haxe.io.Error.Blocked.__enum__ = haxe.io.Error;
haxe.io.Error.Overflow = ["Overflow",1];
haxe.io.Error.Overflow.toString = $estr;
haxe.io.Error.Overflow.__enum__ = haxe.io.Error;
haxe.io.Error.OutsideBounds = ["OutsideBounds",2];
haxe.io.Error.OutsideBounds.toString = $estr;
haxe.io.Error.OutsideBounds.__enum__ = haxe.io.Error;
haxe.io.Error.Custom = function(e) { var $x = ["Custom",3,e]; $x.__enum__ = haxe.io.Error; $x.toString = $estr; return $x; }
haxe.io.Output = function() { }
$hxClasses["haxe.io.Output"] = haxe.io.Output;
haxe.io.Output.__name__ = ["haxe","io","Output"];
var js = {}
js.Boot = function() { }
$hxClasses["js.Boot"] = js.Boot;
js.Boot.__name__ = ["js","Boot"];
js.Boot.__string_rec = function(o,s) {
	if(o == null) return "null";
	if(s.length >= 5) return "<...>";
	var t = typeof(o);
	if(t == "function" && (o.__name__ || o.__ename__)) t = "object";
	switch(t) {
	case "object":
		if(o instanceof Array) {
			if(o.__enum__) {
				if(o.length == 2) return o[0];
				var str = o[0] + "(";
				s += "\t";
				var _g1 = 2;
				var _g = o.length;
				while(_g1 < _g) {
					var i = _g1++;
					if(i != 2) str += "," + js.Boot.__string_rec(o[i],s); else str += js.Boot.__string_rec(o[i],s);
				}
				return str + ")";
			}
			var l = o.length;
			var i;
			var str = "[";
			s += "\t";
			var _g = 0;
			while(_g < l) {
				var i1 = _g++;
				str += (i1 > 0?",":"") + js.Boot.__string_rec(o[i1],s);
			}
			str += "]";
			return str;
		}
		var tostr;
		try {
			tostr = o.toString;
		} catch( e ) {
			return "???";
		}
		if(tostr != null && tostr != Object.toString) {
			var s2 = o.toString();
			if(s2 != "[object Object]") return s2;
		}
		var k = null;
		var str = "{\n";
		s += "\t";
		var hasp = o.hasOwnProperty != null;
		for( var k in o ) { ;
		if(hasp && !o.hasOwnProperty(k)) {
			continue;
		}
		if(k == "prototype" || k == "__class__" || k == "__super__" || k == "__interfaces__" || k == "__properties__") {
			continue;
		}
		if(str.length != 2) str += ", \n";
		str += s + k + " : " + js.Boot.__string_rec(o[k],s);
		}
		s = s.substring(1);
		str += "\n" + s + "}";
		return str;
	case "function":
		return "<function>";
	case "string":
		return o;
	default:
		return String(o);
	}
}
js.Boot.__interfLoop = function(cc,cl) {
	if(cc == null) return false;
	if(cc == cl) return true;
	var intf = cc.__interfaces__;
	if(intf != null) {
		var _g1 = 0;
		var _g = intf.length;
		while(_g1 < _g) {
			var i = _g1++;
			var i1 = intf[i];
			if(i1 == cl || js.Boot.__interfLoop(i1,cl)) return true;
		}
	}
	return js.Boot.__interfLoop(cc.__super__,cl);
}
js.Boot.__instanceof = function(o,cl) {
	if(cl == null) return false;
	switch(cl) {
	case Int:
		return (o|0) === o;
	case Float:
		return typeof(o) == "number";
	case Bool:
		return typeof(o) == "boolean";
	case String:
		return typeof(o) == "string";
	case Dynamic:
		return true;
	default:
		if(o != null) {
			if(typeof(cl) == "function") {
				if(o instanceof cl) {
					if(cl == Array) return o.__enum__ == null;
					return true;
				}
				if(js.Boot.__interfLoop(o.__class__,cl)) return true;
			}
		} else return false;
		if(cl == Class && o.__name__ != null) return true;
		if(cl == Enum && o.__ename__ != null) return true;
		return o.__enum__ == cl;
	}
}
js.Browser = function() { }
$hxClasses["js.Browser"] = js.Browser;
js.Browser.__name__ = ["js","Browser"];
js.Browser.getLocalStorage = function() {
	try {
		var s = window.localStorage;
		s.getItem("");
		return s;
	} catch( e ) {
		return null;
	}
}
js.NodeC = function() { }
$hxClasses["js.NodeC"] = js.NodeC;
js.NodeC.__name__ = ["js","NodeC"];
js.Node = function() { }
$hxClasses["js.Node"] = js.Node;
js.Node.__name__ = ["js","Node"];
js.Node.newSocket = function(options) {
	return new js.Node.net.Socket(options);
}
var nw = {}
nw.$ui = function() { }
$hxClasses["nw.$ui"] = nw.$ui;
nw.$ui.__name__ = ["nw","$ui"];
nw._MenuItem = {}
nw._MenuItem.MenuItemType_Impl_ = function() { }
$hxClasses["nw._MenuItem.MenuItemType_Impl_"] = nw._MenuItem.MenuItemType_Impl_;
nw._MenuItem.MenuItemType_Impl_.__name__ = ["nw","_MenuItem","MenuItemType_Impl_"];
var sys = {}
sys.io = {}
sys.io.File = function() { }
$hxClasses["sys.io.File"] = sys.io.File;
sys.io.File.__name__ = ["sys","io","File"];
sys.io.File.append = function(path,binary) {
	throw "Not implemented";
	return null;
}
sys.io.File.copy = function(src,dst) {
	var content = js.Node.fs.readFileSync(src);
	js.Node.fs.writeFileSync(dst,content);
}
sys.io.File.getContent = function(path) {
	return js.Node.fs.readFileSync(path);
}
sys.io.File.saveContent = function(path,content) {
	js.Node.fs.writeFileSync(path,content);
}
sys.io.File.write = function(path,binary) {
	throw "Not implemented";
	return null;
}
function $iterator(o) { if( o instanceof Array ) return function() { return HxOverrides.iter(o); }; return typeof(o.iterator) == 'function' ? $bind(o,o.iterator) : o.iterator; };
var $_, $fid = 0;
function $bind(o,m) { if( m == null ) return null; if( m.__id__ == null ) m.__id__ = $fid++; var f; if( o.hx__closures__ == null ) o.hx__closures__ = {}; else f = o.hx__closures__[m.__id__]; if( f == null ) { f = function(){ return f.method.apply(f.scope, arguments); }; f.scope = o; f.method = m; o.hx__closures__[m.__id__] = f; } return f; };
Math.__name__ = ["Math"];
Math.NaN = Number.NaN;
Math.NEGATIVE_INFINITY = Number.NEGATIVE_INFINITY;
Math.POSITIVE_INFINITY = Number.POSITIVE_INFINITY;
$hxClasses.Math = Math;
Math.isFinite = function(i) {
	return isFinite(i);
};
Math.isNaN = function(i) {
	return isNaN(i);
};
String.prototype.__class__ = $hxClasses.String = String;
String.__name__ = ["String"];
Array.prototype.__class__ = $hxClasses.Array = Array;
Array.__name__ = ["Array"];
Date.prototype.__class__ = $hxClasses.Date = Date;
Date.__name__ = ["Date"];
var Int = $hxClasses.Int = { __name__ : ["Int"]};
var Dynamic = $hxClasses.Dynamic = { __name__ : ["Dynamic"]};
var Float = $hxClasses.Float = Number;
Float.__name__ = ["Float"];
var Bool = $hxClasses.Bool = Boolean;
Bool.__ename__ = ["Bool"];
var Class = $hxClasses.Class = { __name__ : ["Class"]};
var Enum = { };
var q = window.jQuery;
js.JQuery = q;
q.fn.iterator = function() {
	return { pos : 0, j : this, hasNext : function() {
		return this.pos < this.j.length;
	}, next : function() {
		return $(this.j[this.pos++]);
	}};
};
var __filename, __dirname, module;
js.Node.__filename = __filename;
js.Node.__dirname = __dirname;
js.Node.setTimeout = setTimeout;
js.Node.clearTimeout = clearTimeout;
js.Node.setInterval = setInterval;
js.Node.clearInterval = clearInterval;
js.Node.global = global;
js.Node.process = process;
js.Node.require = require;
js.Node.console = console;
js.Node.module = module;
js.Node.stringify = JSON.stringify;
js.Node.parse = JSON.parse;
js.Node.util = js.Node.require("util");
js.Node.fs = js.Node.require("fs");
js.Node.net = js.Node.require("net");
js.Node.http = js.Node.require("http");
js.Node.https = js.Node.require("https");
js.Node.path = js.Node.require("path");
js.Node.url = js.Node.require("url");
js.Node.os = js.Node.require("os");
js.Node.crypto = js.Node.require("crypto");
js.Node.dns = js.Node.require("dns");
js.Node.queryString = js.Node.require("querystring");
js.Node.assert = js.Node.require("assert");
js.Node.childProcess = js.Node.require("child_process");
js.Node.vm = js.Node.require("vm");
js.Node.tls = js.Node.require("tls");
js.Node.dgram = js.Node.require("dgram");
js.Node.assert = js.Node.require("assert");
js.Node.repl = js.Node.require("repl");
js.Node.cluster = js.Node.require("cluster");
nw.$ui = require('nw.gui');
nw.Menu = nw.$ui.Menu;
nw.MenuItem = nw.$ui.MenuItem;
nw.Window = nw.$ui.Window;
Main.r_id = new EReg("^[A-Za-z_][A-Za-z_0-9]*$","");
haxe.Serializer.USE_CACHE = false;
haxe.Serializer.USE_ENUM_INDEX = false;
haxe.Serializer.BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789%:";
haxe.Unserializer.DEFAULT_RESOLVER = Type;
haxe.Unserializer.BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789%:";
haxe.ds.ObjectMap.count = 0;
js.NodeC.UTF8 = "utf8";
js.NodeC.ASCII = "ascii";
js.NodeC.BINARY = "binary";
js.NodeC.BASE64 = "base64";
js.NodeC.HEX = "hex";
js.NodeC.EVENT_EVENTEMITTER_NEWLISTENER = "newListener";
js.NodeC.EVENT_EVENTEMITTER_ERROR = "error";
js.NodeC.EVENT_STREAM_DATA = "data";
js.NodeC.EVENT_STREAM_END = "end";
js.NodeC.EVENT_STREAM_ERROR = "error";
js.NodeC.EVENT_STREAM_CLOSE = "close";
js.NodeC.EVENT_STREAM_DRAIN = "drain";
js.NodeC.EVENT_STREAM_CONNECT = "connect";
js.NodeC.EVENT_STREAM_SECURE = "secure";
js.NodeC.EVENT_STREAM_TIMEOUT = "timeout";
js.NodeC.EVENT_STREAM_PIPE = "pipe";
js.NodeC.EVENT_PROCESS_EXIT = "exit";
js.NodeC.EVENT_PROCESS_UNCAUGHTEXCEPTION = "uncaughtException";
js.NodeC.EVENT_PROCESS_SIGINT = "SIGINT";
js.NodeC.EVENT_PROCESS_SIGUSR1 = "SIGUSR1";
js.NodeC.EVENT_CHILDPROCESS_EXIT = "exit";
js.NodeC.EVENT_HTTPSERVER_REQUEST = "request";
js.NodeC.EVENT_HTTPSERVER_CONNECTION = "connection";
js.NodeC.EVENT_HTTPSERVER_CLOSE = "close";
js.NodeC.EVENT_HTTPSERVER_UPGRADE = "upgrade";
js.NodeC.EVENT_HTTPSERVER_CLIENTERROR = "clientError";
js.NodeC.EVENT_HTTPSERVERREQUEST_DATA = "data";
js.NodeC.EVENT_HTTPSERVERREQUEST_END = "end";
js.NodeC.EVENT_CLIENTREQUEST_RESPONSE = "response";
js.NodeC.EVENT_CLIENTRESPONSE_DATA = "data";
js.NodeC.EVENT_CLIENTRESPONSE_END = "end";
js.NodeC.EVENT_NETSERVER_CONNECTION = "connection";
js.NodeC.EVENT_NETSERVER_CLOSE = "close";
js.NodeC.FILE_READ = "r";
js.NodeC.FILE_READ_APPEND = "r+";
js.NodeC.FILE_WRITE = "w";
js.NodeC.FILE_WRITE_APPEND = "a+";
js.NodeC.FILE_READWRITE = "a";
js.NodeC.FILE_READWRITE_APPEND = "a+";
nw._MenuItem.MenuItemType_Impl_.separator = "separator";
nw._MenuItem.MenuItemType_Impl_.checkbox = "checkbox";
nw._MenuItem.MenuItemType_Impl_.normal = "normal";
Main.main();
})();
