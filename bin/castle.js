(function () { "use strict";
var $hxClasses = {},$estr = function() { return js.Boot.__string_rec(this,''); };
var ColumnType = $hxClasses["ColumnType"] = { __ename__ : ["ColumnType"], __constructs__ : ["TId","TString","TBool","TInt","TFloat","TEnum","TRef","TImage"] }
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
ColumnType.TImage = ["TImage",7];
ColumnType.TImage.toString = $estr;
ColumnType.TImage.__enum__ = ColumnType;
var EReg = function(r,opt) {
	opt = opt.split("u").join("");
	this.r = new RegExp(r,opt);
};
$hxClasses["EReg"] = EReg;
EReg.__name__ = ["EReg"];
EReg.prototype = {
	replace: function(s,by) {
		return s.replace(this.r,by);
	}
	,match: function(s) {
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
HxOverrides.remove = function(a,obj) {
	var i = 0;
	var l = a.length;
	while(i < l) {
		if(a[i] == obj) {
			a.splice(i,1);
			return true;
		}
		i++;
	}
	return false;
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
Lambda.has = function(it,elt) {
	var $it0 = $iterator(it)();
	while( $it0.hasNext() ) {
		var x = $it0.next();
		if(x == elt) return true;
	}
	return false;
}
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
	this["window"] = nodejs.webkit.Window.get();
	this.prefs = { windowPos : { x : 50, y : 50, w : 800, h : 600, max : false}, curFile : null, curSheet : 0};
	try {
		this.prefs = haxe.Unserializer.run(js.Browser.getLocalStorage().getItem("prefs"));
	} catch( e ) {
	}
	this.initMenu();
	this.mousePos = { x : 0, y : 0};
	this["window"]["window"].addEventListener("keydown",$bind(this,this.onKey));
	this["window"]["window"].addEventListener("mousemove",$bind(this,this.onMouseMove));
	new js.JQuery("body").click(function(_) {
		new js.JQuery(".selected").removeClass("selected");
	});
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
		var menu = new nodejs.webkit.Menu({ type : "menubar"});
		var mfile = new nodejs.webkit.MenuItem({ label : "File"});
		var mfiles = new nodejs.webkit.Menu();
		var mnew = new nodejs.webkit.MenuItem({ label : "New"});
		var mopen = new nodejs.webkit.MenuItem({ label : "Open..."});
		var msave = new nodejs.webkit.MenuItem({ label : "Save As..."});
		var mclean = new nodejs.webkit.MenuItem({ label : "Clean Images"});
		var mhelp = new nodejs.webkit.MenuItem({ label : "Help"});
		var mdebug = new nodejs.webkit.MenuItem({ label : "Dev"});
		mnew.click = function() {
			_g.prefs.curFile = null;
			_g.load(true);
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
		mhelp.click = function() {
			new js.JQuery("#help").show();
		};
		mclean.click = function() {
			if(_g.imageBank == null) {
				_g.error("No image bank");
				return;
			}
			var count = Reflect.fields(_g.imageBank).length;
			_g.cleanImages();
			var count2 = Reflect.fields(_g.imageBank).length;
			_g.error(count - count2 + " unused images removed");
			if(count2 == 0) _g.imageBank = null;
			_g.refresh();
			_g.saveImages();
		};
		mfiles.append(mnew);
		mfiles.append(mopen);
		mfiles.append(msave);
		mfiles.append(mclean);
		mfile.submenu = mfiles;
		menu.append(mfile);
		menu.append(mhelp);
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
	,cleanImages: function() {
		if(this.imageBank == null) return;
		var used = new haxe.ds.StringMap();
		var _g = 0;
		var _g1 = this.data.sheets;
		while(_g < _g1.length) {
			var s = _g1[_g];
			++_g;
			var _g2 = 0;
			var _g3 = s.columns;
			while(_g2 < _g3.length) {
				var c = _g3[_g2];
				++_g2;
				var _g4 = c.type;
				switch(_g4[1]) {
				case 7:
					var _g5 = 0;
					var _g6 = s.lines;
					while(_g5 < _g6.length) {
						var obj = _g6[_g5];
						++_g5;
						var v = (function($this) {
							var $r;
							var v1 = null;
							try {
								v1 = obj[c.name];
							} catch( e ) {
							}
							$r = v1;
							return $r;
						}(this));
						if(v != null) used.set(v,true);
					}
					break;
				default:
				}
			}
		}
		var _g = 0;
		var _g1 = Reflect.fields(this.imageBank);
		while(_g < _g1.length) {
			var f = _g1[_g];
			++_g;
			if(!used.get(f)) Reflect.deleteField(this.imageBank,f);
		}
	}
	,initContent: function() {
		this.smap = new haxe.ds.StringMap();
		var _g = 0;
		var _g1 = this.data.sheets;
		while(_g < _g1.length) {
			var s = _g1[_g];
			++_g;
			this.makeSheet(s);
		}
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
		var refColumn = null;
		if(v.ref != "") {
			var _g = 0;
			var _g1 = this.sheet.columns;
			while(_g < _g1.length) {
				var c = _g1[_g];
				++_g;
				if(c.name == v.ref) refColumn = c;
			}
		}
		var t;
		var _g = v.type;
		switch(_g) {
		case "id":
			if(refColumn == null) {
				var _g1 = 0;
				var _g2 = this.sheet.columns;
				while(_g1 < _g2.length) {
					var c = _g2[_g1];
					++_g1;
					if(c.type == ColumnType.TId) {
						this.error("Only one ID allowed");
						return;
					}
				}
			}
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
			if(vals.length == 0) {
				this.error("Missing value list");
				return;
			}
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
			var s = this.data.sheets[Std.parseInt(v.sheet)];
			if(s == null) {
				this.error("Sheet not found");
				return;
			}
			t = ColumnType.TRef(s.name);
			break;
		case "image":
			t = ColumnType.TImage;
			break;
		default:
			return;
		}
		var c = { type : t, typeStr : null, opt : v.opt == "on", name : v.name, size : null};
		if(refColumn != null) {
			var old = refColumn;
			if(old.name != c.name) {
				var _g1 = 0;
				var _g2 = this.sheet.lines;
				while(_g1 < _g2.length) {
					var o = _g2[_g1];
					++_g1;
					var v1 = (function($this) {
						var $r;
						var v2 = null;
						try {
							v2 = o[old.name];
						} catch( e ) {
						}
						$r = v2;
						return $r;
					}(this));
					Reflect.deleteField(o,old.name);
					if(v1 != null) o[c.name] = v1;
				}
				old.name = c.name;
			}
			if(!Type.enumEq(old.type,c.type)) {
				var conv = null;
				{
					var _g1 = old.type;
					var _g2 = c.type;
					switch(_g1[1]) {
					case 3:
						switch(_g2[1]) {
						case 4:
							break;
						case 1:
							conv = Std.string;
							break;
						case 2:
							conv = function(v1) {
								return v1 != 0;
							};
							break;
						case 5:
							var values = _g2[2];
							conv = function(i) {
								if(i < 0 || i >= values.length) return null; else return i;
							};
							break;
						default:
							this.error("Cannot convert " + HxOverrides.substr(old.type[0],1,null) + " to " + HxOverrides.substr(c.type[0],1,null));
							return;
						}
						break;
					case 0:case 6:
						switch(_g2[1]) {
						case 1:
							break;
						default:
							this.error("Cannot convert " + HxOverrides.substr(old.type[0],1,null) + " to " + HxOverrides.substr(c.type[0],1,null));
							return;
						}
						break;
					case 1:
						switch(_g2[1]) {
						case 0:case 6:
							var r_invalid = new EReg("[^A-Za-z0-9_]","g");
							conv = function(r) {
								return r_invalid.replace(r,"_");
							};
							break;
						case 3:
							conv = Std.parseInt;
							break;
						case 4:
							conv = Std.parseFloat;
							break;
						case 2:
							conv = function(s) {
								return s != "";
							};
							break;
						case 5:
							var values = _g2[2];
							var map = new haxe.ds.StringMap();
							var _g4 = 0;
							var _g3 = values.length;
							while(_g4 < _g3) {
								var i = _g4++;
								var key = values[i].toLowerCase();
								map.set(key,i);
							}
							conv = function(s) {
								var key = s.toLowerCase();
								return map.get(key);
							};
							break;
						default:
							this.error("Cannot convert " + HxOverrides.substr(old.type[0],1,null) + " to " + HxOverrides.substr(c.type[0],1,null));
							return;
						}
						break;
					case 2:
						switch(_g2[1]) {
						case 3:case 4:
							conv = function(b) {
								if(b) return 1; else return 0;
							};
							break;
						case 1:
							conv = Std.string;
							break;
						default:
							this.error("Cannot convert " + HxOverrides.substr(old.type[0],1,null) + " to " + HxOverrides.substr(c.type[0],1,null));
							return;
						}
						break;
					case 4:
						switch(_g2[1]) {
						case 3:
							conv = Std["int"];
							break;
						case 1:
							conv = Std.string;
							break;
						case 2:
							conv = function(v1) {
								return v1 != 0;
							};
							break;
						default:
							this.error("Cannot convert " + HxOverrides.substr(old.type[0],1,null) + " to " + HxOverrides.substr(c.type[0],1,null));
							return;
						}
						break;
					case 5:
						switch(_g2[1]) {
						case 5:
							var values1 = _g1[2];
							var values2 = _g2[2];
							var map1 = [];
							var _g3 = 0;
							while(_g3 < values1.length) {
								var v1 = values1[_g3];
								++_g3;
								var pos = Lambda.indexOf(values2,v1);
								if(pos < 0) map1.push(null); else map1.push(pos);
							}
							conv = function(i) {
								return map1[i];
							};
							break;
						case 3:
							var values = _g1[2];
							break;
						default:
							this.error("Cannot convert " + HxOverrides.substr(old.type[0],1,null) + " to " + HxOverrides.substr(c.type[0],1,null));
							return;
						}
						break;
					default:
						this.error("Cannot convert " + HxOverrides.substr(old.type[0],1,null) + " to " + HxOverrides.substr(c.type[0],1,null));
						return;
					}
				}
				if(conv != null) {
					var _g3 = 0;
					var _g4 = this.sheet.lines;
					while(_g3 < _g4.length) {
						var o = _g4[_g3];
						++_g3;
						var v1 = (function($this) {
							var $r;
							var v2 = null;
							try {
								v2 = o[c.name];
							} catch( e ) {
							}
							$r = v2;
							return $r;
						}(this));
						if(v1 != null) {
							v1 = conv(v1);
							if(v1 != null) o[c.name] = v1; else Reflect.deleteField(o,c.name);
						}
					}
				}
				old.type = c.type;
				old.typeStr = null;
			}
			if(old.opt != c.opt) {
				if(old.opt) {
					var _g1 = 0;
					var _g2 = this.sheet.lines;
					while(_g1 < _g2.length) {
						var o = _g2[_g1];
						++_g1;
						var v1 = (function($this) {
							var $r;
							var v2 = null;
							try {
								v2 = o[c.name];
							} catch( e ) {
							}
							$r = v2;
							return $r;
						}(this));
						if(v1 == null) {
							v1 = this.getDefault(c);
							if(v1 != null) o[c.name] = v1;
						}
					}
				} else {
					var _g1 = old.type;
					switch(_g1[1]) {
					case 5:
						break;
					default:
						var def = this.getDefault(old);
						var _g2 = 0;
						var _g3 = this.sheet.lines;
						while(_g2 < _g3.length) {
							var o = _g3[_g2];
							++_g2;
							var v1 = (function($this) {
								var $r;
								var v2 = null;
								try {
									v2 = o[c.name];
								} catch( e ) {
								}
								$r = v2;
								return $r;
							}(this));
							if(v1 == def) Reflect.deleteField(o,c.name);
						}
					}
				}
				old.opt = c.opt;
			}
			this.makeSheet(this.sheet);
		} else {
			var _g1 = 0;
			var _g2 = this.sheet.columns;
			while(_g1 < _g2.length) {
				var c2 = _g2[_g1];
				++_g1;
				if(c2.name == c.name) {
					this.error("Column already exists");
					return;
				}
			}
			this.sheet.columns.push(c);
			var _g1 = 0;
			var _g2 = this.sheet.lines;
			while(_g1 < _g2.length) {
				var i = _g2[_g1];
				++_g1;
				var def = this.getDefault(c);
				if(def != null) i[c.name] = def;
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
		var s = { name : name, columns : [], lines : [], separators : [], props : { displayColumn : null}};
		this.prefs.curSheet = this.data.sheets.length - 1;
		this.data.sheets.push(s);
		this.initContent();
		this.save();
		this.selectSheet(s);
	}
	,newLine: function(index) {
		var o = { };
		var _g = 0;
		var _g1 = this.sheet.columns;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			var d = this.getDefault(c);
			if(d != null) o[c.name] = d;
		}
		if(index == null) this.sheet.lines.push(o); else {
			var _g1 = 0;
			var _g = this.sheet.separators.length;
			while(_g1 < _g) {
				var i = _g1++;
				var s = this.sheet.separators[i];
				if(s >= index) this.sheet.separators[i] = s + 1;
			}
			this.sheet.lines.splice(index + 1,0,o);
		}
		this.refresh();
		this.save();
		if(index != null) this.selectLine(index + 2);
	}
	,newColumn: function(ref) {
		var form = new js.JQuery("#newcol form");
		var sheets = new js.JQuery("[name=sheet]");
		sheets.html("");
		var _g1 = 0;
		var _g = this.data.sheets.length;
		while(_g1 < _g) {
			var i = _g1++;
			new js.JQuery("<option>").attr("value","" + i).text(this.data.sheets[i].name).appendTo(sheets);
		}
		form.removeClass("edit").removeClass("create");
		if(ref != null) {
			form.addClass("edit");
			form.find("[name=name]").val(ref.name);
			form.find("[name=type]").val(HxOverrides.substr(ref.type[0],1,null).toLowerCase()).change();
			form.find("[name=opt]").attr("checked",ref.opt);
			form.find("[name=ref]").val(ref.name);
			{
				var _g = ref.type;
				switch(_g[1]) {
				case 5:
					var values = _g[2];
					form.find("[name=values]").val(values.join(","));
					break;
				case 6:
					var sname = _g[2];
					form.find("[name=sheet]").val(sname);
					break;
				default:
				}
			}
		} else {
			form.addClass("create");
			form.find("input").not("[type=submit]").val("");
		}
		new js.JQuery("#newcol").show();
	}
	,deleteLine: function(sheet,index) {
		sheet.lines.splice(index,1);
		var prev = -1;
		var toRemove = null;
		var _g1 = 0;
		var _g = sheet.separators.length;
		while(_g1 < _g) {
			var i = _g1++;
			var s = sheet.separators[i];
			if(s >= index) {
				if(prev == s - 1) toRemove = prev;
				sheet.separators[i] = s - 1;
			} else prev = s;
		}
		if(toRemove != null) HxOverrides.remove(sheet.separators,toRemove);
	}
	,deleteColumn: function(cname) {
		if(cname == null) cname = new js.JQuery("#newcol form [name=ref]").val();
		var _g = 0;
		var _g1 = this.sheet.columns;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			if(c.name == cname) {
				HxOverrides.remove(this.sheet.columns,c);
				var _g2 = 0;
				var _g3 = this.sheet.lines;
				while(_g2 < _g3.length) {
					var o = _g3[_g2];
					++_g2;
					Reflect.deleteField(o,c.name);
				}
				if(this.sheet.props.displayColumn == c.name) {
					this.sheet.props.displayColumn = null;
					this.makeSheet(this.sheet);
				}
			}
		}
		new js.JQuery("#newcol").hide();
		this.refresh();
		this.save();
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
		var _g4 = this;
		var s = this.sheet;
		var content = new js.JQuery("#content");
		if(s.columns.length == 0) {
			content.html("<a href='javascript:_.newColumn()'>Add a column</a>");
			return;
		}
		content.html("");
		var cols = new js.JQuery("<tr>").addClass("head");
		var types;
		var _g = [];
		var _g1 = 0;
		var _g2 = Type.getEnumConstructs(ColumnType);
		while(_g1 < _g2.length) {
			var t = _g2[_g1];
			++_g1;
			_g.push(HxOverrides.substr(t,1,null).toLowerCase());
		}
		types = _g;
		new js.JQuery("<td>").addClass("start").appendTo(cols);
		var lines;
		var _g1 = [];
		var _g3 = 0;
		var _g2 = s.lines.length;
		while(_g3 < _g2) {
			var i = [_g3++];
			_g1.push((function($this) {
				var $r;
				var l = [new js.JQuery("<tr>")];
				l[0].data("index",i[0]);
				var head = [new js.JQuery("<td>").addClass("start").text("" + i[0])];
				head[0].click((function(l) {
					return function(e) {
						if(!e.ctrlKey) new js.JQuery("tr.selected").removeClass("selected");
						l[0].toggleClass("selected");
						e.stopPropagation();
					};
				})(l));
				l[0].mousedown((function(head,i) {
					return function(e) {
						if(e.which == 3) {
							head[0].click();
							haxe.Timer.delay((function($this) {
								var $r;
								var f = $bind(_g4,_g4.popupLine), a1 = i[0];
								$r = (function() {
									return function() {
										return f(a1);
									};
								})();
								return $r;
							}(this)),1);
							e.preventDefault();
							return;
						}
					};
				})(head,i));
				head[0].appendTo(l[0]);
				$r = l[0];
				return $r;
			}(this)));
		}
		lines = _g1;
		var _g2 = 0;
		var _g3 = s.columns;
		while(_g2 < _g3.length) {
			var c = [_g3[_g2]];
			++_g2;
			var col = new js.JQuery("<td>");
			col.html(c[0].name);
			col.css("width",c[0].size == null?(100 / s.columns.length | 0) + "%":c[0].size + "%");
			if(s.props.displayColumn == c[0].name) col.addClass("display");
			col.mousedown((function(c) {
				return function(e) {
					if(e.which == 3) {
						haxe.Timer.delay((function($this) {
							var $r;
							var f1 = $bind(_g4,_g4.popupColumn), c1 = c[0];
							$r = (function() {
								return function() {
									return f1(c1);
								};
							})();
							return $r;
						}(this)),1);
						e.preventDefault();
						return;
					}
				};
			})(c));
			cols.append(col);
			var ctype = "t_" + types[c[0].type[1]];
			var _g5 = 0;
			var _g41 = s.lines.length;
			while(_g5 < _g41) {
				var index = [_g5++];
				var obj = [s.lines[index[0]]];
				var val = (function($this) {
					var $r;
					var v = null;
					try {
						v = obj[0][c[0].name];
					} catch( e ) {
					}
					$r = v;
					return $r;
				}(this));
				var v1 = [new js.JQuery("<td>").addClass(ctype)];
				v1[0].appendTo(lines[index[0]]);
				var html = this.valueHtml(c[0],val,this.sheet,obj[0]);
				v1[0].html(html);
				var _g6 = c[0].type;
				switch(_g6[1]) {
				case 7:
					v1[0].click((function(v1) {
						return function(e) {
							new js.JQuery(".selected").removeClass("selected");
							v1[0].addClass("selected");
							e.stopPropagation();
						};
					})(v1));
					v1[0].change((function(obj,c) {
						return function(_) {
							if((function($this) {
								var $r;
								var v = null;
								try {
									v = obj[0][c[0].name];
								} catch( e ) {
								}
								$r = v;
								return $r;
							}(this)) != null) {
								Reflect.deleteField(obj[0],c[0].name);
								_g4.refresh();
								_g4.save();
							}
						};
					})(obj,c));
					v1[0].dblclick((function(v1,index,c) {
						return function(_) {
							_g4.editCell(c[0],v1[0],_g4.sheet,index[0]);
						};
					})(v1,index,c));
					break;
				default:
					v1[0].click((function(v1,index,c) {
						return function() {
							_g4.editCell(c[0],v1[0],_g4.sheet,index[0]);
						};
					})(v1,index,c));
				}
			}
		}
		content.html("");
		content.append(cols);
		var snext = 0;
		var _g3 = 0;
		var _g2 = lines.length;
		while(_g3 < _g2) {
			var i = _g3++;
			content.append(lines[i]);
			if(s.separators[snext] == i) {
				new js.JQuery("<tr>").addClass("separator").append("<td colspan=\"" + (s.columns.length + 1) + "\">").appendTo(content);
				snext++;
			}
		}
	}
	,editCell: function(c,v,sheet,index) {
		var _g = this;
		var obj = sheet.lines[index];
		var val = (function($this) {
			var $r;
			var v1 = null;
			try {
				v1 = obj[c.name];
			} catch( e ) {
			}
			$r = v1;
			return $r;
		}(this));
		var html = _g.valueHtml(c,val,sheet,obj);
		if(v.hasClass("edit")) return;
		var editDone = function() {
			v.html(html);
			v.removeClass("edit");
		};
		{
			var _g1 = c.type;
			switch(_g1[1]) {
			case 3:case 4:case 1:case 0:
				v.html("");
				var i = new js.JQuery("<input>");
				v.addClass("edit");
				i.appendTo(v);
				if(val != null) i.val("" + Std.string(val));
				i.keydown(function(e) {
					var _g11 = e.keyCode;
					switch(_g11) {
					case 27:
						editDone();
						break;
					case 13:
						i.blur();
						break;
					case 9:
						i.blur();
						var n = v.next("td");
						while(n.hasClass("t_bool") || n.hasClass("t_enum") || n.hasClass("t_ref")) n = n.next("td");
						n.click();
						e.preventDefault();
						break;
					case 46:
						var val2 = _g.getDefault(c);
						if(val2 != val) {
							val = val2;
							if(val == null) Reflect.deleteField(obj,c.name); else obj[c.name] = val;
						}
						_g.changed(sheet,c);
						html = _g.valueHtml(c,val,sheet,obj);
						editDone();
						break;
					}
					e.stopPropagation();
				});
				i.blur(function(_) {
					var nv = i.val();
					if(nv == "" && c.opt) {
						if(val != null) {
							val = html = null;
							Reflect.deleteField(obj,c.name);
							_g.changed(sheet,c);
						}
					} else {
						var val2;
						var _g11 = c.type;
						switch(_g11[1]) {
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
						if(val2 != val && val2 != null) {
							val = val2;
							obj[c.name] = val;
							_g.changed(sheet,c);
							html = _g.valueHtml(c,val,sheet,obj);
						}
					}
					editDone();
				});
				i.focus();
				break;
			case 5:
				var values = _g1[2];
				v.html("");
				var s = new js.JQuery("<select>");
				v.addClass("edit");
				var _g2 = 0;
				var _g11 = values.length;
				while(_g2 < _g11) {
					var i = _g2++;
					new js.JQuery("<option>").attr("value","" + i).attr(val == i?"selected":"_sel","selected").text(values[i]).appendTo(s);
				}
				if(c.opt) new js.JQuery("<option>").attr("value","-1").text("--- None ---").prependTo(s);
				v.append(s);
				s.change(function(_) {
					val = Std.parseInt(s.val());
					if(val < 0) {
						val = null;
						Reflect.deleteField(obj,c.name);
					} else obj[c.name] = val;
					html = _g.valueHtml(c,val,sheet,obj);
					_g.changed(sheet,c);
					editDone();
				});
				s.blur(function(_) {
					editDone();
				});
				s.focus();
				var event = window.document.createEvent("MouseEvents");
				event.initMouseEvent("mousedown",true,true,window);
				s[0].dispatchEvent(event);
				break;
			case 6:
				var sname = _g1[2];
				var sdat = this.smap.get(sname);
				if(sdat == null) return;
				v.html("");
				var s1 = new js.JQuery("<select>");
				v.addClass("edit");
				var _g11 = 0;
				var _g2 = sdat.all;
				while(_g11 < _g2.length) {
					var l = _g2[_g11];
					++_g11;
					new js.JQuery("<option>").attr("value","" + l.id).attr(val == l.id?"selected":"_sel","selected").text(l.disp).appendTo(s1);
				}
				if(c.opt) new js.JQuery("<option>").attr("value","").text("--- None ---").prependTo(s1);
				v.append(s1);
				s1.change(function(_) {
					val = s1.val();
					if(val == "") {
						val = null;
						Reflect.deleteField(obj,c.name);
					} else obj[c.name] = val;
					html = _g.valueHtml(c,val,sheet,obj);
					_g.changed(sheet,c);
					editDone();
				});
				s1.blur(function(_) {
					editDone();
				});
				s1.focus();
				var event = window.document.createEvent("MouseEvents");
				event.initMouseEvent("mousedown",true,true,window);
				s1[0].dispatchEvent(event);
				break;
			case 2:
				val = !val;
				obj[c.name] = val;
				v.html(_g.valueHtml(c,val,sheet,obj));
				_g.changed(sheet,c);
				break;
			case 7:
				var i = new js.JQuery("<input>").attr("type","file").css("display","none").change(function(e) {
					var j = $(this);
					var file = j.val();
					var ext = file.split(".").pop().toLowerCase();
					if(ext == "jpeg") ext = "jpg";
					if(ext != "png" && ext != "gif" && ext != "jpg") {
						_g.error("Unsupported image extension " + ext);
						return;
					}
					var bytes = sys.io.File.getBytes(file);
					var md5 = haxe.crypto.Md5.make(bytes).toHex();
					if(_g.imageBank == null) _g.imageBank = { };
					if(!Reflect.hasField(_g.imageBank,md5)) {
						var data = "data:image/" + ext + ";base64," + new haxe.crypto.BaseCode(haxe.io.Bytes.ofString("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")).encodeBytes(bytes).toString();
						_g.imageBank[md5] = data;
					}
					val = md5;
					obj[c.name] = val;
					v.html(_g.valueHtml(c,val,sheet,obj));
					_g.changed(sheet,c);
					j.remove();
				});
				i.appendTo(new js.JQuery("body"));
				i.click();
				break;
			}
		}
	}
	,popupColumn: function(c) {
		var _g = this;
		var n = new nodejs.webkit.Menu();
		var nedit = new nodejs.webkit.MenuItem({ label : "Edit"});
		var nins = new nodejs.webkit.MenuItem({ label : "Add Column"});
		var nleft = new nodejs.webkit.MenuItem({ label : "Move Left"});
		var nright = new nodejs.webkit.MenuItem({ label : "Move Right"});
		var ndel = new nodejs.webkit.MenuItem({ label : "Delete"});
		var ndisp = new nodejs.webkit.MenuItem({ label : "Display Column", type : "checkbox"});
		var _g1 = 0;
		var _g11 = [nedit,nins,nleft,nright,ndel,ndisp];
		while(_g1 < _g11.length) {
			var m = _g11[_g1];
			++_g1;
			n.append(m);
		}
		ndisp.checked = this.sheet.props.displayColumn == c.name;
		nedit.click = function() {
			_g.newColumn(c);
		};
		nleft.click = function() {
			var index = Lambda.indexOf(_g.sheet.columns,c);
			if(index > 0) {
				HxOverrides.remove(_g.sheet.columns,c);
				_g.sheet.columns.splice(index - 1,0,c);
				_g.refresh();
				_g.save();
			}
		};
		nright.click = function() {
			var index = Lambda.indexOf(_g.sheet.columns,c);
			if(index < _g.sheet.columns.length - 1) {
				HxOverrides.remove(_g.sheet.columns,c);
				_g.sheet.columns.splice(index + 1,0,c);
				_g.refresh();
				_g.save();
			}
		};
		ndel.click = function() {
			_g.deleteColumn(c.name);
		};
		ndisp.click = function() {
			if(_g.sheet.props.displayColumn == c.name) _g.sheet.props.displayColumn = null; else _g.sheet.props.displayColumn = c.name;
			_g.makeSheet(_g.sheet);
			_g.refresh();
			_g.save();
		};
		nins.click = function() {
			_g.newColumn();
		};
		n.popup(this.mousePos.x,this.mousePos.y);
	}
	,popupLine: function(index) {
		var _g = this;
		var n = new nodejs.webkit.Menu();
		var nup = new nodejs.webkit.MenuItem({ label : "Move Up"});
		var ndown = new nodejs.webkit.MenuItem({ label : "Move Down"});
		var nins = new nodejs.webkit.MenuItem({ label : "Insert"});
		var ndel = new nodejs.webkit.MenuItem({ label : "Delete"});
		var nsep = new nodejs.webkit.MenuItem({ label : "Separator", type : "checkbox"});
		var _g1 = 0;
		var _g11 = [nup,ndown,nins,ndel,nsep];
		while(_g1 < _g11.length) {
			var m = _g11[_g1];
			++_g1;
			n.append(m);
		}
		var hasSep = Lambda.has(this.sheet.separators,index);
		nsep.checked = hasSep;
		nins.click = function() {
			_g.newLine(index);
		};
		nup.click = function() {
			_g.moveColumn(index,-1);
		};
		ndown.click = function() {
			_g.moveColumn(index,1);
		};
		ndel.click = function() {
			_g.deleteLine(_g.sheet,index);
			_g.refresh();
			_g.save();
		};
		nsep.click = function() {
			if(hasSep) HxOverrides.remove(_g.sheet.separators,index); else {
				_g.sheet.separators.push(index);
				_g.sheet.separators.sort(Reflect.compare);
			}
			_g.refresh();
			_g.save();
		};
		n.popup(this.mousePos.x,this.mousePos.y);
	}
	,valueHtml: function(c,v,sheet,obj) {
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
				if(v == "") return "<span class=\"error\">#MISSING</span>"; else if(((function($this) {
					var $r;
					var key = v;
					$r = $this.smap.get(sheet.name).index.get(key);
					return $r;
				}(this))).obj == obj) return v; else return "<span class=\"error\">#DUP(" + Std.string(v) + ")</span>";
				break;
			case 1:
				if(v == "") return "&nbsp;"; else return StringTools.htmlEscape(v);
				break;
			case 6:
				var sname = _g[2];
				if(v == "") return "<span class=\"error\">#MISSING</span>"; else {
					var s = this.smap.get(sname);
					var i;
					var key = v;
					i = s.index.get(key);
					if(i == null) return "<span class=\"error\">#REF(" + Std.string(v) + ")</span>"; else return StringTools.htmlEscape(i.disp);
				}
				break;
			case 2:
				if(v) return "Y"; else return "N";
				break;
			case 5:
				var values = _g[2];
				return values[v];
			case 7:
				if(v == "") return "<span class=\"error\">#MISSING</span>"; else {
					var data;
					var field = v;
					var v1 = null;
					try {
						v1 = this.imageBank[field];
					} catch( e ) {
					}
					data = v1;
					if(data == null) return "<span class=\"error\">#NOTFOUND(" + Std.string(v) + ")</span>"; else return "<img src=\"" + data + "\"/>";
				}
				break;
			}
		}
	}
	,makeSheet: function(s) {
		var sdat = { s : s, index : new haxe.ds.StringMap(), all : []};
		var cid = null;
		var _g = 0;
		var _g1 = s.columns;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			if(c.type == ColumnType.TId) {
				var _g2 = 0;
				var _g3 = s.lines;
				while(_g2 < _g3.length) {
					var l = _g3[_g2];
					++_g2;
					var v = (function($this) {
						var $r;
						var v1 = null;
						try {
							v1 = l[c.name];
						} catch( e ) {
						}
						$r = v1;
						return $r;
					}(this));
					if(v != null && v != "") {
						var disp = v;
						if(s.props.displayColumn != null) {
							var v1 = null;
							try {
								v1 = l[s.props.displayColumn];
							} catch( e ) {
							}
							disp = v1;
							if(disp == null || disp == "") disp = "#" + v;
						}
						var o = { id : v, disp : disp, obj : l};
						if(sdat.index.get(v) == null) sdat.index.set(v,o);
						sdat.all.push(o);
					}
				}
				break;
			}
		}
		this.smap.set(s.name,sdat);
	}
	,error: function(msg) {
		js.Lib.alert(msg);
	}
	,quickLoad: function(data) {
		return haxe.Unserializer.run(data);
	}
	,quickSave: function() {
		return haxe.Serializer.run(this.data);
	}
	,saveImages: function() {
		if(this.prefs.curFile == null) return;
		var img = this.prefs.curFile.split(".");
		img.pop();
		var path = img.join(".") + ".img";
		if(this.imageBank == null) js.Node.require("fs").unlinkSync(path); else sys.io.File.saveContent(path,js.Node.stringify(this.imageBank,null,"\t"));
	}
	,save: function(history) {
		if(history == null) history = true;
		if(history) {
			var sdata = this.quickSave();
			if(sdata != this.curSavedData) {
				if(this.curSavedData != null) {
					this.history.push(this.curSavedData);
					this.redo = [];
				}
				this.curSavedData = sdata;
			}
		}
		if(this.prefs.curFile == null) return;
		var save = [];
		var _g = 0;
		var _g1 = this.data.sheets;
		while(_g < _g1.length) {
			var s = _g1[_g];
			++_g;
			var _g2 = 0;
			var _g3 = s.columns;
			while(_g2 < _g3.length) {
				var c = _g3[_g2];
				++_g2;
				save.push(c.type);
				if(c.typeStr == null) c.typeStr = haxe.Serializer.run(c.type);
				c.type = null;
			}
		}
		sys.io.File.saveContent(this.prefs.curFile,js.Node.stringify(this.data,null,"\t"));
		var _g = 0;
		var _g1 = this.data.sheets;
		while(_g < _g1.length) {
			var s = _g1[_g];
			++_g;
			var _g2 = 0;
			var _g3 = s.columns;
			while(_g2 < _g3.length) {
				var c = _g3[_g2];
				++_g2;
				c.type = save.shift();
			}
		}
	}
	,load: function(noError) {
		if(noError == null) noError = false;
		this.history = [];
		this.redo = [];
		try {
			var jsonString = sys.io.File.getContent(this.prefs.curFile);
			this.data = js.Node.parse(jsonString);
			var _g = 0;
			var _g1 = this.data.sheets;
			while(_g < _g1.length) {
				var s = _g1[_g];
				++_g;
				var _g2 = 0;
				var _g3 = s.columns;
				while(_g2 < _g3.length) {
					var c = _g3[_g2];
					++_g2;
					c.type = haxe.Unserializer.run(c.typeStr);
				}
			}
		} catch( e ) {
			if(!noError) js.Lib.alert(e);
			this.prefs.curFile = null;
			this.prefs.curSheet = 0;
			this.data = { sheets : []};
		}
		try {
			var img = this.prefs.curFile.split(".");
			img.pop();
			var jsonString = sys.io.File.getContent(img.join(".") + ".img");
			this.imageBank = js.Node.parse(jsonString);
		} catch( e ) {
			this.imageBank = null;
		}
		this.curSavedData = this.quickSave();
		this.initContent();
	}
	,changed: function(sheet,c) {
		this.save();
		var _g = c.type;
		switch(_g[1]) {
		case 0:
			this.makeSheet(sheet);
			break;
		case 7:
			this.saveImages();
			break;
		default:
		}
	}
	,moveColumn: function(index,delta) {
		if(delta < 0 && index > 0) {
			var l = this.sheet.lines[index];
			this.sheet.lines.splice(index,1);
			this.sheet.lines.splice(index - 1,0,l);
			this.refresh();
			this.save();
			this.selectLine(index);
		} else if(delta > 0 && this.sheet != null && index < this.sheet.lines.length - 1) {
			var l = this.sheet.lines[index];
			this.sheet.lines.splice(index,1);
			this.sheet.lines.splice(index + 1,0,l);
			this.refresh();
			this.save();
			this.selectLine(index + 2);
		}
	}
	,selectLine: function(index) {
		((function($this) {
			var $r;
			var html = new js.JQuery("#content tr").not(".separator")[index];
			$r = new js.JQuery(html);
			return $r;
		}(this))).addClass("selected");
	}
	,onKey: function(e) {
		var _g = e.keyCode;
		switch(_g) {
		case 45:
			if(this.sheet != null) this.newLine(Std.parseInt(new js.JQuery("tr.selected").data("index")));
			break;
		case 46:
			var indexes;
			var _g1 = [];
			var $it0 = (function($this) {
				var $r;
				var _this = new js.JQuery(".selected");
				$r = (_this.iterator)();
				return $r;
			}(this));
			while( $it0.hasNext() ) {
				var i = $it0.next();
				_g1.push((function($this) {
					var $r;
					i.change();
					$r = Std.parseInt(i.data("index"));
					return $r;
				}(this)));
			}
			indexes = _g1;
			while(HxOverrides.remove(indexes,null)) {
			}
			if(indexes.length == 0) return;
			indexes.sort(function(a,b) {
				return b - a;
			});
			var _g2 = 0;
			while(_g2 < indexes.length) {
				var i = indexes[_g2];
				++_g2;
				this.deleteLine(this.sheet,i);
			}
			this.refresh();
			this.save();
			break;
		case 38:
			var index = new js.JQuery("tr.selected").data("index");
			this.moveColumn(index,-1);
			break;
		case 40:
			var index = new js.JQuery("tr.selected").data("index");
			this.moveColumn(index,1);
			break;
		case 90:
			if(e.ctrlKey && this.history.length > 0) {
				this.redo.push(this.curSavedData);
				this.curSavedData = this.history.pop();
				this.data = this.quickLoad(this.curSavedData);
				this.initContent();
				this.save(false);
			}
			break;
		case 89:
			if(e.ctrlKey && this.redo.length > 0) {
				this.history.push(this.curSavedData);
				this.curSavedData = this.redo.pop();
				this.data = this.quickLoad(this.curSavedData);
				this.initContent();
				this.save(false);
			}
			break;
		default:
		}
	}
	,onMouseMove: function(e) {
		this.mousePos.x = e.clientX;
		this.mousePos.y = e.clientY;
	}
	,getDefault: function(c) {
		if(c.opt) return null;
		{
			var _g = c.type;
			switch(_g[1]) {
			case 3:case 4:case 5:
				return 0;
			case 1:case 0:case 6:case 7:
				return "";
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
IMap.prototype = {
	__class__: IMap
}
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
Reflect.compare = function(a,b) {
	if(a == b) return 0; else if(a > b) return 1; else return -1;
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
Std["int"] = function(x) {
	return x | 0;
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
Type.enumEq = function(a,b) {
	if(a == b) return true;
	try {
		if(a[0] != b[0]) return false;
		var _g1 = 2;
		var _g = a.length;
		while(_g1 < _g) {
			var i = _g1++;
			if(!Type.enumEq(a[i],b[i])) return false;
		}
		var e = a.__enum__;
		if(e != b.__enum__ || e == null) return false;
	} catch( e ) {
		return false;
	}
	return true;
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
haxe.Timer = function(time_ms) {
	var me = this;
	this.id = setInterval(function() {
		me.run();
	},time_ms);
};
$hxClasses["haxe.Timer"] = haxe.Timer;
haxe.Timer.__name__ = ["haxe","Timer"];
haxe.Timer.delay = function(f,time_ms) {
	var t = new haxe.Timer(time_ms);
	t.run = function() {
		t.stop();
		f();
	};
	return t;
}
haxe.Timer.prototype = {
	run: function() {
	}
	,stop: function() {
		if(this.id == null) return;
		clearInterval(this.id);
		this.id = null;
	}
	,__class__: haxe.Timer
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
haxe.crypto = {}
haxe.crypto.BaseCode = function(base) {
	var len = base.length;
	var nbits = 1;
	while(len > 1 << nbits) nbits++;
	if(nbits > 8 || len != 1 << nbits) throw "BaseCode : base length must be a power of two.";
	this.base = base;
	this.nbits = nbits;
};
$hxClasses["haxe.crypto.BaseCode"] = haxe.crypto.BaseCode;
haxe.crypto.BaseCode.__name__ = ["haxe","crypto","BaseCode"];
haxe.crypto.BaseCode.prototype = {
	encodeBytes: function(b) {
		var nbits = this.nbits;
		var base = this.base;
		var size = b.length * 8 / nbits | 0;
		var out = haxe.io.Bytes.alloc(size + (b.length * 8 % nbits == 0?0:1));
		var buf = 0;
		var curbits = 0;
		var mask = (1 << nbits) - 1;
		var pin = 0;
		var pout = 0;
		while(pout < size) {
			while(curbits < nbits) {
				curbits += 8;
				buf <<= 8;
				buf |= (function($this) {
					var $r;
					var pos = pin++;
					$r = b.b[pos];
					return $r;
				}(this));
			}
			curbits -= nbits;
			var pos = pout++;
			out.b[pos] = base.b[buf >> curbits & mask];
		}
		if(curbits > 0) {
			var pos = pout++;
			out.b[pos] = base.b[buf << nbits - curbits & mask];
		}
		return out;
	}
	,__class__: haxe.crypto.BaseCode
}
haxe.crypto.Md5 = function() {
};
$hxClasses["haxe.crypto.Md5"] = haxe.crypto.Md5;
haxe.crypto.Md5.__name__ = ["haxe","crypto","Md5"];
haxe.crypto.Md5.make = function(b) {
	var h = new haxe.crypto.Md5().doEncode(haxe.crypto.Md5.bytes2blks(b));
	var out = haxe.io.Bytes.alloc(16);
	var p = 0;
	var _g = 0;
	while(_g < 4) {
		var i = _g++;
		var pos = p++;
		out.b[pos] = h[i] & 255;
		var pos = p++;
		out.b[pos] = h[i] >> 8 & 255;
		var pos = p++;
		out.b[pos] = h[i] >> 16 & 255;
		var pos = p++;
		out.b[pos] = h[i] >>> 24;
	}
	return out;
}
haxe.crypto.Md5.bytes2blks = function(b) {
	var nblk = (b.length + 8 >> 6) + 1;
	var blks = new Array();
	var blksSize = nblk * 16;
	var _g = 0;
	while(_g < blksSize) {
		var i = _g++;
		blks[i] = 0;
	}
	var i = 0;
	while(i < b.length) {
		blks[i >> 2] |= b.b[i] << (((b.length << 3) + i & 3) << 3);
		i++;
	}
	blks[i >> 2] |= 128 << (b.length * 8 + i) % 4 * 8;
	var l = b.length * 8;
	var k = nblk * 16 - 2;
	blks[k] = l & 255;
	blks[k] |= (l >>> 8 & 255) << 8;
	blks[k] |= (l >>> 16 & 255) << 16;
	blks[k] |= (l >>> 24 & 255) << 24;
	return blks;
}
haxe.crypto.Md5.prototype = {
	doEncode: function(x) {
		var a = 1732584193;
		var b = -271733879;
		var c = -1732584194;
		var d = 271733878;
		var step;
		var i = 0;
		while(i < x.length) {
			var olda = a;
			var oldb = b;
			var oldc = c;
			var oldd = d;
			step = 0;
			a = this.ff(a,b,c,d,x[i],7,-680876936);
			d = this.ff(d,a,b,c,x[i + 1],12,-389564586);
			c = this.ff(c,d,a,b,x[i + 2],17,606105819);
			b = this.ff(b,c,d,a,x[i + 3],22,-1044525330);
			a = this.ff(a,b,c,d,x[i + 4],7,-176418897);
			d = this.ff(d,a,b,c,x[i + 5],12,1200080426);
			c = this.ff(c,d,a,b,x[i + 6],17,-1473231341);
			b = this.ff(b,c,d,a,x[i + 7],22,-45705983);
			a = this.ff(a,b,c,d,x[i + 8],7,1770035416);
			d = this.ff(d,a,b,c,x[i + 9],12,-1958414417);
			c = this.ff(c,d,a,b,x[i + 10],17,-42063);
			b = this.ff(b,c,d,a,x[i + 11],22,-1990404162);
			a = this.ff(a,b,c,d,x[i + 12],7,1804603682);
			d = this.ff(d,a,b,c,x[i + 13],12,-40341101);
			c = this.ff(c,d,a,b,x[i + 14],17,-1502002290);
			b = this.ff(b,c,d,a,x[i + 15],22,1236535329);
			a = this.gg(a,b,c,d,x[i + 1],5,-165796510);
			d = this.gg(d,a,b,c,x[i + 6],9,-1069501632);
			c = this.gg(c,d,a,b,x[i + 11],14,643717713);
			b = this.gg(b,c,d,a,x[i],20,-373897302);
			a = this.gg(a,b,c,d,x[i + 5],5,-701558691);
			d = this.gg(d,a,b,c,x[i + 10],9,38016083);
			c = this.gg(c,d,a,b,x[i + 15],14,-660478335);
			b = this.gg(b,c,d,a,x[i + 4],20,-405537848);
			a = this.gg(a,b,c,d,x[i + 9],5,568446438);
			d = this.gg(d,a,b,c,x[i + 14],9,-1019803690);
			c = this.gg(c,d,a,b,x[i + 3],14,-187363961);
			b = this.gg(b,c,d,a,x[i + 8],20,1163531501);
			a = this.gg(a,b,c,d,x[i + 13],5,-1444681467);
			d = this.gg(d,a,b,c,x[i + 2],9,-51403784);
			c = this.gg(c,d,a,b,x[i + 7],14,1735328473);
			b = this.gg(b,c,d,a,x[i + 12],20,-1926607734);
			a = this.hh(a,b,c,d,x[i + 5],4,-378558);
			d = this.hh(d,a,b,c,x[i + 8],11,-2022574463);
			c = this.hh(c,d,a,b,x[i + 11],16,1839030562);
			b = this.hh(b,c,d,a,x[i + 14],23,-35309556);
			a = this.hh(a,b,c,d,x[i + 1],4,-1530992060);
			d = this.hh(d,a,b,c,x[i + 4],11,1272893353);
			c = this.hh(c,d,a,b,x[i + 7],16,-155497632);
			b = this.hh(b,c,d,a,x[i + 10],23,-1094730640);
			a = this.hh(a,b,c,d,x[i + 13],4,681279174);
			d = this.hh(d,a,b,c,x[i],11,-358537222);
			c = this.hh(c,d,a,b,x[i + 3],16,-722521979);
			b = this.hh(b,c,d,a,x[i + 6],23,76029189);
			a = this.hh(a,b,c,d,x[i + 9],4,-640364487);
			d = this.hh(d,a,b,c,x[i + 12],11,-421815835);
			c = this.hh(c,d,a,b,x[i + 15],16,530742520);
			b = this.hh(b,c,d,a,x[i + 2],23,-995338651);
			a = this.ii(a,b,c,d,x[i],6,-198630844);
			d = this.ii(d,a,b,c,x[i + 7],10,1126891415);
			c = this.ii(c,d,a,b,x[i + 14],15,-1416354905);
			b = this.ii(b,c,d,a,x[i + 5],21,-57434055);
			a = this.ii(a,b,c,d,x[i + 12],6,1700485571);
			d = this.ii(d,a,b,c,x[i + 3],10,-1894986606);
			c = this.ii(c,d,a,b,x[i + 10],15,-1051523);
			b = this.ii(b,c,d,a,x[i + 1],21,-2054922799);
			a = this.ii(a,b,c,d,x[i + 8],6,1873313359);
			d = this.ii(d,a,b,c,x[i + 15],10,-30611744);
			c = this.ii(c,d,a,b,x[i + 6],15,-1560198380);
			b = this.ii(b,c,d,a,x[i + 13],21,1309151649);
			a = this.ii(a,b,c,d,x[i + 4],6,-145523070);
			d = this.ii(d,a,b,c,x[i + 11],10,-1120210379);
			c = this.ii(c,d,a,b,x[i + 2],15,718787259);
			b = this.ii(b,c,d,a,x[i + 9],21,-343485551);
			a = this.addme(a,olda);
			b = this.addme(b,oldb);
			c = this.addme(c,oldc);
			d = this.addme(d,oldd);
			i += 16;
		}
		return [a,b,c,d];
	}
	,ii: function(a,b,c,d,x,s,t) {
		return this.cmn(this.bitXOR(c,this.bitOR(b,~d)),a,b,x,s,t);
	}
	,hh: function(a,b,c,d,x,s,t) {
		return this.cmn(this.bitXOR(this.bitXOR(b,c),d),a,b,x,s,t);
	}
	,gg: function(a,b,c,d,x,s,t) {
		return this.cmn(this.bitOR(this.bitAND(b,d),this.bitAND(c,~d)),a,b,x,s,t);
	}
	,ff: function(a,b,c,d,x,s,t) {
		return this.cmn(this.bitOR(this.bitAND(b,c),this.bitAND(~b,d)),a,b,x,s,t);
	}
	,cmn: function(q,a,b,x,s,t) {
		return this.addme(this.rol(this.addme(this.addme(a,q),this.addme(x,t)),s),b);
	}
	,rol: function(num,cnt) {
		return num << cnt | num >>> 32 - cnt;
	}
	,addme: function(x,y) {
		var lsw = (x & 65535) + (y & 65535);
		var msw = (x >> 16) + (y >> 16) + (lsw >> 16);
		return msw << 16 | lsw & 65535;
	}
	,bitAND: function(a,b) {
		var lsb = a & 1 & (b & 1);
		var msb31 = a >>> 1 & b >>> 1;
		return msb31 << 1 | lsb;
	}
	,bitXOR: function(a,b) {
		var lsb = a & 1 ^ b & 1;
		var msb31 = a >>> 1 ^ b >>> 1;
		return msb31 << 1 | lsb;
	}
	,bitOR: function(a,b) {
		var lsb = a & 1 | b & 1;
		var msb31 = a >>> 1 | b >>> 1;
		return msb31 << 1 | lsb;
	}
	,__class__: haxe.crypto.Md5
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
	,get: function(key) {
		return this.h[key.__id__];
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
	,toHex: function() {
		var s = new StringBuf();
		var chars = [];
		var str = "0123456789abcdef";
		var _g1 = 0;
		var _g = str.length;
		while(_g1 < _g) {
			var i = _g1++;
			chars.push(HxOverrides.cca(str,i));
		}
		var _g1 = 0;
		var _g = this.length;
		while(_g1 < _g) {
			var i = _g1++;
			var c = this.b[i];
			s.b += String.fromCharCode(chars[c >> 4]);
			s.b += String.fromCharCode(chars[c & 15]);
		}
		return s.b;
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
js.Lib = function() { }
$hxClasses["js.Lib"] = js.Lib;
js.Lib.__name__ = ["js","Lib"];
js.Lib.alert = function(v) {
	alert(js.Boot.__string_rec(v,""));
}
js.NodeC = function() { }
$hxClasses["js.NodeC"] = js.NodeC;
js.NodeC.__name__ = ["js","NodeC"];
js.Node = function() { }
$hxClasses["js.Node"] = js.Node;
js.Node.__name__ = ["js","Node"];
js.Node.get_assert = function() {
	return js.Node.require("assert");
}
js.Node.get_childProcess = function() {
	return js.Node.require("child_process");
}
js.Node.get_cluster = function() {
	return js.Node.require("cluster");
}
js.Node.get_crypto = function() {
	return js.Node.require("crypto");
}
js.Node.get_dgram = function() {
	return js.Node.require("dgram");
}
js.Node.get_dns = function() {
	return js.Node.require("dns");
}
js.Node.get_fs = function() {
	return js.Node.require("fs");
}
js.Node.get_http = function() {
	return js.Node.require("http");
}
js.Node.get_https = function() {
	return js.Node.require("https");
}
js.Node.get_net = function() {
	return js.Node.require("net");
}
js.Node.get_os = function() {
	return js.Node.require("os");
}
js.Node.get_path = function() {
	return js.Node.require("path");
}
js.Node.get_querystring = function() {
	return js.Node.require("querystring");
}
js.Node.get_repl = function() {
	return js.Node.require("repl");
}
js.Node.get_tls = function() {
	return js.Node.require("tls");
}
js.Node.get_url = function() {
	return js.Node.require("url");
}
js.Node.get_util = function() {
	return js.Node.require("util");
}
js.Node.get_vm = function() {
	return js.Node.require("vm");
}
js.Node.get___filename = function() {
	return __filename;
}
js.Node.get___dirname = function() {
	return __dirname;
}
js.Node.newSocket = function(options) {
	return new js.Node.net.Socket(options);
}
var nodejs = {}
nodejs.webkit = {}
nodejs.webkit.$ui = function() { }
$hxClasses["nodejs.webkit.$ui"] = nodejs.webkit.$ui;
nodejs.webkit.$ui.__name__ = ["nodejs","webkit","$ui"];
nodejs.webkit._MenuItemType = {}
nodejs.webkit._MenuItemType.MenuItemType_Impl_ = function() { }
$hxClasses["nodejs.webkit._MenuItemType.MenuItemType_Impl_"] = nodejs.webkit._MenuItemType.MenuItemType_Impl_;
nodejs.webkit._MenuItemType.MenuItemType_Impl_.__name__ = ["nodejs","webkit","_MenuItemType","MenuItemType_Impl_"];
var sys = {}
sys.FileSystem = function() { }
$hxClasses["sys.FileSystem"] = sys.FileSystem;
sys.FileSystem.__name__ = ["sys","FileSystem"];
sys.FileSystem.exists = function(path) {
	return js.Node.require("fs").existsSync(path);
}
sys.FileSystem.rename = function(path,newpath) {
	js.Node.require("fs").renameSync(path,newpath);
}
sys.FileSystem.stat = function(path) {
	return js.Node.require("fs").statSync(path);
}
sys.FileSystem.fullPath = function(relpath) {
	return js.Node.require("path").resolve(null,relpath);
}
sys.FileSystem.isDirectory = function(path) {
	if(js.Node.require("fs").statSync(path).isSymbolicLink()) return false; else return js.Node.require("fs").statSync(path).isDirectory();
}
sys.FileSystem.createDirectory = function(path) {
	js.Node.require("fs").mkdirSync(path);
}
sys.FileSystem.deleteFile = function(path) {
	js.Node.require("fs").unlinkSync(path);
}
sys.FileSystem.deleteDirectory = function(path) {
	js.Node.require("fs").rmdirSync(path);
}
sys.FileSystem.readDirectory = function(path) {
	return js.Node.require("fs").readdirSync(path);
}
sys.FileSystem.signature = function(path) {
	var shasum = js.Node.require("crypto").createHash("md5");
	shasum.update(js.Node.require("fs").readFileSync(path));
	return shasum.digest("hex");
}
sys.FileSystem.join = function(p1,p2,p3) {
	return js.Node.require("path").join(p1 == null?"":p1,p2 == null?"":p2,p3 == null?"":p3);
}
sys.FileSystem.readRecursive = function(path,filter) {
	var files = sys.FileSystem.readRecursiveInternal(path,null,filter);
	if(files == null) return []; else return files;
}
sys.FileSystem.readRecursiveInternal = function(root,dir,filter) {
	if(dir == null) dir = "";
	if(root == null) return null;
	var dirPath = js.Node.require("path").join(root == null?"":root,dir == null?"":dir,"");
	if(!(js.Node.require("fs").existsSync(dirPath) && sys.FileSystem.isDirectory(dirPath))) return null;
	var result = [];
	var _g = 0;
	var _g1 = js.Node.require("fs").readdirSync(dirPath);
	while(_g < _g1.length) {
		var file = _g1[_g];
		++_g;
		var fullPath = js.Node.require("path").join(dirPath == null?"":dirPath,file == null?"":file,"");
		var relPath;
		if(dir == "") relPath = file; else relPath = js.Node.require("path").join(dir == null?"":dir,file == null?"":file,"");
		if(js.Node.require("fs").existsSync(fullPath)) {
			if(sys.FileSystem.isDirectory(fullPath)) {
				if(fullPath.charCodeAt(fullPath.length - 1) == 47) fullPath = HxOverrides.substr(fullPath,0,-1);
				if(filter != null && !filter(relPath)) continue;
				var recursedResults = sys.FileSystem.readRecursiveInternal(root,relPath,filter);
				if(recursedResults != null && recursedResults.length > 0) result = result.concat(recursedResults);
			} else if(filter == null || filter(relPath)) result.push(relPath);
		}
	}
	return result;
}
sys.io = {}
sys.io.File = function() { }
$hxClasses["sys.io.File"] = sys.io.File;
sys.io.File.__name__ = ["sys","io","File"];
sys.io.File.append = function(path,binary) {
	throw "Not implemented";
	return null;
}
sys.io.File.copy = function(src,dst) {
	var content = js.Node.require("fs").readFileSync(src);
	js.Node.require("fs").writeFileSync(dst,content);
}
sys.io.File.getBytes = function(path) {
	var o = js.Node.require("fs").openSync(path,"r");
	var s = js.Node.require("fs").fstatSync(o);
	var len = s.size;
	var pos = 0;
	var bytes = haxe.io.Bytes.alloc(s.size);
	while(len > 0) {
		var r = js.Node.require("fs").readSync(o,bytes.b,pos,len,null);
		pos += r;
		len -= r;
	}
	js.Node.require("fs").closeSync(o);
	return bytes;
}
sys.io.File.getContent = function(path) {
	return js.Node.require("fs").readFileSync(path);
}
sys.io.File.saveContent = function(path,content) {
	js.Node.require("fs").writeFileSync(path,content);
}
sys.io.File.write = function(path,binary) {
	throw "Not implemented";
	return null;
}
function $iterator(o) { if( o instanceof Array ) return function() { return HxOverrides.iter(o); }; return typeof(o.iterator) == 'function' ? $bind(o,o.iterator) : o.iterator; };
var $_, $fid = 0;
function $bind(o,m) { if( m == null ) return null; if( m.__id__ == null ) m.__id__ = $fid++; var f; if( o.hx__closures__ == null ) o.hx__closures__ = {}; else f = o.hx__closures__[m.__id__]; if( f == null ) { f = function(){ return f.method.apply(f.scope, arguments); }; f.scope = o; f.method = m; o.hx__closures__[m.__id__] = f; } return f; };
if(Array.prototype.indexOf) HxOverrides.remove = function(a,o) {
	var i = a.indexOf(o);
	if(i == -1) return false;
	a.splice(i,1);
	return true;
};
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
if(Array.prototype.map == null) Array.prototype.map = function(f) {
	var a = [];
	var _g1 = 0;
	var _g = this.length;
	while(_g1 < _g) {
		var i = _g1++;
		a[i] = f(this[i]);
	}
	return a;
};
var q = window.jQuery;
js.JQuery = q;
q.fn.iterator = function() {
	return { pos : 0, j : this, hasNext : function() {
		return this.pos < this.j.length;
	}, next : function() {
		return $(this.j[this.pos++]);
	}};
};
var module, setImmediate, clearImmediate;
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
var version = HxOverrides.substr(js.Node.process.version,1,null).split(".").map(Std.parseInt);
if(version[0] > 0 || version[1] >= 9) {
	js.Node.setImmediate = setImmediate;
	js.Node.clearImmediate = clearImmediate;
}
nodejs.webkit.$ui = require('nw.gui');
nodejs.webkit.Menu = nodejs.webkit.$ui.Menu;
nodejs.webkit.MenuItem = nodejs.webkit.$ui.MenuItem;
nodejs.webkit.Window = nodejs.webkit.$ui.Window;
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
nodejs.webkit._MenuItemType.MenuItemType_Impl_.separator = "separator";
nodejs.webkit._MenuItemType.MenuItemType_Impl_.checkbox = "checkbox";
nodejs.webkit._MenuItemType.MenuItemType_Impl_.normal = "normal";
Main.main();
})();
